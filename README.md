# aj-tf-module-aurora

Terraform module — Aurora PostgreSQL + pgvector for the AI Search Engine platform.

Provisions an Aurora PostgreSQL cluster in the data VPC, shared across blue and green EKS clusters. pgvector is enabled for RAG embedding similarity search. RDS IAM authentication eliminates static database passwords.

---

## Features

- Aurora PostgreSQL 16 with pgvector extension (`shared_preload_libraries = vector`)
- RDS IAM database authentication — app pods use 15-min rotating tokens (no static passwords)
- AWS-managed master password (`manage_master_user_password = true`) for break-glass access
- Graviton 4 ARM instances (`db.r8g.*`) — RI size flexibility across all environments
- Blue/green SG toggle — green VPC CIDR added to security group during EKS cutover
- `az_count` pattern — consistent with `aj-tf-module-vpc`, `aj-tf-module-eks`, `aj-tf-module-valkey`
- Connection config bundle written to Secrets Manager — consumed by ESO in k8s-manifests
- IAM policy for `rds-db:connect` — attached to Pod Identity role per service namespace

---

## FinOps — Instance Class Selection

All environments use `db.r8g.*` (Graviton 4 ARM). Do not mix instance families across environments.

**RDS RI size flexibility:** RDS Reserved Instances are normalised within the same instance family. A `db.r8g.xlarge` RI (4 units) covers 2× `db.r8g.large` (2 units each) in the same region. Buying a prod RI partially offsets dev/staging cost with zero configuration.

| Environment | Instance | 1yr All-Upfront RI savings |
|---|---|---|
| dev / staging | `db.r8g.large` | ~41% vs on-demand |
| prod | `db.r8g.xlarge` | ~41% vs on-demand |

**Do not use `db.t4g` for dev** — burstable CPU exhausts during pgvector HNSW index builds and creates a separate RI family (no normalisation benefit with r8g).

---

## Usage

```hcl
module "aurora" {
  source = "github.com/ajay/aj-tf-module-aurora?ref=v0.1.0"

  cluster_name = "ai-search-dev"
  environment  = "dev"
  aws_region   = "us-east-1"

  data_vpc_id     = module.vpc.data_vpc_id
  data_subnet_ids = module.vpc.data_subnet_ids
  blue_vpc_cidr   = "10.102.0.0/16"
  az_count        = 2

  instance_class = "db.r8g.large"
  replica_count  = 1

  deletion_protection         = false
  enable_performance_insights = false
}
```

---

## Post-Provisioning (one-time)

After `terraform apply`, create the IAM auth DB user and enable pgvector:

```sql
-- Connect using master credentials from Secrets Manager (master_user_secret_arn output)
CREATE USER ai_search_app WITH LOGIN;
GRANT rds_iam TO ai_search_app;
GRANT CONNECT ON DATABASE ai_search TO ai_search_app;
GRANT USAGE ON SCHEMA public TO ai_search_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ai_search_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ai_search_app;

CREATE EXTENSION IF NOT EXISTS vector;
```

---

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `cluster_name` | string | — | Logical name for resource naming |
| `environment` | string | `dev` | Environment label |
| `aws_region` | string | `us-east-1` | AWS region |
| `data_vpc_id` | string | — | Data VPC ID |
| `data_subnet_ids` | list(string) | — | Data VPC subnet IDs (all AZs; az_count slices) |
| `blue_vpc_cidr` | string | — | Blue EKS VPC CIDR (allowed inbound 5432) |
| `green_enabled` | bool | `false` | Add green VPC CIDR to SG during cutover |
| `green_vpc_cidr` | string | `""` | Green EKS VPC CIDR |
| `az_count` | number | `2` | AZs to use (2=dev, 3=prod, 4=regulated) |
| `engine_version` | string | `16.6` | Aurora PostgreSQL engine version |
| `instance_class` | string | `db.r8g.large` | Instance class (all instances) |
| `database_name` | string | `ai_search` | Initial database name |
| `master_username` | string | `dbadmin` | Master username (break-glass only) |
| `iam_auth_db_username` | string | `ai_search_app` | PostgreSQL user for RDS IAM auth |
| `replica_count` | number | `1` | Reader instance count (not including writer) |
| `backup_retention_days` | number | `7` | Automated backup retention (1-35) |
| `backup_window` | string | `03:00-04:00` | Daily backup window (UTC) |
| `maintenance_window` | string | `mon:04:00-mon:05:00` | Weekly maintenance window (UTC) |
| `deletion_protection` | bool | `false` | Prevent accidental deletion |
| `enable_performance_insights` | bool | `false` | RDS Performance Insights (free 7-day) |
| `enable_iam_auth` | bool | `true` | RDS IAM database authentication |
| `apply_immediately` | bool | `false` | Apply changes immediately vs maintenance window |
| `secret_recovery_window_days` | number | `7` | Days before deleted secret is purged (0 or 7-30) |
| `team` | string | `infra-core` | Team tag |
| `cost_center` | string | `infra-2026-q1` | Cost center tag |

---

## Outputs

| Name | Description |
|---|---|
| `cluster_endpoint` | Writer endpoint (writes) |
| `reader_endpoint` | Reader endpoint (read-heavy RAG queries) |
| `cluster_identifier` | Cluster ID (Aurora native blue/green upgrades) |
| `cluster_resource_id` | Resource ID for rds-db:connect IAM ARN |
| `secret_arn` | Secrets Manager ARN for connection config (ESO) |
| `master_user_secret_arn` | Secrets Manager ARN for AWS-managed master password |
| `iam_auth_policy_arn` | IAM policy ARN for rds-db:connect (Pod Identity) |
| `iam_auth_db_username` | PostgreSQL username for IAM auth |
| `security_group_id` | SG ID (for EKS node group rules if needed) |
| `database_name` | Initial database name |
| `writer_instance_id` | Writer instance ID (RI purchase target) |
| `reader_instance_ids` | Reader instance IDs |

---

## Provider Pins

| Provider | Version |
|---|---|
| Terraform | `= 1.7.5` |
| AWS | `= 5.100.0` |

---

## Versioning

Semver: `PATCH` = config tweak, `MINOR` = new feature, `MAJOR` = breaking variable change.
CI auto-tags patch on merge to main.
