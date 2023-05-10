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
    description = "String to append to resources to generate unique names"
    type        = string    
}

variable "kms_key_id" {
    description = "ID of the KMS key used to encrypt the Aurora instances"
    type        = string
}

variable "rds_cluster_id" {
    description = "The ID of the Aurora RDS Cluster"
    type        = string
}

variable "rds_instance_ids" {
    description = "List of IDs for the RDS instances"
    type        = list
}

variable "input_s3_bucket_id" {
    description = "Name of the S3 Bucket which contains the Input Files"
    type        = string
}

variable "output_s3_bucket_id" {
    description = "Name of the S3 Bucket which contains the Output Files"
    type        = string
}

variable "db_secret_arn" {
    description = "The arn for the Secret in Secrets Manager containing the DB credentials"
    type        = string
}

variable "user_secret_arn" {
    description = "The arn for the Secret in Secrets Manager containing the user DB credentials"
    type        = string
}

variable "db_secret_name" {
    description = "The key of the Secret in Secrets Manager containing the DB credentials"
    type        = string
}

variable "user_secret_name" {
    description = "The key of the Secret in Secrets Manager containing the user DB credentials"
    type        = string
}

variable "loadbalancer_arn_suffix" {
  description = "The ARN Suffix for the ELB"
  type        = string
}

variable "targetgroup_arn_suffix" {
  description = "The ARN Suffix for the Target Group"
  type        = string
}

variable "ecs_cluster_name" {
  description = "The Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "The Name of the ECS Service"
  type        = string
}
