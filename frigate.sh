#!/usr/bin/env bash

# =======================
# Fixed Frigate LXC Installer (tteck edition)
# With local Yamnet file from /mnt
# =======================

set -euo pipefail

# === Настройки ===
CTID=105
CTNAME="frigate"
CTIP="192.168.1.30/24"
CTGW="192.168.1.1"
CTBRIDGE="vmbr0"
CTDISKSIZE="32"
CTCORES="4"
CTMEMORY="8192"
CTSWAP="2048"
CTGPU="yes"  # GPU passthrough (Intel)
CTSTORAGE="local-zfs"  # твой storage

# Путь к твоему файлу Yamnet на хосте
YAMNET_FILE="/mnt/yamnet-tflite-classification-tflite-v1.tar.gz"

# === Проверки ===
if [ ! -f "$YAMNET_FILE" ]; then
  echo "Ошибка: файл Yamnet не найден по пути $YAMNET_FILE"
  echo "Положи файл в /mnt и укажи правильный путь в скрипте"
  exit 1
fi

# === Создание LXC ===
echo "Создаём LXC контейнер $CTID ($CTNAME)..."

pct create $CTID local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname $CTNAME \
  --cores $CTCORES \
  --memory $CTMEMORY \
  --swap $CTSWAP \
  --net0 name=eth0,bridge=$CTBRIDGE,ip=$CTIP,gw=$CTGW \
  --rootfs $CTSTORAGE:$CTDISKSIZE \
  --features nesting=1,keyctl=1 \
  --unprivileged 0 \
  --start 1

# === Настройка GPU (Intel) ===
if [ "$CTGPU" = "yes" ]; then
  echo "Настраиваем Intel GPU passthrough..."
  echo "lxc.cgroup2.devices.allow: c 226:* rwm" >> /etc/pve/lxc/$CTID.conf
  echo "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" >> /etc/pve/lxc/$CTID.conf
fi

# === Запуск и настройка ===
pct start $CTID
pct exec $CTID -- bash -c "apt update && apt upgrade -y && apt install curl wget git nano mc docker.io docker-compose -y"

# === Копируем Yamnet с хоста в контейнер ===
echo "Копируем Yamnet с хоста в контейнер..."
pct push $CTID $YAMNET_FILE /tmp/yamnet.tar.gz

# === Установка Frigate внутри контейнера ===
pct exec $CTID -- bash -c "
  mkdir -p /opt/frigate/config /media/frigate/clips /media/frigate/recordings /media/frigate/snapshots
  cd /tmp
  tar -xzf yamnet.tar.gz -C /opt/frigate/models/yamnet
  mkdir -p /opt/frigate/models/yamnet
  # Если нужно распаковать в другую папку — измени путь выше

  docker run -d \
    --name frigate \
    --restart unless-stopped \
    --device /dev/dri:/dev/dri \
    -p 5000:5000 \
    -p 8554:8554 \
    -v /opt/frigate/config:/config \
    -v /media/frigate:/media/frigate \
    ghcr.io/blakeblackshear/frigate:stable
"

# === Финальные сообщения ===
echo "Frigate установлен в контейнере $CTID (IP: $CTIP)"
echo "UI: http://$CTIP:5000"
echo "Yamnet скопирован в /opt/frigate/models/yamnet"
echo "Готово! Проверь логи: pct enter $CTID && docker logs frigate"
