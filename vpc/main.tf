resource "aws_vpc" "wordpress_dev" {
    cidr_block           = "10.0.0.0/24"
    enable_dns_hostnames = false
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags = {
        Name = "wordpress_dev"
    }
}
