# CLAUDE.md — aj-tf-module-aurora

> Local context file for Claude. Not pushed to GitHub.

---

## What This Module Does

Provisions an Aurora PostgreSQL cluster in the data VPC. Shared across both blue and green EKS clusters — the data layer is never duplicated. Both clusters connect to the same Aurora instance via data VPC peering.

pgvector extension is enabled for RAG embedding similarity search. RDS IAM authentication is always on — app pods use 15-min rotating tokens instead of static passwords.

---

## Where It Fits

**Architecture layer:** L6 — Data (Aurora PostgreSQL)
**Provisioned by:** `aj-infra-release` — data layer pipeline stage (not yet wired; target: `provision-eks.yml` Stage 4)
**Depends on:** data VPC subnet IDs from `aj-tf-module-vpc` outputs
**State key pattern:** `workload/blue-green/<env>/aurora/terraform.tfstate`

## How to Use

Not yet wired into the release pipeline. Planned as Stage 4 of `provision-eks.yml` after the platform stage.

To use manually:
```bash
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=workload/blue-green/<env>/aurora/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"

terraform apply \
  -var-file=aj-infra-release/envs/workload/blue-green/<env>/common.tfvars \
  -var-file=aj-infra-release/envs/workload/blue-green/<env>/aurora.tfvars \
  -var="data_subnet_ids=[...]" \
  -var="blue_vpc_cidr=10.100.0.0/16"
```

tfvars file to configure: `aj-infra-release/envs/workload/blue-green/<env>/aurora.tfvars`

After apply, run the one-time SQL commands in the "RDS IAM Auth — Post-Provisioning Setup" section to create the app user.

---

## Module Structure

```
modules/
  db-cluster/   → security group + DB subnet group + parameter groups (cluster + instance)
                  + aws_rds_cluster + aws_rds_cluster_instance (writer + readers)
  iam-auth/     → aws_iam_policy for rds-db:connect (attached to Pod Identity role)

root:
  main.tf       → orchestrates both submodules + writes connection config bundle to Secrets Manager
  locals.tf     → name_prefix, active_data_subnets, allowed_cidr_blocks, full_tags
  variables.tf  → all input variables with FinOps-aware defaults and EOT descriptions
  outputs.tf    → cluster_endpoint, reader_endpoint, cluster_identifier, secret_arn,
                  security_group_id, iam_auth_policy_arn, master_user_secret_arn
  providers.tf  → Terraform = 1.10.5, AWS = 5.100.0 (no random provider — AWS manages master password)
```

---

## Key Design Decisions

- **Aurora PostgreSQL not MySQL** — pgvector extension required for RAG embeddings; Aurora native blue/green for major version upgrades
- **pgvector via shared_preload_libraries** — `vector` loaded at cluster startup via cluster parameter group; `pg_stat_statements` also included for Performance Insights query tracking
- **Shared across blue + green** — data layer is NOT duplicated per EKS color; both clusters hit same instance via data VPC peering; security group dynamically adds green VPC CIDR when `green_enabled = true`
- **az_count slices subnet list** — same pattern as EKS + VPC + Valkey modules; pass all data subnets, module uses only az_count of them
- **RDS IAM auth always on** — `iam_database_authentication_enabled = true`; app pods use 15-min rotating tokens via Pod Identity → `rds-db:connect`; decided 2026-03-31 (eliminates static DB credentials)
- **manage_master_user_password = true** — AWS creates and auto-rotates master password in Secrets Manager; master creds are for break-glass/admin only — never used by application code
- **No password in connection bundle** — Secrets Manager secret contains host, reader_host, port, dbname, username, region, iam_auth=true; NO password field; app generates IAM token at runtime
- **Aurora native blue/green for DB upgrades** — major version upgrades (pg16 → pg17) use Aurora's built-in blue/green cloning, NOT EKS blue/green; the two are independent
- **Storage always encrypted** — `storage_encrypted = true` unconditional; AWS-managed KMS key by default
- **CloudWatch logs export** — `postgresql` log type exported; can be picked up by Alloy CloudWatch receiver → central Loki
- **Deletion protection toggle** — false for dev (easy teardown), true for prod; when true, `skip_final_snapshot = false` (safety net snapshot on delete)

---

## FinOps — Instance Class Strategy

### Why db.r8g.* (Graviton 4 ARM) across ALL environments

