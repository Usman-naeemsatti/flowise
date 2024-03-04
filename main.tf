#EC2
resource "aws_instance" "flowise" {
  ami                         = "ami-0440d3b780d96b29d"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.mykey.key_name
  subnet_id                   = aws_subnet.public1.id
  security_groups             = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file("~/.ssh/id_rsa")
  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum install docker -y",
      "sudo systemctl start docker.service",
      "sudo systemctl enable docker.service",
      "sudo yum install git -y",
      "sudo git clone https://github.com/FlowiseAI/Flowise.git",
      "sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "sudo cp /home/ec2-user/Flowise/docker/.env.example /home/ec2-user/Flowise/docker/.env",
      "sudo docker-compose -f /home/ec2-user/Flowise/docker/docker-compose.yml up -d"
    ]
  }  

  depends_on = [
    aws_db_instance.flowise
  ]

}

resource "aws_db_instance" "flowise" {
  allocated_storage    = 5
  storage_type         = "gp2"
  instance_class       = "db.t2.micro"
  identifier           = "flowise"
  engine               = "postgres"
  engine_version       = "12.15"

  db_name  = "flowise"
  username = "user123"
  password = "user12345"

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  skip_final_snapshot    = true

  tags = {
    Name = "RDS Instance"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
}

# RDS security group
resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"]
  }


  tags = {
    Name = "RDS Security Group"
  }
}

resource "aws_key_pair" "mykey" {
  key_name   =  "mykey"
  public_key =  file("~/.ssh/id_rsa.pub") 
}

output "db_endpoint" {
  value = aws_db_instance.flowise.endpoint
}
