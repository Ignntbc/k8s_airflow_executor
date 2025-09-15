# Офлайн установка Kubernetes кластера

Руководство по подготовке и установке Kubernetes компонентов на серверах без доступа в интернет.

## 📁 Структура папок для скачивания

Создайте следующую структуру папок на машине с интернетом:

```
k8s-offline-install/
├── docker/
│   ├── docker-packages/
│   └── docker-images/
├── kubernetes/
│   ├── binaries/
│   ├── packages/
│   └── images/
├── network/
│   ├── flannel/
│   └── calico/
└── scripts/
    ├── install-docker.sh
    ├── install-k8s.sh
    └── setup-cluster.sh
```

## 🐳 1. Подготовка Docker

### Создание папок и скачивание пакетов Docker

```bash
# Создание структуры папок
mkdir -p k8s-offline-install/{docker/{docker-packages,docker-images},kubernetes/{binaries,packages,images},network/{flannel,calico},scripts}
cd k8s-offline-install

# Для Ubuntu/Debian
mkdir -p docker/docker-packages/ubuntu
cd docker/docker-packages/ubuntu

# Скачивание Docker пакетов для Ubuntu 20.04/22.04
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.6.24-1_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_24.0.7-1~ubuntu.20.04~focal_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_24.0.7-1~ubuntu.20.04~focal_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-buildx-plugin_0.11.2-1~ubuntu.20.04~focal_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-compose-plugin_2.21.0-1~ubuntu.20.04~focal_amd64.deb

# Для CentOS/RHEL
cd ../../../
mkdir -p docker/docker-packages/centos
cd docker/docker-packages/centos

# Скачивание Docker для CentOS 7/8
wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/containerd.io-1.6.24-3.1.el8.x86_64.rpm
wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-ce-cli-24.0.7-1.el8.x86_64.rpm
wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-ce-24.0.7-1.el8.x86_64.rpm
wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-buildx-plugin-0.11.2-1.el8.x86_64.rpm
wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-compose-plugin-2.21.0-1.el8.x86_64.rpm
```

## ☸️ 2. Подготовка Kubernetes

### Скачивание бинарных файлов Kubernetes

```bash
cd ../../../kubernetes/binaries

# Версия Kubernetes
K8S_VERSION="v1.21.0"

# Скачивание бинарных файлов
wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl
wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm
wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet

# Скачивание crictl
CRICTL_VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

# Делаем файлы исполняемыми
chmod +x kubectl kubeadm kubelet
```

### Скачивание пакетов Kubernetes

```bash
cd ../packages

# Для Ubuntu/Debian
mkdir ubuntu
cd ubuntu

# Добавляем GPG ключ Kubernetes (сохраняем в файл)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key > kubernetes-key.gpg

# Скачиваем deb пакеты
K8S_VERSION="1.28.0-1.1"
wget https://pkgs.k8s.io/core:/stable:/v1.28/deb/kubelet_${K8S_VERSION}_amd64.deb
wget https://pkgs.k8s.io/core:/stable:/v1.28/deb/kubeadm_${K8S_VERSION}_amd64.deb  
wget https://pkgs.k8s.io/core:/stable:/v1.28/deb/kubectl_${K8S_VERSION}_amd64.deb

# Для CentOS/RHEL
cd ..
mkdir centos
cd centos

# Скачиваем RPM пакеты
K8S_VERSION="1.28.0-150500.1.1"
wget https://pkgs.k8s.io/core:/stable:/v1.28/rpm/kubelet-${K8S_VERSION}.x86_64.rpm
wget https://pkgs.k8s.io/core:/stable:/v1.28/rpm/kubeadm-${K8S_VERSION}.x86_64.rpm
wget https://pkgs.k8s.io/core:/stable:/v1.28/rpm/kubectl-${K8S_VERSION}.x86_64.rpm
```

## 🖼️ 3. Подготовка Docker образов

### Скачивание образов Kubernetes

