output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "EC2 Backend Public IP (use in Ansible inventory)"
  value       = module.ec2.public_ip
}

output "s3_bucket_name" {
  value = module.s3.bucket_id
}

output "cloudfront_domain" {
  description = "CloudFront URL for Angular frontend"
  value       = module.cloudfront.cloudfront_domain_name
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
