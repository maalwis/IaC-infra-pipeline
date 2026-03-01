# terraform-network

Provisions a foundational AWS VPC with public and private subnets spread across multiple Availability Zones. Designed as the base networking layer — routing (IGW, NAT Gateway, route tables), VPC endpoints, and flow logs are added as separate modules that consume this module's outputs.

---

## Architecture

### Repository Structure

```
.
├── backend/                    # Remote state bootstrap — apply once before any environment
│   ├── main.tf                 # S3 state bucket + DynamoDB lock table
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── versions.tf
│
├── environments/
│   ├── dev/                    # State: infra/dev/terraform.tfstate
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   ├── terraform.tfvars
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── staging/                # State: infra/staging/terraform.tfstate
│   │   └── ...
│   └── prod/                   # State: infra/prod/terraform.tfstate
│       └── ...
│
└── modules/
    └── network/                # Reusable VPC module consumed by each environment
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

### VPC Layout

```
VPC (vpc_cidr)
├── Public Subnets  (one per AZ) — map_public_ip_on_launch = true
└── Private Subnets (one per AZ)
```

### Remote State

Each environment stores its state file in a shared S3 bucket with DynamoDB used for state locking to prevent concurrent applies. The `backend/` configuration provisions these resources and must be applied once before initialising any environment.

> The state file records the last known result of operations such as `terraform apply`, `destroy`, and `refresh` — representing what Terraform has provisioned based on your declared configuration, not a live snapshot of the actual infrastructure. Terraform uses it to calculate the diff between your desired configuration and what was last applied, determining what needs to be created, updated, or destroyed.

| Environment | State Key                         |
|-------------|-----------------------------------|
| dev         | `infra/dev/terraform.tfstate`     |
| staging     | `infra/staging/terraform.tfstate` |
| prod        | `infra/prod/terraform.tfstate`    |

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
  source = "../../modules/network"

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

### 1. Bootstrap remote state (once)

The `backend/` must be applied first to create the S3 bucket and DynamoDB lock table before any environment can use remote state.

```bash
cd backend
terraform init
terraform apply
```

### 2. Initialise and apply an environment

```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

Repeat for `staging` and `prod` by swapping the environment path.

---

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `aws_region` | `string` | yes | AWS region (e.g. `ap-south-1`) |
| `aws_account_id` | `string` | yes | AWS account ID — appended to S3 bucket name for global uniqueness |
| `project_name` | `string` | yes | Short lowercase identifier prefixed on all resource names |
| `environment` | `string` | yes | One of `dev`, `staging`, `prod` |
| `cost_center` | `string` | yes | FinOps billing code (e.g. `CC-1234`) |
| `vpc_cidr` | `string` | yes | RFC 1918 CIDR for the VPC (e.g. `10.0.0.0/16`) |
| `azs` | `list(string)` | yes | 2–4 Availability Zones |
| `public_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |
| `private_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |

---

## Outputs

### Network module

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_name` | VPC name |
| `vpc_cidr_block` | VPC primary CIDR block |
| `public_subnet_ids` | Public subnet IDs (ordered by AZ) |
| `private_subnet_ids` | Private subnet IDs (ordered by AZ) |
| `availability_zones` | AZs used — reference this in downstream modules |

### Backend

| Name | Description |
|---|---|
| `state_bucket_name` | Name of the S3 bucket storing state files |
| `state_bucket_arn` | ARN of the S3 bucket — used for IAM policy definitions |
| `dynamodb_lock_table_name` | Name of the DynamoDB state lock table |
| `dynamodb_lock_table_arn` | ARN of the DynamoDB table — used for IAM policy definitions |

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