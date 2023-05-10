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

variable "stack_prefix" {
    description = "Identifier to prepend to resources"
    type        = string
}

variable "module_name" {
    description = "Identifier of the Blu Age Module"
    type        = string
    default     = "SAMPLE"
}

variable "batch_ecs_task_role_arn" {
    description = "The ARN for the batch task IAM Role"
    type        = string
}

variable "batch_ecs_task_execution_role_arn" {
    description = "The ARN for the batch task execution IAM Role"
    type        = string
}

variable "task_memory_allocation" {
    description = "The RAM to allocate to the task"
    type        = string
    default     = "1024"
}

variable "task_cpu_allocation" {
    description = "The CPU to allocate to the task"
    type        = string
    default     = "512"
}

variable "cloudwatch_log_group_name" {
    description = "The name of the CloudWatch Log Group for the tasks log streams"
    type        = string
}

variable "private_subnets" {
    description = "The subnet IDs in which to run the ECS containers"
    type        = list
}

variable "container_image" {
    description = "The Image path and version for the task definition"
    type        = string
}

variable "input_s3_bucket_id" {
    description = "Name of the S3 Bucket which contains the Input Files"
    type        = string
}

variable "output_s3_bucket_id" {
    description = "Name of the S3 Bucket which contains the Output Files"
    type        = string
}

variable "user_secret_arn" {
    description = "The arn for the Secret in Secrets Manager containing the user DB credentials"
    type        = string
}

variable "ssm_rds_endpoint_arn" {
    description = "The arn for the SSM parameter containing the RDS endpoint"
    type        = string
}

variable "stepfunction_role_arn" {
    description = "The ARN for the Step Function IAM Role"
    type        = string
}

variable "ecs_cluster_arn" {
    description = "The arn for the ECS cluster"
    type        = string
}

variable "rds_sg_id" {
    description = "The ID of the RDS Security Group"
    type        = string
}

variable "database_name" {
    description = "Name of the schema in PostgreSQL"
    type        = string
    default     = "bluagedb"
}

variable "java_max_heap" {
    description = "max heap size for java process"
    type        = string
    default     = ""
}

variable "debug_enabled" {
    description = "Whether to enable debug logging level"
    type        = string
    default     = ""
}

variable "force_execution_time" {
    description = "Whether to override the batch task execution time"
    type        = string
    default     = ""
}

variable "task_ephemeral_storage" {
    description = "The ammount of ephemeral storage for the task"
    type        = string
    default     = "21"
}

variable "jdbc_parameters" {
    description = "JDBC parameters to apply to the database connection"
    type        = string
    default     = "defaultRowFetchSize=1000"
}