terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend for state management
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "fullstack/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# ─────────────────────────────────────────
# EC2 (Backend - Spring Boot / Node.js)
# ─────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  environment       = var.environment
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  vpc_id            = module.vpc.vpc_id
  allowed_ssh_cidr  = var.allowed_ssh_cidr
}

# ─────────────────────────────────────────
# S3 (Frontend - Angular)
# ─────────────────────────────────────────
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# ─────────────────────────────────────────
# CloudFront (CDN for S3 Frontend)
# ─────────────────────────────────────────
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name        = var.project_name
  environment         = var.environment
  s3_bucket_id        = module.s3.bucket_id
  s3_bucket_domain    = module.s3.bucket_regional_domain_name
  s3_bucket_arn       = module.s3.bucket_arn
}

# ─────────────────────────────────────────
# EKS (Kubernetes Cluster)
# ─────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  instance_types  = var.eks_instance_types
  desired_size    = var.eks_desired_size
  min_size        = var.eks_min_size
  max_size        = var.eks_max_size
}
