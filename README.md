# IaC Infrastructure Pipeline

Infrastructure as Code pipeline using Terraform and GitHub Actions, with multi-environment deployment, drift detection, and branch governance.

---

## Table of Contents

- [Pipeline Overview](#pipeline-overview)
- [Branch Strategy](#branch-strategy)
- [Workflow Files](#workflow-files)
- [Pipeline Flow](#pipeline-flow)
- [Environment Structure](#environment-structure)
- [GitHub Configuration](#github-configuration)
- [AWS Configuration](#aws-configuration)
- [Deployment Guide](#deployment-guide)
- [Troubleshooting](#troubleshooting)

---

## Pipeline Overview

```
feature/* ──► PR ──► main ──► drift-check
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼               ▼
                plan-dev     plan-staging      plan-prod
                    └──────────────┼──────────────┘
                                   ▼
                               deploy-dev  (auto)
                                   │
                                   ▼
                                release  (GitHub Release)
                                   │
                      manual: git tag v1-staging
                                   ▼
                               deploy-staging  (manual approval)
                                   │
                      manual: git tag v1.0.0
                                   ▼
                               deploy-prod  (manual approval)
```

---

## Branch Strategy

| Branch | Purpose | Direct Push |
|--------|---------|-------------|
| `main` | Production trunk | ❌ Blocked |
| `feature/*` | All development work | ✅ Allowed |

- All changes to `main` must go through a Pull Request from a `feature/*` branch
- PRs from non-`feature/` branches are automatically rejected by `branch_validation`
- `main` is protected with required status checks and linear history enforcement

---

## Workflow Files

### `branch_validation.yml`
**Trigger:** Pull request targeting `main`

Validates that the PR source branch follows the `feature/<descriptor>` naming convention. PRs from any other branch pattern are automatically failed.

```
PR from feature/my-change  →  ✅ pass
PR from fix/my-change      →  ❌ fail
PR from main               →  ❌ fail
```

---

### `feature_ci.yml`
**Trigger:** Push to any `feature/**` branch

Runs a Terraform plan against the `dev` environment on every push to a feature branch. Ensures infrastructure changes are valid before a PR is opened.

Steps: `checkout → configure AWS → terraform init → validate → plan`

---

### `main_ci.yml`
**Trigger:** Push to `main` (i.e. after PR merge)

The core pipeline. Runs the full sequence:

| Job | Depends On | Description |
|-----|-----------|-------------|
| `drift-check` | — | Detects infrastructure drift using `terraform plan -detailed-exitcode` |
| `plan-dev` | `drift-check` | Plans Terraform changes for dev environment |
| `plan-staging` | `drift-check` | Plans Terraform changes for staging environment |
| `plan-prod` | `drift-check` | Plans Terraform changes for prod environment |
| `deploy-dev` | all three plans | Applies Terraform to dev automatically |
| `release` | `deploy-dev` | Creates a GitHub Release with auto-generated notes |

**Drift detection exit codes:**
- `0` — No changes, infrastructure matches state ✅
- `2` — Drift detected, pipeline fails ⚠️
- `1` — Terraform error ❌

---

### `terraform_plan.yml`
**Type:** Reusable workflow (`workflow_call`)

Shared plan workflow called by `feature_ci`, `main_ci`. Accepts `environment` and `working_directory` as inputs. Uploads `tfplan` as an artifact retained for 1 day.

Steps: `checkout → configure AWS → init → validate → plan → upload artifact`

---

### `terraform_apply.yml`
**Type:** Reusable workflow (`workflow_call`)

Shared apply workflow called by `main_ci`, `deploy_staging`, `deploy_prod`. Always runs init → validate → plan → apply in sequence.

Steps: `checkout → configure AWS → init → validate → plan → apply`

---

### `deploy_staging.yml`
**Trigger:** Push of tag matching `v*-staging` (e.g. `v1-staging`)

Deploys to the staging environment. Requires manual approval if the `staging` GitHub Environment is configured with required reviewers.

```bash
# To trigger staging deployment
git tag v1-staging
git push origin v1-staging
```

---

### `deploy_prod.yml`
**Trigger:** Push of tag matching `v[0-9]+.[0-9]+.[0-9]+` (e.g. `v1.0.0`)

Deploys to the production environment. The semver pattern naturally excludes `-staging` tags. Requires manual approval via the `prod` GitHub Environment.

```bash
# To trigger production deployment
git tag v1.0.0
git push origin v1.0.0
```

---

## Pipeline Flow

### 1. Feature Development
```bash
git checkout -b feature/my-change
# make changes
git push origin feature/my-change
# feature_ci runs automatically (terraform plan on dev)
```

### 2. Pull Request
```bash
# Open PR: feature/my-change → main
# GitHub runs:
#   - branch_validation (checks branch name)
#   - feature_ci (terraform plan)
# Both must pass before merge is allowed
```

### 3. Merge to Main
```bash
# Squash and merge PR on GitHub
# main_ci runs automatically:
#   drift-check → plan-dev + plan-staging + plan-prod → deploy-dev → release
```

### 4. Promote to Staging
```bash
git checkout main
git pull origin main
git tag v1-staging
git push origin v1-staging
# deploy_staging runs — approve in GitHub Environments if configured
```

### 5. Promote to Production
```bash
git tag v1.0.0
git push origin v1.0.0
# deploy_prod runs — requires manual approval in GitHub Environments
```

---

## Environment Structure

```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars        # gitignored — stored as GitHub Secret
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars        # gitignored — stored as GitHub Secret
└── prod/
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars        # gitignored — stored as GitHub Secret
```

`terraform.tfvars` files are gitignored and injected at runtime from GitHub Secrets.

---

## GitHub Configuration

### Repository Secrets

Navigate to **Settings → Secrets and variables → Actions → Repository secrets** and add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for `terraform-user` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for `terraform-user` |
| `TERRAFORM_TFVARS` | Contents of `terraform.tfvars` (all environments) |

### Branch Protection — `main`

Navigate to **Settings → Branches → Add rule** for `main`:

| Setting | Value |
|---------|-------|
| Require a pull request before merging | ✅ |
| Require status checks to pass | ✅ |
| Required checks | `validate-branch-name`, `ci / terraform` |
| Require branches to be up to date | ✅ |
| Require linear history | ✅ |
| Do not allow bypassing the above settings | ✅ |

### GitHub Environments

Navigate to **Settings → Environments** and create:

| Environment | Protection |
|-------------|-----------|
| `dev` | None — auto deploys |
| `staging` | Required reviewers (optional) |
| `prod` | Required reviewers (mandatory) |

---

## AWS Configuration

### IAM User
The pipeline uses a static IAM user `terraform-user` with credentials stored as GitHub Secrets. The user requires permissions to manage all resources defined in Terraform, plus:

- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` — Terraform state backend
- `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:DeleteItem` — State locking

### State Backend
Terraform state is stored in S3 with DynamoDB locking:

```hcl
terraform {
  backend "s3" {
    bucket         = "mumbai-state-management"
    key            = "infra/<environment>/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "<your-lock-table>"
  }
}
```

### State Lock Issues
If a pipeline is cancelled mid-run, the DynamoDB lock may not be released. To force unlock:

```bash
# Get the lock ID from the error message, then:
terraform force-unlock <lock-id>
```

---

## Deployment Guide

### First-Time Setup

```bash
# 1. Clone the repo
git clone git@github.com:maalwis/IaC-infra-pipeline.git
cd IaC-infra-pipeline

# 2. Create your feature branch
git checkout -b feature/initial-setup

# 3. Make your infrastructure changes
# 4. Push and open a PR
git push origin feature/initial-setup
```

### Tagging Reference

| Tag Pattern | Example | Triggers |
|------------|---------|----------|
| `v*-staging` | `v1-staging` | `deploy_staging.yml` |
| `v[0-9]+.[0-9]+.[0-9]+` | `v1.0.0` | `deploy_prod.yml` |

---

## Troubleshooting

### Credentials could not be loaded
Reusable workflows require `secrets: inherit` in the calling workflow. Verify all `uses:` blocks include this directive.

### Terraform prompting for variables interactively
`terraform.tfvars` is not present. Ensure the `TERRAFORM_TFVARS` secret is set and the workflow writes it to file before `terraform init`.

### State lock not released
A previous run was cancelled. Run `terraform force-unlock <lock-id>` locally with the lock ID from the error output.

### PR merge blocked — approval required
For solo repositories, uncheck **"Require approval of the most recent reviewable push"** in the branch protection rule.

### Branch push rejected (GH006)
Direct pushes to `main` are blocked by branch protection. Always work through a `feature/*` branch and PR.

---
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