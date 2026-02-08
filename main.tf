terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"

}

# Createation du aws_vpc
resource "aws_vpc" "mainvpc" {
  cidr_block       = "10.0.0.0/16"

  tags             = {
    Name           = "mainvpc"
  }
}

#creation de notre sous-reseau publique
resource "aws_subnet" "public-subnet" {
    vpc_id            = aws_vpc.mainvpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-west-1a"
}


#creation de notre sous-reseau prive
resource "aws_subnet" "private-subnet" {
    vpc_id            = aws_vpc.mainvpc.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-west-1a"
}

#creation du deuxieme sous-reseau prive
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.mainvpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-1c"
}

# creation du sous-reseau de la base de donnee
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "dbsubnet"
   subnet_ids = [
    aws_subnet.private-subnet.id,
    aws_subnet.private_subnet_1.id
  ]
  tags = {
    Name = "dbsubnet"
  }
}

#groupde de securite du frontend
resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.mainvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}


#groupde de securite du backtend
resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.mainvpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}


#groupde de securite de la bd
resource "aws_default_security_group" "bdsg" {
  vpc_id    = aws_subnet.private-subnet.vpc_id
  ingress {
    protocol  = "tcp"
    self      = true
    from_port = 3306
    to_port   = 3306
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
#creation d'une instance ec2 dans le sous-reseau public
resource "aws_instance" "ec2_frontend" {
  subnet_id               = aws_subnet.public-subnet.id
  vpc_security_group_ids  = [aws_security_group.frontend_sg.id]
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t3.micro"

  tags   = {
    Name = "HelloWorld"
  }
}

#creqation d'une instance ec2 dans le sous-reseau prive

resource "aws_instance" "ec2_backend" {
  subnet_id              = aws_subnet.private-subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"

  tags   = {
    Name = "HelloWorld"
  }
}

#creation d'une base de donnee RDS dans le sous-reseau prive

resource "aws_db_instance" "bd_instance" {
  db_subnet_group_name = aws_db_subnet_group.dbsubnet.name
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
}