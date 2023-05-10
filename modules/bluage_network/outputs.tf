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

output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(aws_vpc.main.id, "")
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = try(aws_vpc.main.arn, "")
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(aws_vpc.main.cidr_block, "")
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = try(aws_subnet.private[*].id, "")
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = try(aws_subnet.private[*].arn, "")
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = try(aws_subnet.private[*].cidr_block, "")
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = try(aws_subnet.public[*].id, "")
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = try(aws_subnet.public[*].arn, "")
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = try(aws_subnet.public[*].cidr_block, "")
}

output "rds_sg_id" {
  description = "The ID of the RDS Security Group"
  value       = try(aws_security_group.rds_sg.id, "")
}

output "ecs_service_sg_id" {
  description = "The ID of the ECS Service Security Group"
  value       = try(aws_security_group.ecs_service_sg.id, "")
}
