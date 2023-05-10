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

# Data source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones)
data "aws_availability_zones" "available" {
  state = "available"
}

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)
data "aws_region" "current" {}

locals {
  private_subnet_list = jsonencode(var.private_subnets)
}

resource "aws_ecs_task_definition" "batch_ecs_task_definition" {
  # checkov:skip=CKV_AWS_336:Read-only root filesystem is not supported in this example
  family                   = "${var.stack_prefix}-${var.module_name}"
  task_role_arn            = var.batch_ecs_task_role_arn
  execution_role_arn       = var.batch_ecs_task_execution_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  cpu                      = var.task_cpu_allocation
  memory                   = var.task_memory_allocation
  ephemeral_storage {
    size_in_gib = var.task_ephemeral_storage
  }
  container_definitions = <<DEFINITION
[
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
            "awslogs-group": "${var.cloudwatch_log_group_name}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "/aws/ecs"
        }
      },
      "entryPoint": [
        "/bin/bash",
        "-l",
        "-c"
      ],
      "portMappings": [],
      "command": [
        "./wrapper.sh BATCH ${var.module_name} ${var.input_s3_bucket_id} ${var.output_s3_bucket_id}"
      ],
      "linuxParameters": null,
      "cpu": 0,
      "environment": [
        {
          "name": "S3_INPUT_BUCKET",
          "value": "${var.input_s3_bucket_id}"
        },
        {
          "name": "S3_OUTPUT_BUCKET",
          "value": "${var.input_s3_bucket_id}"
        },
        {
          "name": "DB_NAME",
          "value": "${var.database_name}"
        },
        {
          "name": "JAVA_MAX_HEAP",
          "value": "${var.java_max_heap}"
        },
        {
          "name": "DEBUG_ENABLED",
          "value": "${var.debug_enabled}"
        },
        {
          "name": "FIXED_EXPORT_TIME",
          "value": "${var.force_execution_time}"
        },
        {
          "name": "JDBC_PARAMETERS",
          "value": "${var.jdbc_parameters}"
        }
      ],
      "resourceRequirements": null,
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": "/usr/share",
      "secrets": [
          {
              "valueFrom": "${var.user_secret_arn}",
              "name": "DB_PASSWORD"
          },
          {
              "valueFrom": "${var.ssm_rds_endpoint_arn}",
              "name": "RDS_ENDPOINT"
          }          
      ],
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": null,
      "volumesFrom": [],
      "stopTimeout": 30,
      "image": "${var.container_image}",
      "startTimeout": 30,
      "firelensConfiguration": null,
      "dependsOn": null,
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": null,
      "name": "${var.stack_prefix}_${var.module_name}_module"
    }
]
DEFINITION

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_sns_topic" "stepfunction_batch_sns_topic" {
  name = "${var.stack_prefix}-${var.module_name}-sns"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_cloudwatch_log_group" "stepfunction_cloudwatch_loggroup" {
  # checkov:skip=CKV_AWS_158:Relying on default CloudWatch protections, encryption with a specific KMS key is not required
  name = "/aws/stepfunction/${var.stack_prefix}-${var.module_name}"
  retention_in_days = 365

  tags = {
    Name = "/aws/stepfunction/${var.stack_prefix}-${var.module_name}"
  }
}

resource "aws_sfn_state_machine" "stepfunction_ecs_state_machine" {
  # checkov:skip=CKV_AWS_285:Execution history logging may be enabled if required
  # checkov:skip=CKV_AWS_284:XRay integration may be enabled if required
  name     = "${var.stack_prefix}-${var.module_name}"
  role_arn = var.stepfunction_role_arn
  logging_configuration {
    include_execution_data = false
    log_destination        = "${aws_cloudwatch_log_group.stepfunction_cloudwatch_loggroup.arn}:*"
    level                  = "ALL"
  }

  definition = <<DEFINITION
{
  "Comment": "Blu Age ${var.module_name} Module wrapper",
  "StartAt": "Run Fargate Task",
  "TimeoutSeconds": 3600,
  "States": {
    "Run Fargate Task": {
      "Type": "Task",
      "Resource": "arn:aws:states:::ecs:runTask.sync",
      "Parameters": {
        "LaunchType": "FARGATE",
        "Cluster": "${var.ecs_cluster_arn}",
        "TaskDefinition": "${aws_ecs_task_definition.batch_ecs_task_definition.arn}",
        "NetworkConfiguration": {
          "AwsvpcConfiguration": {
            "Subnets": ${local.private_subnet_list},
            "AssignPublicIp": "DISABLED",
            "SecurityGroups": [
              "${var.rds_sg_id}"
            ]
          }
        }
      },
      "Next": "Notify Success",
      "Catch": [
          {
            "ErrorEquals": [ "States.ALL" ],
            "Next": "Notify Failure"
          }
      ]
    },
    "Notify Success": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message": "${var.module_name} module succeeded",
        "TopicArn": "${aws_sns_topic.stepfunction_batch_sns_topic.arn}"
      },
      "End": true
    },
    "Notify Failure": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message": "${var.module_name} module failed",
        "TopicArn": "${aws_sns_topic.stepfunction_batch_sns_topic.arn}"
      },
      "End": true
    }
  }
}
DEFINITION
}
