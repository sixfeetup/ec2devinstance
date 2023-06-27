variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS Profile"
  default     = "sfu"
}

variable "path_to_public_key" {
  type    = string
  default = "~/.ssh/ec2dev_key.pub"
}

variable "admin_ip" {
  type = string
}

