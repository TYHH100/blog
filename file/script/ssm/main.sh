#!/bin/bash

# 获取当前脚本所在目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$BASE_DIR/.lib/config.sh"
source "$BASE_DIR/.lib/utils.sh"
source "$BASE_DIR/.lib/config_utils.sh"
source "$BASE_DIR/.lib/config_ui.sh"
source "$BASE_DIR/.lib/system.sh"
source "$BASE_DIR/.lib/steam.sh"
source "$BASE_DIR/.lib/game.sh"
source "$BASE_DIR/.lib/addons.sh"
source "$BASE_DIR/.lib/service.sh"
source "$BASE_DIR/.lib/github_proxy.sh"

# 初始化
check_root          # 确保以 root 用户运行
detect_os           # 检测操作系统
load_user_config    # 加载用户配置

show_help() {
    cat << 'EOF'
SSM - Source Server Manager (Refactored)

用法:
  main.sh                进入交互菜单
  main.sh menu           进入交互菜单
  main.sh deps           安装系统依赖
  main.sh user           设置运行用户
  main.sh steamcmd       SteamCMD 管理
  main.sh game           游戏服务器管理
  main.sh addons         插件管理
  main.sh service        服务管理
  main.sh config         游戏定义管理
  main.sh github-proxy   GitHub 代理下载工具
  main.sh info           查看当前配置
  main.sh help           显示帮助
EOF
}

run_menu() {
    while true; do
        clear
        # 动态生成菜单标题
        MENU_TITLE="服务器管理脚本 v3.0 (Refactor)"
        MENU_TEXT="OS: $OS_INFO | 用户: ${STEAM_USER:-未设置} | 游戏: ${GAME_NAME:-未选择}"
        
        CHOICE=$(menu_select "$MENU_TITLE" "$MENU_TEXT" \
        "1" "环境准备 (依赖安装)" \
        "2" "账户设置 (设置运行用户)" \
        "3" "SteamCMD 管理" \
        "4" "游戏服务器安装/更新" \
        "5" "插件管理 (SM/MM:S)" \
        "6" "启动脚本与服务管理" \
        "7" "游戏定义管理" \
        "8" "查看配置信息" \
        "9" "GitHub 代理下载" \
        "10" "退出")

        if [ $? -ne 0 ]; then
            save_user_config
            exit 0
        fi

        case $CHOICE in
            1) install_dependencies ;;
            2) set_server_user ;;
            3) menu_steamcmd ;;
            4) menu_game_manage ;;
            5) menu_addons ;;
            6) menu_service ;;
            7) menu_config_ui ;;
            8) show_config_info ;;
            9) menu_github_proxy ;;
            10) save_user_config; exit 0 ;;
        esac
    done
}

if [ $# -eq 0 ]; then
    run_menu
    exit 0
fi

case "$1" in
    menu) run_menu ;;
    deps) install_dependencies ;;
    user) set_server_user ;;
    steamcmd) menu_steamcmd ;;
    game) menu_game_manage ;;
    addons) menu_addons ;;
    service) menu_service ;;
    config) menu_config_ui ;;
    github-proxy) handle_github_proxy_cli "$2" "$3" "$4" ;;
    info) show_config_info ;;
    help|-h|--help) show_help ;;
    *) msg_error "未知命令: $1"; show_help; exit 1 ;;
 esac
