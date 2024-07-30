# minikube-via-terraform
Terraform을 기반으로 AWS EC2 기반의 Minikube 클러스터를 구축하고 관련 Tools을 설치하는 Terraform 코드입니다.

## 사용법

### 1. Terraform 초기화 및 실행
```bash
terraform init
terraform plan
terraform apply
```


## 2. SSH Key 생성
위 명령을 순차적으로 실행 후 다음과 같은 결과(output)을 확인하실 수 있습니다.

![img](https://raw.githubusercontent.com/hyungwook0221/img/main/uPic/vv6qOU.jpg)

결과로 나온 값 중에서 `-----BEGIN RSA PRIVATE KEY-----`로 시작하고 `-----END RSA PRIVATE KEY-----`로 끝나는 부분을 복사하여 파일로 생성합니다.

필자는 `minikube`라는 이름으로 파일을 생성 후 권한을 추가했습니다.
 
```bash
touch minikube
# 파일내용 기입 후 저장

chmod 400 minikube
```

## 3. EC2 인스턴스 SSH 접속
이제 저장된 결과값을 기반으로 EC2 인스턴스에 접속합니다.

```bash
ssh -i minikube ubuntu@<IP주소>
```

## 4. 접속 후 설치확인
접속 후 docker, kubectl 명령등이 정상적으로 동작하는지 확인합니다.

```bash
ubuntu@ip-10-0-0-196:~$ docker ps
CONTAINER ID   IMAGE                                 COMMAND                  CREATED        STATUS        PORTS                                                                                                                                  NAMES
65fc3cd2446d   gcr.io/k8s-minikube/kicbase:v0.0.44   "/usr/local/bin/entr…"   24 hours ago   Up 24 hours   127.0.0.1:32768->22/tcp, 127.0.0.1:32769->2376/tcp, 127.0.0.1:32770->5000/tcp, 127.0.0.1:32771->8443/tcp, 127.0.0.1:32772->32443/tcp   minikube

ubuntu@ip-10-0-0-196:~$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   23h   v1.30.0
ubuntu@ip-10-0-0-196:~$
```

> 📌 참고 :   
`main.tf` 코드에 들어있는 user_data는 Clodu Init으로 동작합니다. 이로인해 EC2 인스턴스가 생성된 후 접속하더라도 백그라운드에서 스크립트가 동작하고 있을 수 있습니다.   
생성된 직후 접속할 경우 Docker, Minikube 등이 구성되어 있지 않을 수 있습니다. 5분~10분정도 후 Shell을 새롭게 접속하여 실행할 경우 정상적으로 동작하는 것을 확인할 수 있습니다.