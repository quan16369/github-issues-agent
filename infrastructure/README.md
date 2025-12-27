# GCP Infrastructure with Terraform

Infrastructure as Code cho GitHub Issue Agent trên Google Cloud Platform.

## Kiến trúc

- **VPC Network**: Custom VPC với subnet public và private
- **Cloud SQL**: PostgreSQL 16 instance với private IP
- **GKE**: Google Kubernetes Engine cluster với node pool auto-scaling

## Yêu cầu

1. **Cài đặt công cụ:**
   ```bash
   # Terraform
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Google Cloud SDK
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

2. **Xác thực GCP:**
   ```bash
   gcloud auth application-default login
   ```

3. **Tạo GCP Project:**
   ```bash
   gcloud projects create your-project-id
   gcloud config set project your-project-id
   ```

4. **Bật APIs cần thiết:**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```

## Cấu hình

1. **Copy file cấu hình mẫu:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Chỉnh sửa `terraform.tfvars`:**
   ```hcl
   project_id   = "your-gcp-project-id"
   region       = "us-central1"
   db_password  = "your-secure-password"
   ```

## Deployment

### 1. Khởi tạo Terraform
```bash
cd gcp_terraform_infra
terraform init
```

### 2. Xem kế hoạch thay đổi
```bash
terraform plan
```

### 3. Triển khai infrastructure
```bash
terraform apply
```

### 4. Lấy thông tin kết nối
```bash
# Xem tất cả outputs
terraform output

# Kết nối kubectl với GKE
terraform output -raw get_credentials_command | bash
```

## Kết nối Database

### Từ GKE (trong cluster)
```yaml
env:
  - name: POSTGRES_HOST
    value: "<CLOUD_SQL_PRIVATE_IP>"
  - name: POSTGRES_PORT
    value: "5432"
  - name: POSTGRES_DB
    value: "github_issues"
  - name: POSTGRES_USER
    value: "postgres"
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

### Từ local (qua Cloud SQL Proxy)
```bash
# Cài Cloud SQL Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy

# Chạy proxy
./cloud-sql-proxy <CONNECTION_NAME>

# Kết nối
psql -h 127.0.0.1 -U postgres -d github_issues
```

## Quản lý Infrastructure

### Xem trạng thái
```bash
terraform show
terraform state list
```

### Cập nhật
```bash
# Chỉnh sửa variables.tf hoặc terraform.tfvars
terraform plan
terraform apply
```

### Xóa infrastructure
```bash
terraform destroy
```

## Chi phí ước tính (tháng)

- **GKE**: ~$74/tháng (1 cluster zonal + 1 e2-medium node)
- **Cloud SQL**: ~$17/tháng (db-f1-micro + 10GB SSD)
- **VPC/Network**: ~$5/tháng (NAT gateway)
- **Tổng**: ~$96/tháng

**Tiết kiệm chi phí:**
- Sử dụng preemptible nodes cho GKE
- Tắt resources khi không dùng: `terraform destroy`
- Sử dụng GKE Autopilot thay vì Standard

## So sánh với AWS

| Dịch vụ | AWS | GCP |
|---------|-----|-----|
| VPC | Amazon VPC | Google VPC |
| Kubernetes | EKS Fargate | GKE Autopilot/Standard |
| Database | RDS PostgreSQL | Cloud SQL PostgreSQL |
| IAM | AWS IAM | Google IAM |
| Networking | NAT Gateway | Cloud NAT |

## Troubleshooting

### Lỗi API chưa được bật
```bash
gcloud services enable <API_NAME>
```

### Lỗi quota
```bash
# Kiểm tra quota
gcloud compute project-info describe --project=<PROJECT_ID>

# Yêu cầu tăng quota tại:
# https://console.cloud.google.com/iam-admin/quotas
```

### Kết nối kubectl thất bại
```bash
# Cấu hình lại credentials
gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION>
```

## Security Best Practices

1. **Sử dụng Secret Manager cho passwords:**
   ```bash
   gcloud secrets create db-password --data-file=-
   ```

2. **Bật Binary Authorization cho GKE**
3. **Sử dụng Private GKE cluster**
4. **Bật Cloud Armor cho DDoS protection**
5. **Cấu hình Network Policies**

## Tài liệu tham khảo

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
