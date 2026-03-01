terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket = "mumbai-state-management"
    key    = "infra/staging/terraform.tfstate"
    region = "ap-south-1"
    dynamodb_table = "mumbai-terraform-state-lock"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}