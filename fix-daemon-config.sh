#!/bin/bash

# 🔧 Corregir configuración Docker daemon para WSL2

# Backup del archivo actual
cp /etc/docker/daemon.json /etc/docker/daemon.json.backup

# Crear configuración compatible con WSL2
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "Max Open Files",
      "Hard": 1048576,
      "Soft": 1048576
    },
    "nproc": {
      "Name": "Max User Processes",
      "Hard": 1048576,
      "Soft": 1048576
    },
    "memlock": {
      "Name": "Memory Lock",
      "Hard": -1,
      "Soft": -1
    }
  },
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "live-restore": true,
  "userland-proxy": false,
  "ip-forward": true,
  "iptables": true
}
EOF

# Corregir systemd override
cat > /etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
EOF

echo "✅ Configuración Docker daemon corregida para WSL2"