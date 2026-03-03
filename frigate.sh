#!/usr/bin/env bash

source <(curl -fsSL https://git.community-scripts.org/community-scripts/ProxmoxVE/raw/branch/main/misc/build.func)

# Copyright (c) 2021-2026 community-scripts ORG
# Authors: MickLesk (CanbiZ) | Co-Author: remz1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://frigate.video/ | Github: https://github.com/blakeblackshear/frigate

APP="Frigate"
var_tags="${var_tags:-nvr}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-0}"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /etc/systemd/system/frigate.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_error "To update Frigate, create a new container and transfer your configuration."
    exit
}

start
build_container
description

# === Фикс: вместо скачивания Yamnet с Kaggle копируем локальный файл ===
echo "Копируем локальный файл Yamnet с хоста в контейнер..."
YAMNET_FILE="/mnt/yamnet-tflite-classification-tflite-v1.tar.gz"

if [ ! -f "$YAMNET_FILE" ]; then
  echo "Ошибка: файл Yamnet не найден по пути $YAMNET_FILE"
  echo "Проверь путь и наличие файла!"
  exit 1
fi

# Копируем файл в контейнер
pct push $CTID "$YAMNET_FILE" /tmp/yamnet.tar.gz

# Распаковываем Yamnet в правильное место
pct exec $CTID -- bash -c "
  mkdir -p /opt/frigate/models/yamnet
  tar -xzf /tmp/yamnet.tar.gz -C /opt/frigate/models/yamnet
  rm /tmp/yamnet.tar.gz
  echo 'Yamnet успешно скопирован и распакован'
"

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5000${CL}"
