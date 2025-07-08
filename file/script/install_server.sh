#!/bin/bash

# 检查whiptail是否安装，未安装则自动安装
if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail 未安装，正在尝试自动安装..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y whiptail
    elif command -v yum >/dev/null 2>&1; then
        yum install -y newt
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm libnewt
    else
        echo "无法自动安装 whiptail，请手动安装后重试。"
        exit 1
    fi
    # 再次检测
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "whiptail 安装失败，请手动安装后重试。"
        exit 1
    fi
fi

# 配置文件路径
CONFIG_FILE="/etc/Source_Dedicated_Server.conf"

# 初始化变量
STEAM_USER=""
STEAM_HOME=""
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
declare -A GAME_APPS=(
    ["Team Fortress 2"]="232250"
    ["Left 4 Dead 2"]="222860"
    ["No More Room in Hell"]="317670"
)
# 游戏短名称映射
declare -A GAME_SHORT_NAMES=(
    ["Team Fortress 2"]="tf"
    ["Left 4 Dead 2"]="left4dead2"
    ["No More Room in Hell"]="nmrih"
)
SERVER_DIR=""
GAME_NAME=""
OS_INFO=""
STEAMCMD_PATH=""

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        # 确保STEAM_USER存在
        if [ -n "$CONFIG_STEAM_USER" ] && id "$CONFIG_STEAM_USER" &>/dev/null; then
            STEAM_USER="$CONFIG_STEAM_USER"
            STEAM_HOME=$(eval echo ~$STEAM_USER)
        fi
        # 确保STEAMCMD_PATH存在
        if [ -n "$CONFIG_STEAMCMD_PATH" ] && [ -f "$CONFIG_STEAMCMD_PATH" ]; then
            STEAMCMD_PATH="$CONFIG_STEAMCMD_PATH"
        fi
        # 恢复游戏安装路径
        if [ -n "$CONFIG_GAME_NAME" ]; then
            GAME_NAME="$CONFIG_GAME_NAME"
        fi
        if [ -n "$CONFIG_SERVER_DIR" ] && [ -d "$CONFIG_SERVER_DIR" ]; then
            SERVER_DIR="$CONFIG_SERVER_DIR"
        fi
    fi
}

# 保存配置文件
save_config() {
    # 创建新配置文件
    cat > "$CONFIG_FILE" << EOF
    # 起源服务器安装器配置文件
    # 创建于: $(date)

    # 游戏服务器账户
    CONFIG_STEAM_USER="$STEAM_USER"

    # SteamCMD路径
    CONFIG_STEAMCMD_PATH="$STEAMCMD_PATH"

    # 上次安装的游戏
    CONFIG_GAME_NAME="$GAME_NAME"

    # 上次安装的游戏路径
    CONFIG_SERVER_DIR="$SERVER_DIR"
EOF
}

# 添加颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 重置颜色

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        whiptail --title "错误" --msgbox "此脚本需要以root权限运行！\n请使用sudo ./install_server.sh重新运行或者使用root账户" 8 60
        exit 1
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
        # 备份原始配置文件
        #cp /etc/pacman.conf /etc/pacman.conf.bak
        # 启用multilib仓库
        echo "启用Arch Linux的multilib仓库..."
        sed -i.bak -e 's/^#\s*\[multilib\]/[multilib]/' -e 's/^#\s*Include\s*=\s*\/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
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
        echo "$pkg_name 已安装"
        return 0
    fi

    # 创建构建目录
    mkdir -p "$build_dir"
    cd "$build_dir"

    # 下载AUR包
    if [ ! -d "$build_dir/.git" ]; then
        if ! git clone "https://aur.archlinux.org/$pkg_name.git" .; then
            echo "无法下载 $pkg_name"
            return 1
        fi
    else
        echo "$pkg_name 已存在，跳过下载"
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
        
        # GPG密钥导入（使用多个服务器+直接下载）
        #if gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys CC2AF4472167BE03 || \
        #   gpg --keyserver hkps://keys.openpgp.org --recv-keys CC2AF4472167BE03 || \
        #   gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys CC2AF4472167BE03; then
        #    echo "尝试从备用源下载GPG密钥..."
        #    curl -sL "https://invisible-island.net/public/dickey.gpg" | gpg --import -
        #fi
        
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
        echo "$pkg_name 安装成功"
        return 0
    else
        echo "$pkg_name 安装失败"
        return 1
    fi
}

