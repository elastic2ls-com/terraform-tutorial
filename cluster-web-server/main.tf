provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "all" {}

variable "ssh_access" {
  description = "The ip address where ssh access is allowed from"
  type        = string
  default     = "0.0.0.0/0"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "ssh_key" {
  description = "ssh key"
  type        = string
  default     = ""
}

resource "aws_security_group" "instance" {
    name = "terraform-elastic2ls-sg-ec2"
    ingress {
      from_port   = var.server_port
      to_port     = var.server_port
      protocol    = "tcp"
      security_groups    = [aws_security_group.elb.id]
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

resource "aws_launch_configuration" "tutorial" {
  image_id        = "ami-de486035"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]
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
  tag {
    key                 = "Name"
    value               = "terraform-elastic2ls-ec2"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "tutorial" {
  launch_configuration = aws_launch_configuration.tutorial.id
  availability_zones   = data.aws_availability_zones.all.names
  min_size = 2
  max_size = 10
  load_balancers    = [aws_elb.tutorial.name]
  health_check_type = "ELB"
  tag {
    key                 = "Name"
    value               = "terraform-elastic2ls-asg"
    propagate_at_launch = true
  }
}

resource "aws_elb" "tutorial" {
  name               = "terraform-elastic2ls-elb"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names  # This adds a listener for incoming HTTP requests.
  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-elastic2ls-sg-elb"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "clb_dns_name" {
  value       = aws_elb.tutorial.dns_name
  description = "The domain name of the load balancer"
}
