data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-kubernetes-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_subnet" "kubernetes" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.kubernetes_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-kubernetes-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "kubernetes" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-kubernetes-private"
  }
}

resource "aws_route_table_association" "kubernetes" {
  subnet_id      = aws_subnet.kubernetes.id
  route_table_id = aws_route_table.kubernetes.id
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for the bastion host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_security_group" "control_plane" {
  name        = "${var.project_name}-control-plane-sg"
  description = "Security group for the Kubernetes control plane"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-control-plane-sg"
  }
}

resource "aws_security_group" "worker" {
  name        = "${var.project_name}-worker-sg"
  description = "Security group for Kubernetes workers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-worker-sg"
  }
}

resource "aws_security_group" "k8s_nodes" {
  name        = "${var.project_name}-k8s-nodes-sg"
  description = "Shared Kubernetes node overlay network traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-k8s-nodes-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_from_admin" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_ssh_to_control_plane" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.control_plane.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_ssh_to_workers" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_api_to_control_plane" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.control_plane.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_http_outbound" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_https_outbound" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "control_plane_ssh_from_bastion" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_api_from_bastion" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_api_from_workers" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "control_plane_kubelet_to_workers" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "control_plane_http_outbound" {
  security_group_id = aws_security_group.control_plane.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "control_plane_https_outbound" {
  security_group_id = aws_security_group.control_plane.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "worker_ssh_from_bastion" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "worker_kubelet_from_control_plane" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.control_plane.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "worker_api_to_control_plane" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.control_plane.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "worker_http_outbound" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "worker_https_outbound" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "k8s_nodes_vxlan_from_nodes" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "k8s_nodes_vxlan_to_nodes" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-kubernetes"
  public_key = var.ssh_public_key
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.main.key_name

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

resource "aws_instance" "kubernetes" {
  for_each = {
    control_plane = "control-plane"
    worker_1      = "worker-1"
    worker_2      = "worker-2"
  }

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.kubernetes_instance_type
  subnet_id     = aws_subnet.kubernetes.id
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = each.key == "control_plane" ? [
    aws_security_group.control_plane.id,
    aws_security_group.k8s_nodes.id,
    ] : [
    aws_security_group.worker.id,
    aws_security_group.k8s_nodes.id,
  ]

  tags = {
    Name = "${var.project_name}-${each.value}"
    Role = each.value == "control-plane" ? "control-plane" : "worker"
  }
}

resource "aws_vpc_security_group_ingress_rule" "k8s_nodes_typha_from_nodes" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id

  ip_protocol = "tcp"
  from_port   = 5473
  to_port     = 5473
}

resource "aws_vpc_security_group_egress_rule" "k8s_nodes_typha_to_nodes" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id

  ip_protocol = "tcp"
  from_port   = 5473
  to_port     = 5473
}
