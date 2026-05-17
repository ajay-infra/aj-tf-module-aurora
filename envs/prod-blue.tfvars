# envs/prod-blue.tfvars — Aurora config for production
# Aurora is shared across blue + green EKS clusters — no blue/green suffix here.
# green_enabled flips to true only during a live blue/green cutover window.
# Used with: -var-file=envs/prod-blue.tfvars (plus common.tfvars from aj-infra-release)

environment  = "prod"
cluster_name = "ai-search-prod"
aws_region   = "us-east-1"

# Network — filled in by aj-infra-release pipeline from vpc module outputs
# data_vpc_id     = "<from vpc output>"
# data_subnet_ids = ["<from vpc output>"]

blue_vpc_cidr  = "10.122.0.0/16" # prod data VPC CIDR
green_enabled  = false           # flip to true when green EKS cluster is live
green_vpc_cidr = ""              # set to green workload VPC CIDR during cutover

az_count = 3 # prod: 3 AZs — writer + 2 readers spread across all 3 AZs

# Engine
engine_version = "16.6"

# Instance class — db.r8g.xlarge for prod writer and readers
# FinOps: r8g family RI normalisation — 1× db.r8g.xlarge RI (4 units) covers
#   2× db.r8g.large (2 units each) in dev/staging. Buy 1yr All-Upfront RIs for
#   prod instances; normalised units apply across all r8g instances in same region.
# db.r8g.xlarge: 4 vCPU, 32 GB RAM (~$0.570/hr on-demand, ~$0.334/hr 1yr RI)
# Total prod cost (1 writer + 2 readers × db.r8g.xlarge, 1yr All-Upfront):
#   3 × $0.334/hr × 8,760 hrs ≈ $8,784/yr (~$732/month)
#   vs on-demand: 3 × $0.570/hr × 8,760 hrs ≈ $14,983/yr (~$1,249/month)
#   RI savings: ~$6,200/yr (41% off)
instance_class = "db.r8g.xlarge"

# Database
database_name        = "ai_search"
master_username      = "dbadmin"
iam_auth_db_username = "ai_search_app"

# Replication: writer + 2 readers across 3 AZs
# Reader 0 → AZ-b (RAG search queries)
# Reader 1 → AZ-c (Kong rate-limit reads, analytics)
replica_count = 2

# Backup — 30-day PITR for prod compliance
backup_retention_days = 30
backup_window         = "02:00-03:00"
maintenance_window    = "sun:03:00-sun:04:00"

# Protection — on for prod (must be disabled before terraform destroy)
deletion_protection = true

# Observability — always on for prod
enable_performance_insights = true

# IAM auth — always true
enable_iam_auth = true

apply_immediately           = false # prod: changes go through maintenance window only
secret_recovery_window_days = 7

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
  Env   = "prod"
}
