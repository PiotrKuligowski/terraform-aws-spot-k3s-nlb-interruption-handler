resource "random_uuid" "hash" {}

locals {
  hash = substr(random_uuid.hash.result, 0, 8)
}

resource "null_resource" "build_lambda" {
  triggers = {
    handler      = base64sha256(file("${path.module}/handler.py"))
    requirements = base64sha256(file("${path.module}/requirements.txt"))
    build        = base64sha256(file("${path.module}/build.sh"))
  }
  provisioner "local-exec" {
    command = "${path.module}/build.sh"
  }
}

data "archive_file" "lambda_zip" {
  depends_on  = [null_resource.build_lambda]
  source_dir  = "${path.module}/package/"
  output_path = "${path.module}/${var.function_name}.zip"
  type        = "zip"
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  runtime          = var.runtime
  handler          = var.handler
  timeout          = var.timeout
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.this.arn
  tags             = var.tags
  environment {
    variables = var.environment_vars
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = join("-", [var.project, var.component, local.hash])
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "policy_statements" {
  count = length(var.policy_statements) > 0 ? 1 : 0
  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "this" {
  count  = length(var.policy_statements) > 0 ? 1 : 0
  name   = join("-", [var.project, var.component, local.hash])
  policy = data.aws_iam_policy_document.policy_statements[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = length(var.policy_statements) > 0 ? 1 : 0
  policy_arn = aws_iam_policy.this[0].arn
  role       = aws_iam_role.this.name
}

resource "aws_cloudwatch_event_rule" "spot" {
  name          = "${var.project}-${var.component}"
  event_pattern = var.eventbridge_trigger
  tags          = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.spot.name
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "this" {
  count         = var.eventbridge_trigger == "" ? 0 : 1
  statement_id  = "AllowCloudwatchEventRuleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spot.arn
}