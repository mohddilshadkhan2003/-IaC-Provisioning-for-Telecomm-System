terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for provisioning"
  type        = string
  default     = "ap-south-1"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "telecom-iac-demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use for EC2; if left empty, the latest Amazon Linux 2 AMI is used"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "telecom_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "telecom-iac-vpc"
  }
}

resource "aws_subnet" "telecom_subnet" {
  vpc_id                  = aws_vpc.telecom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "telecom-iac-subnet"
  }
}

resource "aws_internet_gateway" "telecom_igw" {
  vpc_id = aws_vpc.telecom_vpc.id

  tags = {
    Name = "telecom-iac-igw"
  }
}

resource "aws_route_table" "telecom_rt" {
  vpc_id = aws_vpc.telecom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.telecom_igw.id
  }

  tags = {
    Name = "telecom-iac-rt"
  }
}

resource "aws_route_table_association" "telecom_rta" {
  subnet_id      = aws_subnet.telecom_subnet.id
  route_table_id = aws_route_table.telecom_rt.id
}

resource "aws_security_group" "telecom_sg" {
  name        = "telecom-iac-sg"
  description = "Security group for telecom demo instance"
  vpc_id      = aws_vpc.telecom_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "telecom-iac-sg"
  }
}

resource "aws_instance" "telecom_instance" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.telecom_subnet.id
  vpc_security_group_ids      = [aws_security_group.telecom_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Telecom IaC Demo Instance" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.telecom_instance.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.telecom_instance.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.telecom_instance.public_dns
}
