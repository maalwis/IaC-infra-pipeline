output "vpc_id" {
  description = "ID of the provisioned VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the provisioned VPC."
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs, one per AZ."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs, one per AZ."
  value       = module.network.private_subnet_ids
}

output "availability_zones" {
  description = "Availability Zones used by the subnets."
  value       = module.network.availability_zones
}