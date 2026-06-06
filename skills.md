# skills.md — aj-tf-module-aurora

## Purpose
Provisions an Aurora PostgreSQL cluster with blue/green VPC support, IAM authentication, encryption, automated backups, and Secrets Manager integration.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajaylakma/aj-tf-module-aurora?ref=aurora-01"
```

## Key inputs
| Variable | Description |
|---|---|
| `cluster_name` | Aurora cluster identifier |
| `environment` | dev \| staging \| uat \| prod |
| `data_vpc_id` | VPC for the DB cluster |
| `data_subnet_ids` | Data tier subnet IDs |
| `engine_version` | Aurora PostgreSQL version |
| `instance_class` | DB instance class |
| `replica_count` | Number of read replicas |
| `green_enabled` | Enable green VPC variant |
| `storage_encrypted` | Encryption at rest |
| `backup_retention_days` | Backup window in days |

## Key outputs
| Output | Description |
|---|---|
| `cluster_endpoint` | Writer endpoint |
| `reader_endpoint` | Reader endpoint |
| `cluster_identifier` | Cluster ID |
| `secret_arn` | Secrets Manager secret ARN |
| `iam_auth_policy_arn` | IAM policy ARN for DB auth |
| `security_group_id` | DB security group ID |

## AWS tags applied
`Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer`

## Depends on
`aj-tf-module-vpc` — requires data_vpc_id and data_subnet_ids

## Branching convention
- `main` — active development
- `aurora-01` — stable pinned release

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Detect engine version drift vs latest Aurora PostgreSQL
- Validate backup_retention_days meets env policy (prod >= 7)
- Flag deletion_protection=false in prod
- Generate PR for engine version upgrades
- Verify IAM auth is enabled (not password-only)
