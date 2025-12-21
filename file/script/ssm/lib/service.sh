#!/bin/bash

# 创建游戏服务器启动脚本
create_start_script() {
    local short_name=${GAME_SHORT_NAMES[$GAME_NAME]}
    local script_file="$SERVER_DIR/start.sh"
    local custom_func="override_start_script_${short_name}"
    
    if type "$custom_func" &>/dev/null; then
        msg_info "检测到自定义启动逻辑 ($short_name)，正在应用..."
        # 调用自定义函数，传入 install_dir 和 script_file 路径
        $custom_func "$SERVER_DIR" "$script_file"
        
        # 赋予权限并提示
        chmod +x "$script_file"
        chown "$STEAM_USER:$STEAM_USER" "$script_file"
        whiptail --msgbox "自定义启动脚本已创建于: $script_file" 8 60
        return
    fi

    local default_port=$(( RANDOM % 1000 + 27015 ))
    local cfg_dir="$SERVER_DIR/$short_name/cfg"
    local config_name="server.cfg"
    local game_update="$STEAMCMD_PATH/$short_name-update.txt"
    local default_maps=""
    # 设置默认地图
    case "$GAME_NAME" in
        "Team Fortress 2") default_map="cp_5gorge" ;;
        "Left 4 Dead 2") default_map="c2m1_highway" ;;
        "No More Room in Hell") default_map="nmo_broadway" ;;
        "Garry's Mod") default_map="gm_construct" ;;
        "Counter-Strike: Source") default_map="de_dust2" ;;
        *) default_map="dm_mario_kart" ;;
    esac

    msg_info "正在创建游戏更新脚本..."
    cat > "$game_update" << EOF
login anonymous
force_install_dir "$SERVER_DIR"
app_update "$GAME_APPS"
quit
EOF

    msg_info "正在创建启动脚本..."
    cat > "$script_file" << EOF
#!/bin/bash
./srcds_run \\
    -game "$short_name" \\
    -console \\
    +ip "0.0.0.0" \\
    -port "$default_port" \\
    +maxplayers "16" \\
    +map "$default_map" \\
    +exec "$config_name" \\
    -autoupdate \\
    -steam_dir "$SERVER_DIR/steamcmd" \\
    -steamcmd_script "$SERVER_DIR/steamcmd/${short_name}_update.txt"
EOF

    create_server_config "$short_name" "$cfg_dir" "$config_name"

    chmod +x "$script_file"
    chown "$STEAM_USER:$STEAM_USER" "$script_file"
    whiptail --msgbox "启动脚本已创建于: $script_file" 8 60
}

create_server_config() {
    local short_name=$1
    local cfg_dir=$2
    local config_name=$3

    local custom_cfg_func="override_config_gen_${short_name}"
    if type "$custom_cfg_func" &>/dev/null; then
        msg_info "正在生成自定义配置文件..."
        $custom_cfg_func "$SERVER_DIR" "$cfg_dir" "$config_name"
        return
    fi

    if [ ! -f "$cfg_dir/$config_name" ]; then
        msg_info "正在创建默认配置文件..."
        cat > "$cfg_dir/$config_name" << EOF
// ${GAME_NAME} 服务器配置
// 显示在服务器浏览器和计分版的服务器名字,PS:L4D2服务器服务器配置文件中这个hostname是无效的要使用插件进行更改
hostname "${GAME_NAME} 服务器"
// 是否需要给服务器上密码,留空即无密码
sv_password ""
// 使用控制台rcon的密码,玩家(或者网站/软件)可以通过这个直接向服务器发送相关指令(必须要填写的)
rcon_password "$(openssl rand -hex 30)"
// 控制台作弊(0/1)
// https://developer.valvesoftware.com/wiki/Sv_cheats
sv_cheats "0"
// 允许玩家使用自定义的内容-1/0/1/2)
// https://developer.valvesoftware.com/wiki/Pure_Servers
sv_pure "0"
EOF
        chown "$STEAM_USER:$STEAM_USER" "$cfg_dir/$config_name"
    fi
}

# 创建 Systemd 服务文件
create_systemd() {
    local short_name=${GAME_SHORT_NAMES[$GAME_NAME]}
    local service_name="${short_name}server"
    local file="/etc/systemd/system/${service_name}.service"
    
    msg_info "正在创建 Systemd 服务文件..."
    cat > "$file" << EOF
[Unit]
Description=${GAME_NAME} Server
After=network.target

[Service]
User=$STEAM_USER
Group=$STEAM_USER
WorkingDirectory=$SERVER_DIR
ExecStart=screen -SDm ${short_name}server $SERVER_DIR/start.sh
ExecStop=screen -S ${short_name}server -X quit
RestartSec=15
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    msg_info "正在重新加载 Systemd 守护进程..."
    systemctl daemon-reload

    msg_info "创建别名..."
    alias_name=$(input_box "创建别名(用于打开服务器控制台)" "请输入别名:(不更改则使用默认别名:$short_name)" "$short_name")
    alias_name=${alias_name:-$short_name}
    alias_line="alias $alias_name='sudo su -c \"screen -d -r ${short_name}server\" $STEAM_USER'"
    if ! grep -qF "$alias_line" /etc/profile; then
        echo "$alias_line" >> /etc/profile
    fi
    source /etc/profile
    whiptail --msgbox "服务 $service_name 已创建 (别名: $alias_name)\n手动输入source /etc/profile让别名立刻生效, 或者重新登录账户" 15 60
}

# 服务管理菜单
menu_service() {
    local choice=$(whiptail --menu "服务管理" 15 60 5 \
        "1" "创建 start.sh 启动脚本" \
        "2" "创建 Systemd 服务" \
        "3" "启动服务" \
        "4" "停止服务" \
        "5" "重启服务" \
        "6" "查看服务状态" \
        "7" "返回主菜单" 3>&1 1>&2 2>&3)
        
    case $choice in
        1) create_start_script ;;
        2) create_systemd ;;
        3) systemctl start "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
        4) systemctl stop "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
        5) systemctl restart "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
        6) systemctl status "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
    esac
}