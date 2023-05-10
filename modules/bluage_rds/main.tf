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

# Database superuser account
# Generate a random password and store the value in Secrets Manager
resource "random_password" "db_credentials"{
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "db_password" {
  # checkov:skip=CKV2_AWS_57:Secret rotation for the database password is out of scope for this sample
  name        = "${var.stack_prefix}-db-password"
  kms_key_id  = var.kms_key_arn

  tags = {
    Name = "${var.stack_prefix}-database-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_credentials.result
}

# Database user account
# Generate a random password and store the value in Secrets Manager
resource "random_password" "user_db_credentials"{
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "user_db_password" {
  # checkov:skip=CKV2_AWS_57:Secret rotation for the database password is out of scope for this sample
  name        = "${var.stack_prefix}-user-database-password"
  kms_key_id  = var.kms_key_arn

  tags = {
    Name = "${var.stack_prefix}-user-database-password"
  }
}

resource "aws_secretsmanager_secret_version" "user_db_password" {
  secret_id = aws_secretsmanager_secret.user_db_password.id
  secret_string = random_password.user_db_credentials.result
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.stack_prefix}-db-subnet-group"
  subnet_ids = var.subnets

  tags = {
    Name = "${var.stack_prefix}-subnet-group"
  }
}

resource "aws_rds_cluster_parameter_group" "db_param_group" {
  name        = "${var.stack_prefix}-db-parameter-group"
  family      = "aurora-postgresql13"
  description = "Aurora cluster parameter group"

  parameter {
    name         = "max_locks_per_transaction"
    value        = 100
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "datestyle"
    value        = "iso, dmy"
    apply_method = "pending-reboot"
  }

  # test
  parameter {
    name         = "max_connections"
    value        = "1600"
    apply_method = "pending-reboot"
  }
    
}

resource "aws_rds_cluster" "postgresql" {
  # checkov:skip=CKV2_AWS_27:Query logging will be enabled as required - this can lead to capturing credentials in log data
  # checkov:skip=CKV_AWS_324:Log Capture will be enabled as required - this can lead to capturing credentials in log data
  # checkov:skip=CKV_AWS_139:Deletion protection can be enabled as required
  cluster_identifier                  = "${var.stack_prefix}-aurora-postgresql"
  engine                              = "aurora-postgresql"
  engine_version                      = "13.6"
  db_subnet_group_name                = aws_db_subnet_group.db_subnet_group.name
  database_name                       = "bluagedb"
  master_username                     = "adminuser"
  master_password                     = random_password.db_credentials.result
  backup_retention_period             = 5
  preferred_backup_window             = "02:00-04:00"
  final_snapshot_identifier           = "${var.stack_prefix}-db-finalsnapshot"
  skip_final_snapshot                 = false
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  vpc_security_group_ids              = [ var.rds_security_group_id ]
  iam_database_authentication_enabled = true
  deletion_protection                 = false
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.db_param_group.name
  copy_tags_to_snapshot               = true

  tags = {
    Name = "${var.stack_prefix}-db"
  }

}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count                      = 2
  identifier                 = "${var.stack_prefix}-db-${count.index}"
  cluster_identifier         = aws_rds_cluster.postgresql.id
  instance_class             = var.rds_instance_type
  engine                     = aws_rds_cluster.postgresql.engine
  engine_version             = aws_rds_cluster.postgresql.engine_version
  monitoring_interval        = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring_role.arn
  auto_minor_version_upgrade = true
}

resource "aws_ssm_parameter" "rds_endpoint" {
  # checkov:skip=CKV2_AWS_34:The RDS endpoint is not sensitive data
  # checkov:skip=CKV_AWS_337:The RDS endpoint is not sensitive data
  name  = "/bluage/rds_endpoint"
  type  = "String"
  value = aws_rds_cluster.postgresql.endpoint
}


resource "aws_iam_role" "rds_backup_role" {
  name               = "${var.stack_prefix}-aws-backup-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "rds_backup_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.rds_backup_role.name
}


resource "aws_backup_plan" "bluage_backup" {
  name = "${var.stack_prefix}-aurora-postgresql-backup"

  rule {
    rule_name         = "${var.stack_prefix}-backup-rule"
    target_vault_name = "${var.stack_prefix}-postgresql"
    schedule          = "cron(0 4 * * ? *)"

    lifecycle {
      delete_after = 14
    }
  }

  depends_on = [
    aws_backup_vault.backup_vault
  ]
}

resource "aws_backup_vault" "backup_vault" {
  name        = "${var.stack_prefix}-postgresql"
  kms_key_arn = var.kms_key_arn
}

resource "aws_backup_selection" "backup_selection" {
  iam_role_arn = aws_iam_role.rds_backup_role.arn
  name         = "${var.stack_prefix}_backup_selection"
  plan_id      = aws_backup_plan.bluage_backup.id

  resources = [
    aws_rds_cluster.postgresql.arn
  ]
}

resource "aws_iam_role" "rds_enhanced_monitoring_role" {
  name               = "${var.stack_prefix}-rds-enhanced-monitoring-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["monitoring.rds.amazonaws.com"]
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring_attachment" {
  role       = aws_iam_role.rds_enhanced_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}