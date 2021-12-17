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

resource "aws_elastic_beanstalk_environment" "amor_de_4patas_beanstalk_environment" {
  name          = "amor-de-4patas-prod"
  application   = aws_elastic_beanstalk_application.amor_de_4patas_beanstalk.name
  platform_arn  = "arn:aws:elasticbeanstalk:us-west-1::platform/Node.js 14 running on 64bit Amazon Linux 2/5.4.8"
  
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "production"
  }  

}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

# resource "aws_route53_record" "www" {
#   zone_id = data.aws_elastic_beanstalk_hosted_zone.current.id
#   name    = "amorde4patas.org"
#   type    = "A"

#   alias {
#     name    = "${aws_elastic_beanstalk_environment.amor_de_4patas_beanstalk_environment.cname}"
#     zone_id = "${data.aws_elastic_beanstalk_hosted_zone.current.id}"
#     evaluate_target_health = true
#   }
# }

resource "aws_cloudfront_origin_access_identity" "static_content_origin" {
  comment = "Origin for static content"
}

resource "aws_s3_bucket" "amor_de_4_patas_static_content" {
  bucket = "amor-de-4-patas-static-content"
  acl    = "private"

  tags = {
    Name = "amor-de-4-patas-static-content"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.amor_de_4_patas_static_content.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_cloudfront_origin_access_identity.static_content_origin.iam_arn}"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.amor_de_4_patas_static_content.arn}",
        "${aws_s3_bucket.amor_de_4_patas_static_content.arn}/*"
      ]
    }
  ]
}
EOF
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.amor_de_4_patas_static_content.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static_content_origin.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["CN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
