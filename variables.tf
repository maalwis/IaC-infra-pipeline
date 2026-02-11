variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "project_name" {
  type        = string
  description = "Prefix used for naming/tagging resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones to use"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for public subnets (must match azs length)"

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs length must match azs length."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private subnets (must match azs length)"

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs length must match azs length."
  }
}
