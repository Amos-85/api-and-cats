module s3-dy-demo {
  source = "terraform-aws-modules/s3-bucket/aws"

  create_bucket = true
  bucket = var.bucket_name
  acl    = "private"

  versioning = {
    enabled = false
  }
  tags = {
    Environment = "DY-Demo"
  }
}

module validation  {
  source        = "terraform-aws-modules/lambda/aws"
  create        = true
  function_name = "dy_validation"
  description   = "Lambda function triggered for validation fed status"
  handler       = "validation.lambda_handler"
  runtime       = "python3.8"
  publish = true
  create_current_version_allowed_triggers = false

  build_in_docker   = false
  docker_file       = "src/Dockerfile"
  docker_build_root = "src"
  docker_image      = "python:3.8"
//  allowed_triggers = {
//    S3 = {
//      service = "s3"
//      arn = module.s3-dy-demo.this_s3_bucket_arn
//    }
//  }
#  source_path   = "${path.module}/src/validation.py"
   source_path = [
    {
      path             = "${path.module}/src/validation"
      pip_requirements = true
      prefix_in_zip    = "/"
    }
  ]
  vpc_subnet_ids = var.lambda_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids
  environment_variables = {
    EMAIL_RECEPIENT=var.email
    REDIS_MASTER_ENDPOINT=module.redis.endpoint
  }
  tags = {
    Environment = "DY-Demo"
  }
  attach_policy_json = true
  number_of_policies = 1
  policy_json   =  <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
      },

        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail"
            ],
            "Resource": "*"
        },
        {
            "Action": "iam:CreateServiceLinkedRole",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::*:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": "elasticache.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

module lambda-s3-listener  {
  source        = "terraform-aws-modules/lambda/aws"
  create        = true
  function_name = "dy_s3_listener"
  description   = "Lambda function triggered by s3 events"
  handler       = "s3_listener.lambda_handler"
  publish       = true
  vpc_subnet_ids = var.lambda_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids
  create_current_version_allowed_triggers = false
  runtime       = "python3.8"
  build_in_docker   = false
  docker_file       = "src/Dockerfile"
  docker_build_root = "src"
  docker_image      = "python:3.8"
  source_path = [
    {
      path             = "${path.module}/src/s3_listener"
      pip_requirements = true
      prefix_in_zip    = "/"
    }
  ]
  allowed_triggers = {
    S3 = {
      service = "s3"
      arn = module.s3-dy-demo.this_s3_bucket_arn
    }
  }
  environment_variables = {
      REDIS_MASTER_ENDPOINT=module.redis.endpoint
  }

  tags = {
    Environment = "DY-Demo"
  }
  attach_policy_json = true
  number_of_policies = 1
  policy_json   =  <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    },
        {
            "Effect": "Allow",
            "Action": [
                "rekognition:DetectLabels"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Action": "iam:CreateServiceLinkedRole",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::*:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": "elasticache.amazonaws.com"
                }
            }
        }

    ]
}
EOF
}

 module "redis" {
   source  = "github.com/terraform-community-modules/tf_aws_elasticache_redis.git?ref=v2.2.0"

   env            = "dev"
   name           = "dy-demo"
   redis_clusters = "1"
   redis_failover = "false"
   subnets        = var.redis_vpc_subnet_ids
   vpc_id         = var.vpc_id
   redis_version = "5.0.6"
   redis_node_type = "cache.t2.micro"
   tags = {
     Environment = "DY-Demo"
   }
   allowed_cidr = var.allowed_cidr
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3-dy-demo.this_s3_bucket_id

  lambda_function {
    lambda_function_arn = module.lambda-s3-listener.this_lambda_function_arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".jpg"
  }
}

resource "aws_cloudwatch_event_rule" "fed_validate" {
  name                = "validate_fed"
  is_enabled          = true
  description         = "Runs periodically every 15 minutes."
  schedule_expression = "rate(15 minutes)"
  tags = {
    Environment = "DY-Demo"
  }
}

resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
  rule = aws_cloudwatch_event_rule.fed_validate.name
  arn = module.validation.this_lambda_function_arn
}