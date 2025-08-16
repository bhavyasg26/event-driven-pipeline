output "events_bucket_name" {
  value = aws_s3_bucket.events_bucket.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.events.name
}

output "lambda_collect_arn" {
  value = aws_lambda_function.collect.arn
}

output "lambda_parse_arn" {
  value = aws_lambda_function.parse.arn
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.user_activity.arn
}

output "sfn_state_machine_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}

output "sfn_logs_log_group" {
  value = aws_cloudwatch_log_group.sfn_logs.name
}


