provider "aws" {
  region = "eu-central-1"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "ssh_access" {
  description = "The ip address where ssh access is allowed from"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_key" {
  description = "ssh key"
  type        = string
  default     = ""
}

resource "aws_instance" "example" {
  ami           = "ami-de486035"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name      = ""
  user_data     = <<-EOF
                  #!/bin/bash
                  echo 'APT::Periodic::Enable "0";' > /etc/apt/apt.conf.d/10cloudinit-disable
                  sudo apt-get -y purge update-notifier-common ubuntu-release-upgrader-core landscape-common unattended-upgrades
                  sudo apt-get update
                  sudo apt-get install apache2 -y
                  service apache2 start
                  echo  >> ${var.ssh_key}" ~/.ssh/authorized_keys
                  EOF
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "terraform-elastic2ls-ec2"
  }
}

resource "aws_security_group" "instance" {
    name = "terraform-elastic2ls-sg-ec2"
    ingress {
      from_port   = var.server_port
      to_port     = var.server_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_access}"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



output "public_ip" {
  value       = aws_instance.example.public_ip
  description = "The public IP of the web server"
}
output "server_port" {
  value       = var.server_port
  description = "The port of the web server"
}
