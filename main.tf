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
      name_prefix      = "trf-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = var.public_port
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.7.0"

  name = "terra-asg"
  min_size = var.min_size
  max_size = var.max_size

  vpc_zone_identifier = module.terra-tute-vpc.public_subnets
  target_group_arns = module.terra-alb.target_group_arns
  security_groups = [module.sg-module.security_group_id]

  image_id           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
}
