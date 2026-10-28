# Task 5 — AWS DevSecOps, Security Hardening & Disaster Recovery

Reusable Terraform modules, GitLab OIDC federation, Ansible OS hardening, CI security gates, audit monitoring, and S3 backup/restore scaffolding.

> **Production-readiness note:** This is a secure reference implementation, not a guarantee that a fresh AWS account is production-ready without environment-specific review. Validate quotas, CIDRs, OS image IDs, GitLab issuer/audience/subject claims, organization policies, log retention, recovery requirements, and costs before apply. Test only in an authorized sandbox.

## Repository map

- `terraform/modules/vpc`: VPC, public/private subnets, NAT, routing, VPC flow logs.
- `terraform/modules/iam_oidc`: GitLab OIDC provider and scoped CI role.
- `terraform/modules/security_monitoring`: private audit bucket, CloudTrail, GuardDuty, CloudWatch alarm, EventBridge, and SNS alerts.
- `terraform/modules/compute`: private EC2 application node, encrypted EBS, instance profile, SSM access.
- Root Terraform: CloudTrail, CloudWatch log group/alarms, GuardDuty, SNS, Secrets Manager placeholder, and module wiring.
- `ansible/`: idempotent Ubuntu/Debian security hardening.
- `scripts/`: versioned S3 backup and guarded restore.
- `docs/`: architecture, RTO/RPO, incident response, and test evidence template.

## Prerequisites

1. AWS account with permissions to create VPC, EC2, IAM/OIDC, CloudTrail, CloudWatch, GuardDuty, SNS, S3, and DynamoDB resources. Organization SCPs may block some services.
2. Terraform >= 1.6 (CI pins 1.9.8), AWS CLI v2, Ansible Core, Checkov, Trivy, ShellCheck.
3. GitLab project with protected default branch and protected/manual production deployment.
4. A GitLab issuer URL, normally `https://gitlab.com` (self-managed GitLab differs).
5. An existing, uniquely named S3 state bucket and DynamoDB lock table before enabling the S3 backend.
6. SSH access is deliberately not exposed by default; use AWS Systems Manager Session Manager. If SSH is required, implement a reviewed, restricted CIDR rule and key rotation process.

## Initial setup (safe order)

### 1. Create remote-state prerequisites

Create the state bucket in the intended region using an administrator/bootstrap identity. Enable S3 versioning, block all public access, default SSE-KMS encryption, and bucket-policy enforcement of TLS. Create a DynamoDB table with partition key `LockID` (String), enable point-in-time recovery where available, and restrict access to the CI role. These are intentionally **not** self-created by the backend configuration because Terraform cannot initialize a backend that does not exist yet.

Set `terraform/s3_backend.tf` values to your bucket/key/region/table and run:

```bash
cd terraform
terraform init -backend-config=s3_backend.tf
terraform validate
terraform plan -out=tfplan
terraform show tfplan
# Apply only after reviewing the plan and costs:
terraform apply tfplan
```

Never commit state files, plans, credentials, private keys, or `.tfvars` containing secrets. Add them to `.gitignore` (recommended). The backend bucket/table must be managed separately from this state to avoid circular dependencies.

### 2. Configure variables

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` (the real `.tfvars` should be ignored by Git) and set unique names, GitLab project path, region, and AMI ID. Obtain a current, supported Ubuntu LTS AMI for your region; do not hardcode an old AMI.

```bash
terraform plan -var-file=terraform.tfvars
```

### 3. Configure GitLab CI variables

Set non-secret variables `AWS_ROLE_ARN`, `AWS_DEFAULT_REGION`, `AWS_ROLE_SESSION_NAME` and optionally `SONAR_HOST_URL`, `SONAR_PROJECT_KEY`. Store `SONAR_TOKEN` as masked/protected. AWS credentials are obtained using GitLab ID tokens and STS AssumeRoleWithWebIdentity, not static access keys. Update the trust policy subject to the exact GitLab namespace/project/ref. Test the token claims before production use.

### 4. Ansible

Set the target host in `ansible/inventory/hosts.ini` or use a dynamic AWS inventory. Ensure the operator connects via SSM or a controlled management network. Review the SSH role before applying; it disables root login and password authentication. Keep an existing session open and verify key/SSM access before ending it.

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/secops_hardening.yml --syntax-check
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/secops_hardening.yml --check --diff
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/secops_hardening.yml
```

