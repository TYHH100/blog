#!/bin/bash

# 添加颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色
BOLD='\033[1m'
PLAIN='\033[0m'
WORKING='\033[1;33m[*]\033[0m'
OK='\033[1;32m[✓]\033[0m'
FAIL='\033[1;31m[✗]\033[0m'
WARN='\033[1;33m[!]\033[0m'
TIP='\033[1;34m[Tip]\033[0m'

# 游戏映射
declare -A GAME_APPS=(
    ["Team Fortress 2"]="232250"
    ["Left 4 Dead 2"]="222860"
    ["No More Room in Hell"]="317670"
    ["Garry's Mod"]="4020"
    ["Counter-Strike: Source"]="232330"
)

# 游戏短名称映射
declare -A GAME_SHORT_NAMES=(
    ["Team Fortress 2"]="tf"
    ["Left 4 Dead 2"]="left4dead2"
    ["No More Room in Hell"]="nmrih"
    ["Garry's Mod"]="garrysmod"
    ["Counter-Strike: Source"]="cstrike"
)

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[Error]${NC} 需要root权限运行此脚本！"
        echo -e "请执行: sudo $0"
        exit 1
    fi
}

# 获取用户输入
get_user_input() {
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}       自动安装服务器配置             ${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e ""
    
    # 获取游戏名称
    while true; do
        echo -e "${CYAN}请选择要安装的游戏:${NC}"
        echo -e "${CYAN}[1]${NC} Team Fortress 2 (TF2)"
        echo -e "${CYAN}[2]${NC} Left 4 Dead 2 (L4D2)"
        echo -e "${CYAN}[3]${NC} No More Room in Hell (NMRIH)"
        echo -e "${CYAN}[4]${NC} Garry's Mod (GMod)"
        echo -e "${CYAN}[5]${NC} Counter-Strike: Source (CSS)"
        echo -e ""
        read -p "请输入选择 [1-5]: " game_choice
        
        case $game_choice in
            1) GAME_NAME="Team Fortress 2"; break ;;
            2) GAME_NAME="Left 4 Dead 2"; break ;;
            3) GAME_NAME="No More Room in Hell"; break ;;
            4) GAME_NAME="Garry's Mod"; break ;;
            5) GAME_NAME="Counter-Strike: Source"; break ;;
            *) echo -e "${RED}[Error]${NC} 无效的选择，请输入1-5的数字" ;;
        esac
    done
    
    echo -e ""
    
    # 获取用户名
    while true; do
        read -p "请输入游戏服务器账户名: " STEAM_USER
        if [ -n "$STEAM_USER" ]; then
            break
        else
            echo -e "${RED}[Error]${NC} 用户名不能为空"
        fi
    done
    
    # 获取别名
    echo -e ""
    read -p "请输入服务器别名（用于系统服务和别名）: " SERVER_ALIAS
    if [ -z "$SERVER_ALIAS" ]; then
        SERVER_ALIAS="${GAME_SHORT_NAMES[$GAME_NAME]}_server"
        echo -e "${BLUE}[Info]${NC} 使用默认别名: $SERVER_ALIAS"
    fi
    
    # 设置默认安装目录
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    SERVER_DIR="/home/$STEAM_USER/${game_short_name}_server"
    
    echo -e ""
    echo -e "${GREEN}配置信息:${NC}"
    echo -e "游戏: $GAME_NAME"
    echo -e "用户: $STEAM_USER"
    echo -e "别名: $SERVER_ALIAS"
    echo -e "安装目录: $SERVER_DIR"
    echo -e ""
    
    read -p "确认配置信息? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[Info]${NC} 安装已取消"
        exit 0
    fi
}

