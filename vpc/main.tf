resource "aws_vpc" "wordpress_dev" {
    cidr_block           = "10.0.0.0/24"
    enable_dns_hostnames = false
    enable_dns_support   = true
    instance_tenancy     = "default"
    assign_generated_ipv6_cidr_block = false

    tags = {
        Name = "wordpress_dev"
    }

}

resource "aws_subnet" "subnet-0468596059578f067-Public-Subnet" {
    vpc_id                  = "vpc-085516d3f8f6801af"
    cidr_block              = "100.0.1.0/24"
    availability_zone       = "ap-northeast-1a"
    map_public_ip_on_launch = false

    tags = {
        Name = "Public-Subnet"
    }
}

resource "aws_subnet" "subnet-09884f6f01e76da38-Private-Subnet" {
    vpc_id                  = "vpc-085516d3f8f6801af"
    cidr_block              = "100.0.2.0/24"
    availability_zone       = "ap-northeast-1a"
    map_public_ip_on_launch = false

    tags = {
        Name = "Private-Subnet"
    }
}

resource "aws_subnet" "subnet-09884f6f01e76da38-Database-Subnet" {
    vpc_id                  = "vpc-085516d3f8f6801af"
    cidr_block              = "100.0.3.0/24"
    availability_zone       = "ap-northeast-1a"
    map_public_ip_on_launch = false

    tags = {
        Name = "Datbase-Subnet"
    }
}

resource "aws_network_acl" "acl-0ce0bdf0810935868" {
    vpc_id     = "vpc-085516d3f8f6801af"
    subnet_ids = ["subnet-0468596059578f067", "subnet-09884f6f01e76da38"]

    ingress {
        from_port  = 0
        to_port    = 0
        rule_no    = 100
        action     = "allow"
        protocol   = "-1"
        cidr_block = "0.0.0.0/0"
    }

    egress {
        from_port  = 0
        to_port    = 0
        rule_no    = 100
        action     = "allow"
        protocol   = "-1"
        cidr_block = "0.0.0.0/0"
    }

    tags = {
    }
}

resource "aws_route_table" "rtb-0997c59914af4966b" {
    vpc_id = aws_vpc.wordpress_dev.id

    tags = {
    }
}
resource "aws_internet_gateway" "terraform_test_igw" {
    vpc_id = aws_vpc.wordpress_dev.id

    tags = {
        Name = "terraform_test_igw"
    }
}

resource "aws_eip" "terraform_test_ip_for_nat_gw" {
  vpc      = true
}

resource "aws_nat_gateway" "terraform_test_nat_gw" {
    allocation_id = aws_eip.terraform_test_ip_for_nat_gw.id
    subnet_id     = aws_subnet.subnet-0468596059578f067-Public-Subnet.id

    tags = {
        Name = "terraform_test_nat_gw"
    }

    depends_on = [aws_internet_gateway.terraform_test_igw]
}

resource "aws_route_table" "terraform_test_rtb_public" {
    vpc_id = aws_vpc.wordpress_dev.id

    tags = {
        Name = "terraform_test_rtb_public"
    }
}

resource "aws_route_table" "terraform_test_rtb_private" {
    vpc_id = aws_vpc.wordpress_dev.id

    tags = {
        Name = "terraform_test_rtb_private"
    }
}

resource "aws_route" "terraform_test_route_public" {
    route_table_id = aws_route_table.terraform_test_rtb_public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_test_igw.id
}

resource "aws_route" "terraform_test_route_private" {
    route_table_id = aws_route_table.terraform_test_rtb_private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.terraform_test_nat_gw.id
}

resource "aws_route_table_association" "terraform_test_rtb_a_public" {
  subnet_id      = aws_subnet.subnet-0468596059578f067-Public-Subnet.id
  route_table_id = aws_route_table.terraform_test_rtb_public.id
}

resource "aws_route_table_association" "terraform_test_rtb_a_private" {
  subnet_id      = aws_subnet.subnet-09884f6f01e76da38-Private-Subnet.id
  route_table_id = aws_route_table.terraform_test_rtb_private.id
}

resource "aws_route_table_association" "terraform_test_rtb_a_database" {
  subnet_id      = aws_subnet.subnet-09884f6f01e76da38-Database-Subnet.id
  route_table_id = aws_route_table.terraform_test_rtb_private.id
}

module "terraform_test_sg_ssh" {
    source = "../modules/security_group"

    vpc_id = aws_vpc.wordpress_dev.id
    resource_name = "terraform_test_sg_ssh"
    port = 22
}
output public_ip_for_nat_gateway {
    value = aws_eip.terraform_test_ip_for_nat_gw.public_ip
}