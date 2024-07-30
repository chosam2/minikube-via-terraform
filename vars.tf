variable "region" {
  default = "ap-northeast-2"
}

variable "availability_zones" {
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "instance_count" {
  default = 1
}

variable "ami_id" {
  default = "ami-095264d8e1cde7af3" # Ubuntu 22.04 LTS
}

variable "instance_type" {
  default = "t2.xlarge"  
}
