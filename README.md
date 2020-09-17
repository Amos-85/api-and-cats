## Api's & cats 

**NOTE**: Please take care to define private subnet connected to nat-gateway for lambda's to function properly
```
tfvars example:

region = "us-east-2"
allowed_cidr = ["172.16.0.0/8"]
lambda_subnet_ids = ["subnet-0afaed6211043bf25"]
redis_vpc_subnet_ids = ["subnet-cc6486a7","subnet-556f44ef", "subnet-59ea791a"]
vpc_id = "vpc-562be14d"
vpc_security_group_ids = ["sg-3da0b30b"]
email = "test@example.com"
```