# 检测操作系统
detect_os() {
    OS_INFO="未知系统"
    
    # 尝试使用/etc/os-release文件
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_INFO="$ID $VERSION_ID"
    
    # 尝试使用lsb_release命令
    elif command -v lsb_release >/dev/null 2>&1; then
        OS_INFO=$(lsb_release -si)" "$(lsb_release -sr)
    
    # 尝试CentOS特定的发布文件
    elif [ -f /etc/centos-release ]; then
        OS_INFO=$(cat /etc/centos-release | awk '{print $1" "$3}')
    
    # 尝试Red Hat特定的发布文件
    elif [ -f /etc/redhat-release ]; then
        OS_INFO=$(cat /etc/redhat-release | awk '{print $1" "$3}')

    # 尝试Alma Linux特定的发布文件
    elif [ -f /etc/almalinux-release ]; then
        OS_INFO=$(cat /etc/almalinux-release | awk '{print $1" "$3}')
    
    # 尝试Debian版本文件
    elif [ -f /etc/debian_version ]; then
        OS_INFO="Debian "$(cat /etc/debian_version)

    elif command -v pacman >/dev/null 2>&1; then
        OS_INFO="arch"
    
    # 尝试其他Linux发行版
    elif [ -f /etc/issue ]; then
        OS_INFO=$(head -n 1 /etc/issue | awk '{print $1" "$2}')
    fi
    
    # 清理输出中的特殊字符
    OS_INFO=$(echo "$OS_INFO" | tr -d '\r\n\\')
}

enable_multilib() {
    # 检查multilib仓库是否已启用
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        # 启用multilib仓库
        echo -e "${BLUE}[Info]${NC} 启用Arch Linux的multilib仓库..."
        #sed -i.bak -e 's/^#\s*\[multilib\]/[multilib]/' -e 's/^#\s*Include\s*=\s*\/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
        cp /etc/pacman.conf /etc/pacman.conf.bak
        echo [multilib] >> /etc/pacman.conf
        echo Include = /etc/pacman.d/mirrorlist >> /etc/pacman.conf
        # 更新软件包列表
        pacman -Sy
    fi
}

# 安装AUR包
install_aur_package() {
    local pkg_name=$1
    local build_dir="/tmp/aur_build_$pkg_name"

    # 检查是否已安装
    if pacman -Qq $pkg_name &>/dev/null; then
        echo -e "${BLUE}[Info]${NC} $pkg_name 已安装"
        return 0
    fi

    # 尝试安装预构建包
    if [ "$pkg_name" = "lib32-ncurses5-compat-libs" ]; then
        local prebuilt_url="https://blog.tyhh10.xyz/file/arch-zst-file/lib32-ncurses5-compat-libs-6.5-3-x86_64.pkg.tar.zst"
        local temp_pkg="/tmp/lib32-ncurses5-compat-libs.pkg.tar.zst"
        
        echo -e "${BLUE}[Info]${NC} 尝试安装预构建包: $pkg_name"
        axel -q -n 10 "$prebuilt_url" -o "$temp_pkg"
        
        if [ -f "$temp_pkg" ]; then
            pacman -U --noconfirm --overwrite=* "$temp_pkg" >/dev/null 2>&1
            rm -f "$temp_pkg"
            
            if pacman -Qq $pkg_name &>/dev/null; then
                echo -e "${BLUE}[Info]${NC} 预构建包安装成功: $pkg_name"
                return 0
            else
                echo -e "${YELLOW}[Warning]${NC} 预构建包安装失败，尝试从AUR构建"
            fi
        else
            echo -e "${YELLOW}[Warning]${NC} 无法下载预构建包，尝试从AUR构建"
        fi
    fi

    # 创建构建目录
    mkdir -p "$build_dir"
    cd "$build_dir"

    # 下载AUR包
    if [ ! -d "$build_dir/.git" ]; then
        if ! git clone "https://aur.archlinux.org/$pkg_name.git" .; then
            echo -e "${RED}[Error]${NC} 无法下载 $pkg_name"
            return 1
        fi
    else
        echo -e "${BLUE}[Info]${NC} $pkg_name 已存在，跳过下载"
    fi

    # 如果是root，自动创建临时用户
    if [ "$(id -u)" -eq 0 ]; then
        local aur_tmp_user="aurbuild_tmp"
        # 如果用户已存在先杀掉进程再删除（忽略警告）
        if id "$aur_tmp_user" &>/dev/null; then
            pkill -u "$aur_tmp_user" 2>/dev/null
            userdel -f -r "$aur_tmp_user" 2>/dev/null
        fi
        
        # 创建临时用户
        useradd -m -s /bin/bash "$aur_tmp_user"
        chown -R "$aur_tmp_user":"$aur_tmp_user" "$build_dir"
        
        # 临时添加免密码sudo权限
        echo "$aur_tmp_user ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/aurbuild_tmp
        chmod 0440 /etc/sudoers.d/aurbuild_tmp
        
        # 构建包（跳过PGP验证）
        su - "$aur_tmp_user" -c "cd '$build_dir' && makepkg -sri --noconfirm --skippgpcheck"
        
        # 删除临时用户（忽略警告）
        pkill -u "$aur_tmp_user" 2>/dev/null
        userdel -f -r "$aur_tmp_user" 2>/dev/null
        rm -f /etc/sudoers.d/aurbuild_tmp
    else
        # 非root直接构建（跳过PGP验证）
        makepkg -sri --noconfirm --skippgpcheck
    fi

    # 检查安装结果
    if pacman -Qq $pkg_name &>/dev/null; then
        echo -e "${BLUE}[Info]${NC} $pkg_name 安装成功"
        return 0
    else
        echo -e "${RED}[Error]${NC} $pkg_name 安装失败"
        return 1
    fi
}

