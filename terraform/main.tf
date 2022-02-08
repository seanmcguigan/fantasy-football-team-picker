module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "cache-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "allow_memcached" {
  name        = "allow_memcached"
  description = "Allow memcached inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "Mem from anywhere"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_mamcached"
  }
}


resource "aws_elasticache_subnet_group" "memcached-subnets" {
  name       = "memcached-subnets"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_cluster" "this" {
  cluster_id         = "cluster-ffl"
  engine             = "memcached"
  subnet_group_name  = aws_elasticache_subnet_group.memcached-subnets.name
  node_type          = "cache.t2.micro"
  num_cache_nodes    = 1
  port               = 11211
  security_group_ids = [aws_security_group.allow_memcached.id]
}

resource "aws_ssm_parameter" "cache_endpoint" {
  name  = "cache_endpoint"
  type  = "String"
  value = aws_elasticache_cluster.this.cluster_address
}

resource "aws_ssm_parameter" "cache_port" {
  name  = "cache_port"
  type  = "String"
  value = 11211
}

resource "aws_ssm_parameter" "pymemcache_layer" {
  name  = "pymemcache_layer"
  type  = "String"
  value = aws_lambda_layer_version.pymemcache_layer.arn
}

resource "aws_ssm_parameter" "lambda_security_group" {
  name  = "lambda_security_group"
  type  = "String"
  value = aws_security_group.allow_memcached.id
}

# resource "aws_ssm_parameter" "lambda_subnets" {
#   count = length(module.vpc.private_subnets)
#   name  = "subnet_${count.index}"
#   type  = "String"
#   value = module.vpc.private_subnets[count.index]
# }

resource "aws_ssm_parameter" "lambda_subnets" {
  name  = "private_subnets"
  type  = "StringList"
  #value = module.vpc.private_subnets
  value = join(",", module.vpc.private_subnets)
}

resource "aws_lambda_layer_version" "pymemcache_layer" {
  filename   = "memcache_python.zip"
  layer_name = "pymemcache"
  compatible_runtimes = ["python3.8"]
}