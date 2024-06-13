# Simplifying Serverless Architecture with Terraform and AWS Lambda

I will detail how to automate serverless architecture using Terraform as Infrastructure as Code (IaC), focusing on setting up an API Gateway and integrating it with AWS Lambda functions using TypeScript.
## TL;DR:
- **Project Setup**: Organize your project structure and initialize an npm project for managing dependencies.
- **Lambda Functions**: Develop two AWS Lambda functions in TypeScript to process API requests, using essential modules like `aws-lambda` and `base-64`.
- **Building and Deployment**: Utilize `esbuild` to compile and zip your Lambda function code, automating the process with a custom Bash script.
- **Terraform Configuration**: Configure Terraform for both AWS Lambda and API Gateway. This includes setting up IAM roles, CloudWatch logs, and deploying an API Gateway using an OpenAPI Specification template.
- **Source Code**: Access all the configurations and scripts on the [GitHub repository](https://github.com/etorralba/serverless-terraform-lambda).
### **Setting Up Your Lambda Functions**

To begin, ensure you have a well-organized directory and an initialized npm project:

1. **Create Your Directory Structure**: Maintaining an organized project structure is essential for efficiently managing your Lambda handlers and shared modules. Here’s a recommended setup:
```
   ├── scripts
   │   └── build.sh
   ├── lambda_handlers
   │   ├── function1.ts
   │   └── function2.ts
   ├── package-lock.json
   ├── package.json
   ├── Makefile
   ├── tsconfig.json
   └── src
       └── test_function.ts
```
2. **Initialize the npm Project**: Run `npm init` to initiate your npm project. This will create your project's package.json and prepare it for adding dependencies.

3. **Install Dependencies**: Install the required packages for your project:
```bash
   npm install base-64
   npm install --save-dev aws-lambda esbuild typescript @types/node ts-node @types/base-64 @types/aws-lambda
```

### **Lambda Function Handlers**
Next, let's explore two straightforward TypeScript Lambda functions designed to process requests:

```typescript
// lambda_handlers/function1.ts
import {
    APIGatewayProxyEventV2,
    APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import base64 from "base-64";
import { printValue } from "../src/test_function";

// Define the Lambda handler function
export const handler = async (
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyStructuredResultV2> => {
    const body = JSON.parse(base64.decode(event.body!));
    printValue(body);
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "This is function1",
        }),
    };
};
```

```typescript
// lambda_handlers/function2.ts
import {
    APIGatewayProxyEventV2,
    APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import base64 from "base-64";
import { printValue } from "../src/test_function";

export const handler = async (
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyStructuredResultV2> => {
    const body = JSON.parse(base64.decode(event.body!));
    printValue(body);
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "This is function2",
        }),
    };
};
```
```ts
// src/test_function.ts
// Function to log any value to the console
export const printValue = (value: any) => {
    console.log(value);
}
```

### **Building and Zipping Lambda Functions**

For deployment, use `esbuild` to compile and zip your TypeScript files:
```json
"scripts": {
    "build:function1": "esbuild lambda_handlers/function1.ts --bundle --outdir=dist --platform=node && cd ./dist && zip -r function1.zip function1.js",
    "build:function2": "esbuild lambda_handlers/function2.ts --bundle --outdir=dist --platform=node && cd ./dist && zip -r function2.zip function2.js"
},
```

A bash script can automate the building process for all functions, ensuring efficient and error-free builds:
```bash
#!/bin/bash

# Build script to automate the compilation and zipping of Lambda functions
npm install
mkdir -p dist

cd lambda_handlers

for file in *.ts; do
    npx esbuild $file --bundle --platform=node --outfile=../dist/${file%.*}.js
    cd ../dist
    zip -r ${file%.*}.zip ${file%.*}.js
    rm ${file%.*}.js
    cd ../lambda_handlers
done
```

`chmod +x scripts/build.sh`
### **Setting Up Terraform for Serverless**

Now, configure a basic Terraform setup to manage your infrastructure effectively:
```
├── terraform
    ├── templates
    │   └── openapi.tpl.yml
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    └── output.tf
```

Use the following configuration to define your provider and backend:
```hcl
# providers.tf
// Define the required providers and configure the AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"


      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}
```

Define the variables required for your infrastructure:
```hcl
# variables.tf
// Define variables for the AWS region and Lambda function filenames
variable "region" {
  description = "The region where the resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "file_names" {
  description = "The file names of the Lambda functions"
  type        = list(string)
}
```

Set up CloudWatch Log Groups, IAM Policies, and roles for each Lambda to ensure secure and compliant logging and execution permissions:
```hcl
# main.tf
// Define CloudWatch Log Groups
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

// Define the Lambda Functions in Terraform, specifying code, execution role, and settings
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
```

### **Setting Up Terraform for API Gateway**
Create the templates directory under the terraform folder.
```
├── terraform
    ├── templates
        └── openapi.tpl.yml
```
Then, create an OpenAPI Specification file template to define how your API Gateway interacts with the deployed Lambda functions:
```yaml
# openapi.tpl.yml
openapi: 3.0.0
info:
  title: API Gateway OpenAPI Example
  version: 1.0.0

paths:
%{ for lambda in lambdas ~}
  /api/${lambda.function_name}:
      post:
        operationId: Invoke-${lambda.function_name}
        x-amazon-apigateway-integration:
          uri: ${lambda.invoke_arn}
          responses:
            default:
              statusCode: "200"
          passthroughBehavior: "when_no_match"
          httpMethod: "POST"
          type: "aws_proxy"
        responses:
          '200':
            description: 200 response
%{ endfor ~}
```
Note: Keep in mind that the indentation in this file is crucial; incorrect indentation can lead to improper API Gateway creation.

Next step is to populate the OpenAPI template and pass it to the `aws_api_gateway_rest_api` resource.
```hcl
# main.tf
(...)
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

resource "

aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = "prod"
}
```

Create the outputs file to display the information you want at the end of the provisioning.
```hcl
# outputs.tf
output "api_gateway_rest_api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_main_resource_id" {
  description = "The ID of the API Gateway main resource"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}
```
## Create the terraform.tfvars and authenticate in aws cli
1. Create the `terraform.tfvars` like this:
```yml
region = "us-east-1"
file_names = [
  "function1",
  "function2"
]
```
2. Using the `aws cli`, authenticate with your access keys by running the command `aws configure`
## Apply the configuration
1. Run `make build` to build the TypeScript functions zips
2. Go to the terraform directory with `cd terraform`
3. Initialize the Terraform environment using `terraform init`
4. Make `terraform plan` to visualize the changes and resources the configuration will perform
5. Use `terraform apply` to apply the configuration and update the state.
6. When you finalize, you could destroy the resources by using the `terraform destroy` command

### Further Improvements: Enhancing the Project
After completing this tutorial, there are several ways to enhance the functionality, scalability, and maintainability of the serverless architecture. These improvements can serve as challenges for developers looking to expand their expertise and further optimize the project:

1. **Add More Lambda Functions**: Explore the creation of additional Lambda functions to handle different types of requests, such as GET requests for fetching data or DELETE requests for removing records. This will provide a more comprehensive API.
    
2. **Implement API Caching**: Configure caching mechanisms in the API Gateway to improve response times and reduce the load on Lambda functions. This is particularly useful for endpoints that do not require real-time data.
    
3. **Advanced Error Handling**: Improve error handling in the Lambda functions to manage different types of exceptions more effectively. Implementing more sophisticated error logging and notifications can also help in quick debugging.
    
4. **Environment Variables**: Use Terraform to manage environment variables for Lambda functions, which can include database connection strings, API keys, and other sensitive information that should not be hard-coded.
    
5. **Database Integration**: Integrate a database with the Lambda functions. This could involve setting up a DynamoDB table with Terraform and modifying the Lambda functions to read and write data to the database.
    
6. **Automated Alerts and Monitoring**: Enhance monitoring and alerts using AWS CloudWatch or a third-party service. Set up alerts for function errors, high execution times, and resource limits.
    
7. **Security Enhancements**: Implement stricter security practices, such as more restrictive IAM roles, VPC configurations, and API authentication mechanisms. Explore the use of AWS Cognito for user authentication.