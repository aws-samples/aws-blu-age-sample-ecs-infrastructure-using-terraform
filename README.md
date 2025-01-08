# aws-blu-age-sample-ecs-infrastructure-using-terraform

## AWS Blu Age Sample ECS Infrastructure (Terraform)

## Description
This pattern provides Terraform modules which may be used to create an orchestration environment mainframe applications which have been modernised using the AWS Blu Age tool. The Java application(s) which are produced by the Blu Age tool are containerised and orchestrated using Amazon Elastic Container Service (ECS).

These modules can be used to create the network and other associated resources needed to deploy ECS, along with example modules for deploying batch and realtime applications which have been modernised with Blu Age.

See the APG artefact for detailed instructions on usage.
https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/deploy-an-environment-for-containerized-blu-age-applications-by-using-terraform.html

## Notes
The code in this repository has been scanned with Checkov (version 2.3.199) for security issues. In some cases, certain warnings have been suppressed as they have been deemed to not be relevant to the security of the solution. Additionally, the Terraform modules included here are intended to be copied and customised to meet the intended use case; these are not intended to be executed in a production environment in their current form. 

## Authors and acknowledgment
Richard Milner-Watts 

