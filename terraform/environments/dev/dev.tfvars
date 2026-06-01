aws_region   = "eu-north-1"
project_name = "flipkart"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"

# EC2
instance_type    = "t3.medium"
key_name         = "your-key-pair-name"   # <-- change this
allowed_ssh_cidr = "0.0.0.0/0"

# EKS
eks_instance_types = ["t3.medium"]
eks_desired_size   = 2
eks_min_size       = 1
eks_max_size       = 2