# 安装依赖
install_dependencies() {
    local packages=()
    if [[ "$OS_INFO" == *"ubuntu"* ]] || [[ "$OS_INFO" == *"debian"* ]]; then
        # Debian/Ubuntu 依赖
        packages=(
            lib32z1 libbz2-1.0:i386 lib32gcc-s1 lib32stdc++6 libcurl3-gnutls:i386 libsdl2-2.0-0:i386 zlib1g:i386 screen unzip axel
        )
    elif [[ "$OS_INFO" == *"centos"* ]] || [[ "$OS_INFO" == *"rhel"* ]] || [[ "$OS_INFO" == *"almalinux"* ]]; then
        # CentOS/RHEL 依赖
        packages=(
            glibc.i686 libstdc++.i686 libcurl.i686 zlib.i686 ncurses-libs.i686 libgcc.i686 screen unzip axel
        )
    elif [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
        # 确保multilib仓库已启用
        enable_multilib

        # Arch Linux 依赖
        packages=(
            lib32-gcc-libs lib32-libcurl-gnutls lib32-openssl screen vim git sudo base-devel unzip axel
        )
    else
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "不支持的操作系统：$OS_INFO" 10 60
        else
            echo -e "${RED}[Error]${NC} 不支持的操作系统：$OS_INFO"
        fi
        exit 1
    fi
    
    if [ "$USE_WHIPTAIL" = true ]; then
        {
            for ((i=0; i<${#packages[@]}; i++)); do
                pkg="${packages[$i]}"
                echo $((i * 100 / ${#packages[@]}))
                echo -e "${BLUE}[Info]${NC} 安装依赖: $pkg"

                # 根据不同系统检查是否已安装
                if [[ "$OS_INFO" == *"ubuntu"* || "$OS_INFO" == *"debian"* ]]; then
                    # Debian/Ubuntu: 检查包是否存在
                    if ! dpkg -l | grep -q "^ii.*${pkg%%:*}"; then
                        # 安装前确保启用了i386架构
                        [ "$i" -eq 0 ] && dpkg --add-architecture i386
                        apt-get update
                        apt-get install -y "$pkg"
                    fi
                elif [[ "$OS_INFO" == *"arch"* || "$OS_INFO" == *"manjaro"* || "$OS_INFO" == *"artix"* ]]; then
                    # Arch Linux: 检查包是否存在
                    if ! pacman -Qi "$pkg" &>/dev/null; then
                        # 安装包
                        pacman -S --needed --noconfirm "$pkg" > /dev/null 2>&1
                    fi
                else
                    # CentOS/RHEL: 检查包是否存在
                    if ! rpm -q "${pkg}" >/dev/null 2>&1; then
                        yum install -y "${pkg}"
                    fi
                fi
            done
        } | whiptail --title "安装依赖" --gauge "正在安装游戏服务器依赖..." 8 70 0
    else
        # 无whiptail模式
        echo -e "${BLUE}[Info]${NC} 正在安装游戏服务器依赖..."
        for ((i=0; i<${#packages[@]}; i++)); do
            pkg="${packages[$i]}"
            echo -e "${YELLOW}[$((i+1))/${#packages[@]}]${NC} 安装依赖: $pkg"

            # 根据不同系统检查是否已安装
            if [[ "$OS_INFO" == *"ubuntu"* || "$OS_INFO" == *"debian"* ]]; then
                # Debian/Ubuntu: 检查包是否存在
                if ! dpkg -l | grep -q "^ii.*${pkg%%:*}"; then
                    # 安装前确保启用了i386架构
                    [ "$i" -eq 0 ] && dpkg --add-architecture i386
                    apt-get update
                    apt-get install -y "$pkg"
                fi
            elif [[ "$OS_INFO" == *"arch"* || "$OS_INFO" == *"manjaro"* || "$OS_INFO" == *"artix"* ]]; then
                # Arch Linux: 检查包是否存在
                if ! pacman -Qi "$pkg" &>/dev/null; then
                    # 安装包
                    pacman -S --needed --noconfirm "$pkg" > /dev/null 2>&1
                fi
            else
                # CentOS/RHEL: 检查包是否存在
                if ! rpm -q "${pkg}" >/dev/null 2>&1; then
                    yum install -y "${pkg}"
                fi
            fi
        done
        echo -e "${GREEN}[Success]${NC} 依赖安装完成"
    fi

    # 为Arch Linux安装额外的AUR依赖
    if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --infobox "正在安装额外的AUR依赖: lib32-ncurses5-compat-libs..." 7 70
            if install_aur_package "lib32-ncurses5-compat-libs"; then
                whiptail --title "安装成功" --msgbox "AUR包 lib32-ncurses5-compat-libs 已安装" 8 70
            else
                whiptail --title "安装失败" --msgbox "无法安装 lib32-ncurses5-compat-libs，服务器可能无法正常运行" 8 70
            fi
        else
            echo -e "${BLUE}[Info]${NC} 正在安装额外的AUR依赖: lib32-ncurses5-compat-libs..."
            if install_aur_package "lib32-ncurses5-compat-libs"; then
                echo -e "${GREEN}[Success]${NC} AUR包 lib32-ncurses5-compat-libs 已安装"
            else
                echo -e "${RED}[Error]${NC} 无法安装 lib32-ncurses5-compat-libs，服务器可能无法正常运行"
            fi
        fi
    fi
}

# 创建用户
create_user() {
    if ! id "$STEAM_USER" &>/dev/null; then
        echo -e "${YELLOW}[Warning]${NC} 用户 '$STEAM_USER' 不存在，正在创建..."
        useradd -m -s /bin/bash "$STEAM_USER"
        local password=$(openssl rand -base64 12)
        echo "$STEAM_USER:$password" | chpasswd
        echo -e "${GREEN}[Success]${NC} 已创建用户 '$STEAM_USER'"
        echo -e "${GREEN}[Success]${NC} 密码: $password"
        
        # 设置用户组权限
        usermod -aG sudo "$STEAM_USER" 2>/dev/null || true
    else
        echo -e "${BLUE}[Info]${NC} 用户 '$STEAM_USER' 已存在"
    fi
    
    # 设置账户主目录
    STEAM_HOME=$(eval echo ~$STEAM_USER)
}

# 安装SteamCMD
install_steamcmd() {
    echo -e "${BLUE}[Info]${NC} 开始安装SteamCMD..."
    
    mkdir -p "$STEAM_HOME/steamcmd"
    cd "$STEAM_HOME/steamcmd"
    wget -q https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xf steamcmd_linux.tar.gz
    rm steamcmd_linux.tar.gz
    chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
    
    STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
    echo -e "${GREEN}[Success]${NC} SteamCMD已安装到: $STEAMCMD_PATH"
}

# 创建服务器目录
create_server_dir() {
    if [ ! -d "$SERVER_DIR" ]; then
        echo -e "${BLUE}[Info]${NC} 创建服务器目录: $SERVER_DIR"
        mkdir -p "$SERVER_DIR"
    else
        echo -e "${BLUE}[Info]${NC} 服务器目录已存在: $SERVER_DIR"
    fi
    
    # 确保目录权限正确
    chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
    chmod 755 "$SERVER_DIR"
    echo -e "${GREEN}[Success]${NC} 已设置服务器目录权限"
}

# 安装游戏服务器
install_game_server() {
    echo -e "${BLUE}[Info]${NC} 开始安装游戏服务器..."
    
    local app_id="${GAME_APPS[$GAME_NAME]}"
    if [ -z "$app_id" ]; then
        echo -e "${RED}[Error]${NC} 不支持的游戏: $GAME_NAME"
        exit 1
    fi
    
    # 创建日志文件
    local log_file="$SERVER_DIR/install.log"
    
    echo -e "${BLUE}[Info]${NC} 正在下载安装 $GAME_NAME 服务器..."
    echo -e "此过程可能需要一些时间，请耐心等待。"
    
    # 执行安装
    if [ "$app_id" == "222860" ]; then
        # L4D2的特殊安装方式
        echo -e "${YELLOW}[Step 1/2]${NC} 正在下载Windows版本文件..."
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
        
        echo -e "\n${YELLOW}[Step 2/2]${NC} 正在下载Linux版本文件..."
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    else
        # 其他游戏正常安装
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    fi
    
    # 检查安装结果
    if grep -qi "Success!" "$log_file"; then
        echo -e "\n${GREEN}[Success]${NC} 成功安装 $GAME_NAME 服务器到: $SERVER_DIR"
        echo -e "安装日志已保存至: $SERVER_DIR/install.log"
    else
        echo -e "\n${RED}[Error]${NC} 安装失败!"
        echo -e "错误日志已保存至: $SERVER_DIR/install.log"
        exit 1
    fi
}

# 创建启动脚本
create_start_script() {
    local start_script="$SERVER_DIR/start.sh"
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    local app_id="${GAME_APPS[$GAME_NAME]}"
    
    echo -e "${BLUE}[Info]${NC} 创建启动脚本: $start_script"
    
    # 生成随机端口
    local default_port=$(( RANDOM % 1000 + 27015 ))
    
    # 游戏特定的默认地图
    local default_map=""
    case "$GAME_NAME" in
        "Team Fortress 2") default_map="cp_5gorge" ;;
        "Left 4 Dead 2") default_map="c2m1_highway" ;;
        "No More Room in Hell") default_map="nmo_broadway" ;;
        "Garry's Mod") default_map="gm_construct" ;;
        "Counter-Strike: Source") default_map="de_dust2" ;;
        *) default_map="dm_mario_kart" ;;
    esac
    
    # Garry's Mod 特殊处理
    local gmod_workshop_collection=""
    local gmod_gamemode=""
    if [ "$GAME_NAME" = "Garry's Mod" ]; then
        gmod_workshop_collection="+host_workshop_collection 0 "
        gmod_gamemode="+gamemode sandbox "
    fi
    
    # SteamCMD 目录和更新脚本
    local steamcmd_dir=$(dirname "$STEAMCMD_PATH")
    local game_update="$steamcmd_dir/$game_short_name-update.txt"
    
    # 创建更新脚本
    cat > "$game_update" << EOF
login anonymous \\
force_install_dir "$SERVER_DIR" \\
app_update $app_id \\
quit
EOF
    
    # 创建启动脚本
    cat > "$start_script" << EOF
#!/bin/bash
# 服务器参数
./srcds_run \\
    -game $game_short_name \\
    -console \\
    $gmod_workshop_collection \\
    $gmod_gamemode \\
    +ip 0.0.0.0 \\
    -port $default_port \\
    +maxplayers 16 \\
    +map $default_map \\
    -autoupdate \\
    -steam_dir $steamcmd_dir \\
    -steamcmd_script $game_update
EOF
    
    chmod +x "$start_script"
    chown "$STEAM_USER:$STEAM_USER" "$start_script"
    echo -e "${GREEN}[Success]${NC} 启动脚本已创建"
}

# 创建server.cfg配置文件
create_server_cfg() {
    local cfg_file="$SERVER_DIR/cfg/server.cfg"
    
    echo -e "${BLUE}[Info]${NC} 创建server.cfg配置文件: $cfg_file"
    
    mkdir -p "$(dirname "$cfg_file")"
    
    cat > "$cfg_file" << EOF
// $GAME_NAME 服务器配置文件
// 创建于: $(date)

// 服务器基本信息
hostname "$GAME_NAME 专用服务器"
sv_contact "admin@example.com"
sv_region 255 // 全球

// 网络设置
sv_maxrate 0
sv_minrate 0
sv_maxupdaterate 66
sv_minupdaterate 10
sv_maxcmdrate 66
sv_mincmdrate 10

// 游戏设置
mp_timelimit 30
mp_maxrounds 0
mp_winlimit 0
mp_fraglimit 0

// 反作弊
sv_cheats 0
sv_allowupload 1
sv_allowdownload 1

// 日志记录
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
sv_log_onefile 0

// RCON设置
rcon_password "changeme123"

// 其他设置
sv_lan 0
sv_password ""

// 执行其他配置文件
exec banned_user.cfg
exec banned_ip.cfg
EOF
    
    chown "$STEAM_USER:$STEAM_USER" "$cfg_file"
    echo -e "${GREEN}[Success]${NC} server.cfg配置文件已创建"
}

# 创建系统服务
create_system_service() {
    local service_file="/etc/systemd/system/${SERVER_ALIAS}.service"
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    
    echo -e "${BLUE}[Info]${NC} 创建系统服务: $service_file"
    
    # 根据游戏类型设置启动参数
    case "$game_short_name" in
        "tf")
            PARAMS="-game tf -console -usercon +map cp_dustbowl +maxplayers 24"
            ;;
        "left4dead2")
            PARAMS="-game left4dead2 -console -usercon +map c1m1_hotel +maxplayers 8"
            ;;
        "nmrih")
            PARAMS="-game nmrih -console -usercon +map nmo_broadway +maxplayers 8"
            ;;
        "garrysmod")
            PARAMS="-game garrysmod -console -usercon +map gm_construct +maxplayers 16"
            ;;
        "cstrike")
            PARAMS="-game cstrike -console -usercon +map de_dust2 +maxplayers 32"
            ;;
        *)
            PARAMS="-console -usercon"
            ;;
    esac
    
    cat > "$service_file" << EOF
