terraform {
  backend "s3" {
    bucket         = "iac-terraform-state-mumbai"
    key            = "mumbai/network/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
