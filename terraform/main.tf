terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "devops_sg" {
  name        = "auto-devops-sg"
  description = "Security group for Auto DevOps Lab sandbox"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allow_cidr]
  }

  ingress {
    description = "HTTP (Nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Sample app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "auto-devops-sg"
  }
}

resource "aws_instance" "sandbox" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  # Optional key name (for SSH access)
  key_name = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/userdata.tpl.sh", {
    git_repo   = var.git_repo,
    enable_ai  = var.enable_ai_assistant,
    openai_key = var.openai_api_key
  })

  tags = {
    Name = "auto-devops-sandbox"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}

resource "aws_eip" "sandbox_ip" {
  instance = aws_instance.sandbox.id
  domain   = "vpc"
}
