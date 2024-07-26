terraform {
  required_providers {
    qovery = {
      source = "qovery/qovery"
    }
  }
}

provider "qovery" {
  token = var.qovery_access_token
}

data "local_file" "airbyte_values" {
  filename = "${path.module}/airbyte-values.yaml"
}

resource "qovery_environment" "airbyte_environment" {
  project_id = var.qovery_project_id
  cluster_id = var.qovery_cluster_id
  name       = "airbyte-production"
  mode       = "PRODUCTION"
}

resource "qovery_deployment_stage" "database" {
  environment_id = qovery_environment.airbyte_environment.id
  name           = "Database Stage"
}

resource "qovery_deployment_stage" "init" {
  environment_id = qovery_environment.airbyte_environment.id
  name           = "Init Stage"

  is_after = qovery_deployment_stage.database.id
}

resource "qovery_deployment_stage" "app" {
  environment_id = qovery_environment.airbyte_environment.id
  name           = "Apps Stage"

  is_after = qovery_deployment_stage.init.id
}

resource "qovery_database" "airbyte_database" {
  environment_id      = qovery_environment.airbyte_environment.id
  deployment_stage_id = qovery_deployment_stage.database.id
  name                = "Database"
  type                = "POSTGRESQL"
  version             = "16"
  storage             = 20
  mode                = "CONTAINER"
  accessibility       = "PRIVATE"
}

resource "qovery_job" "airbyte_database_init" {
  environment_id      = qovery_environment.airbyte_environment.id
  deployment_stage_id = qovery_deployment_stage.init.id
  name                = "DB Init Script"
  cpu                 = 100
  memory              = 64
  healthchecks = {}
  source = {
    docker = {
      git_repository = {
        url       = "https://github.com/evoxmusic/qovery-airbyte.git"
        branch    = "main"
        root_path = "/"
      }
      dockerfile_path = "Dockerfile.dbinit"
    }
  }
  schedule = {
    lifecycle_type = "GENERIC"
    on_start = {
      arguments = ["/app/init_db.sh"]
      entrypoint = ""
    }
    on_stop   = null
    on_delete = null
  }
  environment_variables = [
    {
      key   = "DATABASE_USER"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_LOGIN"
    }
  ]
  secret_aliases = [
    {
      key   = "DATABASE_URL"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_DATABASE_URL_INTERNAL"
    }
  ]
}

resource "qovery_helm_repository" "airbyte_helm_repository" {
  organization_id       = var.qovery_organization_id
  name                  = "Airbyte"
  kind                  = "HTTPS"
  url                   = "https://airbytehq.github.io/helm-charts"
  skip_tls_verification = false
  description           = "Airbyte Helm repository"
}

resource "qovery_helm" "airbyte_helm" {
  environment_id      = qovery_environment.airbyte_environment.id
  deployment_stage_id = qovery_deployment_stage.app.id
  name                = var.airbyte_service_name
  source = {
    helm_repository = {

      helm_repository_id = qovery_helm_repository.airbyte_helm_repository.id
      chart_name         = "airbyte"
      chart_version      = var.airbyte_helm_version
    }
  }
  allow_cluster_wide_resources = true
  values_override = {
    file = {
      raw = {
        file1 = {
          content = data.local_file.airbyte_values.content
        }
      }
    }
  }
  environment_variable_aliases = [
    {
      key   = "DATABASE_HOST"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_HOST_INTERNAL"
    },
    {
      key   = "DATABASE_NAME"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_DEFAULT_DATABASE_NAME"
    },
    {
      key   = "DATABASE_USER"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_LOGIN"
    },
    {
      key   = "DATABASE_PORT"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_PORT"
    }
  ]
  environment_variables = [
    {
      key = "DATABASE_JDBC_URL"
      // Interpolated by Qovery dynamically
      value = "jdbc:postgresql://{{DATABASE_USER}}:{{DATABASE_PASSWORD}}@{{DATABASE_HOST}}:{{DATABASE_PORT}}/{{DATABASE_NAME}}"
    }
  ]
  secret_aliases = [
    {
      key   = "DATABASE_URL"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_DATABASE_URL_INTERNAL"
    },
    {
      key   = "DATABASE_PASSWORD"
      value = "QOVERY_POSTGRESQL_Z${upper(element(split("-", qovery_database.airbyte_database.id), 0))}_PASSWORD"
    }
  ]
}

resource "qovery_application" "airbyte_webapp_proxy" {
  environment_id      = qovery_environment.airbyte_environment.id
  deployment_stage_id = qovery_deployment_stage.app.id
  name                = "${var.airbyte_service_name} Webapp Proxy"

  git_repository = {
    url       = "https://github.com/evoxmusic/qovery-airbyte.git"
    branch    = "main"
    root_path = "/"
  }
  build_mode            = "DOCKER"
  dockerfile_path       = "Dockerfile.webappproxy"
  cpu                   = 250
  memory                = 256
  min_running_instances = 2
  max_running_instances = 5
  ports = [
    {
      internal_port       = 80
      external_port       = 443
      protocol            = "HTTP"
      publicly_accessible = true
      is_default          = true
    }
  ]
  healthchecks = {
    readiness_probe = {
      type = {
        http = {
          scheme = "HTTP"
          port   = 80
          path   = "/"
        }
      }
      initial_delay_seconds = 30
      period_seconds        = 10
      timeout_seconds       = 10
      success_threshold     = 1
      failure_threshold     = 3
    }
    liveness_probe = {
      type = {
        http = {
          scheme = "HTTP"
          port   = 80
          path   = "/"
        }
      }
      initial_delay_seconds = 30
      period_seconds        = 10
      timeout_seconds       = 10
      success_threshold     = 1
      failure_threshold     = 3
    }
  }
  environment_variables = flatten([
    [
      {
        key   = "AIRBYTE_WEBAPP_INTERNAL_HOST",
        value = "helm-z${lower(element(split("-", qovery_helm.airbyte_helm.id), 0))}-airbyte-${lower(qovery_helm.airbyte_helm.name)}-webapp-svc"
      },
      {
        key   = "AIRBYTE_WEBAPP_INTERNAL_PORT",
        value = "80"
      }
    ], var.qovery_airbyte_web_app_proxy_basic_auth != "" ? [
      {
        key   = "AIRBYTE_WEBAPP_BASIC_AUTH",
        value = var.qovery_airbyte_web_app_proxy_basic_auth
      }
    ] : []
  ])
  advanced_settings_json = var.qovery_airbyte_web_app_proxy_basic_auth != "" ? jsonencode({
    "network.ingress.basic_auth_env_var" : "AIRBYTE_WEBAPP_BASIC_AUTH"
  }) : "{}"
}