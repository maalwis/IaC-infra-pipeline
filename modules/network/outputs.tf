output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC. Useful when authoring security group rules in other modules."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs ordered by AZ. Consumed by load balancer, NAT gateway, and bastion modules."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs ordered by AZ. Consumed by compute, RDS, and EKS node-group modules."
  value       = [for s in aws_subnet.private : s.id]
}

output "public_subnet_cidr_blocks" {
  description = "CIDR blocks of the public subnets. Useful for route table and security group rules in downstream modules."
  value       = [for s in aws_subnet.public : s.cidr_block]
}

output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the private subnets."
  value       = [for s in aws_subnet.private : s.cidr_block]
}

output "availability_zones" {
  description = "Availability Zones in which subnets were created. Downstream modules should reference this rather than re-declaring the AZ list."
  value       = var.azs
}