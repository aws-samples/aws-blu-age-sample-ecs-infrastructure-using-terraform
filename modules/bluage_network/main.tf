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

resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:VPC flow logs may be enabled as required
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.stack_prefix}-vpc"
  }
}

# Ensure the default Security Group restricts all traffic https://docs.bridgecrew.io/docs/networking_4
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.stack_prefix}-default-sg"
  }
}

# Function (https://www.terraform.io/language/functions/cidrsubnet)
resource "aws_subnet" "private" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.stack_prefix}-private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.stack_prefix}-public-subnet-${count.index + 1}"
  }
}

# Conditional resouces if direct internet access required (direct_internet_access_required), otherwise it is assumed that Transit Gateway will be used to access resources 

resource "aws_internet_gateway" "igw" {
count  = var.direct_internet_access_required ? 1 : 0
 vpc_id = aws_vpc.main.id
 tags = {
   Name = "${var.stack_prefix}-IGW"
 }
}

resource "aws_route" "public-route" {
 count  = var.direct_internet_access_required ? 1 : 0
 route_table_id         = aws_vpc.main.main_route_table_id
 destination_cidr_block = "0.0.0.0/0"
 gateway_id             = aws_internet_gateway.igw[count.index].id
}

resource "aws_eip" "eip" {
 count  = var.direct_internet_access_required ? var.az_count : 0
 vpc        = true
 depends_on = [aws_internet_gateway.igw]
 tags = {
   Name = "${var.stack_prefix}-eip-${count.index + 1}"
 }
}

# Function (https://www.terraform.io/language/functions/element)
resource "aws_nat_gateway" "nat" {
 count  = var.direct_internet_access_required ? var.az_count : 0
 subnet_id     = element(aws_subnet.public.*.id, count.index)
 allocation_id = element(aws_eip.eip.*.id, count.index)
 tags = {
   Name = "${var.stack_prefix}-ngw-${count.index + 1}"
 }
}

resource "aws_route_table" "private-route-table" {
 count  = var.direct_internet_access_required ? var.az_count : 0
 vpc_id = aws_vpc.main.id

 route {
   cidr_block     = "0.0.0.0/0"
   nat_gateway_id = element(aws_nat_gateway.nat.*.id, count.index)
 }
 tags = {
   Name = "${var.stack_prefix}-private-rtb-${count.index + 1}"
 }
}

resource "aws_route_table_association" "route-association" {
 count  = var.direct_internet_access_required ? var.az_count : 0
 subnet_id      = element(aws_subnet.private.*.id, count.index)
 route_table_id = element(aws_route_table.private-route-table.*.id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_private_rtb_assoc" {
 count  = var.direct_internet_access_required ? var.az_count : 0
 route_table_id  = element(aws_route_table.private-route-table.*.id, count.index)
 vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  tags = {
    Name = "${var.stack_prefix}-s3-gateway-endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_main_rtb_assoc" {
  route_table_id  = aws_vpc.main.main_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
}

resource "aws_security_group" "rds_sg" {
  # checkov:skip=CKV2_AWS_5:Security Groups are created here and then consumed by further modules
  name        = "${var.stack_prefix}-rds-security-group"
  description = "Enables access to the RDS PostgreSQL Aurora Service"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow members of the SG to communicate over PostgreSQL ports"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    self             = true
  }

  egress {
    description      = "Allow outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.stack_prefix}-rds-security-group"
  }
}

# This Security Group will allow access to the internal NLB to the local VPC address range, along with 
# the contents of a list object supplied as a variable to this module (additional_nlb_igress_cidrs)
resource "aws_security_group" "ecs_service_sg" {
  # checkov:skip=CKV2_AWS_5:Security Groups are created here and then consumed by further modules
  name        = "${var.stack_prefix}-ecs-service-security-group"
  description = "Enables access to the Realtime ECS Services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow the local VPC to communicate over TCP/3090 ports, this includes NLB health checks"
    from_port        = 3090
    to_port          = 3090
    protocol         = "tcp"
    cidr_blocks      =  setunion(var.additional_nlb_igress_cidrs, [var.vpc_cidr])
  }

  egress {
    description      = "Allow outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.stack_prefix}-ecs-service-security-group"
  }
}


resource "aws_security_group" "vpce_sg" {
  name        = "${var.stack_prefix}-vpce-security-group"
  description = "Enables access to the VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "https traffic from local VPC CIDR"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [ "${var.vpc_cidr}" ]
  }

  egress {
    description      = "Allow outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.stack_prefix}-vpce-security-group"
  }
}

# Only deploy interface VPC endpoints if there is no Internet gateway
resource "aws_vpc_endpoint" "secretsmanager" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-secretsmanager-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-ssm-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-ecr-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_docker" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-ecr-docker-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-logs-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "sts" {
  count  = var.direct_internet_access_required ? 0 : 1
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids        = "${aws_subnet.private.*.id}"

  security_group_ids = [
    aws_security_group.vpce_sg.id,
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_prefix}-sts-interface-endpoint"
  }
}