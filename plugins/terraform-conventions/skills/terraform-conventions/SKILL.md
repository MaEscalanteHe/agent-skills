---
name: terraform-conventions
description: "Write and review Terraform HCL following HashiCorp's official style conventions. TRIGGER when: writing, generating, reviewing, or refactoring Terraform code, HCL files, .tf files, infrastructure-as-code, or IaC configurations. Also trigger when discussing Terraform modules, variable design, resource naming, file organization, or tfvars. DO NOT TRIGGER when: working with Pulumi, CDK, CloudFormation, Ansible, or other non-Terraform IaC tools."
---

# Terraform Style Guide

Generate and maintain Terraform code following HashiCorp's official style conventions.

**Reference:** [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)

## Code Generation Strategy

When generating Terraform code, follow this order so the configuration reads top-to-bottom like a narrative — each block builds on what came before:

1. Define provider configuration and version constraints
2. Declare variables for settings that genuinely differ between deployments — avoid creating variables for values that should be hardcoded as secure defaults (overusing variables makes configurations harder to understand and invites misconfiguration)
3. Define data sources before the resources that reference them, so the code builds on itself
4. Create resources in dependency order
5. Add outputs for key resource attributes that consumers or other configurations need

## File Organization

| File           | Purpose                                                     |
| -------------- | ----------------------------------------------------------- |
| `terraform.tf` | Terraform and provider version requirements                 |
| `backend.tf`   | Backend configuration for state storage                     |
| `providers.tf` | Provider configurations and aliases                         |
| `main.tf`      | Primary resources and data sources                          |
| `variables.tf` | Input variable declarations (alphabetical)                  |
| `outputs.tf`   | Output value declarations (alphabetical)                    |
| `locals.tf`    | Local value declarations                                    |
| `README.md`    | Describe the configuration: purpose, inputs, outputs, usage |

As codebases grow, split `main.tf` into domain files like `network.tf`, `storage.tf`, `compute.tf` — a maintainer should immediately know which file contains a given resource. See [references/file-organization.md](references/file-organization.md) for scaling patterns and multi-environment layout.

## Code Formatting

### Indentation and Alignment

