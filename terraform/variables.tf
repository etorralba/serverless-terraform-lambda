variable "region" {
  description = "The region where the resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "file_names" {
  description = "The file names of the Lambda function"
  type        = list(string)
}
