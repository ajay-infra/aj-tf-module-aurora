# example.tfvars — used by CI plan job (backend=false, fake AWS creds)
# Mirrors dev topology at minimal cost.

aws_account_id = "123456789012"

environment  = "dev"
cluster_name = "ai-search-dev"
aws_region   = "us-east-1"

data_vpc_id     = "vpc-00000000000000001"
data_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]

blue_vpc_cidr  = "10.102.0.0/16"
green_enabled  = false
green_vpc_cidr = ""

az_count = 2

engine_version       = "16.6"
instance_class       = "db.r8g.large"
database_name        = "ai_search"
master_username      = "dbadmin"
iam_auth_db_username = "ai_search_app"
replica_count        = 1

backup_retention_days       = 7
backup_window               = "03:00-04:00"
maintenance_window          = "mon:04:00-mon:05:00"
deletion_protection         = false
enable_performance_insights = false
enable_iam_auth             = true
apply_immediately           = true
secret_recovery_window_days = 0

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
  Env   = "dev"
}
