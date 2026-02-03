#!/bin/bash

# 解释 SteamCMD 错误代码
explain_steamcmd_error() {
    local error_code=$1
    local error_message=""
    
    case "$error_code" in
        "0x202") error_message="硬盘空间不足，请检查磁盘空间" ;;
        "0x606") error_message="磁盘写入失败" ;;
        "0x602") error_message="网络连接错误" ;;
        *) error_message="未知错误，请查看详细输出" ;;
    esac
    
    echo "$error_message"
}

# 处理 SteamCMD 错误
handle_steamcmd_error() {
    local output=$1
    local error_title=$2
    
    # 提取应用 ID 和错误代码
    local app_id=$(echo "$output" | grep -o "Error! App '[0-9]*'" | grep -o "[0-9]*")
    local error_code=$(echo "$output" | grep -o "state is [0-9a-fA-Fx]* after" | grep -o "0x[0-9a-fA-F]*")
    
    # 错误代码解释
    local error_message=$(explain_steamcmd_error "$error_code")
    
    # 显示错误信息
    msg_error "$error_title"
    msg_error "应用 ID: $app_id"
    msg_error "错误代码: $error_code"
    msg_error "错误信息: $error_message"
    msg_error "详细输出:"
    echo "$output"
    
    echo "按回车键继续..."
    read
}

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

    # 检查并处理依赖
    local dependencies=${GAME_DEPENDENCIES[$GAME_NAME]}
    if [ -n "$dependencies" ]; then
        msg_info "检测依赖: $dependencies"
        
        # 保存当前游戏信息
        local current_game_name="$GAME_NAME"
        local current_server_dir="$SERVER_DIR"
        
        # 检查依赖是否为单个游戏名称（可能包含空格）
        # 这里简化处理，假设每个游戏配置文件只定义一个依赖
        # 检查完整的依赖游戏名称是否存在
        if [ -n "${GAME_APPS[$dependencies]}" ]; then
            # 临时切换到依赖游戏
            GAME_NAME="$dependencies"
            
            # 为依赖游戏设置安装目录
            local dep_dir="$STEAM_HOME/${dependencies// /_}_server"
            SERVER_DIR="$dep_dir"
            
            # 创建依赖游戏目录
            if [ ! -d "$SERVER_DIR" ]; then
                mkdir -p "$SERVER_DIR"
                chown "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
            fi
            
            # 处理依赖游戏
            msg_info "正在 $mode 依赖游戏: $dependencies"
            local dep_app_id=${GAME_APPS[$dependencies]}
            local dep_cmd_flags="+login anonymous +force_install_dir \"$SERVER_DIR\" +app_update \"$dep_app_id\""
            
            if [ "$mode" == "validate" ]; then dep_cmd_flags+=" validate"; fi
            dep_cmd_flags+=" +quit"
            
            # 捕获依赖游戏操作的输出并处理错误
            local dep_output=$(su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" $dep_cmd_flags" 2>&1)
            
            # 检查输出中是否包含错误消息
            if echo "$dep_output" | grep -q "Error! App '" && echo "$dep_output" | grep -q "' state is " && echo "$dep_output" | grep -q " after update job."; then
                # 恢复当前游戏信息
                GAME_NAME="$current_game_name"
                SERVER_DIR="$current_server_dir"
                save_user_config
                
                handle_steamcmd_error "$dep_output" "SteamCMD 操作错误"
                return
            fi
        else
            msg_warn "依赖游戏 '$dependencies' 未找到，跳过..."
        fi
        
        # 恢复当前游戏信息
        GAME_NAME="$current_game_name"
        SERVER_DIR="$current_server_dir"
        save_user_config
        
        msg_ok "依赖 $mode 完成"
    fi

    # 特殊处理 L4D2 
    if [ "$app_id" == "222860" ]; then
        # 先下载Windows版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${BLUE}[Step 1/2]${NC} 正在下载Windows版本文件..."
        fi
        
        local win_cmd="+force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit"
        local win_output=$(su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" $win_cmd" 2>&1)
        
        # 检查Windows版本下载是否有错误
        if echo "$win_output" | grep -q "Error! App '" && echo "$win_output" | grep -q "' state is " && echo "$win_output" | grep -q " after update job."; then
            handle_steamcmd_error "$win_output" "SteamCMD 操作错误"
            return
        fi
        
        # 然后下载Linux版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${BLUE}[Step 2/2]${NC} 正在下载Linux版本文件..."
        fi
        
        local linux_cmd="+force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit"
        local linux_output=$(su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" $linux_cmd" 2>&1)
        
        # 检查Linux版本下载是否有错误
        if echo "$linux_output" | grep -q "Error! App '" && echo "$linux_output" | grep -q "' state is " && echo "$linux_output" | grep -q " after update job."; then
            handle_steamcmd_error "$linux_output" "SteamCMD 错误"
            return
        fi
    fi

    clear
    msg_info "正在执行 SteamCMD 操作 ($mode)..."
    
    # 捕获 SteamCMD 输出并处理错误
    local steamcmd_output=$(su - "$STEAM_USER" -c "\"$STEAMCMD_PATH/steamcmd.sh\" $cmd_flags" 2>&1)
    local exit_status=$?
    
    # 检查输出中是否包含错误消息
    if echo "$steamcmd_output" | grep -q "Error! App '" && echo "$steamcmd_output" | grep -q "' state is " && echo "$steamcmd_output" | grep -q " after update job."; then
        handle_steamcmd_error "$steamcmd_output" "SteamCMD 错误"
    elif [ $exit_status -ne 0 ]; then
        msg_error "SteamCMD 操作失败，退出码: $exit_status"
        msg_error "详细输出:"
        echo "$steamcmd_output"
        
        echo "按回车键继续..."
        read
    else
        msg_ok "SteamCMD 操作成功完成"
    fi
    
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