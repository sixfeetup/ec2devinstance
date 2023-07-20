output "instance_ip" {
  value = aws_eip.k8s_eip.public_ip
}

output "ecr_repo_url" {
  description = "ECR repository"
  value       = aws_ecr_repository.ec2dev.repository_url
}
