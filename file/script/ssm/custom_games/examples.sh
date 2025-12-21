#!/bin/bash

# 1. 注册游戏信息
GAME_APPS["自定义游戏示例[切勿安装]"]="730"
GAME_SHORT_NAMES["自定义游戏示例[切勿安装]"]="examples"

# 2. 定义专属依赖安装函数
# 函数名必须是: install_dependencies_[短名称]
install_dependencies_cs2() {
    msg_info "开始安装 CS2 专用依赖..."

    if [[ "$OS_INFO" == *"ubuntu"* ]] || [[ "$OS_INFO" == *"debian"* ]]; then
        # Ubuntu/Debian 逻辑
        msg_info "检测到 Debian/Ubuntu 系，正在安装 libicu-dev 和 64位库..."
        apt-get install -y libicu-dev libssl-dev
        
    elif [[ "$OS_INFO" == *"centos"* ]] || [[ "$OS_INFO" == *"almalinux"* ]] || [[ "$OS_INFO" == *"fedora"* ]]; then
        # RHEL 系逻辑
        msg_info "检测到 RHEL 系，正在安装 openssl-libs..."
        yum install -y openssl-libs krb5-libs zlib
        
    elif [[ "$OS_INFO" == *"arch"* ]]; then
        # Arch Linux 逻辑
        msg_info "检测到 Arch Linux..."
        pacman -Sy --noconfirm icu openssl zlib
        
    else
        msg_warn "当前系统 ($OS_INFO) 未定义 CS2 专属依赖，尝试跳过..."
    fi
    
    msg_ok "CS2 依赖安装完成"
}

# 3. 自定义启动脚本 (同上文)
override_start_script_cs2() {
    local server_dir=$1
    local script_file=$2
    # CS2 启动逻辑...
    cat > "$script_file" << EOF
#!/bin/bash
cd "$server_dir/game/bin/linuxsteamrt64"
./cs2 -dedicated -console -usercon +game_type 0 +game_mode 1 +map de_dust2
EOF
}

# 4. 自定义配置生成 (同上文)
override_config_gen_cs2() {
    # CS2 配置生成逻辑...
    local cfg_path="$1/game/csgo/cfg/server.cfg"
    # ...生成文件代码...
}