# Team Fortress 2
game_name="Team Fortress 2"
game_app_id="232250"
game_short_name="tf"
game_default_map="cp_5gorge"

GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"

install_dependencies_tf() {
    msg_info "开始安装 Team Fortress 2 额外依赖..."
    
    # 检查是否是 Ubuntu/Debian 系统
    if grep -q "ubuntu\|debian" /etc/os-release; then
        msg_info "检测到 Debian/Ubuntu 系统，正在安装额外的依赖包..."
        
        # 检查 axel 是否安装
        if ! command -v axel &> /dev/null; then
            msg_warn "未找到 axel 下载工具，正在安装..."
            apt-get update
            apt-get install -y axel
        fi
        
        # 下载必要的依赖包
        msg_info "正在下载 libtinfo5 和 libncurses5 依赖包..."
        axel -q -n 5 "http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb"
        axel -q -n 5 "http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2ubuntu0.1_amd64.deb"
        
        # 安装依赖包
        msg_info "正在安装依赖包..."
        apt-get install -y ./libtinfo5_6.3-2ubuntu0.1_amd64.deb ./libncurses5_6.3-2ubuntu0.1_amd64.deb
        
        # 清理下载的文件
        msg_info "正在清理临时文件..."
        rm -f ./libtinfo5_6.3-2ubuntu0.1_amd64.deb ./libncurses5_6.3-2ubuntu0.1_amd64.deb
        
        msg_ok "Team Fortress 2 依赖包安装完成"
    else
        msg_info "当前系统不是 Debian/Ubuntu，跳过依赖包安装"
    fi
    
    msg_ok "Team Fortress 2 额外依赖安装完成"
}