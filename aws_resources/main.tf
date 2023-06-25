terraform {
  cloud {
    organization = "farisology"
    workspaces {
      name = "aws_casia"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# config provider
provider "aws" {
  region = "ap-southeast-1"
}

data "aws_vpc" "default" {
  default = true
}

module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "dev_ssh_sg"
  description = "Security group for ssh"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  tags = {
    Name    = "dev_ssh_sg"
    Project = "casia"
    Owner   = "Farisology"

  }
}

module "default_ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "default_ec2_sg"
  description = "Security group for deafult access"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]

  tags = {
    Name    = "default_ec2_sg"
    Project = "casia"
    Owner   = "Farisology"

  }
}

resource "aws_ecr_repository" "casia_registry" {
  name                 = "casia_registry"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name    = "Casia Registry"
    Project = "casia"
    Owner   = "Farisology"
  }
}

#Create an IAM Policy
resource "aws_iam_policy" "casia_ec2_policy" {
  name        = "casia_ec2_policy"
  description = "Provides permission to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:*"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:ecr:::repository/casia_registry"]
      },
      {
        Action = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      }
    ]
  })
}
resource "aws_iam_policy" "casia_sm_read_policy" {
  name        = "casia_sm_read_policy"
  description = "Provides full read access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

#Create an IAM Role
resource "aws_iam_role" "casia_ec2_role" {
  name = "casia_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "RoleForEC2"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "casia_ec2_attach" {
  name       = "casia-role-attachment"
  roles      = [aws_iam_role.casia_ec2_role.name]
  policy_arn = aws_iam_policy.casia_ec2_policy.arn
}

resource "aws_iam_policy_attachment" "casia_sm_attach" {
  name       = "casia-role-attachment"
  roles      = [aws_iam_role.casia_ec2_role.name]
  policy_arn = aws_iam_policy.casia_sm_read_policy.arn
}

resource "aws_iam_instance_profile" "casia-profile" {
  name = "casia_profile"
  role = aws_iam_role.casia_ec2_role.name
}

resource "aws_eip" "casia_api_eip" {
  vpc = true
  tags = {
    Name    = "casia_api_eip"
    Project = "casia"
    Owner   = "Fares Hasan"

  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.casia_server.id
  allocation_id = aws_eip.casia_api_eip.id

}

resource "aws_instance" "casia_server" {
  ami           = "ami-0df7a207adb9748c7"
  instance_type = "t2.micro"
  key_name      = "casia_server"
  root_block_device {
    volume_size = 8
  }
  vpc_security_group_ids = [
    module.default_ec2_sg.security_group_id,
    module.dev_ssh_sg.security_group_id
  ]
  iam_instance_profile = aws_iam_instance_profile.casia-profile.name

  tags = {
    Name    = "Casia API"
    Project = "casia"
    Owner   = "Farisology"
  }
}

resource "aws_security_group" "casia_db_sg" {
  name        = "casia_db_sg"
  description = "Allow inbound traffic to "
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "casia_db_sg"
    Project = "casia"
    Owner   = "Farisology"
  }
}

resource "aws_db_instance" "casia_db" {
  identifier        = "casiadb"
  db_name           = "casia"
  instance_class    = "db.t3.micro"
  allocated_storage = 30
  engine            = "postgres"
  # engine_version         = "14.6"
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.casia_db_sg.id]
  username               = "farisology"
  password               = "do!3ackthis"
}

resource "aws_s3_bucket" "casia_bucket" {
  bucket = "casia-artefacts-bucket"

  tags = {
    Name    = "Casia Artefacts Bucket"
    Project = "casia"
    Owner   = "Farisology"
  }
}

resource "aws_s3_bucket_public_access_block" "casia_bucket_public" {
  bucket = aws_s3_bucket.casia_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
