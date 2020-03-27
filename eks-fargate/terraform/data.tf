/**********************
 Data Sources
**********************/

# Region
data "aws_region" "current" {}

# VPC
data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["eksctl-eks-fargate-cluster-cluster/VPC"]
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
    Name = "eksctl-eks-fargate-cluster-cluster/SubnetPrivateUSEAST1D"
  }
}


### Outputs ###
output "subnet_cidr_blocks" {
  value = data.aws_subnet_ids.all.ids
}

output "vpc" {
  value = data.aws_vpc.this.id
}
