# 1. Cria a Rede Privada Virtual (VPC) principal do produto
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# 2. Internet Gateway (A porta de saída da VPC para a internet)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# 3. Sub-redes Públicas (Zonas A e B para Alta Disponibilidade)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-subnet-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-subnet-public-b"
  }
}

# 4. Tabela de Roteamento (Ensina o tráfego da rede a encontrar a internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                 # Qualquer destino de internet...
    gateway_id = aws_internet_gateway.igw.id # ...deve sair pelo Internet Gateway
  }

  tags = {
    Name = "${local.prefix}-rt-public"
  }
}

# 5. Associa as Sub-redes à Tabela de Roteamento
resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}