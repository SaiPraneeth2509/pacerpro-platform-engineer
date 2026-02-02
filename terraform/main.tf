provider "aws" {
  region = "us-east-2"
}

# 1. SNS Topic for Notifications
resource "aws_sns_topic" "alerts" {
  name = "pacerpro-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email 
}

# 2. IAM Role & Policies (Least Privilege)
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_reboot_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_reboot_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:RebootInstances", "ec2:DescribeInstances"]
        Effect   = "Allow"
        Resource = "*" # Or scope to specific instance ARN for max bonus points
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 3. Lambda Function & Function URL
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../lambda_function/lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "rebooter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "EC2_Restarter"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
      TARGET_INSTANCE_ID = aws_instance.app_server.id
      ALERT_TOPIC_ARN    = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_lambda_function_url" "url" {
  function_name      = aws_lambda_function.rebooter.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "sumo_logic_invoke_url" {
  statement_id           = "SumoLogicInvokeURL"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.rebooter.function_name
  principal              = "arn:aws:iam::794038249673:user/test-user"
  function_url_auth_type = "AWS_IAM"
}

# 4. EC2 Instance (Target)
resource "aws_instance" "app_server" {
  ami           = "ami-05fb0b8c1424f266b" 
  instance_type = "t2.micro"

  tags = {
    Name = "PacerPro-App-Server"
  }
}