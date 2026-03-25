# Modules and Architecture

## Table of Contents

- [When to Create a Module](#when-to-create-a-module)
- [Local Module Structure](#local-module-structure)
- [Module Naming](#module-naming)
- [Module Versioning](#module-versioning)
- [Repository Architecture](#repository-architecture)
- [README Requirements](#readme-requirements)

---

## When to Create a Module

Create a module when you have a group of logically related resources that are provisioned together and may be reused. Good module boundaries follow infrastructure purpose:

- **Networking module** — VPC, subnets, route tables, gateways, security groups
- **Application module** — compute, load balancer, auto-scaling, DNS records
- **Database module** — database instance, parameter groups, subnet groups, backups

Avoid creating modules for single resources or resources that have no reuse case — the overhead of indirection outweighs the benefit. Also avoid deeply nested modules; keep nesting to one level when possible, because deep hierarchies make it hard to trace where values come from.

## Local Module Structure

Store local modules under `./modules/<module_name>/` with the standard file set:

```
modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── application/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
└── database/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md
```

Reference local modules with relative paths so Terraform treats them as part of the same configuration:

```hcl
module "networking" {
  source = "./modules/networking"

  vpc_cidr    = var.vpc_cidr
  environment = var.environment
}
```

## Module Naming

Follow the three-part registry convention:

```
terraform-<PROVIDER>-<NAME>
```

- `<PROVIDER>` is the primary provider the module manages (e.g., `aws`, `azurerm`, `google`)
- `<NAME>` describes the infrastructure purpose (e.g., `vpc`, `kubernetes-cluster`, `storage-account`)

Examples:

- `terraform-aws-vpc`
- `terraform-azurerm-storage-account`
- `terraform-google-kubernetes-engine`

This convention is required for the Terraform Registry and recommended for all modules even if you don't publish them — it makes the module's scope immediately clear.

## Module Versioning

For registry modules, pin to a specific major.minor version:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"
}
```

For local modules referenced via relative paths, the `version` parameter is not applicable — the module content is whatever exists at that path. Use Git tags or branches if you need versioning for local modules stored in separate repositories.

For published modules, store each module in its own repository to enable independent versioning. Tag releases following semantic versioning (e.g., `v1.0.0`, `v1.1.0`).

## Repository Architecture

**Multi-repo** (recommended for published modules): one repository per module. Enables independent versioning, focused CI/CD pipelines, and clear ownership boundaries.

**Mono-repo** (common for organization-internal infrastructure): all Terraform configurations in one repository, organized by component or environment. Provides a single source of truth but requires careful CI/CD scoping — tools like HCP Terraform workspace-based triggers help here.

Choose based on team size and module reuse patterns. Small teams with tightly coupled infrastructure often start with a mono-repo and split out modules as they mature.

## README Requirements

Every module and root configuration should include a `README.md` describing:

- **Purpose** — what the module provisions and why
- **Usage** — example `module` block showing how to call it
- **Inputs** — table of variables with descriptions and defaults
- **Outputs** — table of output values
- **Requirements** — minimum Terraform version, required providers

Tools like `terraform-docs` can generate input/output documentation automatically from your code.
