# Extended Examples

Good/bad pairs organized by topic, using diverse providers to demonstrate that conventions apply universally.

## Table of Contents

- [Naming](#naming)
- [Variable Design](#variable-design)
- [count vs for_each](#count-vs-for_each)
- [Block Organization](#block-organization)
- [Comment Style](#comment-style)
- [Provider Configuration](#provider-configuration)
- [Output Design](#output-design)

---

## Naming

```hcl
# Bad — resource type repeated in name, camelCase, plural
resource "aws_instance" "awsWebServer" {}
resource "google_compute_instance" "gcp_compute_instances" {}
resource "azurerm_virtual_network" "azure-vnet-main" {}

# Good — descriptive nouns, underscore-separated, singular
resource "aws_instance" "web_api" {}
resource "google_compute_instance" "application" {}
resource "azurerm_virtual_network" "main" {}
```

## Variable Design

```hcl
# Bad — a variable for every attribute, making code hard to follow
variable "bucket_acl" {
  type    = string
  default = "private"
}

variable "bucket_versioning" {
  type    = bool
  default = true
}

variable "bucket_force_destroy" {
  type    = bool
  default = false
}

# Good — only expose what genuinely varies between deployments
variable "environment" {
  description = "Target deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
}
```

Settings like ACL, versioning, and force_destroy should be hardcoded to secure defaults in the resource block — they don't change between deployments and exposing them as variables invites misconfiguration.

## count vs for_each

```hcl
# Appropriate use of count — conditional creation
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name = "${var.project}-high-cpu"
  threshold  = 80
}

# Appropriate use of count — identical resources differing only by index
resource "azurerm_availability_set" "main" {
  count = var.availability_set_count

  name                = "${var.project}-as-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Appropriate use of for_each — resources with distinct configurations
variable "subnets" {
  description = "Map of subnet name to CIDR block"
  type        = map(string)
  default = {
    public  = "10.0.1.0/24"
    private = "10.0.2.0/24"
    data    = "10.0.3.0/24"
  }
}

resource "google_compute_subnetwork" "main" {
  for_each = var.subnets

  name          = "${var.project}-${each.key}"
  ip_cidr_range = each.value
  network       = google_compute_network.main.id
}

# Bad — count where for_each is clearer (resources have distinct names/roles)
resource "google_compute_subnetwork" "main" {
  count = 3

  name          = "${var.project}-subnet-${count.index}"
  ip_cidr_range = "10.0.${count.index + 1}.0/24"
  network       = google_compute_network.main.id
}
```

## Block Organization

```hcl
# Bad — mixed ordering, lifecycle buried in the middle
resource "aws_instance" "web" {
  tags = { Name = "web" }

  lifecycle {
    create_before_destroy = true
  }

  ami           = data.aws_ami.ubuntu.id
  count         = 2
  instance_type = "t3.micro"

  root_block_device {
    volume_size = 20
  }
}

# Good — meta-arguments first, then arguments, then blocks, lifecycle last
resource "aws_instance" "web" {
  count = 2

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  root_block_device {
    volume_size = 20
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "web-${count.index}" }
}
```

## Comment Style

```hcl
# Bad — non-idiomatic comment styles
// This creates a resource group
resource "azurerm_resource_group" "main" {
  name     = "${var.project}-${var.environment}-rg"
  location = var.location
}

/* This is a multi-line
   comment about the VNet */
resource "azurerm_virtual_network" "main" {
  name = "${var.project}-vnet"
}

# Good — use # for all comments, keep them minimal
# Regional resource group for application infrastructure
resource "azurerm_resource_group" "main" {
  name     = "${var.project}-${var.environment}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
```

## Provider Configuration

```hcl
# Bad — no default provider, only aliased
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

# Good — default provider first, alias for secondary regions
provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project_name
    }
  }
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project_name
    }
  }
}
```

## Output Design

```hcl
# Bad — missing description, wrong attribute order
output "db_password" {
  value     = azurerm_mssql_server.main.administrator_login_password
  sensitive = true
}

output "server_name" {
  value = azurerm_mssql_server.main.name
}

# Good — description first, value second, sensitive last
output "database_admin_password" {
  description = "Administrator password for the SQL server"
  value       = azurerm_mssql_server.main.administrator_login_password
  sensitive   = true
}

output "database_server_name" {
  description = "Fully qualified name of the SQL server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}
```
