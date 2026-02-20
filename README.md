# terraform-network

Provisions a foundational AWS VPC with public and private subnets spread across multiple Availability Zones. Designed as the base networking layer — routing (IGW, NAT Gateway, route tables), VPC endpoints, and flow logs are added as separate modules that consume this module's outputs.

---

## Architecture

```
VPC (vpc_cidr)
├── Public Subnets  (one per AZ) — map_public_ip_on_launch = true
└── Private Subnets (one per AZ)
```

---

## Prerequisites

| Tool      | Version  |
|-----------|----------|
| Terraform | >= 1.6.0 |
| AWS CLI   | any      |

AWS credentials must be available in the environment (environment variables, `~/.aws/credentials`, or an IAM instance profile).

---

## Usage

```hcl
module "network" {
  source = "./modules/network"

  project_name         = "mumbai"
  environment          = "dev"
  cost_center          = "CC-1234"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}
```

---

## Quick Start

```bash
# 1. Initialise
terraform init

# 2. Review the plan
terraform plan

# 3. Apply
terraform apply
```

### Switching to remote state

Edit `versions.tf`: comment out the `backend "local"` block and uncomment the `backend "s3"` block, filling in your bucket name, key, region, and DynamoDB table name. Then re-initialise:

```bash
terraform init -migrate-state
```

---

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `aws_region` | `string` | yes | AWS region (e.g. `ap-south-1`) |
| `project_name` | `string` | yes | Short lowercase identifier prefixed on all resource names |
| `environment` | `string` | yes | One of `dev`, `staging`, `prod` |
| `cost_center` | `string` | yes | FinOps billing code (e.g. `CC-1234`) |
| `vpc_cidr` | `string` | yes | RFC 1918 CIDR for the VPC (e.g. `10.0.0.0/16`) |
| `azs` | `list(string)` | yes | 2–4 Availability Zones |
| `public_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |
| `private_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |

---

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC primary CIDR block |
| `public_subnet_ids` | Public subnet IDs (ordered by AZ) |
| `private_subnet_ids` | Private subnet IDs (ordered by AZ) |
| `availability_zones` | AZs used — reference this in downstream modules |

---

## Tagging

All resources inherit four baseline tags from the provider `default_tags` block:

| Tag | Source |
|---|---|
| `Project` | `var.project_name` |
| `Environment` | `var.environment` |
| `CostCenter` | `var.cost_center` |
| `ManagedBy` | `"terraform"` (hardcoded) |

Individual resources add a `Name` tag and, where relevant, a `Tier` tag (`public` / `private`).

