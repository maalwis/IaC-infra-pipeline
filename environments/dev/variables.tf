# GLOBAL

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into (ap-south-1)."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier (ap-south-1, ap-south-2)."
  }
}

variable "project_name" {
  type        = string
  description = "Short identifier used as a prefix for all resource names and tags. Use lowercase alphanumeric + hyphens only."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3–30 characters, lowercase alphanumeric and hyphens, and must start/end with a letter or digit."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Controls tagging and can be used for workspace-level conditionals."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost center code for FinOps / billing allocation (e.g. CC-1234). Hard-code this per workspace in terraform.tfvars."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{2,20}$", var.cost_center))
    error_message = "cost_center must be 2–20 alphanumeric characters or hyphens."
  }
}


# NETWORKING
variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the VPC. Must be a valid private range (/16–/24 recommended)."

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition = anytrue([
      can(regex("^10\\.", var.vpc_cidr)),
      can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", var.vpc_cidr)),
      can(regex("^192\\.168\\.", var.vpc_cidr)),
    ])
    error_message = "vpc_cidr must be within the RFC 1918 private address space (10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16)."
  }
}

variable "azs" {
  type        = list(string)
  description = "List of Availability Zones to deploy subnets into. Must belong to aws_region."

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 4
    error_message = "azs must contain between 2 and 4 Availability Zones for meaningful HA."
  }

  validation {
    condition     = length(var.azs) == length(distinct(var.azs))
    error_message = "azs must not contain duplicate Availability Zone entries."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "IPv4 CIDR blocks for public subnets — one per AZ. Must be subnets of vpc_cidr."

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs length must match azs length."
  }

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every entry in public_subnet_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(distinct(var.public_subnet_cidrs))
    error_message = "public_subnet_cidrs must not contain duplicate CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "IPv4 CIDR blocks for private subnets — one per AZ. Must be subnets of vpc_cidr."

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs length must match azs length."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every entry in private_subnet_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == length(distinct(var.private_subnet_cidrs))
    error_message = "private_subnet_cidrs must not contain duplicate CIDR blocks."
  }

  validation {
    condition     = length(setintersection(toset(var.public_subnet_cidrs), toset(var.private_subnet_cidrs))) == 0
    error_message = "private_subnet_cidrs and public_subnet_cidrs must not share any CIDR blocks."
  }
}