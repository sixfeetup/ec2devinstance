variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "path_to_public_key" {
  type    = string
  default = "./ec2dev_key.pub"
}

variable "admin_ip" {
  type = string
}

