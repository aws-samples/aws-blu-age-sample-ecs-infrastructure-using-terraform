# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)
data "aws_region" "current" {}

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)
data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "alerting_sns_topic" {
  # checkov:skip=CKV_AWS_26:KMS encryption is not required for a simple notifications
  name = "${var.stack_prefix}-alerts"
}

resource "aws_sns_topic" "notification_sns_topic" {
  # checkov:skip=CKV_AWS_26:KMS encryption is not required for a simple notifications
  name = "${var.stack_prefix}-notifications"
}

resource "aws_sns_topic_policy" "alerting_sns_topic_policy" {
  arn = aws_sns_topic.alerting_sns_topic.arn

  policy = data.aws_iam_policy_document.alerting_sns_topic_policy_document.json
}

data "aws_iam_policy_document" "alerting_sns_topic_policy_document" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "sns:Subscribe",
      "sns:SetTopicAttributes",
      "sns:RemovePermission",
      "sns:Receive",
      "sns:Publish",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:DeleteTopic",
      "sns:AddPermission",
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "${data.aws_caller_identity.current.account_id}",
      ]
    }
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_sns_topic.alerting_sns_topic.arn,
    ]
    sid = "__default_statement_ID"
  }

  statement {
    actions = [
      "sns:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [
      aws_sns_topic.alerting_sns_topic.arn,
    ]
    sid = "AllowEventsToPostToSNSTopic"
  }

}


data "aws_iam_policy_document" "notification_sns_topic_policy_document" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "sns:Subscribe",
      "sns:SetTopicAttributes",
      "sns:RemovePermission",
      "sns:Receive",
      "sns:Publish",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:DeleteTopic",
      "sns:AddPermission",
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "${data.aws_caller_identity.current.account_id}",
      ]
    }
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_sns_topic.notification_sns_topic.arn,
    ]
    sid = "__default_statement_ID"
  }

  statement {
    actions = [
      "sns:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [
      aws_sns_topic.notification_sns_topic.arn,
    ]
    sid = "AllowEventsToPostToSNSTopic"
  }

}

resource "aws_sns_topic_policy" "notification_sns_topic_policy" {
  arn = aws_sns_topic.notification_sns_topic.arn

  policy = data.aws_iam_policy_document.notification_sns_topic_policy_document.json
}


