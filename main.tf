# [1] providers
terraform {
  required_version = ">= 1.5.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

######### VPC #########
resource "aws_vpc" "plate" {
  cidr_block           = "10.7.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "tier-3"
  }
}

######################

########## Subnet ###########
# public a for ALB / Bastion
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.plate.id
  cidr_block              = "10.7.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2a"
  tags = {
    Name = "public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.plate.id
  cidr_block              = "10.7.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2b"
  tags = {
    Name = "public-b"
  }
}

# private b for Web
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.plate.id
  cidr_block              = "10.7.3.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-a"
  }
}

# private c for App
resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.plate.id
  cidr_block              = "10.7.4.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-b"
  }
}
# private d for DB 
# private e for DB (multi-AZs)
###########################

########## GW #############
# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.plate.id
  tags = {
    Name = "tier-3"
  }
}

# eip + NATGW
resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.igw]
}
###########################


#### Route Table #############
# public rt_0
resource "aws_route_table" "public_rt0" {
  vpc_id = aws_vpc.plate.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "tier-3"
  }
}

# private rt_1
resource "aws_route_table" "private_rt1" {
  vpc_id = aws_vpc.plate.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }
}

# private rt_2

# no route for DB

#############################

######## assoc ###############
# public a + rt0 
resource "aws_route_table_association" "assoc_0" {
  route_table_id = aws_route_table.public_rt0.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_route_table_association" "assoc_1" {
  route_table_id = aws_route_table.public_rt0.id
  subnet_id      = aws_subnet.public_b.id
}

# private b + rt1
resource "aws_route_table_association" "assoc_2" {
  route_table_id = aws_route_table.private_rt1.id
  subnet_id      = aws_subnet.private_a.id
}

# private c + rt1
resource "aws_route_table_association" "assoc_3" {
  route_table_id = aws_route_table.private_rt1.id
  subnet_id      = aws_subnet.private_b.id

}

# private d + rt2
# private e + rt2
###############################

######### Security Group #######


# Bastion SG
resource "aws_security_group" "Bastion_SG" {
    name = "Bastion-SG"
  vpc_id = aws_vpc.plate.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["106.101.137.103/32"] // MYIP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB SG
resource "aws_security_group" "ALB_SG" {
    name = "ALB-SG"
  vpc_id = aws_vpc.plate.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# WEB SG
# 22 in + from "Bastion_SG"
# 80 in + from "ALB_SG"
# out ALL
resource "aws_security_group" "WEB_SG" {
    name = "WEB-SG"
  vpc_id = aws_vpc.plate.id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.Bastion_SG.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ALB_SG.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# APP SG
# 22 in + from "Bastion_SG"
# 8080 in + from "WEB_SG"
# out ALL
resource "aws_security_group" "APP_SG" {
    name = "APP-SG"
  vpc_id = aws_vpc.plate.id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.Bastion_SG.id]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.WEB_SG.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB SG
# 3306 in + from "APP_SG"
# 

##################################

########### resources ##############

# Listener + ALB + Target Group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb" "web_lb" {
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.ALB_SG.id]
}

resource "aws_lb_target_group" "web_tg" {
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.plate.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30
}

resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}

# ami data
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# EC2 bastion
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.Bastion_SG.id]
  associate_public_ip_address = true
  user_data                   = <<-EOF
#!/bin/bash
set -eux

# ec2-user 비밀번호 설정
echo 'ec2-user:password' | chpasswd

# sshd 설정 변경 (비밀번호 로그인 허용)
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config

# SSH 재시작
systemctl restart sshd
EOF

}
# EC2 WEB
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_b.id
  vpc_security_group_ids      = [aws_security_group.WEB_SG.id]
  associate_public_ip_address = false
  user_data                   = <<-EOF
#!/bin/bash
set -eux

# ec2-user 비밀번호 설정
echo 'ec2-user:password' | chpasswd

# sshd 설정 변경 (비밀번호 로그인 허용)
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config

# SSH 재시작
systemctl restart sshd
EOF

}


# EC2 APP
resource "aws_instance" "APP" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_b.id
  vpc_security_group_ids      = [aws_security_group.APP_SG.id]
  associate_public_ip_address = false
  user_data                   = <<-EOF
#!/bin/bash
set -eux

# ec2-user 비밀번호 설정
echo 'ec2-user:password' | chpasswd

# sshd 설정 변경 (비밀번호 로그인 허용)
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config

# SSH 재시작
systemctl restart sshd
EOF

}


# DB Subnet Group
# RDS

####################################