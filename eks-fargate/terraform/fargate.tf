/**************************
 Fargate Profiles
**************************/

resource "aws_eks_fargate_profile" "core_dns" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "core-dns"
  pod_execution_role_arn = aws_iam_role.fargate_profile.arn
  subnet_ids             = data.aws_subnet_ids.private.ids

  selector {
    namespace = "kube-system"
    labels = {
                 "k8s-app": "kube-dns",  # core-dns
             }
  }

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_fargate_profile" "alb" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "alb"
  pod_execution_role_arn = aws_iam_role.fargate_profile.arn
  subnet_ids             = data.aws_subnet_ids.private.ids

  selector {
    namespace = "kube-system"
    labels = {
                 "app.kubernetes.io/name": "alb-ingress-controller"  # alb controller
             }
  }

  depends_on = [aws_eks_cluster.this]
}

# Provision workloads to fargate for custom name space
resource "aws_eks_fargate_profile" "fargate_workload" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fargate-worker"
  pod_execution_role_arn = aws_iam_role.fargate_profile.arn
  subnet_ids             = data.aws_subnet_ids.private.ids

  selector {
    namespace = "fargate"
    labels = {
                "infrastructure": "fargate"
             }
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
