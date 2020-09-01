provider "aws" {
  region    = "ap-south-1"
  profile = "default"
}

resource "aws_key_pair" "taskkey" {
  key_name   = "taskkey"
  public_key = file("taskkey.pub")
}

resource "aws_vpc" "newvpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames=true


  tags = {
    Name = "myvpc"
  
 }
}

resource "aws_subnet" "vpc_private" {
     depends_on =[
      aws_vpc.newvpc
     ]
    vpc_id = aws_vpc.newvpc.id



    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = false


    tags = {
        Name = "my_Private_Subnet"
    }
}

resource "aws_subnet" "vpc_public" {
depends_on =[
      aws_subnet.vpc_private
     ]
    
    vpc_id = aws_vpc.newvpc.id



    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
    
    tags = {
        Name = "my_Public_Subnet"
    }


}
resource "aws_internet_gateway" "new_gateway" {
  depends_on =[
      aws_subnet.vpc_private
     ]
  vpc_id = aws_vpc.newvpc.id



  tags = {
    Name = "newvpc_gateway"
  }


}



resource "aws_route_table" "my_routetable" {
    depends_on =[
      aws_internet_gateway.new_gateway
     ]
  vpc_id = aws_vpc.newvpc.id



  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.new_gateway.id
  }



  tags = {
    Name = "my_RoutingTable"
  }


}

resource "aws_route_table_association" "route_table" {
  subnet_id      = aws_subnet.vpc_public.id
  route_table_id = aws_route_table.my_routetable.id
}

//nat gateway

resource "aws_eip" "eip-lb" {
  vpc      = true
  depends_on = [ aws_vpc.newvpc, ]
}


resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.eip-lb.id}"
  subnet_id      = "${aws_subnet.vpc_private.id}"
  

  tags = {
    Name = "NAT-gateway"
  }
  depends_on = [ aws_vpc.newvpc, aws_eip.eip-lb ]
}

//route table for nat gateway

resource "aws_route_table" "route_table_nat_gateway" {
  vpc_id = "${aws_vpc.newvpc.id}"
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }
  tags = {
    Name = "route_table"
  }
  depends_on = [ aws_nat_gateway.nat_gateway, ]
}


resource "aws_route_table_association" "association_routing_table_nat_gateway" {
  subnet_id      = aws_subnet.vpc_private.id
  route_table_id = aws_route_table.route_table_nat_gateway.id
  depends_on = [ aws_route_table.route_table_nat_gateway, ]


}


resource "aws_security_group" "wp_sg" {
depends_on =[
      aws_subnet.vpc_public
     ]



 name = " Public_SG"
 description = "Security Group for Wordpress"
 vpc_id = aws_vpc.newvpc.id
 
 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
 tags ={
   Name ="public_security_group"
 }
}

resource "aws_security_group" "mysql_sg" {
  
depends_on =[
      aws_subnet.vpc_private
     ]



 name = " Private_SG"
 description = "Security Group for MySQL"
 vpc_id = aws_vpc.newvpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
 tags ={
   Name ="private_security_group"
}
}

resource "aws_instance" "mysql" {
depends_on =[
      aws_security_group.mysql_sg
     ]
 ami     =  "ami-08706cb5f68222d09"
 instance_type = "t2.micro"
  key_name = aws_key_pair.taskkey.key_name
 vpc_security_group_ids = [ aws_security_group.mysql_sg.id]
 subnet_id      = aws_subnet.vpc_private.id
 tags = {
  Name = "Mysql"
 }
}

resource "aws_instance" "wp" {
depends_on =[
      aws_instance.mysql
     ]
 ami     =  "ami-049cbce295a54b26b"
 instance_type = "t2.micro"
  key_name = aws_key_pair.taskkey.key_name
 vpc_security_group_ids = [ aws_security_group.wp_sg.id]
 subnet_id      = aws_subnet.vpc_public.id



 tags = {
  Name = "wordpress"
 }


}