#########################################################
## Alert on CMK being scheduled for deletion
#########################################################
resource "aws_cloudwatch_event_rule" "cmk_deletion_rule" {
  name = "${var.stack_prefix}-detect-kms-cmk-deletion"
  description = "A CloudWatch Event Rule that triggers on AWS KMS Customer Master Key (CMK) deletion events."
  is_enabled = true
  event_pattern = <<PATTERN
{
  "source": [
    "aws.kms"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "kms.amazonaws.com"
    ],
    "eventName": [
      "ScheduleKeyDeletion"
    ],
    "requestParameters": {
      "keyId": [
        "${var.kms_key_id}"
      ]
    }
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "cmk_deletion_event_target" {
  rule = aws_cloudwatch_event_rule.cmk_deletion_rule.name
  target_id = "${var.stack_prefix}-target-kms-key-deletion"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## Subscribe to RDS events for the RDS Cluster
##   https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/rds-cloudwatch-events.sample.html
#########################################################
resource "aws_db_event_subscription" "aurora_cluster_subscription" {
  name      = "${var.stack_prefix}-cluster-alerts"
  sns_topic = aws_sns_topic.alerting_sns_topic.arn

  source_type = "db-cluster"
  source_ids  = [
    var.rds_cluster_id
  ]

  event_categories = [
    "deletion",
    "failover",
    "failure"
  ]
}

resource "aws_db_event_subscription" "aurora_cluster_subscription_notifications" {
  name      = "${var.stack_prefix}-cluster-notifications"
  sns_topic = aws_sns_topic.notification_sns_topic.arn

  source_type = "db-cluster"
  source_ids  = [
    var.rds_cluster_id
  ]

  event_categories = [
    "creation",
    "maintenance",
    "notification"
  ]
}

resource "aws_db_event_subscription" "aurora_instance_subscription" {
  name      = "${var.stack_prefix}-instance-alerts"
  sns_topic = aws_sns_topic.alerting_sns_topic.arn

  source_type = "db-instance"
  source_ids  = var.rds_instance_ids

  event_categories = [
    "availability",
    "deletion",
    "failure",
    "low storage"
  ]
}

resource "aws_db_event_subscription" "aurora_instance_subscription_notifications" {
  name      = "${var.stack_prefix}-instance-notifications"
  sns_topic = aws_sns_topic.notification_sns_topic.arn

  source_type = "db-instance"
  source_ids  = var.rds_instance_ids

  event_categories = [
    "configuration change",
    "maintenance",
    "notification",
    "read replica",
    "recovery",
    "restoration"
  ]
}

#########################################################
## CloudWatch Alarms for RDS
#########################################################

resource "aws_cloudwatch_metric_alarm" "alarm_rds_cpu" {
  alarm_name                = "${var.stack_prefix}-rds-cpu-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors PostGRES cpu utilization"
  actions_enabled           = "true"
  alarm_actions             = [
    aws_sns_topic.alerting_sns_topic.arn
  ]
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_rds_memory" {
  alarm_name                = "${var.stack_prefix}-rds-memory-alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  period                    = "120"
  statistic                 = "Average"
  # 128MB (128*1024*1024)
  threshold                 = "134217728"
  alarm_description         = "This metric monitors PostGRES free memory availability"
  actions_enabled           = "true"
  alarm_actions             = [
    aws_sns_topic.alerting_sns_topic.arn
  ]
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_rds_connections" {
  alarm_name                = "${var.stack_prefix}-rds-connections-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "DatabaseConnections"
  namespace                 = "AWS/RDS"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "1000"
  alarm_description         = "This metric monitors PostGRES total database connections"
  actions_enabled           = "true"
  alarm_actions             = [
    aws_sns_topic.alerting_sns_topic.arn
  ]
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_rds_storage" {
  alarm_name                = "${var.stack_prefix}-rds-storage-alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "FreeLocalStorage"
  namespace                 = "AWS/RDS"
  period                    = "120"
  statistic                 = "Average"
  # 2GB (2048*1024*1024)
  threshold                 = "2147483648"
  alarm_description         = "This metric monitors PostGRES storage availability"
  actions_enabled           = "true"
  alarm_actions             = [
    aws_sns_topic.alerting_sns_topic.arn
  ]
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_rds_read_latency" {
  alarm_name                = "${var.stack_prefix}-rds-read-latency-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "ReadLatency"
  namespace                 = "AWS/RDS"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "0.250"
  alarm_description         = "This metric monitors PostGRES read latency"
  actions_enabled           = "true"
  alarm_actions             = [
    aws_sns_topic.alerting_sns_topic.arn
  ]
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}


#########################################################
## Notify on containers being deleted from ECR
#########################################################
resource "aws_cloudwatch_event_rule" "ecr_deletion_rule" {
  name = "${var.stack_prefix}-detect-ecr-deletion"
  description = "A CloudWatch Event Rule that triggers on ECR deletion events."
  is_enabled = true
  event_pattern = <<PATTERN
{
  "source": [
    "aws.ecr"
  ],
  "detail-type": [
    "ECR Image Action"
  ],
  "detail": {
    "result": [
      "SUCCESS"
    ],
    "action-type": [
      "DELETE"
    ],
    "repository-name": [
      "${var.stack_prefix}-ecr"
    ]
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "ecr_deletion_event_target" {
  rule = aws_cloudwatch_event_rule.ecr_deletion_rule.name
  target_id = "${var.stack_prefix}-target-ecr-deletion"
  arn = aws_sns_topic.notification_sns_topic.arn
}

#########################################################
## Alert on changes to S3 policy and bucket deletion
#########################################################

resource "aws_cloudwatch_event_rule" "s3_policy_rule" {
  name = "${var.stack_prefix}-detect-s3-bucket-policy-changes"
  description = "A CloudWatch Event Rule that detects changes to S3 bucket policies and bucket deletions"
  is_enabled = true
  event_pattern = <<PATTERN
{
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "s3.amazonaws.com"
    ],
    "eventName": [
      "PutBucketAcl",
      "PutBucketPolicy",
      "PutBucketCors",
      "PutBucketLifecycle",
      "PutBucketReplication",
      "DeleteBucketPolicy",
      "DeleteBucketCors",
      "DeleteBucketLifecycle",
      "DeleteBucketReplication",
      "DeleteBucket"
    ],
    "requestParameters": {
      "bucketName": [
        "${var.input_s3_bucket_id}",
        "${var.output_s3_bucket_id}"
      ]
    }
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "s3_policy_event_target" {
  rule = aws_cloudwatch_event_rule.s3_policy_rule.name
  target_id = "${var.stack_prefix}-target-s3-bucket-policy-change"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## Alert on Step Function Timeouts or Aborts
#########################################################

resource "aws_cloudwatch_event_rule" "sf_failure_rule" {
  name = "${var.stack_prefix}-detect-sf-failure"
  description = "A CloudWatch Event Rule that detects Timeouts or Aborted Step Function Executions"
  is_enabled = true
  event_pattern = <<PATTERN
{
  "detail-type": [
    "Step Functions Execution Status Change"
  ],
  "source": [
    "aws.states"
  ],
  "detail": {
    "stateMachineArn": [
      { "prefix": "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_prefix}" }
    ],
    "status": [
      "TIMED_OUT",
      "ABORTED"
    ]
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "sf_failure_event_target" {
  rule = aws_cloudwatch_event_rule.sf_failure_rule.name
  target_id = "${var.stack_prefix}-target-sf-failure"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## Notify on modifications to the module SNS topics
#########################################################
resource "aws_cloudwatch_event_rule" "sns_deletion_rule" {
  name = "${var.stack_prefix}-detect-sns-deletion"
  description = "A CloudWatch Event Rule that triggers on SNS topic deletion events."
  is_enabled = true
  event_pattern = <<PATTERN
{
  "source": ["aws.sns"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["sns.amazonaws.com"],
    "eventName": [
      "RemovePermission",
      "AddPermission",
      "DeleteTopic"
    ],
    "requestParameters": {
      "topicArn": [
        { "prefix": "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.stack_prefix}" }
      ]
    }
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "sns_deletion_event_target" {
  rule = aws_cloudwatch_event_rule.sns_deletion_rule.name
  target_id = "${var.stack_prefix}-target-sns-deletion"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## Notify on changes to Secrets Manager 
#########################################################
resource "aws_cloudwatch_event_rule" "secrets_deletion_rule" {
  name = "${var.stack_prefix}-detect-secrets-deletion"
  description = "A CloudWatch Event Rule that triggers on Secrets Manager deletion events."
  is_enabled = true
  event_pattern = <<PATTERN
{
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "secretsmanager.amazonaws.com"
    ],
    "eventName": [
      "UpdateSecret",
      "DeleteSecret",
      "PutSecretValue"
    ],
    "requestParameters": {
      "secretId": [
        "${var.db_secret_arn}",
        "${var.user_secret_arn}",
        "${var.db_secret_name}",
        "${var.user_secret_name}"
      ]
    }
  }
}

PATTERN

}

resource "aws_cloudwatch_event_target" "secrets_deletion_event_target" {
  rule = aws_cloudwatch_event_rule.secrets_deletion_rule.name
  target_id = "${var.stack_prefix}-target-secrets-deletion"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## Notify on changes to SSM Parameters
#########################################################
resource "aws_cloudwatch_event_rule" "ssm_deletion_rule" {
  name = "${var.stack_prefix}-detect-ssm-deletion"
  description = "A CloudWatch Event Rule that triggers on SSM Parameter events."
  is_enabled = true
  event_pattern = <<PATTERN
{
    "source": [
        "aws.ssm"
    ],
    "detail-type": [
        "Parameter Store Change"
    ],
    "detail": {
        "name": [
          "/bluage/rds_endpoint"
        ],
        "operation": [
            "Create",
            "Update",
            "Delete",
            "LabelParameterVersion"
        ]
    }
}

PATTERN

}

resource "aws_cloudwatch_event_target" "ssm_deletion_event_target" {
  rule = aws_cloudwatch_event_rule.ssm_deletion_rule.name
  target_id = "${var.stack_prefix}-target-ssm-deletion"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

#########################################################
## CloudWatch alarm on healthy host cost for the online module
#########################################################

resource "aws_cloudwatch_metric_alarm" "nlb_healthyhosts" {
  alarm_name          = "${var.stack_prefix}-online-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "Number of healthy nodes in Target Group"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.alerting_sns_topic.arn]
  ok_actions          = [aws_sns_topic.alerting_sns_topic.arn]
  dimensions = {
    TargetGroup  = var.targetgroup_arn_suffix
    LoadBalancer = var.loadbalancer_arn_suffix
  }
}

#########################################################
## Alert on ECS Service Failures (online module)
#########################################################
resource "aws_cloudwatch_event_rule" "ecs_service_alerts" {
  name = "${var.stack_prefix}-ecs-service-alerts"
  description = "A CloudWatch Event Rule that triggers on ECS Service Alerts"
  is_enabled = true
  event_pattern = <<PATTERN
{
    "source": [
        "aws.ecs"
    ],
    "detail-type": [
        "ECS Service Action"
    ],
    "resources": [
      "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
    ],
    "detail": {
      "eventName": [
        "SERVICE_TASK_START_IMPAIRED",
        "SERVICE_DAEMON_PLACEMENT_CONSTRAINT_VIOLATED",
        "ECS_OPERATION_THROTTLED",
        "SERVICE_DISCOVERY_OPERATION_THROTTLED",
        "SERVICE_TASK_PLACEMENT_FAILURE",
        "SERVICE_TASK_CONFIGURATION_FAILURE"
      ]
    }
}

PATTERN

}

resource "aws_cloudwatch_event_target" "ecs_service_target" {
  rule = aws_cloudwatch_event_rule.ecs_service_alerts.name
  target_id = "${var.stack_prefix}-target-ecs-service-alerts"
  arn = aws_sns_topic.alerting_sns_topic.arn
}

resource "aws_cloudwatch_event_rule" "ecs_service_deployment_alerts" {
  name = "${var.stack_prefix}-ecs-service-deployment-alerts"
  description = "A CloudWatch Event Rule that triggers on ECS Service Deployment Alerts"
  is_enabled = true
  event_pattern = <<PATTERN
{
    "source": [
        "aws.ecs"
    ],
    "detail-type": [
        "ECS Deployment State Change"
    ],
    "resources": [
      "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
    ],
    "detail": {
      "eventName": [
        "SERVICE_DEPLOYMENT_FAILED"
      ]
    }
}

PATTERN

}

resource "aws_cloudwatch_event_target" "ecs_service_deployment_target" {
  rule = aws_cloudwatch_event_rule.ecs_service_deployment_alerts.name
  target_id = "${var.stack_prefix}-target-ecs-service-deployment-alerts"
  arn = aws_sns_topic.alerting_sns_topic.arn
}