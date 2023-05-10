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

output "batch_ecs_task_role_arn" {
  description = "The ARN for the batch task IAM Role"
  value       = try(aws_iam_role.batch_ecs_task_role.arn, "")
}

output "batch_ecs_task_execution_role_arn" {
  description = "The ARN for the batch task execution IAM Role"
  value       = try(aws_iam_role.batch_ecs_task_execution_role.arn, "")
}

output "stepfunction_role_arn" {
  description = "The ARN for the Step Function IAM Role"
  value       = try(aws_iam_role.stepfunction_role.arn, "")
}

output "realtime_ecs_service_role_arn" {
  description = "The ARN for the batch task IAM Role"
  value       = try(aws_iam_role.realtime_ecs_service_role.arn, "")
}

output "realtime_ecs_service_execution_role_arn" {
  description = "The ARN for the batch task execution IAM Role"
  value       = try(aws_iam_role.realtime_ecs_service_execution_role.arn, "")
}