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

# Data Source (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bluage_input_bucket" {
  # checkov:skip=CKV_AWS_145:SSE-S3 is sufficient for this data
  # checkov:skip=CKV_AWS_18:Access logging is not required for data in this S3 Bucket
  # checkov:skip=CKV_AWS_144:CRR is not required for this data
  # checkov:skip=CKV2_AWS_62:Event notifications are not required
  bucket = "${var.stack_prefix}-inputs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_lifecycle_configuration" "bluage_input_bucket_lifecycle" {
  bucket = aws_s3_bucket.bluage_input_bucket.id

  rule {
    id = "abort-multipart-uploads"
    filter {}
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
  }

  rule {
    id = "expire-after-1-year"

    expiration {
      days = 365
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bluage_input_bucket_encryption" {
  bucket = aws_s3_bucket.bluage_input_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bluage_input_bucket_bpa" {
  bucket = aws_s3_bucket.bluage_input_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "bluage_input_bucket_versioning" {
  bucket = aws_s3_bucket.bluage_input_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "bluage_output_bucket" {
  # checkov:skip=CKV_AWS_145:SSE-S3 is sufficient for this data
  # checkov:skip=CKV_AWS_18:Access logging is not required for data in this S3 Bucket
  # checkov:skip=CKV_AWS_144:CRR is not required for this data
  # checkov:skip=CKV2_AWS_62:Event notifications are not required
  bucket = "${var.stack_prefix}-outputs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_lifecycle_configuration" "bluage_output_bucket_lifecycle" {
  bucket = aws_s3_bucket.bluage_output_bucket.id

  rule {
    id = "abort-multipart-uploads"
    filter {}
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
  }
  rule {
    id = "expire-after-1-year"

    expiration {
      days = 365
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "bluage_output_bucket_bpa" {
  bucket = aws_s3_bucket.bluage_output_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bluage_output_bucket_encryption" {
  bucket = aws_s3_bucket.bluage_output_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "bluage_output_bucket_versioning" {
  bucket = aws_s3_bucket.bluage_output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}