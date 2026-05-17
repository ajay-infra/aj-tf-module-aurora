# envs/dev.tfvars — Aurora config for dev environment
# Used with: -var-file=envs/dev.tfvars (plus common.tfvars from aj-infra-release)

environment  = "dev"
cluster_name = "ai-search-dev"
aws_region   = "us-east-1"

# Network — filled in by aj-infra-release pipeline from vpc module outputs
# data_vpc_id     = "<from vpc output>"
# data_subnet_ids = ["<from vpc output>"]

blue_vpc_cidr  = "10.102.0.0/16" # dev data VPC CIDR
green_enabled  = false
green_vpc_cidr = ""

az_count = 2 # dev: 2 AZs — min for Aurora HA (writer AZ + failover AZ)

# Engine
engine_version = "16.6"

# Instance class — db.r8g.large for all envs (FinOps: RI family alignment)
# DO NOT change to t4g — breaks r8g RI normalisation and CPU bursts on pgvector
# db.r8g.large: 2 vCPU, 16 GB RAM (~$0.285/hr on-demand, ~$0.190/hr 1yr RI)
instance_class = "db.r8g.large"

# Database
database_name        = "ai_search"
master_username      = "dbadmin"
iam_auth_db_username = "ai_search_app"

# Replication: writer + 1 reader (minimum for failover)
# Cost note: 2× db.r8g.large = ~$0.570/hr = ~$413/month on-demand
# With 1yr RI on writer: ~$345/month effective
# Set replica_count = 0 for extreme cost cuts (loses failover + reader endpoint)
replica_count = 1

# Backup
backup_retention_days = 7
backup_window         = "03:00-04:00"
maintenance_window    = "mon:04:00-mon:05:00"

# Protection — off for dev (easy teardown)
deletion_protection = false

# Observability — disabled for dev (can enable temporarily for debugging)
enable_performance_insights = false

# IAM auth — always true
enable_iam_auth = true

apply_immediately           = true
secret_recovery_window_days = 0 # 0 = immediate delete (avoids name collision on re-create)

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
  Env   = "dev"
}
