resource "aws_key_pair" "ec2_dev_key" {
  key_name   = "ec2_dev_key"
  public_key = file(var.path_to_public_key)
}

