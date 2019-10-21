# Input Variables
#################
variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default     = 8080
}

# Data Sources
##############
data "aws_availability_zones" "all" {}

# Provider configuration
########################
provider "aws" {
  region = "eu-west-1"
}

# Resources
###########
resource "aws_launch_configuration" "example" {
  image_id        = "ami-40d28157"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

############################################
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
  load_balancers       = ["${aws_elb.example.name}"]
  health_check_type    = "ELB"
  min_size             = 2
  max_size             = 10

  tags {
    key                 = "Name"
    value               = "tf-asg-example"
    propagate_at_launch = true
  }
}

##########################################
resource "aws_security_group" "instance" {
  name = "tf-example"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["${aws_security_group.elb.id}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

##############################
resource "aws_elb" "example" {
  name               = "tf-asg-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}

##############################
resource "aws_security_group" "elb" {
  name = "tf-elb-example"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#########
# Outputs
#########
output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}
