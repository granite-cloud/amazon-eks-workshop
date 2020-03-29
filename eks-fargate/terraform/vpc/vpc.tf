/*****************
 VPC
******************/

############
## AWS Provider
############
provider "aws" {
  region = var.aws_region
}


############
## VPC
############
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(map("Name", var.vpc_name), var.tags)
}

# IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(map("Name", var.vpc_name), var.tags)
}

############
## Public Subnets
############

# Subnet
resource "aws_subnet" "public_subnet" {
  count                   = var.create_public == "true" ? length(var.public_subnets) : 1
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.aws_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    map(
      "Name", format("%v-public-%v", var.vpc_name, var.aws_zones[count.index])
  ))
}

############
## Private Subnets
############
resource "aws_eip" "nat" {
  count = length(var.aws_zones)
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  count         = var.single_nat == "true" ? 1 : length(var.aws_zones)
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)

  tags = merge(
    var.tags,
    map(
      "Name", format("%v-nat-%v", var.vpc_name, var.aws_zones[count.index])
  ))

  depends_on = [aws_eip.nat, aws_internet_gateway.gw, aws_subnet.public_subnet]
}

# Subnet
resource "aws_subnet" "private_subnet" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = var.aws_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    map(
      "Name", format("%v-private-%v", var.vpc_name, var.aws_zones[count.index]),
      "kubernetes.io/role/elb", "0",
      "kubernetes.io/cluster/${var.cluster_name}", "shared"
  ))
}

############
## Public Routing
############
resource "aws_route_table" "public_route" {
  count  = length(var.public_subnets)
  vpc_id = aws_vpc.vpc.id

  # Default route through Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    var.tags,
    map(
      "Name", format("%v-public-%v", var.vpc_name, var.aws_zones[count.index]),
      "kubernetes.io/role/elb", "1",
      "kubernetes.io/cluster/${var.cluster_name}", "shared"
  ))
}

resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.public_route.*.id, count.index)
}

############
## Private Routing
############
resource "aws_route_table" "private_route" {
  count  = var.single_nat == "true" ? 1 : length(var.aws_zones)
  vpc_id = aws_vpc.vpc.id

  # Default route through NAT
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = element(aws_nat_gateway.nat.*.id, count.index)
  }

  tags = merge(
    var.tags,
    map(
      "Name", format("%v-private-%v", var.vpc_name, var.aws_zones[count.index])
  ))
}

resource "aws_route_table_association" "private_route" {
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_route.*.id, count.index)
}
