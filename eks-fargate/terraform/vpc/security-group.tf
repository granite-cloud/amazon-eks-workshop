/*****************
 Security Groups
******************/

# Control Plane
resource "aws_security_group" "control_plane" {
  name        = "eks-control-${var.cluster_name}"
  description = "Allow communication from workers to control plane"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "eks-control-${var.cluster_name}"
  }
}

# Worker Nodes
resource "aws_security_group" "nodes" {
  name        = "eks-workers-${var.cluster_name}"
  description = "Allow communication from control plane and internal to workers"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "eks-workers-${var.cluster_name}"
  }
}

############
## Control Plane Rules
############
resource "aws_security_group_rule" "ingress_443_control" {
  type                     = "ingress"
  description              = "Allow worker nodes ingress to 443"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.control_plane.id
}

resource "aws_security_group_rule" "egress_ephemeral_control" {
  type                     = "egress"
  description              = "Allow control plane egress to worker ephemeral ports"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.nodes.id
}

############
## Worker Rules
############
resource "aws_security_group_rule" "ingress_443_worker" {
  type                     = "ingress"
  description              = "Allow control plane ingress to 443"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "ingress_ephemeral_worker" {
  type                     = "ingress"
  description              = "Allow control plane ingress to ephemeral ports"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.nodes.id
}

# This is testing only and in prod scenario it would be much more specific / locked down.
resource "aws_security_group_rule" "ingress_all_worker" {
  type                     = "ingress"
  description              = "Allow worker nodes to communicate internally with self"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "egress_ephemeral_nodes" {
  type                     = "egress"
  description              = "Allow workers egress to control plane ephemeral ports"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.control_plane.id
}
