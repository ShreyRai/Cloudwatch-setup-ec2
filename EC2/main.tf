resource "aws_iam_role" "iamrole1" {
  name = var.iam_role_name
  assume_role_policy = jsondecode(
    {
        Version = "12-10-17"
        Statement = [
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazon.com"
            }
            Action = "sts.assume.role"
        ]
    }
  )
}
resource "aws_iam_role_policy_attachment" "iampolicy1" {
    role = aws_iam_role.iamrole1.name
    policy_arn = "arn:aws:iam:aws:policy/CloudWatchAgentServerPolicy"
    
}

resource "aws_iam_instance_profile" "iamprofile1" {
    role = aws_iam_role.iamrole1.name
    name = var.instance_profile_name
  
}

#============================================================

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

resource "aws_instance" "web" {
  ami           = data.aws_ami.azlinux23
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y

              # Install CloudWatch Agent
              yum install -y amazon-cloudwatch-agent

              # Create config file
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