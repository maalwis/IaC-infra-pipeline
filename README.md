# IaC Infrastructure Pipeline

Multi-environment AWS infrastructure pipeline using Terraform and GitHub Actions, with drift detection, branch governance, and progressive deployments across dev, staging, and production.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Branch Strategy](#branch-strategy)
- [Pipeline Overview](#pipeline-overview)
- [Workflow Files](#workflow-files)
- [Pipeline Flow](#pipeline-flow)
- [Network Module](#network-module)
- [Remote State](#remote-state)
- [GitHub Configuration](#github-configuration)
- [AWS Configuration](#aws-configuration)
- [Deployment Guide](#deployment-guide)
- [Troubleshooting](#troubleshooting)

---

## Architecture

### VPC Layout

```
VPC (vpc_cidr)
├── Public Subnets  (one per AZ) — map_public_ip_on_launch = true
└── Private Subnets (one per AZ)
```

### Pipeline Flow

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

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── branch_validation.yml   # Enforces feature/* branch naming on PRs
│       ├── feature_ci.yml          # Terraform plan on feature branch pushes
│       ├── main_ci.yml             # Full pipeline on merge to main
│       ├── deploy_staging.yml      # Staging deploy triggered by v*-staging tag
│       ├── deploy_prod.yml         # Prod deploy triggered by semver tag
│       ├── terraform_plan.yml      # Reusable plan workflow
│       └── terraform_apply.yml     # Reusable apply workflow
│
├── backend/                        # Remote state bootstrap — apply once before any environment
│   ├── main.tf                     # S3 state bucket + DynamoDB lock table
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── versions.tf
│
├── environments/
│   ├── dev/                        # State: infra/dev/terraform.tfstate
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   ├── terraform.tfvars        # gitignored — injected at runtime from GitHub Secret
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── staging/                    # State: infra/staging/terraform.tfstate
│   │   └── ...
│   └── prod/                       # State: infra/prod/terraform.tfstate
│       └── ...
│
└── modules/
    └── network/                    # Reusable VPC module consumed by each environment
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
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
- Pipeline only triggers on infrastructure file changes (`**/*.tf`, `environments/**`, `modules/**`) — documentation and config changes are ignored

---

## Pipeline Overview

### Workflow Files

| File | Trigger | Purpose |
|------|---------|---------|
| `branch_validation.yml` | PR → `main` | Validates `feature/*` branch naming |
| `feature_ci.yml` | Push to `feature/**` | Terraform plan against dev |
| `main_ci.yml` | Push to `main` | Full drift → plan → deploy → release |
| `terraform_plan.yml` | `workflow_call` | Reusable plan workflow |
| `terraform_apply.yml` | `workflow_call` | Reusable apply workflow |
| `deploy_staging.yml` | Tag `v*-staging` | Deploy to staging |
| `deploy_prod.yml` | Tag `v[0-9]+.[0-9]+.[0-9]+` | Deploy to prod |

---

## Workflow Files

### `branch_validation.yml`
**Trigger:** Pull request targeting `main`

Validates the PR source branch follows the `feature/<descriptor>` naming convention.

```
PR from feature/my-change  →  ✅ pass
PR from fix/my-change      →  ❌ fail
PR from main               →  ❌ fail
```

---

### `feature_ci.yml`
**Trigger:** Push to `feature/**` — only when `.tf` or environment files change

Runs Terraform plan against dev on every feature branch push. Validates infrastructure changes before a PR is opened.

Steps: `checkout → configure AWS → init → validate → plan`

---

### `main_ci.yml`
**Trigger:** Push to `main` — only when `.tf` or environment files change

The core pipeline. Runs the full sequence:

| Job | Depends On | Description |
|-----|-----------|-------------|
| `drift-check` | — | Detects infrastructure drift using `terraform plan -detailed-exitcode` |
| `plan-dev` | `drift-check` | Plans Terraform changes for dev |
| `plan-staging` | `drift-check` | Plans Terraform changes for staging |
| `plan-prod` | `drift-check` | Plans Terraform changes for prod |
| `deploy-dev` | all three plans | Applies Terraform to dev automatically |
| `release` | `deploy-dev` | Creates a versioned GitHub Release |

**Drift detection exit codes:**

| Exit Code | Meaning |
|-----------|---------|
| `0` | No changes — infrastructure matches state ✅ |
| `2` | Drift detected — pipeline fails ⚠️ |
| `1` | Terraform error ❌ |

---

### `terraform_plan.yml`
**Type:** Reusable workflow (`workflow_call`)

Shared plan workflow called by `feature_ci` and `main_ci`. Uploads `tfplan` as an artifact retained for 1 day.

Steps: `checkout → configure AWS → init → validate → plan → upload artifact`

---

### `terraform_apply.yml`
**Type:** Reusable workflow (`workflow_call`)

Shared apply workflow called by `main_ci`, `deploy_staging`, and `deploy_prod`.

Steps: `checkout → configure AWS → init → validate → plan → apply`

---

### `deploy_staging.yml`
**Trigger:** Tag matching `v*-staging`

```bash
git tag v1-staging
git push origin v1-staging
```

---

### `deploy_prod.yml`
**Trigger:** Tag matching `v[0-9]+.[0-9]+.[0-9]+`

The semver pattern naturally excludes `-staging` tags. Requires manual approval via the `prod` GitHub Environment.

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Pipeline Flow

### 1. Feature Development
```bash
git checkout -b feature/my-change
# make infrastructure changes
git push origin feature/my-change
# feature_ci triggers if .tf files changed
```

### 2. Pull Request
```bash
# Open PR: feature/my-change → main
# GitHub runs branch_validation + feature_ci
# Both must pass before merge is allowed
```

### 3. Merge to Main
```bash
# Squash and merge PR on GitHub
# main_ci triggers if .tf files changed:
# drift-check → plan-dev + plan-staging + plan-prod → deploy-dev → release
```

### 4. Promote to Staging
```bash
git checkout main
git pull origin main
git tag v1-staging
git push origin v1-staging
```

### 5. Promote to Production
```bash
git tag v1.0.0
git push origin v1.0.0
# Requires manual approval in GitHub Environments
```

---

## Network Module

Provisions a foundational AWS VPC with public and private subnets spread across multiple Availability Zones. Designed as the base networking layer — routing (IGW, NAT Gateway, route tables), VPC endpoints, and flow logs are added as separate modules that consume this module's outputs.

### Usage

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

### Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `aws_region` | `string` | yes | AWS region (e.g. `ap-south-1`) |
| `aws_account_id` | `string` | yes | AWS account ID — appended to S3 bucket name for global uniqueness |
| `project_name` | `string` | yes | Short lowercase identifier prefixed on all resource names |
| `environment` | `string` | yes | One of `dev`, `staging`, `prod` |
| `cost_center` | `string` | yes | FinOps billing code (e.g. `CC-1234`) |
| `vpc_cidr` | `string` | yes | RFC 1918 CIDR for the VPC (e.g. `10.0.0.0/16`) |
| `azs` | `list(string)` | yes | 2–4 Availability Zones |
| `public_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |
| `private_subnet_cidrs` | `list(string)` | yes | One CIDR per AZ, must be subnets of `vpc_cidr` |

### Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_name` | VPC name |
| `vpc_cidr_block` | VPC primary CIDR block |
| `public_subnet_ids` | Public subnet IDs (ordered by AZ) |
| `private_subnet_ids` | Private subnet IDs (ordered by AZ) |
| `availability_zones` | AZs used — reference this in downstream modules |

### Tagging

All resources inherit four baseline tags from the provider `default_tags` block:

| Tag | Source |
|-----|--------|
| `Project` | `var.project_name` |
| `Environment` | `var.environment` |
| `CostCenter` | `var.cost_center` |
| `ManagedBy` | `"terraform"` (hardcoded) |

Individual resources add a `Name` tag and, where relevant, a `Tier` tag (`public` / `private`).

---

## Remote State

Each environment stores its state in a shared S3 bucket with DynamoDB locking to prevent concurrent applies. The `backend/` directory provisions these resources and must be applied once before initialising any environment.

> The state file records the last known result of `terraform apply` — representing what Terraform has provisioned based on your declared configuration, not a live snapshot of the actual infrastructure. Terraform uses it to calculate the diff between your desired configuration and what was last applied.

| Environment | State Key |
|-------------|-----------|
| dev | `infra/dev/terraform.tfstate` |
| staging | `infra/staging/terraform.tfstate` |
| prod | `infra/prod/terraform.tfstate` |

### Backend Config

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

### Backend Outputs

| Name | Description |
|------|-------------|
| `state_bucket_name` | Name of the S3 bucket storing state files |
| `state_bucket_arn` | ARN of the S3 bucket — used for IAM policy definitions |
| `dynamodb_lock_table_name` | Name of the DynamoDB state lock table |
| `dynamodb_lock_table_arn` | ARN of the DynamoDB table — used for IAM policy definitions |

---

## GitHub Configuration

### Repository Secrets

Navigate to **Settings → Secrets and variables → Actions → Repository secrets**:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for `terraform-user` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for `terraform-user` |
| `TERRAFORM_TFVARS` | Contents of `terraform.tfvars` — injected at runtime |

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

Navigate to **Settings → Environments**:

| Environment | Protection |
|-------------|-----------|
| `dev` | None — auto deploys |
| `staging` | Required reviewers (optional) |
| `prod` | Required reviewers (mandatory) |

---

## AWS Configuration

### IAM User

The pipeline authenticates using a static IAM user `terraform-user` with credentials stored as GitHub Secrets. Required permissions:

- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` — Terraform state backend
- `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:DeleteItem` — State locking
- Permissions to manage all resources declared in Terraform

### Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6.0 |
| AWS CLI | any |

---

## Deployment Guide

### First-Time Setup

```bash
# 1. Bootstrap remote state (once only)
cd backend
terraform init
terraform apply

# 2. Clone the repo
git clone git@github.com:maalwis/IaC-infra-pipeline.git
cd IaC-infra-pipeline

# 3. Create a feature branch
git checkout -b feature/initial-setup

# 4. Push and open a PR
git push origin feature/initial-setup
```

### Tagging Reference

| Tag Pattern | Example | Triggers |
|-------------|---------|----------|
| `v*-staging` | `v1-staging` | `deploy_staging.yml` |
| `v[0-9]+.[0-9]+.[0-9]+` | `v1.0.0` | `deploy_prod.yml` |

---

## Troubleshooting

### Credentials could not be loaded
Reusable workflows require `secrets: inherit` in the calling workflow. Verify all `uses:` blocks include this directive.

### Terraform prompting for variables interactively
`terraform.tfvars` is not present at runtime. Ensure the `TERRAFORM_TFVARS` secret exists and the workflow writes it to file before `terraform init`.

### State lock not released
A previous run was cancelled and the DynamoDB lock was not cleaned up. Force unlock using the lock ID from the error output:
```bash
terraform force-unlock <lock-id>
```

### Pipeline not triggering on push
Path filters are active — the pipeline only runs when `.tf` files or `environments/**` / `modules/**` change. Pushes containing only documentation or config changes are intentionally skipped.

### PR merge blocked — approval required
For solo repositories, uncheck **"Require approval of the most recent reviewable push"** in the branch protection rule.

### Branch push rejected (GH006)
Direct pushes to `main` are blocked by branch protection. Always work through a `feature/*` branch and PR.