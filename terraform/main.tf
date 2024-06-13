// CloudWatch Log Groups for each Lambda
resource "aws_cloudwatch_log_group" "loggroup" {
  for_each = toset(var.file_names)

  name              = "/aws/lambda/${each.key}"
  retention_in_days = 14
}

// IAM Policies for each Lambda to write to their respective Log Group
resource "aws_iam_policy" "logs_role_policy" {
  for_each = toset(var.file_names)

  name   = "${each.key}-logs"
  policy = data.aws_iam_policy_document.logs_role_policy[each.key].json
}

data "aws_iam_policy_document" "logs_role_policy" {
  for_each = toset(var.file_names)

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_group.loggroup[each.key].arn
    ]
  }
}

// IAM Role for each Lambda Function
resource "aws_iam_role" "main" {
  for_each = toset(var.file_names)

  name               = "iam-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

// Attach Logging Policies to each IAM Role
resource "aws_iam_role_policy_attachment" "logging_attachment" {
  for_each = toset(var.file_names)

  role       = aws_iam_role.main[each.key].id
  policy_arn = aws_iam_policy.logs_role_policy[each.key].arn
}

// Lambda Functions
resource "aws_lambda_function" "handler" {
  for_each = toset(var.file_names)

  filename         = "../dist/${each.key}.zip"
  source_code_hash = filebase64sha256("../dist/${each.key}.zip")
  function_name    = each.key
  role             = aws_iam_role.main[each.key].arn
  handler          = "index.handler"

  timeout = 20
  runtime = "nodejs20.x"
}

// API Gateway
locals {
  openapi_template = templatefile("${path.module}/templates/openapi.tpl.yml", {
    lambdas = aws_lambda_function.handler
    region  = var.region
  })
}

resource "aws_api_gateway_rest_api" "main" {
  name               = "rest-api"
  description        = "REST API for Lambda functions"
  binary_media_types = ["*/*"]

  body = local.openapi_template
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = "prod"
}


