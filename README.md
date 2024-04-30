# Serverless URL Shortener

A serverless URL shortener using Azure Functions and Azure Table Storage.

## Features

- [x] GET: resolve a short URL into a long URL
  - [x] Count the number of times a short URL has been accessed
- [x] POST: create a short URL from a long URL, password protected
  - [x] Maximun number of access per url as a parameter


## Deployment

You need to have the following tools installed:

- [Terraform](https://www.terraform.io/downloads.html)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

### Login to Azure

```bash
az login
```

### Deploy infrastructure

```bash
export TF_VAR_PASSWORD xxx
export TF_VAR_CLOUDFLARE_API_TOKEN yyy

cd infrastructure/env/(dev|prod)
terraform init
terraform plan
terraform apply
```


## Installation

You need to have the following tools installed:

- [Go](https://golang.org/doc/install)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Azure functions core tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local)

```bash
GOOS=linux GOARCH=amd64 go build handler.go
func azure functionapp publish url_shortener-(dev|prd)-function-app
```
