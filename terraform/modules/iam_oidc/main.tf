resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/${var.github_ref}"
      } }
    }]
  })
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy" "github_actions_state" {
  name = "${var.project_name}-state-access"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "StateBucketList", Effect = "Allow", Action = ["s3:ListBucket"], Resource = var.state_bucket_arn },
      { Sid = "StateObjectAccess", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${var.state_bucket_arn}/*" },
      { Sid = "TerraformReadDiscovery", Effect = "Allow", Action = ["sts:GetCallerIdentity", "ec2:Describe*", "iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:ListOpenIDConnectProviders", "iam:GetOpenIDConnectProvider", "logs:DescribeLogGroups", "cloudtrail:DescribeTrails", "guardduty:ListDetectors", "s3:GetBucketLocation", "s3:GetBucketVersioning", "s3:GetEncryptionConfiguration", "s3:GetBucketPublicAccessBlock", "sns:GetTopicAttributes", "sns:ListSubscriptionsByTopic"], Resource = "*" }
    ]
  })
}
