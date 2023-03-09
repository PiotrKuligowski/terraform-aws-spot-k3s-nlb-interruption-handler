variable "component" {
  description = "Component name, will be used to generate names for created resources"
  type        = string
}

variable "project" {
  description = "Project name, will be used to generate names for created resources"
  type        = string
}

variable "tags" {
  description = "Tags to attach to resources"
  type        = any
  default     = {}
}

variable "function_name" {
  description = "Name of lambda function"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Lambda timeout"
  type        = number
  default     = 180
}

variable "handler" {
  description = "Lambda handler, name of the file and function"
  type        = string
  default     = "handler.lambda_handler"
}

variable "environment_vars" {
  description = "Environment variables for lambda function"
  type        = any
  default     = {}
}

variable "policy_statements" {
  description = "Policy statements to attach to IAM role used by EC2 Instances"
  type        = any
  default     = {}
}

variable "eventbridge_trigger" {
  description = "Lambda will be triggered by provided EventBridge event"
  type        = string
  default     = ""
}