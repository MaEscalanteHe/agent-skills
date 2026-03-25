# Security and State Management

## Table of Contents

- [Security Hardening Defaults](#security-hardening-defaults)
- [Secure Resource Examples](#secure-resource-examples)
- [State Management](#state-management)
- [Secrets Management](#secrets-management)
- [State Sharing](#state-sharing)

---

## Security Hardening Defaults

When generating Terraform resources, apply these defaults because infrastructure is often harder to fix after deployment than during initial creation:

- **Encryption at rest** — enable by default on storage, databases, and messaging. Cloud providers offer managed encryption keys at no additional cost.
- **Private networking** — place resources in private subnets unless they explicitly need public access. Public exposure is the #1 source of cloud security incidents.
- **Least privilege** — security groups and IAM policies should allow only what is needed. Start with zero access and add permissions, rather than starting broad and restricting.
- **Logging and monitoring** — enable access logs and audit trails. These cost little but are invaluable during incident response.
- **No hardcoded credentials** — use provider-specific authentication mechanisms (environment variables, instance profiles, managed identities). Hardcoded secrets end up in state files and version control.
- **Sensitive markers** — use `sensitive = true` on variables and outputs containing passwords, keys, or tokens. This hides values in plan/apply output, though they remain plaintext in state.

## Secure Resource Examples

### AWS — S3 Bucket with Security Defaults

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-${var.environment}-data"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Azure — Storage Account with Security Defaults

```hcl
resource "azurerm_storage_account" "data" {
  name                     = "${var.project}${var.environment}data"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  # Encryption is enabled by default on Azure, but explicit config ensures it
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  tags = local.common_tags
}
```

### GCP — Cloud Storage Bucket with Uniform Access

```hcl
resource "google_storage_bucket" "data" {
  name     = "${var.project}-${var.environment}-data"
  location = var.gcp_region
  project  = var.gcp_project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.data.id
  }

  labels = local.common_labels
}
```

## State Management

State files contain all resource attributes in plaintext, including values marked as `sensitive`. This makes state files a high-value target.

**Remote state storage** — configure a remote backend (S3+DynamoDB, Azure Blob, GCS, or HCP Terraform) rather than local state. Remote backends provide:

- Locking to prevent concurrent modifications
- Encryption at rest
- Access control via IAM/RBAC
- Audit trails

**Restrict access** — limit who can read state files. Anyone with state access can see every attribute of every managed resource, including secrets.

**State backups** — enable versioning on the backend storage (S3 versioning, Azure blob snapshots) so you can recover from accidental state corruption.

## Secrets Management

Ordered by preference:

1. **Dynamic credentials** — use OIDC federation or provider-specific short-lived tokens (AWS IAM roles, Azure managed identities, GCP service account impersonation). No static secrets to manage.
2. **Secrets managers** — retrieve secrets at apply time via data sources (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager). Secrets never appear in Terraform code.
3. **Environment variables** — set `TF_VAR_<name>` for sensitive inputs. Better than hardcoding, but requires secure CI/CD configuration.
4. **Encrypted tfvars** — encrypt `.tfvars` files with tools like `sops` or `age`. Commit the encrypted version, decrypt at apply time.

Regardless of method, remember: Terraform writes sensitive values to state in plaintext. Protect the state file accordingly.

## State Sharing

Avoid passing full state files between configurations. Instead:

- **Data sources** — query the provider directly for resource attributes (`aws_vpc`, `azurerm_virtual_network`, `google_compute_network`).
- **Remote state data source** — `terraform_remote_state` can read outputs from another configuration's state, but couples configurations tightly.
- **HCP Terraform outputs** — `tfe_outputs` data source reads outputs without exposing the full state.

Prefer data sources over remote state references. They're more resilient to state format changes and don't require cross-configuration access to state files.
