variable aws_region {
  type        = string
  description = "AWS region"
}

variable aws_zones {
  type        = list
  description = "AWS AZs (Availability zones) where subnets should be created"
}

variable cluster_name {
  type        = string
  description = "Name of EKS cluster"
}

variable public_subnets {
  description = "List of public subnets"
  type        = list
}

variable private_subnets {
  description = "List of private subnets"
  type        = list
}

variable single_nat {
  description = "Lower environments will only need single nat gateway. Setting this to true will save costs by using 1 nat gateway."
  type        = string
  default     = "true"
}

variable tags {
  description = "Common tag values which should be assigned to resources"
  type        = map
}

variable vpc_cidr {
  type        = string
  description = "CIDR of the VPC"
}

variable vpc_name {
  description = "Name of the VPC"
  type        = string
}
