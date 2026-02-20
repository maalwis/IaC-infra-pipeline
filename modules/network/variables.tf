variable "project_name" {
  type        = string
  description = "Prefix used for resource Name tags."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev / staging / prod)."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for FinOps billing allocation."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones to deploy subnets into."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for public subnets — one per AZ."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private subnets — one per AZ."
}