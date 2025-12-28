# Checkov Security Scanning Configuration

## Prerequisites
```bash
pip install checkov
```

## Running Security Scans

### Scan all Terraform code
```bash
checkov -d iac/terraform --framework terraform
```

### Scan specific environment
```bash
checkov -d iac/terraform/environments/dev --framework terraform
```

### Scan with specific checks
```bash
checkov -d iac/terraform --check CKV_GCP_1,CKV_GCP_6,CKV_GCP_9,CKV_GCP_14
```

### Generate report
```bash
checkov -d iac/terraform --framework terraform --output json > security-report.json
```

### Integration with CI/CD

Add to your pipeline (Tekton/GitHub Actions):

```yaml
- name: Security Scan
  run: |
    pip install checkov
    checkov -d iac/terraform --framework terraform --soft-fail
```

## Key Security Checks

- **CKV_GCP_1**: Ensure Cloud Storage bucket is encrypted with Customer Supplied Encryption Keys (CSEK)
- **CKV_GCP_6**: Ensure Cloud SQL database is encrypted
- **CKV_GCP_9**: Ensure GKE Clusters are not using default service account
- **CKV_GCP_14**: Ensure Cloud SQL database is not publicly accessible
- **CKV_GCP_15**: Ensure BigQuery tables are encrypted
- **CKV_GCP_18**: Ensure GKE cluster nodes have Secure Boot enabled
- **CKV_GCP_19**: Ensure GKE clusters have private nodes
- **CKV_GCP_20**: Ensure GKE clusters have network policy enabled
- **CKV_GCP_21**: Ensure Cloud SQL database instances are not open to the internet
- **CKV_GCP_22**: Ensure VPC flow logs are enabled for every subnet

## Pre-commit Hook

Add to `.pre-commit-config.yaml`:

```yaml
- repo: https://github.com/bridgecrewio/checkov
  rev: 2.3.0
  hooks:
    - id: checkov
      args: [--quiet, --framework, terraform]
```
