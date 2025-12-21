#!/bin/bash

INSTALL_DIR="/tmp/ssm"
script_filefolder="lib custom_games"
script_name="addons.sh config.sh game.sh service.sh steam.sh system.sh utils.sh"
custom_games_script_name="examples.sh"
mkdir -p "$INSTALL_DIR/$script_filefolder"

# 下载 main.sh
curl -fL "https://blog.tyhh10.xyz/file/script/ssm/main.sh" -o "$INSTALL_DIR/main.sh"

# 逐个下载 lib 下的脚本
for f in $script_name; do
  curl -fL "https://blog.tyhh10.xyz/file/script/ssm/lib/$f" -o "$INSTALL_DIR/lib/$f"
done

# 逐个下载 custom_games 下的脚本
for cgfc in $custom_games_script_name; do
  curl -fL "https://blog.tyhh10.xyz/file/script/ssm/custom_games/$cgfc" -o "$INSTALL_DIR/custom_games/$cgfc"
done

chmod +x "$INSTALL_DIR/main.sh"
echo "运行指令: sudo $INSTALL_DIR/main.sh"
#exec sudo "$INSTALL_DIR/main.sh" "$@"