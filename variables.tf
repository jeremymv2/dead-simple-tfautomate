variable "aws_region" {
  default = "us-west-2"
}

variable "aws_profile" {
  default = "default"
}

variable "aws_key_pair_name" {
  default = "jmiller"
}

variable "aws_key_pair_file" {
  default = "~/.ssh/jmiller"
}

variable "automate_subnet" {
 default = "subnet-608eee3b"
}

# This SG needs to allow 22,80,443,8890
variable "automate_security_group" {
 default = "sg-0ba98f71"
}

data "aws_ami" "centos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["chef-highperf-centos7-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["446539779517"]
}

variable "tag_dept" {
  default = "success"
}

variable "tag_contact" {
  default = "jmiller@chef.io"
}

variable "tag_names" {
  default = ["runner", "chef-server", "automate"]
}

variable "aws_instance_types" {
  default = ["t2.medium", "m4.xlarge", "m4.xlarge"]
}

variable "aws_ami_user" {
  default = "centos"
}
