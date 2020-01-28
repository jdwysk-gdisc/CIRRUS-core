module "cumulus" {
  source = "https://github.com/nasa/cumulus/releases/download/v1.17.0/terraform-aws-cumulus.zip//tf-modules/cumulus"

  cumulus_message_adapter_lambda_layer_arn = data.terraform_remote_state.asf.outputs.cma_layer_arn

  prefix = local.prefix

  vpc_id = data.aws_vpc.application_vpcs.id
  lambda_subnet_ids = "${list(sort(data.aws_subnet_ids.subnet_ids.ids)[0])}"

  ecs_cluster_instance_subnet_ids = "${list(sort(data.aws_subnet_ids.subnet_ids.ids)[0])}"
  ecs_cluster_min_size            = 1
  ecs_cluster_desired_size        = 1
  ecs_cluster_max_size            = 2
  key_name                        = var.key_name

  urs_url             = var.urs_url                     # LOOKUP: MATURITY
  urs_client_id       = var.urs_client_id               # LOOKUP: AWS Secrets Svc
  urs_client_password = var.urs_client_password         # LOOKUP: AWS Secrets Svc

  ems_host              = var.ems_host                  # LOOKUP: MATURITY
  ems_port              = var.ems_port                  # LOOKUP: MATURITY
  ems_path              = var.ems_path                  # LOOKUP: MATURITY
  ems_datasource        = var.ems_datasource            # LOOKUP: MATURITY
  ems_private_key       = var.ems_private_key           # LOOKUP: AWS Secrets Svc
  ems_provider          = var.ems_provider              # LOOKUP: MATURITY
  ems_retention_in_days = var.ems_retention_in_days     # LOOKUP: MATURITY
  ems_submit_report     = var.ems_submit_report         # LOOKUP: MATURITY
  ems_username          = var.ems_username              # LOOKUP: AWS Secrets Svc

  metrics_es_host = var.metrics_es_host                 # LOOKUP: MATURITY
  metrics_es_password = var.metrics_es_password         # LOOKUP: AWS Secrets Svc
  metrics_es_username = var.metrics_es_username         # LOOKUP: AWS Secrets Svc

  cmr_client_id   = local.cmr_client_id                 # LOOKUP: MATURITY
  cmr_environment = "UAT"                               # LOOKUP: MATURITY
  cmr_username    = var.cmr_username                    # LOOKUP: AWS Secrets Svc
  cmr_password    = var.cmr_password                    # LOOKUP: AWS Secrets Svc
  cmr_provider    = var.cmr_provider

  cmr_oauth_provider = var.cmr_oauth_provider           # LOOKUP: MATURITY

  launchpad_api         = var.launchpad_api             # LOOKUP: MATURITY
  launchpad_certificate = var.launchpad_certificate     # LOOKUP: AWS Secrets Svc
  launchpad_passphrase  = var.launchpad_passphrase      # LOOKUP: AWS Secrets Svc

  oauth_provider   = var.oauth_provider                 # LOOKUP: MATURITY
  oauth_user_group = var.oauth_user_group               # LOOKUP: MATURITY

  saml_entity_id                  = var.saml_entity_id
  saml_assertion_consumer_service = var.saml_assertion_consumer_service
  saml_idp_login                  = var.saml_idp_login
  saml_launchpad_metadata_path    = var.saml_launchpad_metadata_path

  token_secret = var.token_secret                       # LOOKUP: AWS Secrets Svc
  # ^^^^^^^^^ LOOKUP BASED ON MATURITY ^^^^^^^^^

  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NGAPShRoleBoundary"

  system_bucket = local.system_bucket
  buckets       = local.buckets

  elasticsearch_alarms            = data.terraform_remote_state.data_persistence.outputs.elasticsearch_alarms
  elasticsearch_domain_arn        = data.terraform_remote_state.data_persistence.outputs.elasticsearch_domain_arn
  elasticsearch_hostname          = data.terraform_remote_state.data_persistence.outputs.elasticsearch_hostname
  elasticsearch_security_group_id = data.terraform_remote_state.data_persistence.outputs.elasticsearch_security_group_id

  dynamo_tables = data.terraform_remote_state.data_persistence.outputs.dynamo_tables

  archive_api_users = var.api_users

  distribution_url = var.distribution_url

  sts_credentials_lambda_function_arn = data.aws_lambda_function.sts_credentials.arn

  archive_api_port            = var.archive_api_port
  private_archive_api_gateway = var.private_archive_api_gateway
  api_gateway_stage = var.api_gateway_stage
  log_api_gateway_to_cloudwatch = var.log_api_gateway_to_cloudwatch
  log_destination_arn = var.log_destination_arn

  deploy_distribution_s3_credentials_endpoint = var.deploy_distribution_s3_credentials_endpoint
}

variable "DEPLOY_NAME" {
  type = string
  default = "asf"
}

variable "MATURITY" {
  type = string
  default = "dev"
}

locals {
  prefix = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}"

  asf_remote_state_config = {
    bucket = "cumulus-${var.MATURITY}-tf-state"
    key    = "asf/terraform.tfstate"
    region = "${data.aws_region.current.name}"
  }

  data_persistence_remote_state_config = {
    bucket = "cumulus-${var.MATURITY}-tf-state"
    key    = "data-persistence/terraform.tfstate"
    region = "${data.aws_region.current.name}"
  }

  system_bucket = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}-internal"

  buckets = {
    internal = {
      name = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}-internal"
      type = "internal"
    }
    private = {
      name = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}-private"
      type = "private"
    },
    protected = {
      name = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}-protected"
      type = "protected"
    },
    public = {
      name = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}-public"
      type = "public"
    }
  }

  cmr_client_id = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}"

  default_tags = {
    Deployment = "${var.DEPLOY_NAME}-cumulus-${var.MATURITY}"
  }
}

terraform {
  required_providers {
    aws  = ">= 2.31.0"
    null = "~> 2.1"
  }
  backend "s3" {
  }
}

provider "aws" {
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "application_vpcs" {
  tags = {
    Name = "Application VPC"
  }
}

data "aws_subnet_ids" "subnet_ids" {
  vpc_id = data.aws_vpc.application_vpcs.id
}

data "terraform_remote_state" "asf" {
  backend = "s3"
  workspace = "${var.DEPLOY_NAME}"
  config  = local.asf_remote_state_config
}

data "terraform_remote_state" "data_persistence" {
  backend = "s3"
  workspace = "${var.DEPLOY_NAME}"
  config  = local.data_persistence_remote_state_config
}

data "aws_lambda_function" "sts_credentials" {
  function_name = "gsfc-ngap-sh-s3-sts-get-keys"
}

resource "aws_security_group" "no_ingress_all_egress" {
  name   = "${local.prefix}-cumulus-tf-no-ingress-all-egress"
  vpc_id = data.aws_vpc.application_vpcs.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}
