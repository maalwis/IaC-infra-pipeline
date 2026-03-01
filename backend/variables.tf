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
