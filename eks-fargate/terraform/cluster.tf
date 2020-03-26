/************************************
 Build an EKS cluster with service account
 and  IAM role.
************************************/

# Cluster
resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  enabled_cluster_log_types = ["api", "audit"]
  role_arn                  = aws_iam_role.cluster_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = ["sg-0a93dbd5610c2e660", "sg-0602027b9ceb891d9"]
    subnet_ids              = data.aws_subnet_ids.all.ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.EKSClusterPolicy,
    aws_iam_role_policy_attachment.EKSServicePolicy,
    aws_cloudwatch_log_group.eks
  ]
}

### IAM Service Account Role ###

# IAM OpenID Connect provider
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
  url             = aws_eks_cluster.this.identity.0.oidc.0.issuer
}

# IAM trust policy
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:s3-reader"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.this.arn]
      type        = "Federated"
    }
  }
}

# Role
resource "aws_iam_role" "service_account_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name               = "dev-eks-s3-read"
}

# Attach aws managed policies for S3 Read
resource "aws_iam_role_policy_attachment" "EKSS3Reader" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.service_account_role.name
}

### Cluster IAM Resources ###

# Role and trust policy
resource "aws_iam_role" "cluster_role" {
  name = "dev-eks-cluster-role"

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
# Attach aws managed policies
resource "aws_iam_role_policy_attachment" "EKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster_role.name
}


### Outputs ###
output "endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.this.certificate_authority.0.data
}