| Concern | Rationale |
|---|---|
| Price/performance | r8g (Graviton 4) is ~10-15% better than r7g at same price point |
| RI size flexibility | RDS RIs are normalised within the same instance family per region. A `db.r8g.xlarge` RI (4 normalised units) covers 2× `db.r8g.large` (2 units each). Buying prod RI partially offsets dev/staging cost |
| Family consistency | All envs on r8g = single RI family to manage in Cloudability |
| pgvector workload | 16 GB RAM on r8g.large is sufficient for index builds without CPU burst risk |

### Why NOT db.t4g for dev

- Burstable CPU — pgvector HNSW index builds exhaust CPU credits, causing throttling
- Separate RI family — t4g RIs cannot offset r8g costs (no cross-family normalisation)
- False economy — short-term ~75% cost saving creates RI fragmentation long-term

### Instance sizing reference

| Env | Instance | vCPU | RAM | ~On-demand/hr | ~1yr All-Upfront RI/hr |
|---|---|---|---|---|---|
| dev/staging | db.r8g.large | 2 | 16 GB | $0.285 | $0.167 (41% off) |
| prod | db.r8g.xlarge | 4 | 32 GB | $0.570 | $0.334 (41% off) |

### RI purchase recommendation

- Buy 1yr All-Upfront `db.r8g.xlarge` RI for prod writer — highest utilisation, largest saving
- Normalised units from prod RI partially cover dev/staging `db.r8g.large` instances
- Review with 3yr term once cluster is stable (additional ~20% saving vs 1yr)
- Tag: `FinOpsRIFamily = db.r8g` (set in locals.tf) — enables Cloudability RI coverage report

---

## RDS IAM Auth — Post-Provisioning Setup

After `terraform apply`, run these one-time DB admin commands (using master credentials from `master_user_secret_arn`):

```sql
-- Connect as master user (get token from Secrets Manager)
psql -h <cluster_endpoint> -U dbadmin -d ai_search

-- Create app user with IAM auth role
CREATE USER ai_search_app WITH LOGIN;
GRANT rds_iam TO ai_search_app;
GRANT CONNECT ON DATABASE ai_search TO ai_search_app;

-- Grant schema access (adjust per service)
GRANT USAGE ON SCHEMA public TO ai_search_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ai_search_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ai_search_app;

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
```

App connection (Python/psycopg2 example):
```python
import boto3
token = boto3.client('rds').generate_db_auth_token(
    DBHostname=host, Port=5432, DBUsername='ai_search_app', Region='us-east-1'
)
conn = psycopg2.connect(host=host, user='ai_search_app', password=token,
                        dbname='ai_search', sslmode='require')
```

---

## Variables to Know

- `instance_class` — `db.r8g.large` (dev/staging), `db.r8g.xlarge` (prod); keep r8g family across all envs
- `replica_count` — 1 (dev/staging: writer + 1 reader), 2 (prod: writer + 2 readers across 3 AZs)
- `az_count` — 2 (dev/staging), 3 (prod); controls subnet group and instance AZ distribution
- `deletion_protection` — false (dev), true (prod); gates final snapshot on deletion
- `enable_performance_insights` — false (dev), true (staging/prod); free 7-day retention on r8g
- `green_enabled` — flip to true during blue/green EKS upgrade to allow green VPC CIDR into SG
- `secret_recovery_window_days` — 0 (dev, immediate), 7 (staging/prod)
- `apply_immediately` — true (dev), false (prod — maintenance window only)
- `iam_auth_db_username` — PostgreSQL user for app IAM auth; must be created post-provisioning

---

## Outputs Used by Downstream Modules

`aj-infra-release` consumes these as `-var` flags or remote state:
- `secret_arn` → ESO `ExternalSecret` in k8s-manifests (fetches connection config into K8s Secret)
- `iam_auth_policy_arn` → attached to Pod Identity role in `aj-infra-platform` for each service namespace
- `security_group_id` → optionally added to EKS node group SG rules
- `cluster_endpoint` + `reader_endpoint` → can be passed to app Helm values
- `cluster_identifier` → used for Aurora native blue/green DB upgrade commands

---

## Blue/Green Notes

Aurora is NOT part of the EKS blue/green cluster swap — it's shared data infrastructure.

| Phase | Action |
|---|---|
| Normal | `green_enabled = false`; only blue VPC CIDR in SG |
| Green cluster live | `green_enabled = true`; green VPC CIDR added to SG via `terraform apply` |
| Cutover complete (blue torn down) | `green_enabled = false`; green VPC CIDR removed from SG |

Aurora has its own native blue/green for **database version upgrades** (e.g. pg16 → pg17). This is independent of EKS blue/green. Use:
```bash
aws rds create-blue-green-deployment \
  --blue-green-deployment-name <name> \
  --source <cluster-arn> \
  --target-engine-version "17.x"
```
