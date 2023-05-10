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


#######################################
#######################################
# This sample Terraform is provided to deliver a working example which may be iterated upon.
# It is expected that most customers would use the modules in their own Terraform infrastructure
# rather that using this example as-is.
# A such stylistic concerns such as spliting this file into logical groupings have not been followed.
#######################################
#######################################


##########################
## Terraform Backend
##########################

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = local.tags
  }
}

terraform {
  backend "s3" {
    bucket = "123456789012-terraform-backend"
    key    = "blu-age-infrastructure.tfstate"
    region = "eu-west-1"
    dynamodb_table = "terraform-lock"
    encrypt = true
  }
}

terraform {
  required_version = "~> 1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.63.0"
    }
  }
}

##########################
## Data
##########################

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)
data "aws_region" "current" {}

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)
data "aws_caller_identity" "current" {}


##########################
## Variables
##########################

variable "stack_prefix" {
    description = "Identifier to prepend to resources"
    type        = string
    default     = "blu-age"
}

variable "vpc_cidr" {
    description = "The CIDR range for the VPC"
    type        = string
    default     = "172.16.0.0/23"
}

variable "az_count" {
    description = "The number of Availability Zones to use"
    type        = number
    default     = 2
}

variable "rds_instance_type" {
    description = "Instance type for the Aurora PostgreSQL compute"
    type        = string
    default     = "db.t4g.large"
}

# Format for ECR is "<account>.dkr.ecr.<region>.amazonaws.com/<repository>:<tag>"
variable "container_image" {
    description = "The Image path and version for the blu age container"
    type        = string
    default     = "public.ecr.aws/amazonlinux/amazonlinux:latest"
}

variable "target_environment" {
    description = "The target environment being built, e.g. dev/test/prod"
    type        = string
    default     = "dev"
}

variable "additional_nlb_igress_cidrs" {
  description = "A network address prefix in CIDR notation for network load balancer ingress"
  type        = list(any)
  default     = ["10.0.0.0/16", "10.1.0.0/16"]
}

variable "direct_internet_access_required" {
    description = "Conditional resouces if outbound internet access is required"
    type        = bool
    default     = false
}

##########################
## Locals
##########################

locals {

  # Default tags to apply to all resources, adjust these values as appropriate
  tags = {
    owner        = "Mainframe Team"
    project      = "Blu Age Migration"
    created_with = "Terraform"
    created_by   = "Richard Milner-Watts - AWS"
  }

# Override the module execution time to ensure consistent test results
  module1_export_time_list = {
    "default"          = ""
    "dev"              = "--forceDate=2022-06-14T12:00:00+00:00"
    "test"             = "--forceDate=2022-06-14T12:00:00+00:00"
    "prod"             = ""
  }
  module1_export_time = local.module1_export_time_list["${var.target_environment}"]

  module2_export_time_list = {
    "default"          = ""
    "dev"              = "--forceDate=2022-06-14T12:00:00+00:00"
    "test"             = "--forceDate=2022-06-14T12:00:00+00:00"
    "prod"             = ""
  }
  module2_export_time = local.module2_export_time_list["${var.target_environment}"]

# Configuration details for each batch task to be deployed
# Terraform will loop through "bluage_batch_modules"
# These will deploy as ECS tasks
  bluage_batch_modules = [
    {
      module_name = "module1"
      module_heap_max = ""
      module_fargate_cpu = "512"
      module_fargate_memory = "1024"
      debug_enabled = "TRUE"
      database_name = "bluage_database"
      force_execution_time = local.module1_export_time
      # ECS storage must be between 21 and 200 GiB
      task_ephemeral_storage = "21"
      jdbc_parameters = "defaultRowFetchSize=1500"
    },
    {
      module_name = "module2"
      module_heap_max = "-Xmx8192m"
      module_fargate_cpu = "2048"
      module_fargate_memory = "12288"
      debug_enabled = "FALSE"
      database_name = "bluage_database"
      force_execution_time = local.module2_export_time
      task_ephemeral_storage = "50"
      jdbc_parameters = "defaultRowFetchSize=1500"
    },
  ]

# Values for an ECS Service example
  realtime_heap_max = ""
  realtime_force_execution_time = "--forceDate=2022-07-01T12:00:00+00:00"
  realtime_jdbc_parameters = "defaultRowFetchSize=1500"
  realtime_database_name = "bluage_database"

}

##########################
## Resources
##########################

resource "aws_ecr_repository" "ecs_ecr_repo" {
  # checkov:skip=CKV_AWS_136:The default ECR protections are sufficient, using AES256 
  name = "${var.stack_prefix}-ecr"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.stack_prefix}-ecr"
  }
}

resource "aws_cloudwatch_log_group" "ecs_container_cloudwatch_loggroup" {
  # checkov:skip=CKV_AWS_158:Relying on default CloudWatch protections, encryption with a specific KMS key is not required
  name = "${var.stack_prefix}-cloudwatch-log-group"
  retention_in_days = 365

  tags = {
    Name = "${var.stack_prefix}-cloudwatch-log-group"
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.stack_prefix}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.stack_prefix}-ecs-fargate-cluster"
  }
}

module "bluage_network" {
    source = "./modules/bluage_network"

    stack_prefix                    = var.stack_prefix
    vpc_cidr                        = var.vpc_cidr
    az_count                        = var.az_count
    additional_nlb_igress_cidrs     = var.additional_nlb_igress_cidrs
    direct_internet_access_required = var.direct_internet_access_required
}

module "bluage_s3" {
    source = "./modules/bluage_s3"

