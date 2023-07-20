resource "aws_iam_role" "aws_ec2_custom_role" {
  name = "ec2-custom-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    "Name" = "ec2-custom-iam-role"
  }
}

resource "aws_iam_policy" "allow_secrets_manager" {
  name        = "secrets-manager-policy"
  path        = "/"
  description = "Secrets Manager Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
        ],
        Resource = [
          "*"
        ]
      }
    ]
  })

  tags = {
    "Name" = "secrets-manager-policy"
  }
}

resource "aws_iam_policy" "allow_elastic_ip" {
  name        = "elastic-ip-policy"
  path        = "/"
  description = "Elastic IP Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
        ],
        Resource = [
          "*"
        ]
      }
    ]
  })

  tags = {
    "Name" = "elastic-ip-policy"
  }
}


resource "aws_iam_role_policy_attachment" "attach_allow_secrets_manager_policy" {
  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = aws_iam_policy.allow_secrets_manager.arn
}

resource "aws_iam_role_policy_attachment" "attach_allow_elastic_ip_policy" {
  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = aws_iam_policy.allow_elastic_ip.arn
}

resource "aws_iam_instance_profile" "e2_custom_profile" {
  name = "e2-custom-profile"
  role = aws_iam_role.aws_ec2_custom_role.name
}
