terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_eip" "k8s-ip" {
  instance = aws_instance.k8s.id
  vpc      = true
}

resource "aws_instance" "k8s" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 30
  }

  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_dev_key.key_name

  vpc_security_group_ids = [aws_security_group.admin.id]
}

resource "aws_ecr_repository" "ec2dev" {
  name                 = "ec2dev"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

