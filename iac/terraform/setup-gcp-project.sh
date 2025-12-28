#!/bin/bash
# GCP Project Setup Script

set -e

ENVIRONMENT=${1:-dev}
PROJECT_ID=${2:-}

if [ -z "$PROJECT_ID" ]; then
  echo "Usage: $0 <environment> <project-id>"
  echo "Example: $0 dev github-agent-dev"
  exit 1
fi

echo "Setting up GCP project: $PROJECT_ID for environment: $ENVIRONMENT"

# Set project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create GCS bucket for Terraform state
BUCKET_NAME="${PROJECT_ID}-terraform-state"
echo "Creating GCS bucket for Terraform state: $BUCKET_NAME"

if ! gsutil ls gs://$BUCKET_NAME &> /dev/null; then
  gsutil mb -p $PROJECT_ID gs://$BUCKET_NAME
  gsutil versioning set on gs://$BUCKET_NAME
  gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME
  echo "Bucket created: gs://$BUCKET_NAME"
else
  echo "Bucket already exists: gs://$BUCKET_NAME"
fi

# Create service account for Terraform
SA_NAME="terraform-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account: $SA_EMAIL"
if ! gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &> /dev/null; then
  gcloud iam service-accounts create $SA_NAME \
    --display-name="Terraform Service Account" \
    --project=$PROJECT_ID
  
  # Grant necessary roles
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/editor"
  
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/container.admin"
  
  echo "Service account created successfully!"
else
  echo "Service account already exists: $SA_EMAIL"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. cd iac/terraform/environments/$ENVIRONMENT"
echo "2. Edit terraform.tfvars with your configuration"
echo "3. export TF_VAR_db_password='your-secure-password'"
echo "4. terraform init"
echo "5. terraform plan"
echo "6. terraform apply"
