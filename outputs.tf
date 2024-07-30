output "public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.main[*].public_ip
}

# 실제 프로덕션 환경에서는 절대 아래와 같이 민감정보를 Output으로 사용하지 마세요.
output "private_key" {
  description = "Private key for SSH access"
  value       = nonsensitive(tls_private_key.minikube.private_key_pem)
  # sensitive   = true
}

output "public_key" {
  description = "Public key for SSH access"
  value       = tls_private_key.minikube.public_key_openssh
}

output "ssh_command" {
  description = "SSH command to connect to the instances"
  value       = formatlist("ssh -i ~/.ssh/minikube ubuntu@%s", aws_instance.main[*].public_ip)
}

#output "instance_ids" {
#  description = "IDs of the EC2 instances"
#  value       = aws_instance.main[*].id
#}

#output "vpc_id" {
#  description = "ID of the VPC"
#  value       = aws_vpc.main.id
#}

#output "public_subnet_ids" {
#  description = "IDs of the public subnets"
#  value       = aws_subnet.public[*].id
#}

#output "security_group_id" {
#  description = "ID of the security group"
#  value       = aws_security_group.main.id
#}

