#!/bin/bash
INSTALL_DIR="/tmp/ssm"
script_name="addons.sh \
config.sh \
game.sh \
service.sh \
steam.sh \
system.sh \
utils.sh"
mkdir -p "$INSTALL_DIR"

curl -sSL https://blog.tyhh10.xyz/file/script/ssm/main.sh -o "$INSTALL_DIR/main.sh"
curl -sSL https://blog.tyhh10.xyz/file/script/ssm/lib/$script_name -o "$INSTALL_DIR/lib/$script_name"


# 赋予执行权限并运行
chmod +x "$INSTALL_DIR/main.sh"
exec "$INSTALL_DIR/main.sh" "$@"