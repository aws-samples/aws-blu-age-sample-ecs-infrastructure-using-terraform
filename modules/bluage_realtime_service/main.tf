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


# Uncomment if you are using an ALB rather than the default NLB and wish for access logging
# NLB is required for any other protocol than HTTP/HTTPS, e.g. CICS

#resource "aws_s3_bucket" "elb_logs" {
#  # checkov:skip=CKV_AWS_145:SSE-S3 is sufficient for this data
#  # checkov:skip=CKV_AWS_21:S3 Versioning is not appropriate for ALB log storage
#  # checkov:skip=CKV_AWS_18:Access logging is not required for data in this S3 Bucket
#  # checkov:skip=CKV_AWS_144:CRR is not required for this data
#  bucket = "${var.stack_prefix}-elb-access-logs-${data.aws_caller_identity.current.account_id}"
#}
#
#resource "aws_s3_bucket_lifecycle_configuration" "elb_logs_lifecycle" {
#  bucket = aws_s3_bucket.elb_logs.id
#
#  rule {
#    id = "expire-after-1-month"
#
#    expiration {
#      days = 31
#    }
#
#    status = "Enabled"
#  }
#}
#
#resource "aws_s3_bucket_server_side_encryption_configuration" "elb_logs_encryption" {
#  bucket = aws_s3_bucket.elb_logs.bucket
#
#  rule {
#    apply_server_side_encryption_by_default {
#      sse_algorithm     = "AES256"
#    }
#  }
#}
#
#resource "aws_s3_bucket_public_access_block" "elb_logs_bpa" {
#  bucket = aws_s3_bucket.elb_logs.id
#
#  block_public_acls       = true
#  block_public_policy     = true
#  ignore_public_acls      = true
#  restrict_public_buckets = true
#}
#
## The account delivering logs is owned by AWS, details can be found here
## https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html#attach-bucket-policy
#data "aws_iam_policy_document" "allow_elb_access_logging" {
#  statement {
#    effect = "Allow"
#    actions = [ "s3:PutObject" ]
#    principals {
#      type = "Service"
#      identifiers = [
#        "delivery.logs.amazonaws.com"
#      ]
#    }
#    resources = [
#      "arn:aws:s3:::${aws_s3_bucket.elb_logs.id}/bluage/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
#    ]
#  }
#  statement {
#    effect = "Allow"
#    actions = [ "s3:GetBucketAcl" ]
#    principals {
#      type = "Service"
#      identifiers = [
#        "delivery.logs.amazonaws.com"
#      ]
#    }
#    resources = [
#      "arn:aws:s3:::${aws_s3_bucket.elb_logs.id}"
#    ]
#  }
#}
#
#resource "aws_s3_bucket_policy" "attach_elb_access_logging_policy" {
#  bucket = aws_s3_bucket.elb_logs.id
#  policy = data.aws_iam_policy_document.allow_elb_access_logging.json
#}

resource "aws_lb" "realtime_interface_elb" {
  # checkov:skip=CKV_AWS_91:NLBs do not support access logging
  # checkov:skip=CKV_AWS_150:Deletion protection can be enabled if required
  name                             = "${var.stack_prefix}-elb"
  internal                         = true
  load_balancer_type               = "network"
  enable_deletion_protection       = false
  subnets                          = var.public_subnets
  enable_cross_zone_load_balancing = true

  # Access logs are not written for NLBs

  #access_logs {
  #  bucket  = aws_s3_bucket.elb_logs.bucket
  #  prefix  = "bluage"
  #  enabled = true
  #}

  tags = {
    Name = "${var.stack_prefix}-elb"
  }
}

# Adjust the TCP port as required
resource "aws_lb_target_group" "realtime_interface_tg" {
  name        = "${var.stack_prefix}-tg"
  port        = 3090
  protocol    = "TCP_UDP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    port                = "traffic-port"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "realtime_interface_listener" {
  load_balancer_arn = aws_lb.realtime_interface_elb.arn
  port              = "3090"
  protocol          = "TCP_UDP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.realtime_interface_tg.arn
  }
}

# Uncomment if an Alias record is needed in Route53
#resource "aws_route53_record" "realtime_interface_r53_alias" {
#  zone_id = "AZ12345678910"
#  name    = "dns_record_name"
#  type    = "A"
#
#  alias {
#    name                   = aws_lb.realtime_interface_elb.dns_name
#    zone_id                = aws_lb.realtime_interface_elb.zone_id
#    evaluate_target_health = true
#  }
#}

resource "aws_ecs_task_definition" "realtime_ecs_service_definition" {
  # checkov:skip=CKV_AWS_336:Read-only root filesystem is not supported in this example
  family                   = "${var.stack_prefix}-realtime-interface"
  task_role_arn            = var.realtime_ecs_service_role_arn
  execution_role_arn       = var.realtime_ecs_service_execution_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  cpu                      = var.task_cpu_allocation
  memory                   = var.task_memory_allocation
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
      "portMappings": [
        {
          "containerPort": 3090,
          "hostPort": 3090,
          "protocol": "tcp"
        }
      ],
      "command": [
        "./wrapper.sh REALTIME"
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
      "name": "bluage_realtime_interface"
    }
]
DEFINITION

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_service" "realtime_ecs_Service" {
  name                               = "${var.stack_prefix}-realtime-ecs-service"
  task_definition                    = aws_ecs_task_definition.realtime_ecs_service_definition.arn
  desired_count                      = var.container_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 30
  launch_type                        = "FARGATE"
  enable_ecs_managed_tags            = true
  cluster                            = var.ecs_cluster_arn

  load_balancer {
    container_name   = "bluage_realtime_interface"
    container_port   = 3090
    target_group_arn = aws_lb_target_group.realtime_interface_tg.arn
  }

  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#network_configuration
  network_configuration {
    security_groups  = [
      var.ecs_service_sg_id,
      var.rds_sg_id
    ]
    subnets          = var.private_subnets
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}