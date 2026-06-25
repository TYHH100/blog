#!/bin/bash

INSTALL_DIR="$HOME/ssm"
script_filefolder=".lib custom_games .builtin_games"
script_name="addons.sh config.sh config_ui.sh config_utils.sh game.sh service.sh steam.sh system.sh utils.sh github_proxy.sh"
custom_games_script_name="examples.sh"
builtin_games_script_name="team_fortress_2.sh left_4_dead_2.sh no_more_room_in_hell.sh garrys_mod.sh counter_strike_source.sh team_fortress_2_classified.sh barotrauma.sh"

# 创建主目录
mkdir -p "$INSTALL_DIR"

# 逐个创建子目录
for folder in $script_filefolder; do
  mkdir -p "$INSTALL_DIR/$folder"
done

# 下载 main.sh
curl -fL "https://raw.githubusercontent.com/TYHH100/blog/master/file/script/ssm/main.sh" -o "$INSTALL_DIR/main.sh"

# 逐个下载 .lib 下的脚本
for f in $script_name; do
  curl -fL "https://raw.githubusercontent.com/TYHH100/blog/master/file/script/ssm/lib/$f" -o "$INSTALL_DIR/.lib/$f"
done

# 逐个下载 custom_games 下的脚本
for cgfc in $custom_games_script_name; do
  curl -fL "https://raw.githubusercontent.com/TYHH100/blog/master/file/script/ssm/custom_games/$cgfc" -o "$INSTALL_DIR/custom_games/$cgfc"
done

# 逐个下载 .builtin_games 下的脚本
for bgfc in $builtin_games_script_name; do
  curl -fL "https://raw.githubusercontent.com/TYHH100/blog/master/file/script/ssm/builtin_games/$bgfc" -o "$INSTALL_DIR/.builtin_games/$bgfc"
done

chmod +x "$INSTALL_DIR/main.sh"
# 设置执行权限
for f in "$INSTALL_DIR"/.lib/*.sh; do
    [ -f "$f" ] && chmod +x "$f"
done
for f in "$INSTALL_DIR"/custom_games/*.sh; do
    [ -f "$f" ] && chmod +x "$f"
done
for f in "$INSTALL_DIR"/.builtin_games/*.sh; do
    [ -f "$f" ] && chmod +x "$f"
done

# 检查 whiptail 是否已安装
if ! command -v whiptail &> /dev/null; then
    echo "检测到系统中未安装 whiptail。"
    read -p "是否安装 whiptail? (Y/n): " choice
    case "$choice" in
        n|N )
            echo "跳过 whiptail 安装。"
            ;;
        * )
            echo "正在安装 whiptail..."
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
            ;;
    esac
fi
# ================================================================
# 创建 ssm 全局命令（创建包装脚本到 /usr/local/bin/）
# ================================================================
ssm_wrapper="/usr/local/bin/ssm"
if [ -f "$ssm_wrapper" ]; then
    if [ "$(cat "$ssm_wrapper")" != "#!/bin/bash
exec sudo $INSTALL_DIR/main.sh \"\$@\"" ]; then
        printf '%s\n' '#!/bin/bash' "exec sudo $INSTALL_DIR/main.sh \"\$@\"" | sudo tee "$ssm_wrapper" > /dev/null
        echo "已更新全局命令 'ssm' → $INSTALL_DIR/main.sh"
    fi
else
    printf '%s\n' '#!/bin/bash' "exec sudo $INSTALL_DIR/main.sh \"\$@\"" | sudo tee "$ssm_wrapper" > /dev/null
    sudo chmod +x "$ssm_wrapper"
    echo "已创建全局命令 'ssm' → $INSTALL_DIR/main.sh"
fi

echo "运行指令: sudo $INSTALL_DIR/main.sh"
echo "或直接在终端输入: ssm (需要重新打开终端)"
#exec sudo "$INSTALL_DIR/main.sh" "$@"