```bash
cd ../../../kubernetes/images

# Список необходимых образов для Kubernetes 1.28
cat > k8s-images-list.txt << EOF
registry.k8s.io/kube-apiserver:v1.28.0
registry.k8s.io/kube-controller-manager:v1.28.0
registry.k8s.io/kube-scheduler:v1.28.0
registry.k8s.io/kube-proxy:v1.28.0
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.9-0
registry.k8s.io/coredns/coredns:v1.10.1
EOF

# Скачиваем и сохраняем образы
while read image; do
    echo "Скачиваем образ: $image"
    docker pull $image
    image_name=$(echo $image | sed 's/[\/:]/-/g')
    docker save $image > ${image_name}.tar
done < k8s-images-list.txt

# Образы для Airflow
cat > airflow-images-list.txt << EOF
apache/airflow:2.10.2-python3.9
postgres:15
grafana/grafana:10.0.0
prom/prometheus:v2.45.0
prom/node-exporter:v1.6.0
registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
quay.io/external_storage/nfs-client-provisioner:latest
bitnami/kubectl:latest
curlimages/curl:latest
busybox:latest
EOF

# Скачиваем образы Airflow
while read image; do
    echo "Скачиваем образ: $image"
    if docker pull $image; then
        image_name=$(echo $image | sed 's/[\/:]/-/g')
        docker save $image > ${image_name}.tar
        echo "✅ Образ $image успешно сохранен"
    else
        echo "❌ Ошибка скачивания образа: $image"
        echo "Попробуйте найти альтернативный образ или пропустите этот"
    fi
done < airflow-images-list.txt

# Дополнительные образы для NFS (если основные не работают)
echo "Скачивание дополнительных NFS образов..."
NFS_ALTERNATIVES=(
    "itsthenetwork/nfs-server-alpine:latest"
    "k8s.gcr.io/volume-nfs:0.8"
    "gcr.io/google_containers/volume-nfs:0.8"
)

for nfs_image in "${NFS_ALTERNATIVES[@]}"; do
    echo "Пробуем скачать: $nfs_image"
    if docker pull $nfs_image 2>/dev/null; then
        image_name=$(echo $nfs_image | sed 's/[\/:]/-/g')
        docker save $nfs_image > ${image_name}.tar
        echo "✅ NFS образ $nfs_image успешно сохранен"
        break
    else
        echo "⚠️ Образ $nfs_image недоступен, пробуем следующий..."
    fi
done
```

## 🌐 4. Подготовка сетевых компонентов

### Flannel CNI

```bash
cd ../../network/flannel

# Скачиваем манифесты Flannel
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Скачиваем образ Flannel
docker pull quay.io/coreos/flannel:v0.22.0
docker save quay.io/coreos/flannel:v0.22.0 > flannel-v0.22.0.tar
```

### Calico CNI (альтернатива)

```bash
cd ../calico

# Скачиваем манифесты Calico
wget https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/custom-resources.yaml

# Скачиваем образы Calico
cat > calico-images-list.txt << EOF
quay.io/tigera/operator:v1.30.0
docker.io/calico/cni:v3.26.0
docker.io/calico/node:v3.26.0
docker.io/calico/kube-controllers:v3.26.0
EOF

while read image; do
    echo "Скачиваем образ: $image"
    docker pull $image
    image_name=$(echo $image | sed 's/[\/:]/-/g')
    docker save $image > ${image_name}.tar
done < calico-images-list.txt
```

## 📝 5. Создание установочных скриптов

### Скрипт установки Docker

```bash
cd ../../scripts

cat > install-docker.sh << 'EOF'
#!/bin/bash

echo "=== Установка Docker (офлайн) ==="

# Определяем ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
fi

case $OS in
    "ubuntu"|"debian")
        echo "Установка Docker на Ubuntu/Debian..."
        cd ../docker/docker-packages/ubuntu
        sudo dpkg -i *.deb
        ;;
    "centos"|"rhel"|"rocky"|"almalinux")
        echo "Установка Docker на CentOS/RHEL..."
        cd ../docker/docker-packages/centos
        sudo rpm -ivh *.rpm
        ;;
    *)
        echo "Неподдерживаемая ОС: $OS"
        exit 1
        ;;
esac

# Запуск и автозапуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

echo "Docker установлен успешно!"
echo "Перезайдите в систему для применения изменений группы."
EOF

chmod +x install-docker.sh
```

### Скрипт установки Kubernetes

