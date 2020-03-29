variable "vpc_id" {}
variable "resource_name" {}
variable "port" {}

# Security Group
resource "aws_security_group" "this" {
    name   = var.resource_name
    vpc_id = var.vpc_id

    ingress {
        from_port   = var.port
        to_port     = var.port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    description = var.resource_name
    tags = {
        Name = var.resource_name
    }

}

output security_group_id {
    value = aws_security_group.this.id
}