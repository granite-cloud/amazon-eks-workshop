/************************************
 Build an EKS cluster with service account
 and  IAM role.
************************************/

module "vpc" {
  source = "../data"
}


############
## Cluster
############
resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  enabled_cluster_log_types = ["api", "audit"]
  role_arn                  = aws_iam_role.cluster_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.public ? true : false #testing only
    security_group_ids      = module.vpc.eks_groups
    subnet_ids              = module.vpc.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.EKSClusterPolicy,
    aws_iam_role_policy_attachment.EKSFargatePodPolicy,
    aws_cloudwatch_log_group.eks
  ]
}


############
## OIDC Provider
############
/*  This is a workaround to get the thumbprint via shell
    #https://github.com/terraform-providers/terraform-provider-aws/issues/10104
*/
data "external" "thumbprint" {
  program = [format("%s./bin/finger.sh", path.module), var.aws_region]
}

# IAM OpenID Connect provider
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.this.identity.0.oidc.0.issuer
}

############
## IAM Service Account Role
############

# IAM trust policy
data "aws_iam_policy_document" "eks_fargate" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${var.service_role_name}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.this.arn]
      type        = "Federated"
    }
  }
}

# Service Account Role
resource "aws_iam_role" "service_account_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_fargate.json
  name               = var.service_role_name
}

############
## IAM Cluster Resources
############

# Role and trust policy
resource "aws_iam_role" "cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach aws managed policies
resource "aws_iam_role_policy_attachment" "EKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}


resource "aws_iam_role_policy_attachment" "EKSFargatePodPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.cluster_role.name
}

### Exec hack to patch coredns so it will run on fargate ###
/* # https://github.com/terraform-providers/terraform-provider-aws/issues/11327
    It is attaching:
    eks.amazonaws.com/compute-type: ec2
    when it should be attaching
    eks.amazonaws.com/compute-type: fargate

   Note: The cluster does not have public access
*/
resource "null_resource" "coredns_patch" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} && \
sleep 20 && \
kubectl patch deployment coredns \
  --namespace kube-system \
  --type=json \
  -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]'
EOF
  }

  depends_on = [aws_eks_cluster.this]
}

### Outputs ###
output "endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.this.certificate_authority.0.data
}
