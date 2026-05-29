# Terraform + Ansible Full Stack Deployment Guide
## Architecture: Angular (S3+CloudFront) + Spring Boot (EC2) + EKS

---

## FOLDER STRUCTURE

```
project/
├── terraform/
│   ├── main.tf              ← Root module - calls all sub-modules
│   ├── variables.tf         ← All variable definitions
│   ├── outputs.tf           ← Outputs (IPs, URLs, cluster names)
│   ├── environments/
│   │   └── dev/
│   │       └── dev.tfvars   ← Dev environment values
│   └── modules/
│       ├── vpc/             ← VPC, subnets, IGW, NAT, routes
│       ├── ec2/             ← Backend EC2 + Security Group
│       ├── s3/              ← Frontend S3 bucket
│       ├── cloudfront/      ← CloudFront distribution + OAC
│       └── eks/             ← EKS cluster + Node Group + IAM
│
└── ansible/
    ├── ansible.cfg          ← SSH + inventory config
    ├── inventory.ini        ← EC2 host details
    ├── site.yml             ← Main playbook (runs all roles)
    ├── group_vars/
    │   └── all.yml          ← Shared variables (ports, paths, DB)
    └── roles/
        ├── java/            ← Installs Java 17
        ├── nginx/           ← NGINX reverse proxy setup
        └── app-deploy/      ← Copies JAR + systemd service
```

---

## STEP 1 — Prerequisites (One-time setup)

```bash
# Install Terraform
sudo apt install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install Ansible
sudo apt install -y ansible

# Install AWS CLI + configure
sudo apt install -y awscli
aws configure
# Enter: Access Key, Secret Key, eu-north-1, json

# Verify
terraform -v
ansible --version
aws sts get-caller-identity
```

---

## STEP 2 — Edit dev.tfvars

Open `terraform/environments/dev/dev.tfvars` and change:
- `key_name` → your EC2 Key Pair name in AWS
- `allowed_ssh_cidr` → your IP (e.g., "203.x.x.x/32") for security

---

## STEP 3 — Terraform: Create Infrastructure

```bash
cd project/terraform

# Initialize (downloads providers + modules)
terraform init

# Preview what will be created
terraform plan -var-file="environments/dev/dev.tfvars"

# Apply (creates everything)
terraform apply -var-file="environments/dev/dev.tfvars"
# Type 'yes' when prompted
```

**Resources created:**
- VPC with public + private subnets (2 AZs)
- Internet Gateway + NAT Gateway
- EC2 instance (Ubuntu) with Security Group
- S3 bucket (Angular frontend)
- CloudFront distribution (CDN → S3)
- EKS cluster + Node Group (2 nodes)

**Note the outputs:**
```bash
terraform output ec2_public_ip       # → update Ansible inventory
terraform output cloudfront_domain   # → your frontend URL
terraform output eks_cluster_name    # → for kubectl config
```

---

## STEP 4 — Ansible: Update Inventory

Open `ansible/inventory.ini`:
```ini
[backend]
backend-server ansible_host=<PASTE_EC2_PUBLIC_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
```

Also update `ansible/group_vars/all.yml`:
- `db_url` → your RDS endpoint (if using RDS) or localhost
- `db_user` / `db_password` → your DB credentials

---

## STEP 5 — Build Spring Boot JAR

```bash
# In your Spring Boot project
mvn clean package -DskipTests

# JAR will be at: target/backend.jar
# Copy it to the same level as ansible/
```

---

## STEP 6 — Ansible: Deploy Backend to EC2

```bash
cd project/ansible

# Test connectivity first
ansible all -m ping -i inventory.ini

# Run full deployment
ansible-playbook site.yml -i inventory.ini

# What it does:
# 1. java role     → apt install openjdk-17-jdk
# 2. nginx role    → install NGINX + configure reverse proxy (port 80 → 8080)
# 3. app-deploy role → copy JAR + create systemd service + start app + health check
```

**Verify on EC2:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_IP>
sudo systemctl status flipkart-backend
curl http://localhost:8080/actuator/health
```

---

## STEP 7 — Deploy Angular Frontend to S3

```bash
# In your Angular project
cd frontend/

# Build for production (set API URL to EC2)
ng build --configuration production \
  --base-href / \
  --output-path=dist/frontend

# Get S3 bucket name
S3_BUCKET=$(cd ../terraform && terraform output -raw s3_bucket_name)

# Upload to S3
aws s3 sync dist/frontend/ s3://$S3_BUCKET/ --delete

# Invalidate CloudFront cache
CF_ID=$(cd ../terraform && terraform output -raw cloudfront_id)
aws cloudfront create-invalidation --distribution-id $CF_ID --paths "/*"
```

**Frontend URL:**
```bash
terraform output cloudfront_domain
# → https://xxxxxxxx.cloudfront.net
```

---

## STEP 8 — Configure kubectl for EKS

```bash
# Get kubeconfig
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name $(terraform output -raw eks_cluster_name)

# Verify
kubectl get nodes
kubectl get namespaces
```

---

## STEP 9 — Deploy to EKS (Your App Containers)

```bash
# Push your Docker image to ECR first
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com

docker build -t flipkart-backend .
docker tag flipkart-backend:latest <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/flipkart-backend:latest
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/flipkart-backend:latest

# Apply Kubernetes manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -n default
```

---

## CLEANUP (Destroy everything)

```bash
cd project/terraform
terraform destroy -var-file="environments/dev/dev.tfvars"
# Type 'yes'
```

---

## QUICK COMMAND REFERENCE

| Action | Command |
|--------|---------|
| Terraform init | `terraform init` |
| Plan infra | `terraform plan -var-file="environments/dev/dev.tfvars"` |
| Apply infra | `terraform apply -var-file="environments/dev/dev.tfvars"` |
| Ansible ping | `ansible all -m ping -i inventory.ini` |
| Deploy backend | `ansible-playbook site.yml -i inventory.ini` |
| Check EC2 app | `sudo systemctl status flipkart-backend` |
| View EC2 logs | `sudo journalctl -u flipkart-backend -f` |
| Upload frontend | `aws s3 sync dist/ s3://<bucket>/ --delete` |
| EKS config | `aws eks update-kubeconfig --region eu-north-1 --name <cluster>` |
| Destroy all | `terraform destroy -var-file="environments/dev/dev.tfvars"` |
