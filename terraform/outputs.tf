output "frontend_public_ip" {
  value = aws_instance.frontend_instance.public_ip
}

output "bastion_eip" {
  value = aws_eip.bastion_eip.public_ip
}

output "frontend_private_ip" {
  value = aws_instance.frontend_instance.private_ip
}

output "backend_private_ip" {
  value = aws_instance.backend_instance.private_ip
}

output "bastion_private_ip" {
  value = aws_instance.ansible_instance.private_ip
}

output "database_private_ip" {
  value = aws_instance.database_instance.private_ip
}