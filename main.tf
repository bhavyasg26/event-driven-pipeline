#############################################
# Data helpers
#############################################
data "aws_caller_identity" "current" {}

#############################################
# S3 bucket for event data (raw)
#############################################
resource "aws_s3_bucket" "events_bucket" {
  bucket        = "user-activity-events-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

#############################################
# DynamoDB table to store parsed events
#############################################
resource "aws_dynamodb_table" "events" {
  name         = "user-activity-events"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "user_id"   # partition key
  range_key = "event_ts"  # sort key

  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "event_ts"
    type = "S"
  }
}

#############################################
# IAM role for both Lambdas
#############################################
resource "aws_iam_role" "lambda_exec_role" {
  name = "user-activity-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# One inline policy with everything Lambdas need:
# - CloudWatch Logs
# - S3 read (parse) + write (collect)
# - DynamoDB PutItem (parse)
resource "aws_iam_role_policy" "lambda_exec_perms_v2" {
  name = "lambda-exec-perms-v2"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "LogsWrite",
        Effect : "Allow",
        Action : ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        Resource : "*"
      },
      {
        Sid    : "S3ReadEvents",
        Effect : "Allow",
        Action : ["s3:GetObject","s3:GetObjectVersion"],
        Resource : "arn:aws:s3:::${aws_s3_bucket.events_bucket.bucket}/*"
      },
      {
        Sid    : "S3ListEvents",
        Effect : "Allow",
        Action : ["s3:ListBucket"],
        Resource : "arn:aws:s3:::${aws_s3_bucket.events_bucket.bucket}"
      },
      {
        Sid    : "S3WriteEvents",
        Effect : "Allow",
        Action : ["s3:PutObject","s3:PutObjectAcl"],
        Resource : "arn:aws:s3:::${aws_s3_bucket.events_bucket.bucket}/*"
      },
      {
        Sid    : "DdbPut",
        Effect : "Allow",
        Action : ["dynamodb:PutItem"],
        Resource : aws_dynamodb_table.events.arn
      }
    ]
  })
}

#############################################
# Lambda: collect → writes raw JSON to S3
#   ZIP file must contain app.py with lambda_handler(event, context)
#############################################
resource "aws_lambda_function" "collect" {
  function_name    = "user-activity-collect-to-s3"
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = "${path.module}/collect_to_s3.zip"
  source_code_hash = filebase64sha256("${path.module}/collect_to_s3.zip")

  handler = "app.lambda_handler"
  runtime = "python3.11"
  timeout = 30

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.events_bucket.bucket
    }
  }
}

#############################################
# Lambda: parse → reads from S3, validates, writes to DynamoDB
#   ZIP file must contain app.py with handler(event, context)
#############################################
resource "aws_lambda_function" "parse" {
  function_name    = "user-activity-parse-validate"
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = "${path.module}/parse_validate.zip"
  source_code_hash = filebase64sha256("${path.module}/parse_validate.zip")

  handler = "app.handler"
  runtime = "python3.11"
  timeout = 30

  environment {
    variables = {
      EVENTS_TABLE = aws_dynamodb_table.events.name
    }
  }
}

#############################################
# Step Functions logging (CloudWatch Logs)
#############################################
resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/user-activity-logs"
  retention_in_days = 14
}

#############################################
# Step Functions: Orchestrate Collect -> Parse
#############################################
resource "aws_iam_role" "sfn_role" {
  name = "user-activity-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "states.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Allow SFN to invoke both Lambdas
resource "aws_iam_role_policy" "sfn_invoke_lambdas" {
  name = "sfn-invoke-lambdas"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : ["lambda:InvokeFunction"],
        Resource : [
          aws_lambda_function.collect.arn,
          aws_lambda_function.parse.arn
        ]
      }
    ]
  })
}

# State machine: pass s3_bucket/s3_key from Collect to Parse
resource "aws_sfn_state_machine" "pipeline" {
  name     = "user-activity-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    # NOTE: The ":*" suffix is REQUIRED by the SFN API
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
  }

  definition = jsonencode({
    Comment = "User activity processing pipeline",
    StartAt = "CollectData",
    States  = {
      CollectData = {
        Type       = "Task",
        Resource   = aws_lambda_function.collect.arn,
        ResultPath = "$.collect",
        Next       = "ParseAndValidate"
      },
      ParseAndValidate = {
        Type       = "Task",
        Resource   = aws_lambda_function.parse.arn,
        Parameters = {
          "s3_bucket.$" : "$.collect.s3_bucket",
          "s3_key.$"    : "$.collect.s3_key"
        },
        End = true
      }
    }
  })
}

#############################################
# EventBridge: run Collect on a schedule (every 5 minutes)
#############################################
resource "aws_cloudwatch_event_rule" "user_activity" {
  name                = "user-activity-events"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "user_activity_to_collect" {
  rule      = aws_cloudwatch_event_rule.user_activity.name
  target_id = "collect-lambda"
  arn       = aws_lambda_function.collect.arn
}

# Allow EventBridge to invoke the Collect Lambda
resource "aws_lambda_permission" "allow_events_to_invoke_collect" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collect.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.user_activity.arn
}

