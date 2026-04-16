########################################
# Provider
########################################
provider "aws" {
  region = "us-east-1" # change if needed (e.g. af-south-1)
}

########################################
# Variables
########################################
variable "key_name" {
  description = "Existing AWS key pair"
  default     = "wordpress-key"
}

########################################
# Security Group
########################################
resource "aws_security_group" "devops_sg" {
  name        = "devops_sg"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ restrict in production
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MariaDB"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ restrict if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# AMIs
########################################

# Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }
}
# Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

########################################
# 1. Ansible Controller (Ubuntu)
########################################
resource "aws_instance" "ansible_controller" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install ansible -y
              EOF

  tags = {
    Name = "Ansible-Controller"
  }
}

########################################
# 2. Web Nodes (Amazon Linux) - 2
########################################
resource "aws_instance" "amazon_web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from Amazon Linux Web Node $(hostname)" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Amazon-Web-${count.index}"
  }
}

########################################
# 3. Web Node (Ubuntu + Apache)
########################################
resource "aws_instance" "ubuntu_web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install apache2 -y
              systemctl start apache2
              systemctl enable apache2
              echo "Hello from Ubuntu Web Node $(hostname)" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Ubuntu-Web"
  }
}

########################################
# 4. Database Node (Amazon Linux + MariaDB)
########################################
resource "aws_instance" "db_node" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install mariadb105-server -y
              systemctl start mariadb
              systemctl enable mariadb
              EOF

  tags = {
    Name = "DB-Node"
  }
}

########################################
# Outputs
########################################
output "ansible_controller_ip" {
  value = aws_instance.ansible_controller.public_ip
}

output "amazon_web_ips" {
  value = aws_instance.amazon_web[*].public_ip
}

output "ubuntu_web_ip" {
  value = aws_instance.ubuntu_web.public_ip
}

output "db_node_ip" {
  value = aws_instance.db_node.public_ip
}
