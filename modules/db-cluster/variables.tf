variable "name_prefix" {
  type        = string
  description = "Resource name prefix (from root locals.name_prefix)"
}

variable "data_vpc_id" {
  type        = string
  description = "Data VPC ID — security group is placed here"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Data VPC subnet IDs (pre-sliced to az_count by root locals)"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed inbound on port 5432 (blue VPC + optional green VPC)"
}

variable "engine_version" {
  type    = string
  default = "16.6"
}

variable "instance_class" {
  type    = string
  default = "db.r8g.large"
}

variable "database_name" {
  type    = string
  default = "ai_search"
}

variable "master_username" {
  type    = string
  default = "dbadmin"
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "enable_iam_auth" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "backup_window" {
  type    = string
  default = "03:00-04:00"
}

variable "maintenance_window" {
  type    = string
  default = "mon:04:00-mon:05:00"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "enable_performance_insights" {
  type    = bool
  default = false
}

variable "apply_immediately" {
  type    = bool
  default = false
}
