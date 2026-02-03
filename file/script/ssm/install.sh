#!/bin/bash

INSTALL_DIR="$HOME/ssm"
script_filefolder="lib custom_games builtin_games"
script_name="addons.sh config.sh game.sh service.sh steam.sh system.sh utils.sh"
custom_games_script_name="examples.sh"
builtin_games_script_name="team_fortress_2.sh left_4_dead_2.sh no_more_room_in_hell.sh garrys_mod.sh counter_strike_source.sh"
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

# 逐个下载 builtin_games 下的脚本
for bgfc in $builtin_games_script_name; do
  curl -fL "https://blog.tyhh10.xyz/file/script/ssm/builtin_games/$bgfc" -o "$INSTALL_DIR/builtin_games/$bgfc"
done

chmod +x "$INSTALL_DIR/main.sh"

# 安装 whiptail
if ! command -v whiptail &> /dev/null; then
    echo "安装 whiptail..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y whiptail
    elif command -v yum &> /dev/null; then
        sudo yum install -y newt
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm libnewt
    else
        echo "错误: 未检测到支持的包管理器 (apt-get, yum, pacman)"
        echo "请手动安装 whiptail"
        exit 1
    fi
fi
echo "运行指令: sudo $INSTALL_DIR/main.sh"
#exec sudo "$INSTALL_DIR/main.sh" "$@"