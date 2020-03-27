variable "cluster_name" {
  default = "dev-fargate"
  type    = string
}

variable "security_groups" {
  default = ["sg-0a93dbd5610c2e660", "sg-0602027b9ceb891d9"]
  type    = list
}

variable "eks_cluster_role" {
  default = "AmazonEKSClusterPolicy"
  type    = string
}

variable "eks_service_role" {
  default = "AmazonEKSServicePolicy"
  type    = string
}
