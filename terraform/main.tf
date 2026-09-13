resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "3 tier app"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name: "3 tier app"
  }
}