### 5. Backup and restore

Configure `BACKUP_BUCKET`, `AWS_DEFAULT_REGION`, and a source directory. Run backup first, verify the object and version ID, and conduct restore into an **isolated destination**. Restore refuses to overwrite a non-empty directory unless `ALLOW_OVERWRITE=true` is explicitly set.

```bash
export BACKUP_BUCKET='your-private-backup-bucket'
export BACKUP_PREFIX='task5/app'
export SOURCE_DIR='/srv/myapp/data'
./scripts/backup.sh
export RESTORE_URI='s3://your-private-backup-bucket/task5/app/<timestamp>.tar.gz'
export RESTORE_DIR='/tmp/task5-restore-test'
./scripts/restore.sh
```

The backup script archives files; it is not a database-consistent backup mechanism. Use native database snapshots/backup tooling for databases and test application consistency.

## Security gates and approvals

- Terraform format/validate, Ansible syntax/lint, shell lint.
- Checkov scans the entire Terraform tree, including modules.
- Trivy scans filesystem dependencies, secrets, and misconfigurations; HIGH/CRITICAL findings fail the job.
- SonarQube runs when configured and waits for the quality gate. It is skipped when variables are absent; enable it as a required gate in protected production projects.
- Apply is manual and only on the default branch. Protect the branch/environment and require approvals in GitLab settings.
- Exceptions must have an owner, risk statement, compensating control, expiry date, and ticket; do not globally suppress scanners.
- The rollback job is manual and points operators to an approved runbook; it does not automatically destroy infrastructure.

## Important limitations / production follow-ups

- State backend resources must be provisioned independently as described above.
- Terraform does not create a full application deployment, database, multi-region failover, or immutable backup vault in this starter. Extend modules to match the actual workload and recovery tier.
- CloudTrail organization trails, cross-account log archive, CloudTrail log-file validation, KMS key policies, SNS email subscription confirmation, and retention must be reviewed for your account.
- GuardDuty may incur charges and may be unavailable under account/organization restrictions.
- The CloudWatch metric alarms here are baseline operational alarms; add application-specific metrics and event-driven security findings.
- For actual DR, define a second region, replicated backups/artifacts, DNS/failover plan, and recovery environment. A single-region VPC is not multi-region DR.
- Run all failure simulations only in an isolated authorized environment and capture evidence as described in `docs/test_evidence_and_rollback.md`.

## Troubleshooting

- `InvalidIdentityToken`: verify GitLab issuer, audience (`sts.amazonaws.com`), exact `sub` claim and provider thumbprint/URL.
- `AccessDenied` on `AssumeRoleWithWebIdentity`: review role trust and project/ref conditions; then review permission policy separately.
- Backend lock error: check DynamoDB table name/region and stale-lock procedure; never delete a lock while another run is active.
- SSM offline: verify instance profile permissions, SSM agent, private subnet egress via NAT or VPC endpoints, and DNS.
- SNS no email: confirm subscription from the email inbox and verify alarm action configuration.
- Checkov/Trivy failures: remediate the issue; document a time-bound exception only with approval.

## ETA estimate

A sandbox implementation typically needs **3–5 working days** for infrastructure, pipeline, hardening, and first backup/restore tests, plus **2–3 additional days** for environment-specific approvals, recovery simulations, evidence, and handover. This assumes AWS/GitLab access, a test application, and timely IAM approvals. Multi-region failover and production data/database recovery are separate scope items.
