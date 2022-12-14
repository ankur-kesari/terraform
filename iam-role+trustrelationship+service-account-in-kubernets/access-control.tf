locals {
  service_account_name = "database-backup"
  oidc_provider = replace(
    data.aws_eks_cluster.kubernetes_cluster.identity[0].oidc[0].issuer,
    "/^https:///",
    ""
  )
}
resource "aws_iam_role" "role" {
  name = "database-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com",
            "${local.oidc_provider}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${local.service_account_name}"
          }
        }
      }
    ]
  })
  inline_policy {
    name = "AllowS3PutObject"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:*",
            "s3-object-lambda:*"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}
resource "kubernetes_service_account" "iam" {
  metadata {
    name      = local.service_account_name
    namespace = var.kubernetes_namespace
  annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
      "eks.amazonaws.com/sts-regional-endpoints" = true
    }
  }
}
