# Deploy Airbyte in 5 minutes on Kubernetes with Qovery

[Airbyte](https://www.airbyte.com) is an open-source data integration platform that syncs data from applications, APIs, and databases to data warehouses, lakes, and other destinations. It is a modern and easy-to-use platform that helps you replicate your data in minutes.

In this tutorial, you will learn how to deploy Airbyte on Kubernetes with Qovery in 5 minutes.

> This tutorial is related to [this forum thread](https://discuss.qovery.com/t/help-setting-up-airbyte-and-using-kubernetes-secrets/2848)

## Prerequisites

Before you start, you need to have the following:

- A [Qovery account](https://console.qovery.com)
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on your local machine

## Install

TODO

## Basic Authentication

As mentioned by Airbyte:

> Airbyte Kubernetes Community Edition does not support basic auth by default. To enable basic auth, consider adding a reverse proxy in front of Airbyte.

But luckily, Qovery supports basic authentication out of the box. You can enable basic authentication for your Airbyte instance by following the steps below:

TODO