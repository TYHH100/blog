#!/bin/bash

# 获取当前脚本所在目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$BASE_DIR/lib/config.sh"
source "$BASE_DIR/lib/utils.sh"
source "$BASE_DIR/lib/system.sh"
source "$BASE_DIR/lib/steam.sh"
source "$BASE_DIR/lib/game.sh"
source "$BASE_DIR/lib/addons.sh"
source "$BASE_DIR/lib/service.sh"

# 初始化
check_root          # 确保以 root 用户运行
detect_os           # 检测操作系统
load_user_config    # 加载用户配置

# 检查 whiptail 是否安装
if ! command -v whiptail &> /dev/null; then
    msg_error "whiptail 未安装"
    exit 1
fi

# 命令行参数处理 (保留原脚本的逻辑，简化实现)
#parse_arguments "$@"

# 主循环
while true; do
    # 动态生成菜单标题
    MENU_TITLE="服务器管理脚本 v2.0 (Modular)"
    MENU_TEXT="OS: $OS_INFO | 用户: ${STEAM_USER:-未设置} | 游戏: ${GAME_NAME:-未选择}"
    
    CHOICE=$(whiptail --title "$MENU_TITLE" --menu "$MENU_TEXT" 20 70 12 \
        "1" "环境准备 (依赖安装)" \
        "2" "账户设置 (设置运行用户)" \
        "3" "SteamCMD 管理" \
        "4" "游戏服务器安装/更新" \
        "5" "插件管理 (SM/MM:S)" \
        "6" "启动脚本与服务管理" \
        "7" "查看配置信息" \
        "8" "退出" 3>&1 1>&2 2>&3)

    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then exit 0; fi

    case $CHOICE in
        1) install_dependencies ;;  # 在 lib/system.sh 中定义
        2) set_server_user ;;       # 在 lib/system.sh 中定义
        3) menu_steamcmd ;;         # 在 lib/steam.sh 中定义
        4) menu_game_manage ;;      # 在 lib/game.sh 中定义
        5) menu_addons ;;           # 在 lib/addons.sh 中定义
        6) menu_service ;;          # 在 lib/service.sh 中定义
        7) show_config_info ;;      # 在 lib/config.sh 中定义
        8) save_user_config; exit 0 ;;
    esac
done