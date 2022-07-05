terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

#  configure the aws provider
provider "aws" {
  region  = "us-east-2"
  profile = "default"
  # access_key = "${AWS_ACCESS_KEY_ID}"
  # secret_key = "${AWS_SECRET_ACCESS_KEY}"
}

# create a vpc
resource "aws_vpc" "terraform-vpc-1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "SampleTerraformVPC"
  }
}

# create a subnet
resource "aws_subnet" "sample-terraform-subnet" {
  vpc_id            = aws_vpc.terraform-vpc-1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2c"
  tags = {
    Name = "SampleTerra1Subnet"
  }
}

# create an Internet gateway
resource "aws_internet_gateway" "sample-terraform-igw" {
  vpc_id = aws_vpc.terraform-vpc-1.id
}

# create a route table
resource "aws_route_table" "sample-terraform-rt" {
  vpc_id = aws_vpc.terraform-vpc-1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sample-terraform-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.sample-terraform-igw.id
  }

  tags = {
    Name = "SampleTerraformRT"
  }
}

# create the route table association
resource "aws_route_table_association" "sample-terraform-rt-assoc" {
  subnet_id      = aws_subnet.sample-terraform-subnet.id
  route_table_id = aws_route_table.sample-terraform-rt.id
}

# create a security group
resource "aws_security_group" "terraform-sample-security-group" {
  name        = "allow_web_traffic"
  description = "Allow inbound traffics"
  vpc_id      = aws_vpc.terraform-vpc-1.id

  ingress {
    description      = "HTTPS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "SampleTerraformSecurityGroup"
  }
}

# create a network interface for private ips
resource "aws_network_interface" "sample-terraform-eni" {
  subnet_id = aws_subnet.sample-terraform-subnet.id
  # Have in mind that AWS will not allow you to attach the same network interface to multiple subnets and will have some reserved.
  private_ips     = ["10.0.1.12"]
  security_groups = [aws_security_group.terraform-sample-security-group.id]
  tags = {
    Name = "SampleTerraformENI"
  }
}

# create an elastic ip 
resource "aws_eip" "sample-terraform-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.sample-terraform-eni.id
  associate_with_private_ip = "10.0.1.12"
  depends_on                = [aws_internet_gateway.sample-terraform-igw]
  tags = {
    Name = "SampleTerraformEIP"
  }
}

# create an EC2 instance
resource "aws_instance" "sample_server" {
  ami               = "ami-02d1e544b84bf7502"
  instance_type     = "t2.nano"
  availability_zone = "us-east-2c"
  key_name          = "terraform-practice"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.sample-terraform-eni.id
  }
  user_data = <<EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo echo "<h2>Hello, World! from first terraform apache web server</h2>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "SampleInstance"
  }

}

