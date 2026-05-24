# github-workflows-ci-cd

This repository serves as the single source of truth for shared GitHub Actions workflows, enabling consistent CI/CD pipelines across all repositories.

---

## Workflows

### 1. `dotnet-build-deploy.yml` — .NET Elastic Beanstalk Deployment

Builds and deploys a .NET 8 application to AWS Elastic Beanstalk. Triggered on PR label events or push to an environment branch.

**Triggers:**
- `pull_request` — on `labeled` or `synchronize` when the label `needs-business-review` is present
- `push` — on `<env-branch>`
- `workflow_dispatch`

**Jobs:** `build` → `deploy` → `comment` (posts PR comment with deployment URL)

**Placeholders to replace:**
| Placeholder | Description |
|---|---|
| `<Env>` | Environment display name (e.g. `Dev`, `Staging`) |
| `<env-branch>` | Branch name that triggers the push deploy |
| `<env-nam>` | GitHub Environment name |
| `<branch-nam>` | Branch to pull `.csproj` overlay from |
| `<app-name>` | Application name (used for artifact/zip naming) |
| `<runner-name>` | Self-hosted runner label |

**Required Secrets:** `AWS_ACCOUNT_ID`, `AWS_PROFILE`, `AWS_DEFAULT_REGION`

**Required Variables:** `APPLICATION_NAME`, `ENVIRONMET_NAME`

---

### 2. `angular-bulid-deploy.yml` — Angular S3 / CloudFront Deployment

Builds an Angular 17 application and deploys the static output to S3, then invalidates the CloudFront distribution.

**Triggers:**
- `push` — on `<env>` branch

**Jobs:** `build` → `deploy`

**Placeholders to replace:**
| Placeholder | Description |
|---|---|
| `<env>` | Environment name / branch name |
| `<app-name>` | Angular app name (matches `dist/<app-name>/browser`) |
| `<runner-name>` | Self-hosted runner with S3/CloudFront access |

**Required Secrets:** `S3_BUCKET`, `AWS_PROFILE`, `CLOUDFRONT_DISTRIBUTION_ID`

**Required Variables:** `AWS_DEFAULT_REGION`

---

### 3. `lambda-deploy.yml` — .NET Lambda (Zip) Deployment

Builds a .NET 8 Lambda function, zips the output, uploads it to AWS Lambda, publishes a new version, and updates the `Currently-Deployed` alias.

**Triggers:**
- `push` — on `<env-branch>` branch

**Jobs:** `build` → `deploy`

**Placeholders to replace:**
| Placeholder | Description |
|---|---|
| `<Env>` | Environment display name |
| `<env-branch>` | Branch that triggers the deploy |
| `<env>` | GitHub Environment name |
| `<app-name>` | Lambda function artifact name |
| `<runner-name>` | Self-hosted runner label |

**Required Secrets:** `AWS_PROFILE`, `AWS_DEFAULT_REGION`

**Required Variables:** `FUNCTION_NAME`

---

### 4. `lambda-container-deploy.yml` — .NET Lambda (Container Image) Deployment

Builds a .NET 8 Lambda function, packages it as a Docker image, pushes it to ECR, and updates the Lambda function code.

**Triggers:**
- `push` — on `<env>` branch

**Jobs:** `build` → `deploy`

**Placeholders to replace:**
| Placeholder | Description |
|---|---|
| `<Env>` | Environment display name |
| `<env>` | Branch name and GitHub Environment name |
| `<app-name>` | Docker image / artifact name |
| `<runner-name>` | Self-hosted runner with Docker and ECR access |

**Required Secrets:** `AWS_PROFILE`

**Required Variables:** `AWS_DEFAULT_REGION`, `ECR_REPO_URI`, `ECR_REPO_NAME`, `FUNCTION_NAME`

---

### 5. `db-sync/db-sync.yml` — Database Synchronizer

Manually triggered workflow that synchronizes databases and optionally copies S3 prod support documents between buckets. Requires companion shell scripts (`syncronize-database.sh`, `copy-s3-object.sh`) to be present in the repository root.

**Triggers:**
- `workflow_dispatch` (manual only)

**Inputs:**
| Input | Required | Description |
|---|---|---|
| `database` | Yes | Target database (`database1` or `database2`) |
| `purpose` | Yes | Operation type (`backup`, `backup_and_add_purpose`, `prod_support_refresh`) |
| `renamepurpose` | No | Backup label suffix — used only with `backup_and_add_purpose` |
| `sync_s3` | No | Whether to sync S3 documents (`yes` / `no`) |
| `s3_start_date` | No | Start date for S3 copy filter (`YYYY-MM-DD`) |
| `s3_end_date` | No | End date for S3 copy filter (`YYYY-MM-DD`) |

**Placeholders to replace:**
| Placeholder | Description |
|---|---|
| `<runner-name>` | Self-hosted runner with database and S3 access |

**Required Secrets:** `PASSWORD`, `USERNAME`

**Required Variables:** `HOST`, `S3_SRC_BUCKET`, `S3_DST_BUCKET`

**GitHub Environment:** `db_sync`

---

## Usage

1. Copy the relevant workflow file(s) into `.github/workflows/` of your target repository.
2. Replace all `<placeholder>` values with your actual environment, app, and runner names.
3. Configure the required **Secrets** and **Variables** in your repository's GitHub Environment settings.
4. For `db-sync`, also copy `db-sync/syncronize-database.sh` and `db-sync/copy-s3-object.sh` to the root of your target repository.

---

## Action Versions

| Action | Version Used |
|---|---|
| `actions/checkout` | `v4` |
| `actions/setup-dotnet` | `v3` |
| `actions/setup-node` | `v4` |
| `actions/upload-artifact` | `v4` |
| `actions/download-artifact` | `v4` |
| `actions/github-script` | `v7` |
