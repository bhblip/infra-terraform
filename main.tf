terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "transaction_logs" {
  bucket = "payment-logs-prod-001"
  tags = {
    Environment = "Prod"
  }
}

resource "aws_s3_bucket_public_access_block" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "payment_processor_sg" {
  name        = "payment-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.egress_cidr_blocks
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = var.egress_cidr_blocks
  }
}

resource "aws_instance" "payment_app" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.payment_processor_sg.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
              #!/bin/bash
              DB_PASSWORD=$(aws secretsmanager get-secret-value \
                --secret-id payment-app/db-password \
                --query SecretString --output text)
              systemctl start payment-service
              EOF
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr_blocks" {
  type = list(string)
}

variable "allowed_ingress_cidrs" {
  type = list(string)
}

variable "egress_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}