[Unit]
Description=$GAME_NAME 专用服务器
After=network.target

[Service]
Type=simple
User=$STEAM_USER
Group=$STEAM_USER
WorkingDirectory=$SERVER_DIR
ExecStart=$SERVER_DIR/srcds_run $PARAMS
ExecStop=/bin/kill -INT \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=$SERVER_DIR
ReadOnlyPaths=/usr /lib /lib64 /bin /sbin

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    systemctl daemon-reload
    systemctl enable "${SERVER_ALIAS}.service"
    
    echo -e "${GREEN}[Success]${NC} 系统服务已创建并启用"
    echo -e "${BLUE}[Info]${NC} 服务管理命令:"
    echo -e "启动服务: sudo systemctl start ${SERVER_ALIAS}"
    echo -e "停止服务: sudo systemctl stop ${SERVER_ALIAS}"
    echo -e "查看状态: sudo systemctl status ${SERVER_ALIAS}"
    echo -e "查看日志: journalctl -u ${SERVER_ALIAS} -f"
}

# 创建别名
create_aliases() {
    local alias_file="/etc/profile.d/${SERVER_ALIAS}_aliases.sh"
    
    echo -e "${BLUE}[Info]${NC} 创建别名文件: $alias_file"
    
    cat > "$alias_file" << EOF
# $GAME_NAME 服务器管理别名
# 创建于: $(date)

alias ${SERVER_ALIAS}_start="sudo systemctl start ${SERVER_ALIAS}"
alias ${SERVER_ALIAS}_stop="sudo systemctl stop ${SERVER_ALIAS}"
alias ${SERVER_ALIAS}_status="sudo systemctl status ${SERVER_ALIAS}"
alias ${SERVER_ALIAS}_restart="sudo systemctl restart ${SERVER_ALIAS}"
alias ${SERVER_ALIAS}_logs="journalctl -u ${SERVER_ALIAS} -f"
alias ${SERVER_ALIAS}_update="su - $STEAM_USER -c 'cd $SERVER_DIR && $STEAMCMD_PATH +force_install_dir $SERVER_DIR +login anonymous +app_update ${GAME_APPS[$GAME_NAME]} validate +quit'"

# 手动启动命令
alias ${SERVER_ALIAS}_manual="su - $STEAM_USER -c 'cd $SERVER_DIR && ./start.sh'"

# 显示可用别名
alias ${SERVER_ALIAS}_help="echo '可用别名:' && alias | grep ${SERVER_ALIAS}_"
EOF
    
    chmod 644 "$alias_file"
    
    echo -e "${GREEN}[Success]${NC} 别名已创建"
    echo -e "${BLUE}[Info]${NC} 重新登录或执行 'source /etc/profile' 后生效"
    echo -e "${BLUE}[Info]${NC} 可用别名:"
    echo -e "  ${SERVER_ALIAS}_start    - 启动服务器"
    echo -e "  ${SERVER_ALIAS}_stop     - 停止服务器"
    echo -e "  ${SERVER_ALIAS}_status   - 查看服务器状态"
    echo -e "  ${SERVER_ALIAS}_restart  - 重启服务器"
    echo -e "  ${SERVER_ALIAS}_logs     - 查看服务器日志"
    echo -e "  ${SERVER_ALIAS}_update   - 更新服务器"
    echo -e "  ${SERVER_ALIAS}_manual   - 手动启动服务器"
    echo -e "  ${SERVER_ALIAS}_help     - 显示所有别名"

    source /etc/profile
}

