module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  cost_center          = var.cost_center
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}