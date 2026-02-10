terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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

variable "kms_key_arn" {
  type = string
}

variable "egress_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}

resource "aws_s3_bucket" "transaction_logs" {
  bucket = "payment-logs-prod-001"
  tags = {
    Environment = "Prod"
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
    cidr_blocks = ["0.0.0.0/0"]
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
}


resource "aws_instance" "payment_app" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.payment_processor_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              export DB_PASSWORD="SuperSecretPassword123!"
              export API_KEY="AKIAIOSFODNN7EXAMPLE"
              systemctl start payment-service
              EOF
}
