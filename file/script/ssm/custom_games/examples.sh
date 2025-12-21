#!/bin/bash

###############################################################################
# 自定义游戏脚本编写示例
# 文件名: examples.sh
# 用途: 展示如何编写自定义游戏脚本的完整示例
# 注意: 这只是一个示例文件，请不要实际安装或使用
###############################################################################

# =============================================================================
# 1. 游戏信息注册 - 这是必须的部分
# =============================================================================

# 游戏显示名称和对应的 Steam App ID
# 格式: GAME_APPS["游戏显示名称"]="Steam App ID"
GAME_APPS["自定义游戏示例[切勿安装]"]="730"

# 游戏短名称（用于函数命名和内部标识）
# 格式: GAME_SHORT_NAMES["游戏显示名称"]="短名称"
GAME_SHORT_NAMES["自定义游戏示例[切勿安装]"]="examples"

# =============================================================================
# 2. 专属依赖安装函数 - 可选，但推荐实现
# =============================================================================

# 函数命名规则: install_dependencies_[短名称]
# 参数: 无
# 返回值: 无，但应该使用 msg_* 函数输出信息
install_dependencies_examples() {
    msg_info "开始安装 自定义游戏示例 专用依赖..."
    
    # 根据操作系统类型安装不同的依赖包
    case "$OS_INFO" in
        *ubuntu*|*debian*)
            # Ubuntu/Debian 系统
            msg_info "检测到 Debian/Ubuntu 系，正在安装依赖包..."
            apt-get update
            apt-get install -y \
                libicu-dev \
                libssl-dev \
                libcurl4-openssl-dev \
                zlib1g-dev
            ;;
            
        *centos*|*almalinux*|*fedora*|*rhel*)
            # RHEL 系系统
            msg_info "检测到 RHEL 系，正在安装依赖包..."
            yum install -y \
                openssl-libs \
                krb5-libs \
                zlib \
                libicu \
                libcurl-devel
            ;;
            
        *arch*)
            # Arch Linux 系统
            msg_info "检测到 Arch Linux，正在安装依赖包..."
            pacman -Sy --noconfirm \
                icu \
                openssl \
                zlib \
                curl
            ;;
            
        *)
            # 其他未定义的系统
            msg_warn "当前系统 ($OS_INFO) 未定义专属依赖，尝试跳过..."
            msg_info "如果游戏运行出现问题，请检查是否需要额外依赖"
            ;;
    esac
    
    # 检查安装是否成功
    if [ $? -eq 0 ]; then
        msg_ok "自定义游戏示例 依赖安装完成"
    else
        msg_error "依赖安装过程中出现错误"
        return 1
    fi
}

# =============================================================================
# 3. 自定义启动脚本函数 - 可选，用于覆盖默认启动脚本
# =============================================================================

# 函数命名规则: override_start_script_[短名称]
# 参数: 
#   $1 - 服务器安装目录路径
#   $2 - 启动脚本文件路径
# 返回值: 无
override_start_script_examples() {
    local server_dir="$1"
    local script_file="$2"
    
    msg_info "正在生成自定义启动脚本..."
    
    # 创建启动脚本内容
    cat > "$script_file" << 'EOF'
#!/bin/bash
# 自定义游戏示例 - 启动脚本
# 这是一个示例启动脚本，展示了各种常见配置

# 设置环境变量
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:./bin/linux64"

# 切换到游戏可执行文件目录
cd "$SERVER_DIR/game/bin/linuxsteamrt64"

# 检查可执行文件是否存在
if [ ! -f "./game_server" ]; then
    echo "错误: 找不到游戏可执行文件"
    exit 1
fi

# 设置服务器参数
SERVER_NAME="${SERVER_NAME:-My Custom Server}"
MAX_PLAYERS="${MAX_PLAYERS:-24}"
MAP="${MAP:-de_dust2}"
PORT="${PORT:-27015}"

# 启动游戏服务器
exec ./game_server \
    -dedicated \
    -console \
    -usercon \
    +hostname "$SERVER_NAME" \
    +maxplayers "$MAX_PLAYERS" \
    +map "$MAP" \
    +port "$PORT" \
    +sv_lan 0 \
    "$@"
EOF
    
    # 设置脚本可执行权限
    chmod +x "$script_file"
    
    msg_ok "自定义启动脚本生成完成"
}

# =============================================================================
# 4. 自定义配置生成函数 - 可选，用于生成游戏配置文件
# =============================================================================

# 函数命名规则: override_config_gen_[短名称]
# 参数:
#   $1 - 服务器安装目录路径
# 返回值: 无
override_config_gen_examples() {
    local server_dir="$1"
    local cfg_dir="$server_dir/game/cfg"
    
    msg_info "正在生成游戏配置文件..."
    
    # 创建配置目录（如果不存在）
    mkdir -p "$cfg_dir"
    
    # 生成主配置文件
    local main_cfg="$cfg_dir/server.cfg"
    cat > "$main_cfg" << 'EOF'
// 自定义游戏示例 - 服务器配置文件
// 这是一个示例配置文件

// 基本服务器设置
hostname "My Custom Game Server"
rcon_password "changeme123"
sv_password ""

// 游戏设置
mp_maxrounds 30
mp_timelimit 0
mp_autoteambalance 1
mp_autokick 0

// 网络设置
sv_maxrate 0
sv_minrate 196608
sv_maxupdaterate 128
sv_minupdaterate 64

// 反作弊设置
sv_cheats 0
sv_lan 0

// 日志设置
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
sv_log_onefile 0

// 管理员设置
// 添加管理员 SteamID
echo "配置文件加载完成"
EOF
    
    # 生成地图循环配置文件
    local mapcycle_cfg="$cfg_dir/mapcycle.txt"
    cat > "$mapcycle_cfg" << 'EOF'
de_dust2
de_inferno
de_mirage
de_nuke
de_train
de_overpass
de_vertigo
EOF
    
    msg_ok "游戏配置文件生成完成"
}