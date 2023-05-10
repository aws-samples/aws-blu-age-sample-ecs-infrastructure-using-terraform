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

output "db_secret_arn" {
  description = "The arn for the Secret in Secrets Manager containing the DB root credentials"
  value       = try(aws_secretsmanager_secret_version.db_password.arn, "")
}

output "user_secret_arn" {
  description = "The arn for the Secret in Secrets Manager containing the runtime database user credentials"
  value       = try(aws_secretsmanager_secret_version.user_db_password.arn, "")
}

output "ssm_rds_endpoint_arn" {
  description = "The arn for the SSM parameter containing the RDS endpoint"
  value       = try(aws_ssm_parameter.rds_endpoint.arn, "")
}

output "rds_cluster_id" {
  description = "The ID of the Aurora RDS Cluster"
  value       = try(aws_rds_cluster.postgresql.id, "")
}

output "rds_instance_ids" {
  description = "List of IDs for the RDS instances"
  value       = try(aws_rds_cluster_instance.cluster_instances[*].id, "")
}

output "rds_endpoint_url" {
  description = "The URL of the writer endpoint for the Aurora RDS Cluster"
  value       = try(aws_rds_cluster.postgresql.endpoint, "")
}
