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


# We require two roles for each ECS task/service
#  The "task" role is assumed by the task and used to access AWS resources
#  The "task execution" role is the context used to create the task/service

# Batch Task Role
resource "aws_iam_role" "batch_ecs_task_role" {
  name = "${var.stack_prefix}-batch-ecs-task-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy" "batch_ecs_task_policy" {
  name = "${var.stack_prefix}-batch-ecs-task-policy"
  role = "${aws_iam_role.batch_ecs_task_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
         {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "${var.input_s3_bucket_arn}/*"
            ]
        },
         {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "${var.input_s3_bucket_arn}",
                "${var.output_s3_bucket_arn}"
            ]
        },
         {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": [
                "${var.input_s3_bucket_arn}/*",
                "${var.output_s3_bucket_arn}/*"
            ]
        }
    ]
}
EOF
}

# Batch Task Execution Role
resource "aws_iam_role" "batch_ecs_task_execution_role" {
  name = "${var.stack_prefix}-batch-ecs-task-execution-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "batch_ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.batch_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "batch_ecs_task_execution_policy" {
  name = "${var.stack_prefix}-batch-ecs-task-execution-policy"
  role = "${aws_iam_role.batch_ecs_task_execution_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
         {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "${var.db_secret_arn}",
                "${var.db_user_secret_arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": [
                "${var.ssm_rds_endpoint_arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": [
                "${var.kms_key_arn}"
            ]
        }
    ]
}
EOF
}

# Step Function Role
resource "aws_iam_role" "stepfunction_role" {
  name               = "${var.stack_prefix}-stepfunction-role"
  assume_role_policy = "${data.aws_iam_policy_document.stepfunction_policy_document.json}"
}

data "aws_iam_policy_document" "stepfunction_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "stepfunction_ecs_policy" {
  name = "${var.stack_prefix}-stepfunction-policy"
  role = aws_iam_role.stepfunction_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogDelivery",
              "logs:GetLogDelivery",
              "logs:UpdateLogDelivery",
              "logs:DeleteLogDelivery",
              "logs:ListLogDeliveries",
              "logs:PutResourcePolicy",
              "logs:DescribeResourcePolicies",
              "logs:DescribeLogGroups"
            ],
            "Resource": [
                "*"
            ],
            "Condition": {
              "StringEquals": {
                "aws:ResourceAccount": [
                  "${data.aws_caller_identity.current.account_id}"
                ]
              }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole"
            ],
            "Resource": [
                "${aws_iam_role.batch_ecs_task_role.arn}",
                "${aws_iam_role.batch_ecs_task_execution_role.arn}"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": "ecs-tasks.amazonaws.com"
                }
            }
        },
        {
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Condition": {
              "StringEquals": {
                "aws:ResourceAccount": [
                  "${data.aws_caller_identity.current.account_id}"
                ]
              }
            }
        },
        {
            "Action": [
                "sns:Publish"
            ],
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Condition": {
              "StringEquals": {
                "aws:ResourceAccount": [
                  "${data.aws_caller_identity.current.account_id}"
                ]
              }
            }
        },
        {
            "Action": [
                "ecs:RunTask"
            ],
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Condition": {
              "StringEquals": {
                "aws:ResourceAccount": [
                  "${data.aws_caller_identity.current.account_id}"
                ]
              }
            }
        },
        {
            "Action": [
                "ecs:StopTask",
                "ecs:DescribeTasks"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
              "StringEquals": {
                "aws:ResourceAccount": [
                  "${data.aws_caller_identity.current.account_id}"
                ]
              }
            }
        },
        {
            "Action": [
                "events:PutTargets",
                "events:PutRule",
                "events:DescribeRule"
            ],
            "Resource": [
                "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
            ],
            "Effect": "Allow"
        }
    ]
}
EOF
}


# Realtime Task Role
resource "aws_iam_role" "realtime_ecs_service_role" {
  name = "${var.stack_prefix}-realtime-ecs-service-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy" "realtime_ecs_service_role_policy" {
  name = "${var.stack_prefix}-realtime-ecs-service-policy"
  role = "${aws_iam_role.realtime_ecs_service_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
         {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "${var.input_s3_bucket_arn}/*"
            ]
        },
         {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "${var.input_s3_bucket_arn}"
            ]
        }
    ]
}
EOF
}

# Realtime Task Execution role

resource "aws_iam_role" "realtime_ecs_service_execution_role" {
  name = "${var.stack_prefix}-realtime-ecs-service-execution-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_service_execution_policy_attachment" {
  role       = aws_iam_role.realtime_ecs_service_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_service_role_custom_attachment_policy" {
  name = "${var.stack_prefix}-realtime-ecs-service-execution-policy"
  role = "${aws_iam_role.realtime_ecs_service_execution_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
         {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "${var.db_secret_arn}",
                "${var.db_user_secret_arn}"
            ]
        },
         {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": [
                "${var.ssm_rds_endpoint_arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": [
                "${var.kms_key_arn}"
            ]
        }
    ]
}
EOF
}
