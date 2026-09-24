output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "kubernetes_subnet_id" {
  value = aws_subnet.kubernetes.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "control_plane_private_ip" {
  value = aws_instance.kubernetes["control_plane"].private_ip
}

output "worker_private_ips" {
  value = {
    for name in ["worker_1", "worker_2"] : name => aws_instance.kubernetes[name].private_ip
  }
}

output "nlb_dns_name" {
  value = aws_lb.kubernetes.dns_name
}
