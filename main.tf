terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-west-1"
}

resource "aws_elastic_beanstalk_application" "amor_de_4patas_beanstalk" {
  name        = "amor-de-4patas"
  description = "Amor de 4 patas production application"
}

resource "aws_elb" "main" {
  name               = "amor-de-4patas-elb"
  availability_zones = ["us-west-1"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_elastic_beanstalk_environment" "amor_de_4patas_beanstalk_environment" {
  name          = "amor-de-4patas-prod"
  application   = aws_elastic_beanstalk_application.amor_de_4patas_beanstalk.name
  platform_arn  = "arn:aws:elasticbeanstalk:us-west-1::platform/Node.js 14 running on 64bit Amazon Linux 2/5.4.8"
  
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "example.com"
#   type    = "A"

#   alias {
#     name    = "${aws_elastic_beanstalk_environment.amor_de_4patas_beanstalk_environment.cname}"
#     zone_id = "${data.aws_elastic_beanstalk_hosted_zone.current.id}"
#     evaluate_target_health = true
#   }
# }