# 安装依赖
install_dependencies() {
    local packages=()
    if [[ "$OS_INFO" == *"ubuntu"* ]] || [[ "$OS_INFO" == *"debian"* ]]; then
        # Debian/Ubuntu 依赖
        packages=(
            lib32z1 libbz2-1.0:i386 lib32gcc-s1 lib32stdc++6 libcurl3-gnutls:i386 libsdl2-2.0-0:i386 screen wget
        )
    elif [[ "$OS_INFO" == *"centos"* ]] || [[ "$OS_INFO" == *"rhel"* ]] || [[ "$OS_INFO" == *"almalinux"* ]]; then
        # CentOS/RHEL 依赖
        packages=(
            glibc.i686 libstdc++.i686 libcurl.i686 zlib.i686 ncurses-libs.i686 libgcc.i686 screen wget
        )
    elif [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
        # Arch Linux 依赖
        # 确保multilib仓库已启用
        enable_multilib
        
        packages=(
            lib32-gcc-libs lib32-libcurl-gnutls lib32-openssl wget screen vim git sudo base-devel
        )
    else
        whiptail --title "错误" --msgbox "不支持的操作系统：$OS_INFO" 10 60
        exit 1
    fi
    
    {
        for ((i=0; i<${#packages[@]}; i++)); do
            pkg="${packages[$i]}"
            echo $((i * 100 / ${#packages[@]}))
            echo -e "安装依赖: $pkg"
            
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

    # 为Arch Linux安装额外的AUR依赖
    if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
        whiptail --infobox "正在安装额外的AUR依赖: lib32-ncurses5-compat-libs..." 7 70
        if install_aur_package "lib32-ncurses5-compat-libs"; then
            whiptail --title "安装成功" --msgbox "AUR包 lib32-ncurses5-compat-libs 已安装" 8 70
        else
            whiptail --title "安装失败" --msgbox "无法安装 lib32-ncurses5-compat-libs，服务器可能无法正常运行" 8 70
        fi
    fi
}

# 设置服务器账户
set_server_user() {
    local users=$(awk -F':' '{ if ($3 >= 1000 && $3 <= 65534) print $1 }' /etc/passwd)
    local current_user=$(id -un)
    local user_list=""
    
    # 生成用户列表选项
    for user in $users; do
        user_list+="$user 已存在 "
    done
    
    # 如果已有配置，使用配置中的用户
    local default_user="$STEAM_USER"
    [ -z "$default_user" ] && default_user="gameserver"

    STEAM_USER=$(whiptail --title "选择游戏服务器账户" --menu "请选择用于运行游戏服务器的账户\n\n(推荐使用非root账户)" 20 60 10 \
        $user_list \
        "创建新账户" "" \
        3>&1 1>&2 2>&3)
    
    if [ -z "$STEAM_USER" ]; then
        return 1
    fi
    
    if [ "$STEAM_USER" == "创建新账户" ]; then
        STEAM_USER=$(whiptail --title "创建新账户" --inputbox "请输入新账户名称:" 8 60 "$default_user" 3>&1 1>&2 2>&3)
        if [ -z "$STEAM_USER" ]; then
            return 1
        fi
        
        # 检查账户是否已存在
        if id "$STEAM_USER" &>/dev/null; then
            whiptail --title "错误" --msgbox "账户 '$STEAM_USER' 已存在！" 8 60
            return 1
        fi
        
        # 创建新账户
        useradd -m -s /bin/bash "$STEAM_USER"
        local password=$(openssl rand -base64 12)
        echo "$STEAM_USER:$password" | chpasswd
        whiptail --title "账户创建成功" --msgbox "已创建用户 '$STEAM_USER' \n密码: $password" 10 60
    fi
    
    # 设置账户主目录
    STEAM_HOME=$(eval echo ~$STEAM_USER)
    
    # 添加当前用户到账户组（以便可以访问文件）
    if [ "$STEAM_USER" != "$current_user" ]; then
        usermod -aG $STEAM_USER $current_user
        chmod g+rX "$STEAM_HOME"
    fi
    
    # 确保steam目录存在
    mkdir -p "$STEAM_HOME"
    chown "$STEAM_USER:$STEAM_USER" "$STEAM_HOME"
    
    # 保存配置
    save_config
}

# 安装SteamCMD
install_steamcmd() {
    local choice=$(whiptail --title "SteamCMD 安装选项" --menu "请选择SteamCMD安装方式" 15 60 4 \
        "1" "自动安装最新版SteamCMD" \
        "2" "使用已安装的SteamCMD" 3>&1 1>&2 2>&3)
    
    case $choice in
        1)
            (
                mkdir -p "$STEAM_HOME/steamcmd"
                cd "$STEAM_HOME/steamcmd"
                wget -q "$STEAMCMD_URL"
                tar -xzf steamcmd_linux.tar.gz
                rm steamcmd_linux.tar.gz
                chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
                
                STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
                save_config
                whiptail --title "安装成功" --msgbox "SteamCMD 已安装到: $STEAMCMD_PATH" 8 70
            )
            ;;
        2)
            while true; do
                # 使用配置中的路径作为默认值
                local default_path="$STEAMCMD_PATH"
                [ -z "$default_path" ] && default_path="/usr/games/steamcmd/steamcmd.sh"
                
                local steam_path=$(whiptail --title "输入SteamCMD路径" --inputbox "请输入已安装的steamcmd脚本完整路径:" 10 70 "$default_path" 3>&1 1>&2 2>&3)
                
                if [ -z "$steam_path" ]; then
                    whiptail --title "错误" --msgbox "路径不能为空！" 8 60
                    continue
                fi
                
                if [ ! -f "$steam_path" ]; then
                    whiptail --title "错误" --msgbox "指定的路径不存在或不是文件: $steam_path" 10 70
                    continue
                fi
                
                STEAMCMD_PATH="$steam_path"
                save_config
                whiptail --title "设置成功" --msgbox "已使用: $STEAMCMD_PATH SteamCMD文件" 8 70
                break
            done
            ;;
        *) 
            return 1
            ;;
    esac
}

# 获取安装位置
get_install_location() {
    # 默认安装位置
    local default_dir="$STEAM_HOME/${GAME_NAME// /_}_server"
    
    # 如果配置中有路径，使用配置中的路径
    if [ -n "$SERVER_DIR" ] && [ -d "$SERVER_DIR" ]; then
        default_dir="$SERVER_DIR"
    fi
    
    while true; do
        local custom_dir=$(whiptail --title "选择安装位置" --inputbox "请输入 $GAME_NAME 服务器的安装路径:" 10 70 "$default_dir" 3>&1 1>&2 2>&3)
        
        if [ -z "$custom_dir" ]; then
            whiptail --title "错误" --msgbox "安装路径不能为空!" 8 60
            continue
        fi
        
        # 检查路径是否有效
        if [[ "$custom_dir" != /* ]]; then
            whiptail --title "错误" --msgbox "请提供绝对路径 (以/开头)!" 8 60
            continue
        fi
        
        # 检查父目录是否存在
        local parent_dir=$(dirname "$custom_dir")
        if [ ! -d "$parent_dir" ]; then
            if whiptail --title "目录不存在" --yesno "父目录 '$parent_dir' 不存在，是否创建?" 10 70; then
                mkdir -p "$parent_dir" || {
                    whiptail --title "错误" --msgbox "无法创建父目录: $parent_dir" 10 70
                    continue
                }
            else
                continue
            fi
        fi
        
        # 如果目标目录已经存在，检查是否为空
        if [ -d "$custom_dir" ]; then
            if [ "$(ls -A "$custom_dir")" ]; then
                if ! whiptail --title "警告" --yesno "目录 '$custom_dir' 非空！继续安装将覆盖现有文件。是否继续?" 10 70; then
                    continue
                fi
            fi
        fi
        
        SERVER_DIR="$custom_dir"
        
        # 创建目录并设置权限
        mkdir -p "$SERVER_DIR"
        chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
        
        # 保存配置
        save_config
        
        break
    done
}

# 下载游戏服务器
download_game() {
    if [ -z "$STEAMCMD_PATH" ]; then
        whiptail --title "错误" --msgbox "尚未安装SteamCMD! 请先安装SteamCMD。" 8 60
        return 1
    fi
    
    # 让用户选择游戏
    local default_game="$GAME_NAME"
    [ -z "$default_game" ] && default_game="Team Fortress 2"
    
    GAME_NAME=$(whiptail --title "选择游戏" --default-item "$default_game" --menu "选择要安装的游戏" 15 45 5 \
        "Team Fortress 2" "" \
        "Left 4 Dead 2" "" \
        "No More Room in Hell" "" 3>&1 1>&2 2>&3)
    
    [ -z "$GAME_NAME" ] && return 1
    
    # 保存配置
    save_config
    
    # 让用户选择安装位置
    get_install_location
    
    local app_id="${GAME_APPS[$GAME_NAME]}"
    
    # 创建临时日志文件
    local log_file="/tmp/steamcmd_install_$app_id.log"
    > "$log_file"  # 清空日志文件
    
    # 显示等待信息
    whiptail --infobox "正在安装 $GAME_NAME，请耐心等待...\n\n详细信息请查看日志: $log_file" 9 70
    
    # 执行安装并捕获输出
    su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee "$log_file"
    
    # 检查安装结果
    if grep -qi "Success!" "$log_file"; then
        mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
        whiptail --title "完成" --msgbox "成功安装 $GAME_NAME 服务器到: $SERVER_DIR" 9 70
    else
        # 移动日志到服务器目录
        whiptail --title "安装失败" --textbox "$log_file" 20 70
        return
    fi
}

# 安装SourceMod和Metamod:Source
install_sourcemod() {
    if [ -z "$GAME_NAME" ]; then
        whiptail --title "错误" --msgbox "未选择游戏，请先选择游戏！" 8 60
        return 1
    fi
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    if [ -z "$game_short_name" ]; then
        whiptail --title "错误" --msgbox "无法获取游戏短名称！" 8 60
        return 1
    fi

    # 插件安装的目标目录
    local addons_dir="$SERVER_DIR/$game_short_name/"
    
    # 确保addons目录存在
    chown "$STEAM_USER:$STEAM_USER" "$addons_dir"

    local error_file=$(mktemp)
    {
        echo 30
        echo "下载Metamod:Source..."
        wget -q "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz" -O $SERVER_DIR/mms.tar.gz
        if [ ! -s $SERVER_DIR/mms.tar.gz ]; then
            echo "Metamod:Source下载失败！" > "$error_file"
            exit 1
        fi
        
        echo 60
        echo "下载SourceMod..."
        wget -q "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7210-linux.tar.gz" -O $SERVER_DIR/sourcemod.tar.gz
        if [ ! -s $SERVER_DIR/sourcemod.tar.gz ]; then
            echo "SourceMod下载失败！" > "$error_file"
            exit 1
        fi
        
        echo 80
        echo "安装到服务器目录..."
        tar -xzf $SERVER_DIR/mms.tar.gz -C "$addons_dir"
        tar -xzf $SERVER_DIR/sourcemod.tar.gz -C "$addons_dir"

        rm $SERVER_DIR/mms.tar.gz $SERVER_DIR/sourcemod.tar.gz
        chown -R "$STEAM_USER:$STEAM_USER" "$addons_dir"
        echo 100
    } | whiptail --title "安装插件" --gauge "正在下载并安装SourceMod+Metamod..." 8 60 0
    
    if [ -s "$error_file" ]; then
        local error_msg=$(cat "$error_file")
        rm "$error_file"
        whiptail --title "安装失败" --msgbox "$error_msg" 8 70
        return 1
    fi
    rm "$error_file"

    whiptail --title "安装完成" --msgbox "SourceMod和Metamod:Source已安装到: $addons_dir" 9 70
}

# 创建启动脚本
create_start_script() {
    local script_path="$SERVER_DIR/start_${GAME_NAME// /_}.sh"
    local default_port=$(( RANDOM % 1000 + 27015 ))
    
    # 获取配置文件名（基于游戏名）
    local config_name="server_${GAME_NAME// /_}.cfg"
    
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    
    # 游戏特定的默认地图
    local default_map=""
    case "$GAME_NAME" in
        "Team Fortress 2") default_map="ctf_2fort" ;;
        "Left 4 Dead 2") default_map="c1m1_hotel" ;;
        "No More Room in Hell") default_map="nmo_broadway" ;;
        *) default_map="dm_mario_kart" ;;
    esac
    
    cat > "$script_path" << EOF
#!/bin/bash
# 服务器参数
./srcds_run \\
    -game $game_short_name \\
    -console \\
    -port $default_port \\
    +maxplayers 16 \\
    +map $default_map \\
    +exec ${config_name} \\
EOF
    
    # 创建基础配置文件
    if [ ! -f "$SERVER_DIR/${config_name}" ]; then
        cat > "$SERVER_DIR/${config_name}" << EOF
// ${GAME_NAME} 服务器配置
hostname "${GAME_NAME} 服务器"
rcon_password "$(openssl rand -hex 10)"
sv_lan 0
EOF
        chown "$STEAM_USER:$STEAM_USER" "$SERVER_DIR/${config_name}"
    fi
    
    chmod +x "$script_path"
    chown "$STEAM_USER:$STEAM_USER" "$script_path"
    
    whiptail --title "启动脚本创建" --msgbox "启动脚本已创建: $script_path\n\n游戏短名称: $game_short_name\n默认地图: $default_map\n默认端口: $default_port\n使用账户: $STEAM_USER\n配置文件: $config_name" 14 70
}

# 显示服务器信息
show_server_info() {
    local info="游戏服务器账户: $STEAM_USER\n"
    info+="账户主目录: $STEAM_HOME\n"
    info+="SteamCMD路径: ${STEAMCMD_PATH:-"未设置"}\n"
    info+="游戏名称: ${GAME_NAME:-"未选择"}\n"
    if [ -n "$SERVER_DIR" ]; then
        info+="安装位置: $SERVER_DIR\n"
        info+="磁盘使用: $(du -sh "$SERVER_DIR" | cut -f1)\n\n"
    else
        info+="安装位置: 未设置\n\n"
    fi
    info+="提示:\n"
    info+="1. 启动脚本在服务器目录中\n"
    info+="2. 启动命令: ./start_*.sh\n"
    info+="3. 默认端口可在启动脚本中修改\n"
    
    whiptail --title "脚本配置信息" --msgbox "$info" 16 70
}

# 显示配置文件内容
show_config() {
    if [ -f "$CONFIG_FILE" ]; then
        whiptail --title "配置文件内容" --textbox "$CONFIG_FILE" 20 70
    else
        whiptail --title "配置文件" --msgbox "配置文件不存在: $CONFIG_FILE" 10 60
    fi
}

# 管理SteamCMD
manage_steamcmd() {
    local choice=$(whiptail --title "管理 SteamCMD" --menu "选择操作" 15 60 4 \
        "1" "安装SteamCMD" \
        "2" "重新安装SteamCMD" \
        "3" "更改现有的SteamCMD路径" \
        "4" "返回主菜单" 3>&1 1>&2 2>&3)
    
    case $choice in
        1) install_steamcmd ;;
        2) 
            # 删除现有安装
            if [ -n "$STEAMCMD_PATH" ] && [ -f "$STEAMCMD_PATH" ]; then
                rm -rf "$(dirname "$STEAMCMD_PATH")"
                STEAMCMD_PATH=""
                save_config
            fi
            install_steamcmd 
            ;;
        3) 
            while true; do
                local steam_path=$(whiptail --title "输入 SteamCMD 路径" --inputbox "请输入已安装的 steamcmd 脚本完整路径:" 10 70 "$STEAMCMD_PATH" 3>&1 1>&2 2>&3)
                
                if [ -z "$steam_path" ]; then
                    whiptail --title "错误" --msgbox "路径不能为空！" 8 60
                    continue
                fi
                
                if [ ! -f "$steam_path" ]; then
                    whiptail --title "错误" --msgbox "指定的路径不存在或不是文件: $steam_path" 10 70
                    continue
                fi
                
                STEAMCMD_PATH="$steam_path"
                save_config
                whiptail --title "设置成功" --msgbox "已更新 SteamCMD 路径为: $STEAMCMD_PATH" 8 70
                break
            done
            ;;
        *) return ;;
    esac
}

# 管理游戏服务器
manage_game_server() {
    local choice=$(whiptail --title "管理游戏服务器" --menu "选择操作" 15 60 5 \
        "1" "安装新游戏服务器" \
        "2" "更新现有游戏服务器" \
        "3" "验证现有游戏服务器" \
        "4" "更改安装位置" \
        "5" "切换游戏" \
        "6" "返回主菜单" 3>&1 1>&2 2>&3)

    case $choice in
        1) 
            # 让用户选择游戏
            #local default_game="$GAME_NAME"
            #[ -z "$default_game" ] && default_game="Team Fortress 2"
            
            #GAME_NAME=$(whiptail --title "选择游戏" --default-item "$default_game" --menu "选择要安装的游戏" 15 45 5 \
            #    "Team Fortress 2" "" \
            #    "Left 4 Dead 2" "" \
            #    "No More Room in Hell" "" 3>&1 1>&2 2>&3)
            #
            #[ -z "$GAME_NAME" ] && return
            
            # 保存配置
            #save_config
            
            # 让用户选择安装位置
            #get_install_location
            
            # 执行安装
            download_game
            ;;
        2)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                whiptail --title "错误" --msgbox "未选择游戏或未设置安装路径！" 8 60
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_update_$app_id.log"
            > "$log_file"
            
            whiptail --infobox "正在更新 $GAME_NAME，请耐心等待...\n\n详细信息请查看日志: $log_file" 9 70
            
            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" +quit" 2>&1 | tee "$log_file"
            
            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
                whiptail --title "完成" --msgbox "更新完成 $GAME_NAME 服务器路径: $SERVER_DIR" 9 70
            else
                whiptail --title "更新失败" --textbox "$log_file" 20 70
                return
            fi
            ;;
        3)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                whiptail --title "错误" --msgbox "未选择游戏或未设置安装路径！" 8 60
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_validate_$app_id.log"
            > "$log_file"
            
            whiptail --infobox "正在验证 $GAME_NAME，请耐心等待...\n\n详细信息请查看日志: $log_file" 9 70
            
            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee "$log_file"
            
            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
                whiptail --title "完成" --msgbox "验证完成 $GAME_NAME 服务器路径: $SERVER_DIR" 9 70
            else
                whiptail --title "安装失败" --textbox "$log_file" 20 70
                return
            fi
            ;;
        4)
            if [ -z "$GAME_NAME" ]; then
                whiptail --title "错误" --msgbox "请先选择游戏！" 8 60
                return
            fi
            
            get_install_location
            whiptail --title "位置已更改" --msgbox "游戏安装位置已更新为: $SERVER_DIR" 9 70
            ;;
        5)
            # 让用户选择新游戏
            local new_game=$(whiptail --title "切换游戏" --menu "选择新游戏" 15 45 5 \
                "Team Fortress 2" "" \
                "Left 4 Dead 2" "" \
                "No More Room in Hell" "" 3>&1 1>&2 2>&3)
            
            if [ -n "$new_game" ]; then
                GAME_NAME="$new_game"
                save_config
                whiptail --title "已切换" --msgbox "当前游戏已切换为: $GAME_NAME" 9 70
            fi
            ;;
        *) return ;;
    esac
}

# 管理插件
manage_plugins() {
    if [ -z "$SERVER_DIR" ]; then
        whiptail --title "错误" --msgbox "请先安装游戏服务器!" 8 60
        return
    fi
    
    local choice=$(whiptail --title "管理插件" --menu "选择操作" 15 60 5 \
        "1" "安装 SourceMod+Metamod:Source[v12]" \
        "2" "更新 SourceMod+Metamod:Source[v12]" \
        "3" "卸载 SourceMod+Metamod:Source[v12]" \
        "4" "返回主菜单" 3>&1 1>&2 2>&3)
    
    case $choice in
        1) 
            # 检查是否已安装
            if [ -d "$SERVER_DIR/addons/sourcemod" ]; then
                if whiptail --title "已安装" --yesno "SourceMod 已安装，是否重新安装？" 10 60; then
                    rm -rf "$SERVER_DIR/addons/sourcemod"
                    rm -rf "$SERVER_DIR/addons/metamod"
                else
                    return
                fi
            fi
            
            install_sourcemod
            ;;
        2)
            if [ -z "$GAME_NAME" ]; then
                whiptail --title "错误" --msgbox "未选择游戏，请先选择游戏！" 8 60
                return 1
            fi
            local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
            if [ -z "$game_short_name" ]; then
                whiptail --title "错误" --msgbox "无法获取游戏短名称！" 8 60
                return 1
            fi
        
            local addons_dir="$SERVER_DIR/$game_short_name/addons"
        
            if [ ! -d "$addons_dir/sourcemod" ]; then
                whiptail --title "未安装" --msgbox "SourceMod 未安装，请先安装！" 8 60
                return
            fi

            if [ ! -d "$addons_dir/metamod" ]; then
                whiptail --title "未安装" --msgbox "Metamod:Source 未安装，请先安装！" 8 60
                return
            fi

            local error_file=$(mktemp)
            {
                echo 20
                echo "下载最新 Metamod:Source..."
                MM_INDEX_URL="https://www.metamodsource.net/mmsdrop/1.12/"
                MM_LATEST_NAME=$(curl -s "https://www.metamodsource.net/mmsdrop/1.12/mmsource-latest-linux")
                MM_FILENAME=$(echo "$MM_LATEST_NAME" | tr -d '\r\n')
                MM_DOWNLOAD_URL="${MM_INDEX_URL}${MM_FILENAME}"
                wget -q "$MM_DOWNLOAD_URL" -O "$SERVER_DIR/$MM_FILENAME"
                if [ ! -s "$SERVER_DIR/$MM_FILENAME" ]; then
                    echo "Metamod:Source下载失败！" > "$error_file"
                    exit 1
                fi

                echo 50
                echo "下载最新 SourceMod..."
                SM_INDEX_URL="https://sm.alliedmods.net/smdrop/1.12/"
                SM_LATEST_NAME=$(curl -s "https://sm.alliedmods.net/smdrop/1.12/sourcemod-latest-linux")
                SM_FILENAME=$(echo "$SM_LATEST_NAME" | tr -d '\r\n')
                SM_DOWNLOAD_URL="${SM_INDEX_URL}${SM_FILENAME}"
                wget -q "$SM_DOWNLOAD_URL" -O "$SERVER_DIR/$SM_FILENAME"
                if [ ! -s "$SERVER_DIR/$SM_FILENAME" ]; then
                    echo "SourceMod下载失败！" > "$error_file"
                    exit 1
                fi

                echo 80
                # 创建临时目录
                local temp_dir=$(mktemp -d)

                # 解压 Metamod:Source
                tar -xzf "$SERVER_DIR/$MM_FILENAME" -C "$temp_dir"
                #mkdir -p "$addons_dir/metamod"
                cp -rf "$temp_dir/addons/metamod/"* "$addons_dir/metamod/"

                # 解压 SourceMod
                tar -xzf "$SERVER_DIR/$SM_FILENAME" -C "$temp_dir"
                local sm_dirs=("bin" "extensions" "gamedata" "plugins" "scripting")
                for dir in "${sm_dirs[@]}"; do
                    if [ -d "$temp_dir/addons/sourcemod/$dir" ]; then
                        #mkdir -p "$addons_dir/sourcemod/$dir"
                        cp -rf "$temp_dir/addons/sourcemod/$dir/"* "$addons_dir/sourcemod/$dir/"
                    fi
                done

                rm -rf "$temp_dir"
                rm "$SERVER_DIR/$MM_FILENAME" "$SERVER_DIR/$SM_FILENAME"

                chown -R "$STEAM_USER:$STEAM_USER" "$addons_dir"
                echo 100
            } | whiptail --title "更新插件" --gauge "正在更新 SourceMod+Metamod:Source..." 8 60 0

            if [ -s "$error_file" ]; then
                error_msg=$(cat "$error_file")
                rm "$error_file"
                whiptail --title "更新失败" --msgbox "$error_msg" 8 70
                return
            fi
            rm "$error_file"

            whiptail --title "更新完成" --msgbox "SourceMod 和 Metamod:Source 已更新到最新版本" 9 70
            ;;
        3)
            if [ -z "$GAME_NAME" ]; then
                whiptail --title "错误" --msgbox "未选择游戏，请先选择游戏！" 8 60
                return 1
            fi
            local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
            if [ -z "$game_short_name" ]; then
                whiptail --title "错误" --msgbox "无法获取游戏短名称！" 8 60
                return 1
            fi
        
            local addons_dir="$SERVER_DIR/$game_short_name/"

            if [ ! -d "$addons_dir/sourcemod" ]; then
                whiptail --title "未安装" --msgbox "SourceMod 未安装！" 8 60
                return
            fi

            if whiptail --title "确认卸载" --yesno "确定要卸载 SourceMod 和 Metamod:Source 吗？" 10 60; then
                rm -rf "$SERVER_DIR/addons/sourcemod"
                rm -rf "$addons_dir/addons/metamod"
                whiptail --title "卸载完成" --msgbox "SourceMod 和 Metamod:Source 已卸载" 9 70
            fi
            ;;
        *) return ;;
    esac
}

show_about() {
    local about_info=""
    about_info+="服务器管理脚本 v1.0.5\n"
    about_info+="作者: TYHH10\n"
    about_info+="创建日期: 2025-07-07\n\n"
    about_info+="这个脚本,就纯粹就为了偷懒然后用AI跑的一个脚本\n"
    about_info+="(结果花了一个下午，再加一个上午:( )\n"
    about_info+="功能说明:\n"
    about_info+="- 支持在Linux系统上安装和配置Source引擎游戏服务器\n"
    about_info+="- 支持游戏: Team Fortress 2, Left 4 Dead 2, No More Room in Hell\n"
    about_info+="- 自动安装游戏依赖项和SM+MM:S(SM 12版本)\n"
    about_info+="- 支持多账户管理\n"
    about_info+="- 提供服务器启动脚本创建功能\n\n"
    
    whiptail --title "关于" --msgbox "$about_info" 18 70
}

# 主菜单
main_menu() {
    # 加载配置文件
    load_config

    while true; do
        load_config
        local account_info=${STEAM_USER:-"未设置"}
        local steamcmd_info=${STEAMCMD_PATH:-"未安装"}
        local game_info=${GAME_NAME:-"未选择"}
        local install_info=${SERVER_DIR:-"未设置"}
        
        # 截取较长路径的中间部分
        if [ ${#install_info} -gt 40 ]; then
            install_info="...${install_info: -37}"
        fi

        local choice=$(whiptail --title "服务器管理脚本" --menu "\nOS: $OS_INFO\n游戏服务器账户: $account_info\nSteamCMD: $steamcmd_info\n游戏: $game_info\n位置: $install_info" 22 70 12 \
            "1" "安装游戏服务器依赖" \
            "2" "管理游戏服务器账户" \
            "3" "管理SteamCMD" \
            "4" "管理游戏服务器" \
            "5" "管理SM+MM:S[v12]" \
            "6" "创建启动脚本" \
            "7" "查看脚本配置信息" \
            "8" "查看配置文件" \
            "9" "关于本脚本" \
            "10" "完成并退出" 3>&1 1>&2 2>&3)

        case $choice in
            1) detect_os; install_dependencies ;;
            2) set_server_user ;;
            3) 
                if [ -z "$STEAM_USER" ]; then
                    whiptail --title "错误" --msgbox "请先设置游戏服务器账户!" 8 60
                    continue
                fi
                manage_steamcmd 
                ;;
            4) 
                if [ -z "$STEAMCMD_PATH" ]; then
                    whiptail --title "错误" --msgbox "请先安装SteamCMD!" 8 60
                    continue
                fi
                
                if [ -z "$STEAM_USER" ]; then
                    whiptail --title "错误" --msgbox "请先设置游戏服务器账户!" 8 60
                    continue
                fi
                
                manage_game_server
                ;;
            5) 
                manage_plugins 
                ;;
            6) 
                if [ -z "$SERVER_DIR" ]; then
                    whiptail --title "错误" --msgbox "请先安装游戏服务器!" 8 60
                    continue
                fi
                create_start_script 
                ;;
            7) show_server_info ;;
            8) show_config ;;
            9) show_about ;;
            10) 
                if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                    if whiptail --title "确认退出" --yesno "您尚未完成全部设置，确定要退出吗？" --defaultno --yes-button "退出" --no-button "返回" 10 60; then
                        save_config
                        exit 0
                    fi
                else
                    local script_name="start_${GAME_NAME// /_}.sh"
                    whiptail --title "安装完成" --msgbox "配置完成！\n\n启动命令:\ncd \"$SERVER_DIR\"\nsudo -u $STEAM_USER ./$script_name" 12 70
                    save_config
                    exit 0
                fi
                ;;
            *) exit 1 ;;
        esac
    done
}

# 主函数
main() {
    check_root
    detect_os
    whiptail --title "服务器管理脚本" --msgbox "欢迎使用服务器管理脚本\n本脚本将协助安装TF2/L4D2/NMRIH服务器\n\n配置文件: $CONFIG_FILE" 12 70
    main_menu
}

# 执行主函数
main