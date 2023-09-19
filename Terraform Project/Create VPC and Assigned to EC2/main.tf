terraform {
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 4.67.0"
  }
}
}

provider "aws" {
region = "us-east-1"
}

resource "aws_vpc" "test_demo_vpc" {
cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "public_subnet" {
vpc_id = aws_vpc.test_demo_vpc.id
cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "private_subnet" {
vpc_id = aws_vpc.test_demo_vpc.id
cidr_block = "10.0.2.0/24"
}

resource "aws_security_group" "allow_tls" {
name        = "allow_tls"
description = "Allow TLS inbound traffic"
vpc_id      = aws_vpc.test_demo_vpc.id

ingress {
  description      = "TLS from VPC"
  from_port        = 8080
  to_port          = 8080
  protocol         = "tcp"
  cidr_blocks      = [aws_vpc.test_demo_vpc.cidr_block, "0.0.0.0/0"]
}

egress {
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
}

tags = {
  Name = "allow_tls"
}
}

resource "aws_internet_gateway" "demo_gateway" {
vpc_id = aws_vpc.test_demo_vpc.id

tags = {
  Name = "main"
}
}

resource "aws_eip" "lab_elastic_ip" {
vpc = true
}

resource "aws_nat_gateway" "lab_nat_gateway" {
allocation_id = aws_eip.lab_elastic_ip.id
subnet_id     = aws_subnet.public_subnet.id 

tags = {
  Name = "Lab NAT Gateway"
}
depends_on = [aws_internet_gateway.demo_gateway]
}  

resource "aws_route_table" "lab_vpc_public_RouteTable" {
  vpc_id = aws_vpc.test_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_gateway.id
  }

  tags = {
    Name = "VPC_Public_RouteTable"
  }
}

resource "aws_route_table" "lab_vpc_private_RouteTable" {
  vpc_id = aws_vpc.test_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.lab_nat_gateway.id
  }

  tags = {
    Name = "VPC_Private_RouteTable"
  }
}

resource "aws_route_table_association" "lab_public_RouteTable_Assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.lab_vpc_public_RouteTable.id
}

resource "aws_route_table_association" "lab_private_RouteTable_Assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.lab_vpc_private_RouteTable.id
}   

resource "aws_instance" "Lab_Web_Server" {
  ami = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  ##vpc_security_group_ids = [aws_security_group.allow_tls.id]
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = "8"
    delete_on_termination = true
  }
  
  tags = {
    Name = "Lab_Web_Server"
  }
}