    stack_prefix = var.stack_prefix
}

module "bluage_kms" {
    source = "./modules/bluage_kms"

    stack_prefix = var.stack_prefix
}

module "bluage_rds" {
    source = "./modules/bluage_rds"

    stack_prefix                      = var.stack_prefix
    rds_security_group_id             = module.bluage_network.rds_sg_id
    kms_key_arn                       = module.bluage_kms.kms_key_arn
    subnets                           = module.bluage_network.private_subnets
    rds_instance_type                 = var.rds_instance_type
}

module "bluage_iam" {
    source = "./modules/bluage_iam"

    stack_prefix           = var.stack_prefix
    input_s3_bucket_arn    = module.bluage_s3.input_bucket_arn
    output_s3_bucket_arn   = module.bluage_s3.output_bucket_arn
    db_secret_arn          = module.bluage_rds.db_secret_arn
    db_user_secret_arn     = module.bluage_rds.user_secret_arn
    ssm_rds_endpoint_arn   = module.bluage_rds.ssm_rds_endpoint_arn
    kms_key_arn            = module.bluage_kms.kms_key_arn
}

# For each Batch module, create an ECS task
module "looped_batch_task" {

    for_each = {
      for index, module in local.bluage_batch_modules:
      index => module
    }

    source = "./modules/bluage_batch_task"

    stack_prefix                       = var.stack_prefix
    module_name                        = each.value.module_name
    batch_ecs_task_role_arn            = module.bluage_iam.batch_ecs_task_role_arn
    batch_ecs_task_execution_role_arn  = module.bluage_iam.batch_ecs_task_execution_role_arn
    private_subnets                    = module.bluage_network.private_subnets
    task_memory_allocation             = each.value.module_fargate_memory
    task_cpu_allocation                = each.value.module_fargate_cpu
    cloudwatch_log_group_name          = aws_cloudwatch_log_group.ecs_container_cloudwatch_loggroup.name
    input_s3_bucket_id                 = module.bluage_s3.input_bucket_id
    output_s3_bucket_id                = module.bluage_s3.output_bucket_id
    user_secret_arn                    = module.bluage_rds.user_secret_arn
    ssm_rds_endpoint_arn               = module.bluage_rds.ssm_rds_endpoint_arn
    container_image                    = var.container_image
    stepfunction_role_arn              = module.bluage_iam.stepfunction_role_arn
    ecs_cluster_arn                    = aws_ecs_cluster.ecs_cluster.arn
    rds_sg_id                          = module.bluage_network.rds_sg_id
    database_name                      = each.value.database_name
    java_max_heap                      = each.value.module_heap_max
    debug_enabled                      = each.value.debug_enabled
    force_execution_time               = each.value.force_execution_time
    task_ephemeral_storage             = each.value.task_ephemeral_storage
    jdbc_parameters                    = each.value.jdbc_parameters
}


# Reatime module deployed as an ECS Service
module "realtime_module" {
    source = "./modules/bluage_realtime_service"

    stack_prefix                             = var.stack_prefix
    rds_sg_id                                = module.bluage_network.rds_sg_id
    ecs_service_sg_id                        = module.bluage_network.ecs_service_sg_id
    public_subnets                           = module.bluage_network.public_subnets
    vpc_id                                   = module.bluage_network.vpc_id
    realtime_ecs_service_role_arn            = module.bluage_iam.realtime_ecs_service_role_arn
    realtime_ecs_service_execution_role_arn  = module.bluage_iam.realtime_ecs_service_execution_role_arn
    task_memory_allocation                   = "1024"
    task_cpu_allocation                      = "512"
    cloudwatch_log_group_name                = aws_cloudwatch_log_group.ecs_container_cloudwatch_loggroup.name
    input_s3_bucket_id                       = module.bluage_s3.input_bucket_id
    output_s3_bucket_id                      = module.bluage_s3.output_bucket_id
    user_secret_arn                          = module.bluage_rds.user_secret_arn
    ssm_rds_endpoint_arn                     = module.bluage_rds.ssm_rds_endpoint_arn
    container_image                          = var.container_image
    container_count                          = 2
    ecs_cluster_arn                          = aws_ecs_cluster.ecs_cluster.arn
    private_subnets                          = module.bluage_network.private_subnets
    database_name                            = local.realtime_database_name
    java_max_heap                            = local.realtime_heap_max
    force_execution_time                     = local.realtime_force_execution_time
    jdbc_parameters                          = local.realtime_jdbc_parameters
}


module "bluage_monitoring" {
    source = "./modules/bluage_monitoring"

    stack_prefix             = var.stack_prefix
    kms_key_id                = module.bluage_kms.kms_key_id
    rds_cluster_id            = module.bluage_rds.rds_cluster_id
    rds_instance_ids          = module.bluage_rds.rds_instance_ids
    input_s3_bucket_id        = module.bluage_s3.input_bucket_id
    output_s3_bucket_id       = module.bluage_s3.output_bucket_id
    db_secret_arn             = module.bluage_rds.db_secret_arn
    user_secret_arn           = module.bluage_rds.user_secret_arn
    db_secret_name            = "${var.stack_prefix}-db-password"
    user_secret_name          = "${var.stack_prefix}-user-database-password"
    loadbalancer_arn_suffix   = module.realtime_module.loadbalancer_arn_suffix
    targetgroup_arn_suffix    = module.realtime_module.targetgroup_arn_suffix
    ecs_cluster_name          = "${var.stack_prefix}-ecs-cluster"
    ecs_service_name          = module.realtime_module.ecs_service_name
}