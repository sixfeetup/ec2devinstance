terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_secretsmanager_secret" "kubeconfig_secret" {
  name        = "ec2dev-kubeconfig"
  description = "ec2dev kubeconfig file"

  tags = { "Name" = "ec2dev-kubeconfig" }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "cloudinit_config" "k3s" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/install-k3s.sh", {
      certmanager_email_address = "roche@sixfeetup.com",
      k3s_url                   = aws_eip.k8s_eip.public_ip,
      k3s_tls_san               = aws_eip.k8s_eip.public_dns,
    })
  }
}

resource "aws_eip" "k8s_eip" {
  vpc = true
}

resource "aws_instance" "k8s" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.e2_custom_profile.name

  root_block_device {
    volume_size = 30
  }

  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_dev_key.key_name

  vpc_security_group_ids = [aws_security_group.admin.id]

  user_data = data.cloudinit_config.k3s.rendered
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.k8s.id
  allocation_id = aws_eip.k8s_eip.id
}

resource "aws_ecr_repository" "ec2dev" {
  name                 = "ec2dev"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

