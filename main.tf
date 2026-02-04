# [1] providers
terraform {
  required_version = ">= 1.5.6"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }

    random = {
        source = "hashicorp/random"
        version = "~> 3.0"
    }
  }
}

provider "aws" {
    region = "ap-northeast-2"
}

######### VPC #########
# main
######################

########## Subnet ###########
# public a for ALB / Bastion
# private b for Web
# private c for App
# private d for DB 
# private e for DB (multi-AZs)
###########################

########## GW #############
# IGW
# eip + NATGW
###########################


#### Route Table #############
# public rt0
  # route (local + IGW)

# private rt_1
  # route (local + NATGW)

# private rt_2
  # no route for DB

#############################

######## assoc ###############
    # public a + rt0 
    # private b + rt1
    # private c + rt1
    # private d + rt2
    # private e + rt2
###############################

######### Security Group #######

# myIP

# Bastion SG
    # 22 in + from "my_IP"
    # out ALL

# ALB SG
    # 80 in
    # 443 in
    # out ALL
    
# WEB SG
    # 22 in + from "Bastion_SG"
    # 80 in + from "ALB_SG"
    # out ALL

# APP SG
    # 22 in + from "Bastion_SG"
    # 8080 in + from "WEB_SG"
    # out ALL

# DB SG
    # 3306 in + from "APP_SG"
    # 

##################################

########### resources ##############

# Listener + ALB + Target Group

# ami data
# EC2 bastion
# EC2 WEB
# EC2 APP

# DB Subnet Group
# RDS

####################################