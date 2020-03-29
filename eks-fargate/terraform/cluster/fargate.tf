/**************************
 Fargate Profiles

 This will allow to define specific types of
 workloads to deploy on fargate using selectors.
**************************/

# Core DNS
resource "aws_eks_fargate_profile" "core_dns" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "namespaces"
  pod_execution_role_arn = aws_iam_role.fargate_profile.arn
  subnet_ids             = data.aws_subnet_ids.private.ids
  # Define what namespaces will provision to fargate
  selector {
    namespace = "kube-system"
  }

  selector {
    namespace = "default"
  }

  selector {
    namespace = "fargate"
  }

  depends_on = [aws_eks_cluster.this]
}


resource "aws_iam_role" "fargate_profile" {
  name = "eks-fargate-profile"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "EKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_profile.name
}
