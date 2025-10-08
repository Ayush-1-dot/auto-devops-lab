variable "aws_region" {
	description = "AWS region to create resources in"
	type        = string
	default     = "us-east-1"
}

variable "instance_type" {
	description = "EC2 instance type for sandbox"
	type        = string
	default     = "t3.medium"
}

variable "ssh_allow_cidr" {
	description = "CIDR block allowed to SSH to the sandbox"
	type        = string
	default     = "0.0.0.0/0"
}

variable "git_repo" {
	description = "Git repo URL containing this project (used by userdata to clone)"
	type        = string
	default     = ""
}

variable "key_name" {
	description = "Optional existing EC2 Key Pair name for SSH"
	type        = string
	default     = ""
}

variable "enable_ai_assistant" {
	description = "Whether to enable the optional AI assistant that can explain resources (requires OpenAI key)"
	type        = bool
	default     = false
}

variable "openai_api_key" {
	description = "OpenAI API key for optional assistant (leave empty to disable)"
	type        = string
	default     = ""
}