# 保存配置
save_config() {
    local config_file="/etc/Source_Dedicated_Server.conf"
    
    echo -e "${BLUE}[Info]${NC} 保存配置到: $config_file"
    
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# 服务器管理脚本配置文件
# 创建于: $(date)

# 游戏服务器账户
CONFIG_STEAM_USER="$STEAM_USER"
# 游戏名称 (tf2, l4d2, nmrih, gmod, css)
CONFIG_GAME_NAME="$GAME_NAME"
# 游戏服务器安装目录
CONFIG_SERVER_DIR="$SERVER_DIR"
# SteamCMD路径
CONFIG_STEAMCMD_PATH="$STEAMCMD_PATH"
# 服务器别名
CONFIG_SERVER_ALIAS="$SERVER_ALIAS"
EOF
    
    echo -e "${GREEN}[Success]${NC} 配置已保存"
}

# 主函数
main() {
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}       自动安装服务器脚本             ${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e ""
    
    # 检查root权限
    check_root
    
    # 获取用户输入
    get_user_input
    
    # 1. 检查操作系统
    detect_os
    
    # 2. 安装依赖
    install_dependencies
    
    # 3. 创建用户
    create_user
    
    # 4. 安装SteamCMD
    install_steamcmd
    
    # 5. 创建服务器目录
    create_server_dir
    
    # 6. 安装游戏服务器
    install_game_server
    
    # 7. 创建启动脚本
    create_start_script
    
    # 8. 创建server.cfg配置文件
    create_server_cfg
    
    # 9. 创建系统服务
    create_system_service
    
    # 10. 创建别名
    create_aliases
    
    # 11. 保存配置
    save_config
    
    # 12. 完成安装
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}       安装完成！                    ${NC}"
    echo -e "${GREEN}====================================${NC}\n"
    echo -e "${NC} 用户 '$STEAM_USER'"
    echo -e "${NC} 密码: $password"
    echo -e "${NC} 游戏名称: $GAME_NAME"
    echo -e "${NC} 游戏服务器安装目录: $SERVER_DIR"
    echo -e "${NC} SteamCMD路径: $STEAMCMD_PATH"
    echo -e "${NC} 服务器别名: $SERVER_ALIAS"
    echo -e ""
    echo -e "${YELLOW}=== 服务器管理命令 ===${NC}"
    echo -e "启动服务器: sudo systemctl start ${SERVER_ALIAS}"
    echo -e "停止服务器: sudo systemctl stop ${SERVER_ALIAS}"
    echo -e "查看状态: sudo systemctl status ${SERVER_ALIAS}"
    echo -e "查看日志: journalctl -u ${SERVER_ALIAS} -f"
    echo -e "手动启动: ${SERVER_ALIAS}_manual"
    echo -e ""
    echo -e "${YELLOW}=== 别名使用说明 ===${NC}"
    echo -e "重新登录后可使用以下别名:"
    echo -e "  ${SERVER_ALIAS}_start    - 启动服务器"
    echo -e "  ${SERVER_ALIAS}_stop     - 停止服务器"
    echo -e "  ${SERVER_ALIAS}_status   - 查看服务器状态"
    echo -e "  ${SERVER_ALIAS}_restart  - 重启服务器"
    echo -e "  ${SERVER_ALIAS}_logs     - 查看服务器日志"
    echo -e "  ${SERVER_ALIAS}_update   - 更新服务器"
    echo -e "  ${SERVER_ALIAS}_manual   - 手动启动服务器"
    echo -e "  ${SERVER_ALIAS}_help     - 显示所有别名"
    echo -e ""
    echo -e "${GREEN}感谢使用自动安装脚本！${NC}"
}

# 执行主函数
main