Use **two spaces** per nesting level (no tabs). Align equals signs for consecutive arguments at the same nesting level — this makes blocks scannable at a glance:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private.id

  tags = {
    Name        = "web-server"
    Environment = var.environment
  }
}
```

### Block Organization

Structure resource blocks in this order so that readers always find information in the same place:

1. **Meta-arguments** (`count`, `for_each`, `provider`, `depends_on`) — these change _which_ or _how many_ resources exist, so they belong at the top
2. **Arguments** — the resource's configuration
3. **Nested blocks** — sub-resources and configurations
4. **`lifecycle`** — always last, since it governs the resource's lifecycle behavior

Separate each group with a blank line:

```hcl
resource "azurerm_linux_virtual_machine" "application" {
  count = var.instance_count

  name                = "${var.project}-app-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### Comments

Use `#` for all comments. The `//` and `/* */` syntaxes are supported for backward compatibility but are not idiomatic Terraform. Write self-documenting code through clear naming and structure — reserve comments for genuinely complex logic that isn't obvious from reading the code.

## Naming Conventions

- **Lowercase with underscores** for all identifiers
- **Descriptive nouns** that exclude the resource type — the resource address already includes the type, so repeating it is redundant (e.g., `aws_instance.web_api` not `aws_instance.web_api_instance`)
- **Singular**, not plural
- Default to **`main`** when a specific descriptive name adds no value and only one instance exists

```hcl
# Bad — type in name, camelCase, plural
resource "aws_instance" "webAPI-aws-instance" {}
resource "google_compute_instance" "compute_instances" {}

# Good — descriptive, singular, underscore-separated
resource "aws_instance" "web_api" {}
resource "google_compute_instance" "application" {}
resource "azurerm_virtual_network" "main" {}
```

## Variables and Locals

### Variables

Declare `type` and `description` for every variable. This is not bureaucracy — type catches misconfigurations at plan time rather than apply time, and description is the primary documentation for anyone consuming the module.

Recommended attribute order: `type`, `description`, `default`, `sensitive`, `validation`.

```hcl
variable "environment" {
  type        = string
  description = "Target deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "database_password" {
  type        = string
  description = "Password for the database admin user"
  sensitive   = true
}
```

**Be intentional about what becomes a variable.** Only expose settings that genuinely differ between deployments. Settings that should always be the same (encryption enabled, public access blocked, TLS version) are better hardcoded as secure defaults in the resource block. A module with 30 variables where 20 are always set to the same value is harder to use than one with 10 well-chosen variables.

Use validation blocks when a variable has uniquely restrictive valid values, not for general type checking that the `type` constraint already handles.

### Locals

Use locals to avoid repeating expressions, but use them sparingly — overuse makes it harder to understand what a resource actually does because values are defined far from where they're used.

- If a local is referenced across multiple files, define it in `locals.tf`
- If it's used only within one file, define it at the top of that file

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
```

## Outputs

Declare `description` for every output. Recommended attribute order: `description`, `value`, `sensitive`.

```hcl
output "database_endpoint" {
  description = "Connection endpoint for the database"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "database_password" {
  description = "Database administrator password"
  value       = azurerm_mssql_server.main.administrator_login_password
  sensitive   = true
}
```

## Dynamic Resource Creation

### count — for identical resources and conditional creation

`count` works well when resources are nearly identical and differ only by index, or when you need to conditionally create a resource:

```hcl
# Conditional creation
resource "google_monitoring_alert_policy" "cpu" {
  count = var.enable_alerting ? 1 : 0

  display_name = "High CPU Usage"
  combiner     = "OR"
  # ...
}
```

### for_each — when resources need distinct configurations

Use `for_each` when each instance needs values that aren't derivable from an integer index. The key benefit: removing an item from the middle of a `for_each` map only affects that item, while removing from a `count` list shifts all subsequent indices and causes destructive recreation.

```hcl
variable "subnets" {
  description = "Map of subnet name to CIDR block"
  type        = map(string)
  default = {
    public  = "10.0.1.0/24"
    private = "10.0.2.0/24"
    data    = "10.0.3.0/24"
  }
}

resource "aws_subnet" "main" {
  for_each = var.subnets

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value

  tags = {
    Name = "${var.project}-${each.key}"
  }
}
```

Use both meta-arguments conservatively — they simplify code but add cognitive complexity. Add a clarifying comment when the effect isn't immediately obvious.

## Version Pinning

Pin provider and Terraform versions to prevent unintentional infrastructure changes from upstream updates:

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

**Version constraint operators:**

- `= 1.0.0` — exact version
- `>= 1.0.0` — minimum version
- `~> 1.0` — allow rightmost component to increment (1.x but not 2.0)
- `>= 1.0, < 2.0` — explicit range

## Provider Configuration

Define all providers in `providers.tf`. Include a default provider first — resources use the default unless explicitly assigned to an alias. If using multiple instances of the same provider, make `alias` the first attribute of non-default providers so it's immediately visible:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project_name
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
```

## Version Control

**Never commit:**

- `terraform.tfstate`, `terraform.tfstate.backup`
- `.terraform.tfstate.lock.info`
- `.terraform/` directory
- `*.tfplan` files
- `.tfvars` files containing sensitive data

**Always commit:**

- All `.tf` configuration files
- `.terraform.lock.hcl` (dependency lock file — ensures reproducible provider installations)
- `README.md`

Run `terraform fmt -recursive` before each commit. Consider a Git pre-commit hook to automate this.

## Validation and Linting

Run before committing:

```bash
terraform fmt -recursive   # Idiomatic formatting
terraform validate          # Syntactic validity and internal consistency
```

`terraform validate` checks that configuration is syntactically valid and internally consistent. It doesn't evaluate variable values or connect to remote state — it's safe to run automatically and frequently.

Additional tools:

- **tflint** — linting and provider-specific best practices
- **checkov** / **tfsec** — security scanning and policy enforcement

## Additional Resources

Read these reference files when you need deeper guidance on specific topics:

- [references/file-organization.md](references/file-organization.md) — file structure scaling, multi-environment layout, backend configuration patterns
- [references/modules-and-architecture.md](references/modules-and-architecture.md) — when and how to create modules, repository architecture, naming conventions
- [references/security-and-state.md](references/security-and-state.md) — security hardening defaults, state management, secrets handling
- [references/examples.md](references/examples.md) — extended good/bad example pairs across AWS, Azure, and GCP

## Code Review Checklist

- [ ] Formatted with `terraform fmt`
- [ ] Validated with `terraform validate`
- [ ] Files organized per standard structure (including `backend.tf`, `README.md`)
- [ ] All variables have `type` and `description`
- [ ] Variables only expose settings that vary between deployments
- [ ] All outputs have `description`
- [ ] Resource names use descriptive singular nouns with underscores
- [ ] Version constraints pinned for Terraform and all providers
- [ ] Sensitive values marked with `sensitive = true`
- [ ] No hardcoded credentials or secrets
- [ ] Comments use `#` style only
- [ ] Security defaults applied (encryption, private networking, least privilege)

---

_Based on: [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)_
