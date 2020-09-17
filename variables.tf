variable "region" {
  description = "provider region"
  type = string
  default = ""
}

variable "vpc_id" {
  description = "vpc id for elasticache redis"
  type = string
  default = ""
}

variable "lambda_subnet_ids" {
  description = "subnets of lambda's"
  type = list(string)
  default = []
}

variable "redis_vpc_subnet_ids" {
  description = "subnets id's of redis"
  type = list(string)
  default = []
}

variable "vpc_security_group_ids" {
  description = "sg's of lambda's"
  type = list(string)
  default = []
}

variable "allowed_cidr" {
  description = "allowed cidr of redis sg"
  type = list(string)
  default = []
}

variable "bucket_name" {
  description = "bucket name"
  type = string
  default = "dy-demo"
}

variable "email" {
  description = "email for notifications"
  type = string
  default = ""
}