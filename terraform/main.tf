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
  tags = {
    Name = "allow_memcached"
  }
}

resource "aws_security_group_rule" "memcached_in" {
  type                     = "ingress"
  from_port                = 11211
  to_port                  = 11211
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.allow_lambdas.id
  security_group_id        = aws_security_group.allow_memcached.id
}

resource "aws_security_group" "allow_lambdas" {
  name        = "allow_lambda"
  description = "Allow lambda egress traffic to Memcached"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "allow_lambdas"
  }
}

resource "aws_security_group_rule" "lambdas_out_memcached" {
  type                     = "egress"
  from_port                = 11211
  to_port                  = 11211
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.allow_memcached.id
  security_group_id        = aws_security_group.allow_lambdas.id
}

resource "aws_security_group_rule" "lambdas_out_fastly" {
  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  # Fastly CIDRS
  cidr_blocks       = ["23.235.32.0/20", "43.249.72.0/22", "103.244.50.0/24", "103.245.222.0/23", "103.245.224.0/24", "104.156.80.0/20", "140.248.64.0/18", "140.248.128.0/17", "146.75.0.0/17", "151.101.0.0/16", "157.52.64.0/18", "167.82.0.0/17", "167.82.128.0/20", "167.82.160.0/20", "167.82.224.0/20", "172.111.64.0/18", "185.31.16.0/22", "199.27.72.0/21", "199.232.0.0/16"]
  security_group_id = aws_security_group.allow_lambdas.id
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

resource "aws_ssm_parameter" "lambdas_security_group" {
  name  = "lambdas_security_group"
  type  = "String"
  value = aws_security_group.allow_lambdas.id
}

resource "aws_ssm_parameter" "lambda_subnets" {
  name = "private_subnets"
  type = "StringList"
  #value = module.vpc.private_subnets
  value = join(",", module.vpc.private_subnets)
}

resource "aws_lambda_layer_version" "pymemcache_layer" {
  filename            = "memcache_python.zip"
  layer_name          = "pymemcache"
  compatible_runtimes = ["python3.8"]
}