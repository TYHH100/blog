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
        su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit"
        
        # 然后下载Linux版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${BLUE}[Step 2/2]${NC} 正在下载Linux版本文件..."
        fi
        su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit"
    fi

    clear
    msg_info "正在执行 SteamCMD 操作 ($mode)..."
    su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" $cmd_flags"
    
    echo "按回车键继续..."
    read
}

rm_server() {
    if [ -n "$SERVER_DIR" ]; then
        msg_warn "确认删除服务器目录 $SERVER_DIR？"
        if whiptail --title "确认删除" --yesno "这将永久删除服务器目录及其所有内容，同时删除 Systemd 服务文件和别名" 10 60; then
            
            # 获取游戏短名称
            local short_name=${GAME_SHORT_NAMES[$GAME_NAME]}
            local service_name="${short_name}server"
            local service_file="/etc/systemd/system/${service_name}.service"
            
            # 1. 停止并禁用服务
            if systemctl is-active --quiet "$service_name"; then
                msg_info "正在停止服务 $service_name..."
                systemctl stop "$service_name"
            fi
            
            if systemctl is-enabled --quiet "$service_name"; then
                msg_info "正在禁用服务 $service_name..."
                systemctl disable "$service_name"
            fi
            
            # 2. 删除 Systemd 服务文件
            if [ -f "$service_file" ]; then
                msg_info "正在删除 Systemd 服务文件 $service_file..."
                rm -f "$service_file"
                systemctl daemon-reload
                msg_ok "Systemd 服务文件已删除"
            else
                msg_info "未找到 Systemd 服务文件: $service_file"
            fi
            
            # 3. 删除别名配置（从 /etc/profile 中移除）
            msg_info "正在清理别名配置..."
            
            # 使用 sed 精确删除包含特定命令的别名行
            if [ -n "$short_name" ]; then
                # 删除包含特定命令的别名行
                sed -i "\|alias .*screen -d -r ${short_name}server|d" /etc/profile
                source /etc/profile
                msg_ok "别名配置已清理"
            else
                msg_info "未找到游戏短名称，跳过别名清理"
            fi
            
            # 4. 删除服务器目录
            msg_info "正在删除服务器目录 $SERVER_DIR..."
            rm -rf "$SERVER_DIR"
            msg_ok "服务器目录已删除"
            
            # 5. 清除相关配置
            SERVER_DIR=""
            save_user_config
            
            msg_ok "服务器删除完成，所有相关文件和服务已清理"
        fi
    else
        msg_warn "未设置服务器目录"
    fi
}

menu_game_manage() {
    local choice=$(whiptail --menu "游戏服务器管理" 15 60 5 \
        "1" "选择游戏" \
        "2" "设置安装目录" \
        "3" "下载/安装服务器" \
        "4" "更新服务器" \
        "5" "验证文件完整性" \
        "6" "删除服务器" \
        "7" "返回主菜单" 3>&1 1>&2 2>&3)

    case $choice in
        1) select_game ;;
        2) set_install_dir ;;
        3) [ -n "$GAME_NAME" ] && run_steam_update "install" ;;
        4) [ -n "$GAME_NAME" ] && run_steam_update "update" ;;
        5) [ -n "$GAME_NAME" ] && run_steam_update "validate" ;;
        6) rm_server ;;
    esac
}