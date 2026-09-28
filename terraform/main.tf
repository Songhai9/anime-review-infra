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

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.kubernetes_instance_type
  subnet_id            = aws_subnet.kubernetes.id
  key_name             = aws_key_pair.main.key_name
  iam_instance_profile = each.key == "control_plane" ? aws_iam_instance_profile.kubernetes_control_plane.name : aws_iam_instance_profile.kubernetes_worker.name

  vpc_security_group_ids = each.key == "control_plane" ? [
    aws_security_group.control_plane.id,
    aws_security_group.k8s_nodes.id,
    ] : [
    aws_security_group.worker.id,
    aws_security_group.k8s_nodes.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

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
resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-nlb-sg"
  description = "Security group for the public ingress NLB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow_k8s_nodes"
  }
}

resource "aws_vpc_security_group_ingress_rule" "worker_http_from_nlb" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = 30080
  ip_protocol                  = "tcp"
  to_port                      = 30080
}

resource "aws_vpc_security_group_ingress_rule" "worker_https_from_nlb" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = 30443
  ip_protocol                  = "tcp"
  to_port                      = 30443
}

resource "aws_vpc_security_group_ingress_rule" "nlb_https_from_internet" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "nlb_http_from_internet" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "ingress_between_workers" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
}

resource "aws_vpc_security_group_egress_rule" "egress_between_workers" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
}

resource "aws_vpc_security_group_egress_rule" "nlb_http_to_workers" {
  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 30080
  to_port                      = 30080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nlb_https_to_workers" {
  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 30443
  to_port                      = 30443
  ip_protocol                  = "tcp"
}

resource "aws_lb" "main" {
  name               = "anilist-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb.id]
  subnets            = [aws_subnet.public.id]

  tags = {
    Name = "${var.project_name}-infra-nlb"
  }

}

resource "aws_lb_target_group" "ingress_http" {
  name        = "${var.project_name}-ingress-http"
  port        = 30080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "ingress_http_workers" {
  for_each = {
    for key, instance in aws_instance.kubernetes :
    key => instance
    if key != "control_plane"
  }

  target_group_arn = aws_lb_target_group.ingress_http.arn
  target_id        = each.value.id
  port             = 30080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_http.arn
  }
}

resource "aws_lb_target_group" "ingress_https" {
  name        = "${var.project_name}-ingress-https"
  port        = 30443
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "ingress_https_workers" {
  for_each = {
    for key, instance in aws_instance.kubernetes :
    key => instance
    if key != "control_plane"
  }

  target_group_arn = aws_lb_target_group.ingress_https.arn
  target_id        = each.value.id
  port             = 30443
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_https.arn
  }
}

resource "aws_iam_role" "kubernetes_worker" {
  name = "${var.project_name}-kubernetes-worker"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-kubernetes-worker"
  }
}

resource "aws_iam_role_policy_attachment" "kubernetes_worker" {
  role       = aws_iam_role.kubernetes_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

resource "aws_iam_instance_profile" "kubernetes_worker" {
  name = "${var.project_name}-kubernetes-worker-profile"
  role = aws_iam_role.kubernetes_worker.name
}

data "aws_iam_openid_connect_provider" "gitlab" {
  url = "https://gitlab.com"
}
resource "aws_iam_role" "k8s_cd" {
  name = "k8s-cd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.gitlab.arn
        }
        Condition = {
          StringEquals = {
            "gitlab.com:aud" = "sts.amazonaws.com"

            "gitlab.com:sub" = "project_path:anilist-cicd/anilist-k8s:ref_type:branch:ref:main"
          }
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}
resource "aws_iam_role_policy" "k8s_cd" {
  name = "k8s-cd-ec2-describe"
  role = aws_iam_role.k8s_cd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeAddresses",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "kubernetes_control_plane" {
  name = "${var.project_name}-kubernetes-control-plane"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-kubernetes-control-plane"
  }
}

resource "aws_iam_role_policy_attachment" "kubernetes_control_plane_ssm" {
  role       = aws_iam_role.kubernetes_control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "kubernetes_control_plane" {
  name = "${var.project_name}-kubernetes-control-plane-profile"
  role = aws_iam_role.kubernetes_control_plane.name
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "k8s_cd_ssm" {
  name = "k8s-cd-ssm"
  role = aws_iam_role.k8s_cd.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ssm:SendCommand"
        ]

        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kubernetes_worker_ssm" {
  role       = aws_iam_role.kubernetes_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}