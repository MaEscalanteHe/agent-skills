# File Organization

## Table of Contents

- [Standard File Structure Example](#standard-file-structure-example)
- [Backend Configuration](#backend-configuration)
- [Scaling to Domain Files](#scaling-to-domain-files)
- [Multi-Environment Layout](#multi-environment-layout)
- [Workspace-Based Environments](#workspace-based-environments)

---

## Standard File Structure Example

A complete root module with multi-provider setup:

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# providers.tf
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# variables.tf (alphabetical)
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-west-2"
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "environment" {
  description = "Target deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

# locals.tf
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# outputs.tf (alphabetical)
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

## Backend Configuration

Separate backend configuration into `backend.tf` to keep version constraints and state storage concerns distinct:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

The pattern applies to any backend type — replace `s3` with `azurerm`, `gcs`, `consul`, or `remote` depending on your infrastructure.

## Scaling to Domain Files

When `main.tf` grows beyond comfortable navigation, split by logical infrastructure domain:

```
project/
├── terraform.tf       # Version constraints
├── backend.tf         # State storage
├── providers.tf       # Provider config
├── variables.tf       # All inputs
├── outputs.tf         # All outputs
├── locals.tf          # Shared locals
├── network.tf         # VPCs, subnets, load balancers, gateways
├── compute.tf         # Instances, containers, serverless functions
├── storage.tf         # Buckets, databases, file systems
├── security.tf        # IAM roles, policies, security groups
└── README.md          # Purpose, inputs, outputs, usage
```

The goal: a maintainer should immediately know which file contains a given resource or data source definition. Group by what the infrastructure _does_, not by provider or resource type.

## Multi-Environment Layout

Use a directory per environment to isolate state files and prevent accidental cross-environment changes:

```
project/
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── application/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── dev/
│   ├── terraform.tf
│   ├── backend.tf
│   ├── main.tf
│   └── variables.tf
├── staging/
│   ├── terraform.tf
│   ├── backend.tf
│   ├── main.tf
│   └── variables.tf
└── prod/
    ├── terraform.tf
    ├── backend.tf
    ├── main.tf
    └── variables.tf
```

Each environment directory has its own backend configuration pointing to a separate state file, its own variable values, and its own provider version constraints if needed. Shared logic lives in `modules/`.

## Workspace-Based Environments

If using HCP Terraform or Terraform Enterprise, you can use workspaces instead of directories — one workspace per environment, all sharing the same configuration but with different variable values. This is simpler to maintain but requires workspace-aware tooling for CI/CD.

For open-source Terraform, CLI workspaces store state in `terraform.tfstate.d/<workspace>/` automatically. This works for small teams but lacks the access control and governance features of the directory approach.
