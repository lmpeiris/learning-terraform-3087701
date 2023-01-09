data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "default_sg" {
  name = "terra_tute_web_sg"
  description = "allow access to web"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "default_sg_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default_sg.id
}

resource "aws_security_group_rule" "default_sg_https" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default_sg.id
}

resource "aws_security_group_rule" "default_sg_outgoing" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default_sg.id
}


module "terra-tute-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"
  name = "terra-tute-vpc"
  cidr = "192.168.99.0/24"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["192.168.99.0/27", "192.168.99.64/27", "192.168.99.128/27"]
  enable_dns_hostnames = true
  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "sg-module" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.2"
  name = "terra-tute-sg-mod"
  
  vpc_id = module.terra-tute-vpc.vpc_id

  # module feature - named rules
  ingress_rules = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  # vpc_security_group_ids = [aws_security_group.default_sg.id]
  vpc_security_group_ids = [module.sg-module.security_group_id]
  # this is optional. vpc to launch can be determined from security group
  subnet_id = module.terra-tute-vpc.public_subnets[0]
  tags = {
    Name = "HelloWorld"
  }
}

module "terra-alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.2.1"

  name = "terra-alb"

  load_balancer_type = "application"

  vpc_id             = module.terra-tute-vpc.vpc_id
  subnets            = module.terra-tute-vpc.public_subnets
  security_groups    = [module.sg-module.security_group_id]

  target_groups = [
    {
      name_prefix      = "terra-alb-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = {
        my_target = {
          target_id = aws_instance.blog.id
          port = 80
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}
