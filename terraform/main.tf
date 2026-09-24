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

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_subnet" "kubernetes" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.kubernetes_subnet_cidr

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

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-kubernetes"
  public_key = var.ssh_public_key
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.bastion_instance_type
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "${var.project_name}-bastion"
  }
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

  tags = {
    Name = "${var.project_name}-${each.value}"
    Role = each.value == "control-plane" ? "control-plane" : "worker"
  }
}

resource "aws_lb" "kubernetes" {
  name               = "${var.project_name}-k8s"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public.id]

  tags = {
    Name = "${var.project_name}-k8s-nlb"
  }
}