```bash
cat > install-k8s.sh << 'EOF'
#!/bin/bash

echo "=== Установка Kubernetes (офлайн) ==="

# Определяем ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
fi

# Отключаем swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Настройка sysctl для Kubernetes
cat <<EOL | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOL
sudo sysctl --system

# Установка пакетов Kubernetes
case $OS in
    "ubuntu"|"debian")
        echo "Установка Kubernetes на Ubuntu/Debian..."
        
        # Добавляем GPG ключ
        cd ../kubernetes/packages/ubuntu
        sudo mkdir -p /etc/apt/keyrings
        sudo cp kubernetes-key.gpg /etc/apt/keyrings/
        
        # Устанавливаем пакеты
        sudo dpkg -i kubelet_*.deb kubeadm_*.deb kubectl_*.deb
        sudo apt-mark hold kubelet kubeadm kubectl
        ;;
        
    "centos"|"rhel"|"rocky"|"almalinux")
        echo "Установка Kubernetes на CentOS/RHEL..."
        cd ../kubernetes/packages/centos
        sudo rpm -ivh kubelet-*.rpm kubeadm-*.rpm kubectl-*.rpm
        ;;
        
    *)
        echo "Неподдерживаемая ОС: $OS"
        exit 1
        ;;
esac

# Установка бинарных файлов
cd ../../../kubernetes/binaries
sudo cp kubectl kubeadm kubelet /usr/local/bin/
sudo chmod +x /usr/local/bin/kube*

# Распаковка crictl
tar xzf crictl-*.tar.gz
sudo cp crictl /usr/local/bin/
sudo chmod +x /usr/local/bin/crictl

# Создание systemd unit для kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d

cat <<EOL | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

cat <<EOL | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=Webhook --client-ca-file=/etc/kubernetes/pki/ca.crt"
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=systemd"
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_SYSTEM_PODS_ARGS \$KUBELET_NETWORK_ARGS \$KUBELET_DNS_ARGS \$KUBELET_AUTHZ_ARGS \$KUBELET_CADVISOR_ARGS \$KUBELET_CERTIFICATE_ARGS \$KUBELET_EXTRA_ARGS
EOL

# Включаем kubelet
sudo systemctl daemon-reload
sudo systemctl enable kubelet

echo "Kubernetes установлен успешно!"
EOF

chmod +x install-k8s.sh
```

### Скрипт загрузки образов

```bash
cat > load-images.sh << 'EOF'
#!/bin/bash

echo "=== Загрузка Docker образов ==="

# Загрузка образов Kubernetes
echo "Загрузка образов Kubernetes..."
cd ../kubernetes/images
for image in *.tar; do
    echo "Загружаем: $image"
    docker load < $image
done

# Загрузка образов сети
echo "Загрузка сетевых образов..."
cd ../../network/flannel
docker load < flannel-*.tar

# Если используете Calico
cd ../calico
for image in *.tar; do
    echo "Загружаем: $image"
    docker load < $image
done

echo "Все образы загружены!"
EOF

chmod +x load-images.sh
```

## 📦 6. Упаковка для передачи

```bash
cd ../../../

# Создаем архив для передачи на сервера
tar -czf k8s-offline-install.tar.gz k8s-offline-install/

echo "=== Архив готов для передачи: k8s-offline-install.tar.gz ==="
echo "Размер архива:"
ls -lh k8s-offline-install.tar.gz
```

## 📋 7. Инструкции по установке на целевых серверах

После передачи архива на серверы без интернета:

```bash
# 1. Распаковка архива
tar -xzf k8s-offline-install.tar.gz
cd k8s-offline-install/scripts

# 2. Установка Docker (на всех узлах)
./install-docker.sh

# 3. Перезагрузка после установки Docker
sudo reboot

# 4. Установка Kubernetes (на всех узлах)
./install-k8s.sh

# 5. Загрузка образов (на всех узлах)
./load-images.sh

# 6. На master ноде - инициализация кластера
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 7. Настройка kubectl на master
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 8. Установка CNI (Flannel)
kubectl apply -f ../network/flannel/kube-flannel.yml

# 9. На worker нодах - присоединение к кластеру
# (команду получите после kubeadm init)
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

Готово! Теперь у вас есть полный набор для офлайн установки Kubernetes кластера из 3 узлов. 🚀
