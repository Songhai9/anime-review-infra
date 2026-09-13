resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "3 tier app"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "3 tier app"
  }
}


resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "api" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "API"
  }
}

resource "aws_subnet" "database" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "Database"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public route table"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "ngw_eip" {
  domain = "vpc"

  tags = {
    Name = "ngw EIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.ngw_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "api_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "api route table"
  }
}

resource "aws_route_table_association" "api_rt_association" {
  subnet_id      = aws_subnet.api.id
  route_table_id = aws_route_table.api_rt.id
}


resource "aws_route_table" "db_rt" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "database route table"
  }
}

resource "aws_route_table_association" "db_rt_association" {
  subnet_id      = aws_subnet.database.id
  route_table_id = aws_route_table.db_rt.id
}

resource "aws_security_group" "frontend_sg" {
  name        = "frontend_sg"
  description = "Allow internet traffic in"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "frontend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_traffic" {
  security_group_id = aws_security_group.frontend_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
}

resource "aws_vpc_security_group_egress_rule" "allow_traffic_to_backend" {
  security_group_id            = aws_security_group.frontend_sg.id
  referenced_security_group_id = aws_security_group.backend_sg.id
  ip_protocol                  = "tcp"
  to_port                      = 3001
  from_port                    = 3001
}

resource "aws_vpc_security_group_egress_rule" "backend_https_egress" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group" "backend_sg" {
  name        = "backend_sg"
  description = "Allow frontend traffic in"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_to_api" {
  security_group_id            = aws_security_group.backend_sg.id
  referenced_security_group_id = aws_security_group.frontend_sg.id
  from_port                    = 3001
  ip_protocol                  = "tcp"
  to_port                      = 3001
}

resource "aws_vpc_security_group_egress_rule" "allow_traffic_to_db" {
  security_group_id            = aws_security_group.backend_sg.id
  referenced_security_group_id = aws_security_group.database_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}


resource "aws_security_group" "database_sg" {
  name        = "database_sg"
  description = "Security group of the DB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "database-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_to_db" {
  security_group_id            = aws_security_group.database_sg.id
  referenced_security_group_id = aws_security_group.backend_sg.id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "allow_db_to_internet_https" {
  security_group_id = aws_security_group.database_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_db_to_internet_http" {
  security_group_id = aws_security_group.database_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group of the Ansible bastion"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_bastion_to_db" {
  security_group_id            = aws_security_group.bastion_sg.id
  referenced_security_group_id = aws_security_group.database_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_bastion_to_api" {
  security_group_id            = aws_security_group.bastion_sg.id
  referenced_security_group_id = aws_security_group.backend_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_bastion_to_frontend" {
  security_group_id            = aws_security_group.bastion_sg.id
  referenced_security_group_id = aws_security_group.frontend_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_bastion_to_db" {
  security_group_id            = aws_security_group.database_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_bastion_to_frontend" {
  security_group_id            = aws_security_group.frontend_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_bastion_to_backend" {
  security_group_id            = aws_security_group.backend_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}