/**********************
 Data Sources
**********************/

# Region
data "aws_region" "current" {}

# VPC
data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["dev-fargate"]
  }
}

# Subnets All []
data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.this.id

}

# Subnets Private []
data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.this.id

  tags = {
    Tier = "private"
  }
}

data "aws_security_groups" "eks" {
  tags = {
    App   = "eks"
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}


### Outputs ###
output "subnet_ids" {
  value = data.aws_subnet_ids.all.ids
}

output "private_subnet_ids" {
  value = data.aws_subnet_ids.private.ids
}

output "vpc" {
  value = data.aws_vpc.this.id
}

output "eks_groups" {
  value = data.aws_security_groups.eks.ids
}
