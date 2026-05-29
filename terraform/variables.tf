variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "flipkart"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# ── EC2 ──
variable "ami_id" {
  description = "AMI ID for EC2 (Ubuntu 22.04 eu-north-1)"
  type        = string
  default     = "ami-0989fb15ce71ba39e"  # Ubuntu 22.04 Stockholm
}

variable "instance_type" {
  description = "EC2 instance type for backend"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH"
  type        = string
  default     = "0.0.0.0/0"  # Change to your IP in prod
}

# ── EKS ──
variable "eks_instance_types" {
  description = "EKS Node Group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_size" {
  type    = number
  default = 2
}

variable "eks_min_size" {
  type    = number
  default = 1
}

variable "eks_max_size" {
  type    = number
  default = 4
}
