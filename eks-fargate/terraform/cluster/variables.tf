variable "alb_deploy" {
  type = bool
}

variable "alb_ingress_policy" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "public" {
  type    = bool
  default = false
}

variable "service_role_name" {
  type = string
}
