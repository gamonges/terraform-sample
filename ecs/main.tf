terraform {
  backend "s3" {
    bucket = "tfstate-gamo-first-terraform"
    key    = "terraform_test/ecs/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tfstate-gamo-first-terraform"
    key    = "terraform_test/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "tfstate-gamo-first-terraform"
    key    = "terraform_test/alb/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

resource "aws_ecs_cluster" "example" {
  name = "example"
}

resource "aws_ecs_task_definition" "example" {
  family                   = "example"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definition.json")
}

resource "aws_ecs_service" "example" {
  name                              = "example"
  cluster                           = aws_ecs_cluster.example.arn
  task_definition                   = aws_ecs_task_definition.example.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]

    subnets = [
      data.terraform_remote_state.vpc.outputs.private_subnet_id
    ]
  }

  load_balancer {
    target_group_arn = data.terraform_remote_state.alb.outputs.http_target_group_arn
    container_name   = "example"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

}

module "nginx_sg" {
  source        = "../modules/security_group"
  vpc_id        = data.terraform_remote_state.vpc.outputs.wordpress_dev_vpc_id
  resource_name = "nginx_sg"
  port          = 80
  #        cidr_blocks = [aws_vpc.example.cidr_blocks]
}