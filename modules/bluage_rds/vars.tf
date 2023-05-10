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

variable "rds_security_group_id" {
    description = "Security Group ID for the Aurora Instances"
    type        = string
}

variable "kms_key_arn" {
    description = "ARN of the KMS key used to encrypt the Aurora instances"
    type        = string
}

variable "subnets" {
    description = "List of subnet IDs for the RDS subnet group"
    type        = list
}

variable "rds_instance_type" {
    description = "Instance type for the Aurora PostgreSQL compute"
    type        = string
    default     = "db.t4g.large"
}
