# ── Core ─────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  type        = string
  description = "Logical cluster name used in resource naming (e.g. 'ai-search-dev')"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

# ── Network (from vpc module outputs) ────────────────────────────────────────

variable "data_vpc_id" {
  type        = string
  description = "Data VPC ID — Aurora lives here, isolated from EKS workload VPCs"
}

variable "data_subnet_ids" {
  type        = list(string)
  description = <<-EOT
    Data VPC subnet IDs ordered by AZ (standard aj-tf-module-vpc output: data_subnet_ids).
    Pass all available; az_count controls how many are used.
  EOT
}

variable "blue_vpc_cidr" {
  type        = string
  description = "Blue EKS cluster VPC CIDR — allowed inbound on port 5432"
}

variable "green_enabled" {
  type        = bool
  default     = false
  description = "Set true when the green EKS cluster VPC exists. Adds green_vpc_cidr to the SG."
}

variable "green_vpc_cidr" {
  type        = string
  default     = ""
  description = "Green EKS cluster VPC CIDR — only used when green_enabled = true"
}

# ── AZ Count ──────────────────────────────────────────────────────────────────

variable "az_count" {
  type        = number
  description = <<-EOT
    Number of Availability Zones to spread cluster instances across.
      2 = dev/staging   (cost-optimised, min for Aurora HA)
      3 = prod default  (standard HA, distributes writer + 2 readers across 3 AZs)
      4 = regulated     (strict SLA)
    Must be <= length(data_subnet_ids). Subnets must be ordered by AZ.
  EOT
  default     = 2
  validation {
    condition     = contains([2, 3, 4], var.az_count)
    error_message = "az_count must be 2, 3, or 4."
  }
}

# ── Engine ────────────────────────────────────────────────────────────────────

variable "engine_version" {
  type        = string
  default     = "16.6"
  description = <<-EOT
    Aurora PostgreSQL engine version.
    Use the full version string (e.g. '16.6'). Aurora manages minor patches automatically.
    pg16 is the LTS target for this project — pgvector 0.7+ supported natively.
    Check current available versions:
      aws rds describe-db-engine-versions --engine aurora-postgresql --query 'DBEngineVersions[*].EngineVersion'
  EOT
}

# ── Instance Class (FinOps) ───────────────────────────────────────────────────

variable "instance_class" {
  type        = string
  default     = "db.r8g.large"
  description = <<-EOT
    Aurora instance class. Graviton 4 ARM (r8g family) recommended for all envs.

    FinOps — RI size flexibility: RDS Reserved Instances are normalised within the
    same instance family (r8g) and region. A prod db.r8g.xlarge RI (4 units) covers
    2× db.r8g.large (2 units each), so a single RI commitment offsets dev/staging cost.
    Using the same r8g family across ALL environments is required for this to work.

    DO NOT mix r7g and r8g across envs — breaks RI family alignment.
    DO NOT use db.t4g for dev — burstable CPU exhausts during pgvector index builds
    and t4g is a separate RI family (no cross-family normalisation).

    dev/staging : db.r8g.large  (2 vCPU, 16 GB RAM, ~$0.285/hr on-demand)
    prod        : db.r8g.xlarge (4 vCPU, 32 GB RAM, ~$0.570/hr on-demand)
                  1yr All-Upfront RI ≈ 41% discount → ~$0.334/hr effective
                  1yr No-Upfront RI ≈ 33% discount → ~$0.380/hr effective

    Applied to BOTH writer and reader instances — Aurora supports per-instance class
    overrides but keeping them uniform simplifies RI planning and Cloudability tagging.
  EOT
}

# ── Database ──────────────────────────────────────────────────────────────────

variable "database_name" {
  type        = string
  default     = "ai_search"
  description = "Initial database name created in the cluster. Must be lowercase, no hyphens."
}

variable "master_username" {
  type        = string
  default     = "dbadmin"
  description = <<-EOT
    Master DB username (admin/break-glass access only).
    AWS manages the master password in Secrets Manager (manage_master_user_password = true).
    Application pods use RDS IAM auth (rds-db:connect token) — NOT this username.
    See iam_auth_db_username for the app-level DB user.
  EOT
}

