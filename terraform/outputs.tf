output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "kubernetes_subnet_id" {
  value = aws_subnet.kubernetes.id
}

output "bastion_security_group_id" {
  value = aws_security_group.bastion.id
}

output "control_plane_security_group_id" {
  value = aws_security_group.control_plane.id
}

output "worker_security_group_id" {
  value = aws_security_group.worker.id
}

output "k8s_nodes_security_group_id" {
  value = aws_security_group.k8s_nodes.id
}

