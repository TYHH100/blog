#!/bin/bash

select_game() {
    local options=()
    for game in "${!GAME_APPS[@]}"; do
        options+=("$game" "")
    done
    
    GAME_NAME=$(whiptail --title "选择游戏" --menu "请选择要管理的游戏" 15 70 6 "${options[@]}" 3>&1 1>&2 2>&3)
    [ -n "$GAME_NAME" ] && save_user_config
}

set_install_dir() {
    local default_dir="$STEAM_HOME/${GAME_NAME// /_}_server"
    SERVER_DIR=$(input_box "安装目录" "请输入绝对路径:" "$default_dir")
    
    if [ -n "$SERVER_DIR" ]; then
        if [ ! -d "$SERVER_DIR" ]; then
            mkdir -p "$SERVER_DIR"
            chown "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
        fi
        save_user_config
    fi
}

run_steam_update() {
    local mode=$1 # install, update, validate
    local app_id=${GAME_APPS[$GAME_NAME]}
    local cmd_flags="+login anonymous +force_install_dir \"$SERVER_DIR\" +app_update \"$app_id\""
    
    if [ "$mode" == "validate" ]; then cmd_flags+=" validate"; fi
    cmd_flags+=" +quit"

    # 特殊处理 L4D2 
    if [ "$app_id" == "222860" ]; then
        # 先下载Windows版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${BLUE}[Step 1/2]${NC} 正在下载Windows版本文件..."
        fi
        su - "$STEAM_USER" -c "\"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit"
        
        # 然后下载Linux版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${BLUE}[Step 2/2]${NC} 正在下载Linux版本文件..."
        fi
        su - "$STEAM_USER" -c "\"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit"
    fi

    clear
    msg_info "正在执行 SteamCMD 操作 ($mode)..."
    su - "$STEAM_USER" -c "\"$STEAMCMD_PATH\" $cmd_flags"
    
    echo "按回车键继续..."
    read
}

menu_game_manage() {
    local choice=$(whiptail --menu "游戏服务器管理" 15 60 5 \
        "1" "选择游戏" \
        "2" "设置安装目录" \
        "3" "下载/安装服务器" \
        "4" "更新服务器" \
        "5" "验证文件完整性" \
        "6" "返回主菜单" 3>&1 1>&2 2>&3)

    case $choice in
        1) select_game ;;
        2) set_install_dir ;;
        3) [ -n "$GAME_NAME" ] && run_steam_update "install" ;;
        4) [ -n "$GAME_NAME" ] && run_steam_update "update" ;;
        5) [ -n "$GAME_NAME" ] && run_steam_update "validate" ;;
    esac
}