# Configure AWS provider
provider "aws" {
  region = var.region
}

# Create a new VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create a new key pair

resource "tls_private_key" "minikube" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minikube" {
  key_name   = "minikube"
  public_key = tls_private_key.minikube.public_key_openssh
}

# Create EC2 instances
resource "aws_instance" "main" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.minikube.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = element(aws_subnet.public.*.id, count.index)

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  # user_data는 Cloud Init으로 백그라운드에서 동작하므로 EC2 생성 후 접속하더라도 스크립트가 완성되지 않았을 수 있습니다.
  # EC2 생성 후 약 5분정도 이후에 kubectl 명령으로 리소스 Minikube 생성여부를 확인해보세요.
  user_data = <<-EOF
  #!/bin/bash

  # Docker 설치
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh

  # 일반 사용자가 Docker 명령을 사용할 수 있도록 설정
  sudo usermod -aG docker ubuntu

  # 그룹 변경 사항 적용
  newgrp docker

  # Wait for the volumes to be attached
  while [ ! -e /dev/xvdb ]; do sleep 1; done
  while [ ! -e /dev/xvdc ]; do sleep 1; done
  
  # Format the volumes as ext4 if they are not already formatted
  if ! blkid /dev/xvdb | grep -q ext4; then
    mkfs.ext4 /dev/xvdb
  fi
  if ! blkid /dev/xvdc | grep -q ext4; then
    mkfs.ext4 /dev/xvdc
  fi
  
  # Mount the volumes
  mkdir -p /data
  
  # /etc/fstab 등록
  echo "/dev/xvdb /data ext4 defaults,nofail 0 2" >> /etc/fstab
  echo "/dev/xvdc /var/lib/docker ext4 defaults,nofail 0 2" >> /etc/fstab

  # Mount & Docker 실행
  systemctl stop docker
  systemctl daemon-reload
  mount -a
  systemctl start docker

  # kubectl 설치
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

  # Minikube 설치
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
  sudo dpkg -i minikube_latest_amd64.deb

  # Minikube 설정
  sudo -u ubuntu -i << 'EOT'
  nohup minikube start --driver=docker > /dev/null 2>&1 &
  # nohup minikube start --driver=none > /dev/null 2>&1 &
  while ! minikube status > /dev/null 2>&1; do
    sleep 30
    echo "Waiting for Minikube to start..."
  done
  minikube config set driver docker
  EOT

  # kubectl alias 및 자동완성 설정
  echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
  echo 'alias k=kubectl' >>/home/ubuntu/.bashrc
  echo 'complete -o default -F __start_kubectl k' >>/home/ubuntu/.bashrc

  # Install krew
  curl -LO https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz
  tar zxvf krew-linux_amd64.tar.gz
  ./krew-linux_amd64 install krew
  export PATH="$PATH:/root/.krew/bin"
  echo 'export PATH="$PATH:/root/.krew/bin"' >> /etc/profile

  # Install krew plugin
  kubectl krew install ctx ns get-all  # ktop df-pv mtail tree

  # K9s 설치
  curl -LO https://webinstall.dev/k9s
  bash k9s
  
  # Helm Install
  curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

  # iptables rule 추가
  sudo apt-get install netfilter-persistent -y
  sudo systemctl enable netfilter-persistent --now
  sudo iptables -t nat -A PREROUTING -p tcp --dport 30000:32767 -j DNAT --to-destination 192.168.49.2:30000-32767
  sudo iptables -t nat -A POSTROUTING -p tcp --dport 30000:32767 -j MASQUERADE
  sudo iptables -I DOCKER -p tcp -d 192.168.49.2 --dport 30000:32767 -j ACCEPT
  sudo netfilter-persistent save

  EOF

  tags = {
    Name = "minikube-${count.index + 1}"
  }
}

# Volume 별도추가
resource "aws_ebs_volume" "additional_volume" {
  count             = var.instance_count * 2
  availability_zone = element(var.availability_zones, floor(count.index / 2))
  size              = 50
  type              = "gp3"

  tags = {
    Name = "minikube-additional-volume-${floor(count.index / 2) + 1}-${count.index % 2 + 1}"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  count       = var.instance_count * 2
  device_name = "/dev/xvd${count.index == 0 ? "b" : "c"}"
  volume_id   = aws_ebs_volume.additional_volume[count.index].id
  instance_id = aws_instance.main[floor(count.index / 2)].id

  force_detach = true
}

# resource "aws_volume_attachment" "ebs_att_1" {
#   count       = var.instance_count
#   device_name = "/dev/xvdb"
#   volume_id   = aws_ebs_volume.additional_volume_1[count.index].id
#   instance_id = aws_instance.main[count.index].id
# }

# resource "aws_volume_attachment" "ebs_att_2" {
#   count       = var.instance_count
#   device_name = "/dev/xvdc"
#   volume_id   = aws_ebs_volume.additional_volume_2[count.index].id
#   instance_id = aws_instance.main[count.index].id
# }

# Create public subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${element(var.availability_zones, count.index)}"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Associate the route table with the public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Create a security group
resource "aws_security_group" "main" {
  name_prefix = "minikube-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
