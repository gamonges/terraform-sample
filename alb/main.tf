terraform {
    backend "s3" {
        bucket = "tfstate-gamo-first-terraform"
        key = "terraform_test/alb/terraform.tfstate"
        region = "ap-northeast-1"
    }
}
data "terraform_remote_state" "vpc" {
    backend = "s3"
    config = {
        bucket = "tfstate-gamo-first-terraform"
        key = "terraform_test/terraform.tfstate"
        region = "ap-northeast-1"
    }
}

data "aws_elb_service_account" "alb_log" {}

resource "aws_s3_bucket" "terraform-test-alb-log" {
    bucket = "terraform-test-alb-log"

    lifecycle_rule {
        enabled = true
        expiration {
            days = "180"
        }
    }
}
resource "aws_s3_bucket_policy" "alb_log" {
    bucket = aws_s3_bucket.terraform-test-alb-log.id
    policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
    statement {
        effect = "Allow"
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::${aws_s3_bucket.terraform-test-alb-log.id}/*"]

        principals {
            type = "AWS"
            identifiers = ["${data.aws_elb_service_account.alb_log.id}"]
        }
    }
}
resource "aws_lb" "terraform-test-alb" {
    name        = "terraform-test-alb"

    load_balancer_type = "application"
    internal           = false
    idle_timeout       = 60
    enable_deletion_protection = true

    subnets = [
        data.terraform_remote_state.vpc.outputs.public_subnet_id,
        data.terraform_remote_state.vpc.outputs.public_subnet2_id
    ] 

    enable_http2                     = true
#    ip_address_type                  = var.ip_address_type

    access_logs {
        enabled = true
        bucket  = aws_s3_bucket.terraform-test-alb-log.id
    }

    security_groups = [
        module.http_sg.security_group_id,
        module.https_sg.security_group_id,
        module.http_redirect_sg.security_group_id
    ]

    tags = {
        Name = "terraform_test_alb_log"
    }

#    timeouts {
#      create = 60
#      update = 60
#      delete = 60
#    }
    
}

module "http_sg" {
    source = "../modules/security_group"
    vpc_id = data.terraform_remote_state.vpc.outputs.wordpress_dev_vpc_id
    resource_name = "http_sg"
    port = 80
}
module "https_sg" {
    source = "../modules/security_group"
    vpc_id = data.terraform_remote_state.vpc.outputs.wordpress_dev_vpc_id
    resource_name = "https_sg"
    port = 443
}
module "http_redirect_sg" {
    source = "../modules/security_group"
    vpc_id = data.terraform_remote_state.vpc.outputs.wordpress_dev_vpc_id
    resource_name = "http_redirect_sg"
    port = 8080
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.terraform-test-alb.arn
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "これはHTTPです"
            status_code = "200"
        }
    }
}

resource "aws_acm_certificate" "example" {
    domain_name = aws_route53_record.example.domain_name
    subjrct_alternative_names = []
    validation_method = "DNS"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_acm_certificate_validation" "exmaple" {
    certificate_arn = aws_acm_certificate.example.arn
    validation_record_fqdns = [aws_route53_record.exmaple_certificate.fqdn]
}

resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.terraform-test-alb.arn
    port = "443"
    protocol = "HTTPS"
    certificate_arn = aws_acm_certificate.example.arn
    ssl_policy = "ELBSecurityPolicy-2016-08"

    default_action {
        type = "fixed-response"
    }

    fixed_response {
        content_type = "text/plain"
        message_body = "これは「HTTPS」です。"
        status_code = "200"
    }
}

resource "aws_lb_listener" "redirect_http_to_https" {
    load_balancer_arn = aws_lb.terraform-test-alb.arn
    port = "8080"
    protocol = "HTTP"

    default_action {
        type = "redirect"
    }

    redirect {
        port = "443"
        protocol = "HTTPS"
        status_code = "HTTP_301"
    }
}

resource "aws_lb_target_group" "example" {
    name = "example"
    target_type = "ip"
    vpc_id = aws_vpc.example.id
    port = 80
    protocol = "HTTP"
    deregistration_delay = 300

    health_check {
        path = "/"
        healthy_threshhold = 5
        unhealthy_threshholod = 2
        timout = 5
        interval = 30
        matcher = 200
        port = "traffic-port"
        protocol = "HTTP"
    }

    depends_on = [aws_lb.example]
}



output "alb_dns_name" {
    value = aws_lb.terraform-test-alb.dns_name
}