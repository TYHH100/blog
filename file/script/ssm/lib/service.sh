#!/bin/bash

create_start_script() {
    local short_name=${GAME_SHORT_NAMES[$GAME_NAME]}
    local script_file="$SERVER_DIR/start.sh"
    
    cat > "$script_file" << EOF
#!/bin/bash
./srcds_run -game $short_name -console -port 27015 +maxplayers 16 +map cp_dustbowl
EOF
    chmod +x "$script_file"
    chown "$STEAM_USER:$STEAM_USER" "$script_file"
    whiptail --msgbox "启动脚本已创建于: $script_file" 8 60
}

create_systemd() {
    local service_name="${GAME_SHORT_NAMES[$GAME_NAME]}_server"
    local file="/etc/systemd/system/${service_name}.service"
    
    cat > "$file" << EOF
[Unit]
Description=$GAME_NAME Server
After=network.target

[Service]
User=$STEAM_USER
WorkingDirectory=$SERVER_DIR
ExecStart=/usr/bin/screen -DmS $service_name $SERVER_DIR/start.sh
ExecStop=/usr/bin/screen -S $service_name -X quit
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    whiptail --msgbox "服务 $service_name 已创建" 8 60
}

menu_service() {
    local choice=$(whiptail --menu "服务管理" 15 60 5 \
        "1" "创建 start.sh 启动脚本" \
        "2" "创建 Systemd 服务" \
        "3" "启动服务" \
        "4" "停止服务" \
        "5" "返回主菜单" 3>&1 1>&2 2>&3)
        
    case $choice in
        1) create_start_script ;;
        2) create_systemd ;;
        3) systemctl start "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
        4) systemctl stop "${GAME_SHORT_NAMES[$GAME_NAME]}_server" ;;
    esac
}