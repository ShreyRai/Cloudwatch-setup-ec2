terraform {
  backend "s3" {
    bucket       = "tf-state-enterprise-grade-bucket"
    key          = "statefiles/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true  
    encrypt      = true
  }
}

# ============================================================
# IAM ROLE
# ============================================================

resource "aws_iam_role" "iamrole1" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach CloudWatch Agent policy
resource "aws_iam_role_policy_attachment" "iampolicy1" {
  role       = aws_iam_role.iamrole1.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "iamprofile1" {
  name = var.instance_profile_name
  role = aws_iam_role.iamrole1.name
}

# ============================================================
# AMI DATA SOURCE
# ============================================================

data "aws_ami" "azlinux23" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# EC2 INSTANCE
# ============================================================

resource "aws_instance" "web" {
  ami           = data.aws_ami.azlinux23.id
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.iamprofile1.name

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y

              # Install CloudWatch Agent
              dnf install -y amazon-cloudwatch-agent

              # Create CloudWatch Agent config
              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "metrics": {
                  "namespace": "EC2/Custom",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": ["cpu_usage_idle", "cpu_usage_user"],
                      "metrics_collection_interval": 60
                    },
                    "mem": {
                      "measurement": ["mem_used_percent"],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              EOT

              # Start CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config \
              -m ec2 \
              -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
              -s
              EOF

  tags = {
    Name = "cw-agent-instance"
  }
}
