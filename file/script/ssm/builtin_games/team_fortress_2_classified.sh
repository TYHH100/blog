# Team Fortress 2 Classified
game_name="Team Fortress 2 Classified"
game_app_id="3557020"
game_short_name="tf2classified"
game_default_map="cp_5gorge"
game_dependencies="Team Fortress 2"

GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"
GAME_DEPENDENCIES["$game_name"]="$game_dependencies"

# 自定义安装后处理函数
install_dependencies_tf2classified() {
    # 修复库文件的符号链接
    msg_info "正在修复 Team Fortress 2 Classified 库文件..."
    
    # 检查是否存在所需目录
    if [ -d "$SERVER_DIR/bin/linux64" ]; then
        # 检查 libvstdlib_srv.so 是否存在
        if [ -f "$SERVER_DIR/bin/linux64/libvstdlib_srv.so" ]; then
            # 删除现有 libvstdlib.so 并替换为符号链接
            if [ -f "$SERVER_DIR/bin/linux64/libvstdlib.so" ]; then
                rm "$SERVER_DIR/bin/linux64/libvstdlib.so"
            fi
            ln -s "libvstdlib_srv.so" "$SERVER_DIR/bin/linux64/libvstdlib.so"
            msg_ok "已修复 libvstdlib.so 符号链接"
        else
            msg_warn "libvstdlib_srv.so 文件不存在，无法创建符号链接"
        fi
    fi
    
    # 创建 .steam/sdk64 目录并添加符号链接
    local steam_dir="$(eval echo ~$STEAM_USER)/.steam/sdk64"
    if [ ! -d "$steam_dir" ]; then
        mkdir -p "$steam_dir"
    fi
    
    if [ -f "$SERVER_DIR/linux64/steamclient.so" ]; then
        ln -sf "$SERVER_DIR/linux64/steamclient.so" "$steam_dir/steamclient.so"
        msg_ok "已添加 steamclient.so 符号链接"
    else
        msg_warn "steamclient.so 文件不存在，无法创建符号链接"
    fi
    
    msg_ok "Team Fortress 2 Classified 库文件修复完成"
}

# 自定义启动脚本生成函数
override_start_script_tf2classified() {
    local install_dir=$1
    local script_file=$2
    
    # 设置默认端口
    local default_port=$(( RANDOM % 1000 + 27015 ))
    
    # 设置默认地图
    local default_map=${GAME_DEFAULT_MAPS[$GAME_NAME]:-"cp_5gorge"}
    
    # 配置文件目录
    local cfg_dir="$install_dir/tf2classified/cfg"
    local config_name="server.cfg"
    
    # TF2 服务器路径（与依赖安装时的默认路径格式一致）
    local tf_server_dir="$(eval echo ~$STEAM_USER)/Team_Fortress_2_server"
    
    # 提示用户输入 TF2 服务器路径
    local tf_path=$(whiptail --inputbox "请输入 TF2 服务器路径:\n（默认为: $tf_server_dir）" 10 70 "$tf_server_dir" 3>&1 1>&2 2>&3)
    tf_path=${tf_path:-$tf_server_dir}
    
    # 创建配置文件目录
    if [ ! -d "$cfg_dir" ]; then
        mkdir -p "$cfg_dir"
    fi
    
    # 创建服务器配置文件
    if [ ! -f "$cfg_dir/$config_name" ]; then
        cat > "$cfg_dir/$config_name" << EOF
// Team Fortress 2 Classified 服务器配置
// 显示在服务器浏览器和计分版的服务器名字
hostname "Team Fortress 2 Classified 服务器"
// 是否需要给服务器上密码,留空即无密码
sv_password ""
// 使用控制台rcon的密码,玩家(或者网站/软件)可以通过这个直接向服务器发送相关指令(必须要填写的)
rcon_password "$(openssl rand -hex 30)"
// 控制台作弊(0/1)
sv_cheats "0"
// 允许玩家使用自定义的内容-1/0/1/2)
sv_pure "0"
EOF
        chown "$STEAM_USER:$STEAM_USER" "$cfg_dir/$config_name"
    fi
    
    # 创建启动脚本
    msg_info "正在创建 Team Fortress 2 Classified 启动脚本..."
    cat > "$script_file" << EOF
#!/bin/bash
./srcds_linux64 \
    -tf_path "$tf_path" \
    +ip "0.0.0.0" \
    -port "$default_port" \
    +maxplayers "24" \
    +map "$default_map" \
    +exec "$config_name"
EOF
    
    msg_info "Team Fortress 2 Classified 启动脚本已创建"
}