variable "iam_auth_db_username" {
  type        = string
  default     = "ai_search_app"
  description = <<-EOT
    PostgreSQL username that the application uses for RDS IAM auth.
    This user must be created manually after cluster provisioning:
      CREATE USER ai_search_app WITH LOGIN;
      GRANT rds_iam TO ai_search_app;
      GRANT CONNECT ON DATABASE ai_search TO ai_search_app;
    The IAM policy grants rds-db:connect to this specific username.
    App pods call generate-db-auth-token to get a 15-min token instead of a password.
  EOT
}

# ── Replication ───────────────────────────────────────────────────────────────

variable "replica_count" {
  type        = number
  description = <<-EOT
    Number of Aurora reader instances (not including the writer).
      0 = writer only  — not recommended (no failover, no reader endpoint)
      1 = dev/staging  — writer + 1 reader; automatic failover enabled
      2 = prod default — writer + 2 readers; readers spread across AZs
    Aurora always places the writer in one AZ; readers are distributed across remaining AZs.
    RI impact: each reader instance is billed separately — size accordingly.
  EOT
  default     = 1
  validation {
    condition     = var.replica_count >= 0 && var.replica_count <= 5
    error_message = "replica_count must be between 0 and 5."
  }
}

# ── Storage ───────────────────────────────────────────────────────────────────

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Encrypt Aurora storage at rest using AWS-managed KMS key. Always true — included for auditability."
}

# ── Backup ────────────────────────────────────────────────────────────────────

variable "backup_retention_days" {
  type        = number
  description = <<-EOT
    Number of days to retain automated backups.
      7  = dev/staging default
      30 = prod default
    Aurora automated backups are continuous (point-in-time recovery within the window).
    Stored in S3 — costs ~$0.021/GB/month beyond 1× instance storage.
  EOT
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "backup_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Daily automated backup window (UTC). Format: hh:mm-hh:mm. Must not overlap maintenance_window."
}

variable "maintenance_window" {
  type        = string
  default     = "mon:04:00-mon:05:00"
  description = "Weekly maintenance window (UTC). Format: ddd:hh:mm-ddd:hh:mm. Aurora applies patches and failover tests here."
}

# ── Protection ────────────────────────────────────────────────────────────────

variable "deletion_protection" {
  type        = bool
  default     = false
  description = <<-EOT
    Prevent cluster deletion via API/console/Terraform destroy.
    false = dev/staging (easy teardown for cost control)
    true  = prod (safety net; must be disabled before terraform destroy)
    When true: skip_final_snapshot = false and a final snapshot is taken on deletion.
  EOT
}

# ── Observability ─────────────────────────────────────────────────────────────

variable "enable_performance_insights" {
  type        = bool
  default     = false
  description = <<-EOT
    Enable RDS Performance Insights on all instances.
    Free tier: 7-day retention (sufficient for most debugging).
    Supported on db.r8g.* instances.
    Enable for prod; optional for dev (can enable temporarily for debugging).
  EOT
}

# ── IAM Auth ─────────────────────────────────────────────────────────────────

variable "enable_iam_auth" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable RDS IAM database authentication on the cluster.
    Always true per 2026-03-31 decision: app pods use 15-min rotating IAM tokens
    (rds-db:connect) instead of a static password. Eliminates long-lived credentials.
    Master password (manage_master_user_password = true) is still managed by AWS for
    break-glass admin access — it is never used by application code.
  EOT
}

# ── Operations ────────────────────────────────────────────────────────────────

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Apply configuration changes immediately rather than at the next maintenance window. Use true for dev, false for prod."
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

variable "secret_recovery_window_days" {
  type        = number
  default     = 7
  description = <<-EOT
    Days before a deleted Secrets Manager secret is purged.
    Set to 0 for immediate deletion (dev only — avoids name collision when re-creating).
    Minimum 7 for staging/prod — required for recovery in case of accidental deletion.
  EOT
  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 (immediate) or 7-30."
  }
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project    = "ai-search"
    ManagedBy  = "Terraform"
    Repository = "aj-tf-module-aurora"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
