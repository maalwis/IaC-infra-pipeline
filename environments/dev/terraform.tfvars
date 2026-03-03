project_name = "mumbai"
aws_region   = "ap-south-1"
environment  = "dev"
cost_center  = "CC-1234"

vpc_cidr = "10.0.0.0/16"

azs      = [
  "ap-south-1a",
  "ap-south-1b",
  "ap-south-1c"
]

public_subnet_cidrs  = [
  "10.0.0.0/24",
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24",
  "10.0.12.0/24",
]
