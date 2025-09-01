#!/bin/bash

# 添加颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 清除屏幕
clear_screen() {
    clear
}

# 显示标题
show_title() {
    local title="$1"
    echo -e "${CYAN}===============${NC}${PURPLE}  $title  ${NC}${CYAN}===============${NC}"
}

# 显示消息
show_message() {
    local message="$1"
    echo -e "${GREEN}${message}${NC}\n"
    echo -e "${YELLOW}按Enter键继续...${NC}"
    read
}

# 显示错误消息
show_error() {
    local message="$1"
    echo -e "${RED}[Error]${NC} $message\n"
    echo -e "${YELLOW}按Enter键继续...${NC}"
    read
}

# 显示警告消息
show_warning() {
    local message="$1"
    echo -e "${YELLOW}[Warning]${NC} $message\n"
}

# 显示信息框
show_info() {
    local message="$1"
    echo -e "${BLUE}[Info]${NC} $message\n"
}

# 显示进度条
show_progress() {
    local title="$1"
    local message="$2"
    local percentage="$3"
    echo -e "\r${YELLOW}[${title}]${NC} $message - ${CYAN}${percentage}%${NC}\c"
}

# 显示文本文件内容
show_textfile() {
    local title="$1"
    local file_path="$2"
    
    clear_screen
    show_title "$title"
    echo -e "${BLUE}文件内容: ${YELLOW}$file_path${NC}\n"
    cat "$file_path"
    echo -e "\n${YELLOW}按Enter键继续...${NC}"
    read
}

# 获取用户输入
get_input() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    local result
    
    clear_screen
    show_title "$title"
    echo -e "$prompt"
    if [ -n "$default_value" ]; then
        echo -e "${YELLOW}默认值: $default_value${NC}"
        read -p "请输入: " result
        if [ -z "$result" ]; then
            result="$default_value"
        fi
    else
        read -p "请输入: " result
    fi
    
    echo "$result"
}

# 确认对话框
confirm() {
    local title="$1"
    local message="$2"
    local default_option="$3"
    local result
    
    clear_screen
    show_title "$title"
    echo -e "$message\n"
    
    if [ "$default_option" = "yes" ]; then
        read -p "确认操作? [Y/n]: " result
        if [ -z "$result" ] || [[ $result == [Yy]* ]]; then
            return 0
        else
            return 1
        fi
    else
        read -p "确认操作? [y/N]: " result
        if [[ $result == [Yy]* ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# 显示菜单
show_menu() {
    local title="$1"
    local subtitle="$2"
    shift 2
    local options=($@)
    local choice
    local valid_choices=()
    
    clear_screen
    show_title "$title"
    
    if [ -n "$subtitle" ]; then
        echo -e "${BLUE}$subtitle${NC}\n"
    fi
    
    # 显示选项
    for ((i=0; i<${#options[@]}; i+=2)); do
        valid_choices+=(${options[i]})
        echo -e "${CYAN}[${options[i]}]${NC} ${options[i+1]}"
    done
    
    echo -e "\n${YELLOW}请输入选项编号:${NC}"
    
    # 读取用户选择
    while true; do
        read -p "请选择: " choice
        if [[ " ${valid_choices[*]} " == *" $choice "* ]]; then
            echo "$choice"
            break
        else
            echo -e "${RED}无效的选项，请重新输入！${NC}"
        fi
    done
}

# 显示进度（模拟）
show_gauge() {
    local title="$1"
    local message="$2"
    local cmd="$3"
    
    clear_screen
    show_title "$title"
    echo -e "${BLUE}$message${NC}\n"
    
    # 执行命令并显示进度
    bash -c "$cmd"
    
    echo -e "\n${GREEN}操作完成！${NC}"
    echo -e "${YELLOW}按Enter键继续...${NC}"
    read
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        # 尝试使用sudo重新执行当前脚本（并传递所有参数）
        exec sudo -E "$0" "$@"
        # 如果exec失败则显示错误
        echo -e "${RED}[Error]${NC} 无法自动获取root权限！\n请手动执行: sudo $0"
        exit 1
    fi
}

# 调用权限检查
check_root "$@"

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
    # 服务器管理脚本配置文件
    # 创建于: $(date)

    # 游戏服务器账户
    CONFIG_STEAM_USER="$STEAM_USER"
    # SteamCMD路径
    CONFIG_STEAMCMD_PATH="$STEAMCMD_PATH"
    # 安装的游戏
    CONFIG_GAME_NAME="$GAME_NAME"
    # 安装的游戏路径
    CONFIG_SERVER_DIR="$SERVER_DIR"
EOF
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
        echo -e "${GREEN}[Info]${NC} 启用Arch Linux的multilib仓库..."
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
        echo -e "${GREEN}[Info]${NC} $pkg_name 已安装"
        return 0
    fi

    # 尝试安装预构建包
    if [ "$pkg_name" = "lib32-ncurses5-compat-libs" ]; then
        local prebuilt_url="https://blog.tyhh10.xyz/file/arch-zst-file/lib32-ncurses5-compat-libs-6.5-3-x86_64.pkg.tar.zst"
        local temp_pkg="/tmp/lib32-ncurses5-compat-libs.pkg.tar.zst"
        
        echo -e "${GREEN}[Info]${NC} 尝试安装预构建包: $pkg_name"
        axel -q -n 10 "$prebuilt_url" -o "$temp_pkg"
        
        if [ -f "$temp_pkg" ]; then
            pacman -U --noconfirm --overwrite=* "$temp_pkg" >/dev/null 2>&1
            rm -f "$temp_pkg"
            
            if pacman -Qq $pkg_name &>/dev/null; then
                echo -e "${GREEN}[Info]${NC} 预构建包安装成功: $pkg_name"
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
        echo -e "${GREEN}[Info]${NC} $pkg_name 已存在，跳过下载"
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
        echo -e "${GREEN}[Info]${NC} $pkg_name 安装成功"
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
        show_error "不支持的操作系统：$OS_INFO"
        exit 1
    fi
    
    clear_screen
    show_title "安装依赖"
    echo -e "${BLUE}正在安装游戏服务器依赖...${NC}\n"
    
    for ((i=0; i<${#packages[@]}; i++)); do
        pkg="${packages[$i]}"
        percentage=$((i * 100 / ${#packages[@]}))
        show_progress "安装进度" "安装 $pkg" "$percentage"

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
    echo ""

    # 为Arch Linux安装额外的AUR依赖
    if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
        show_info "正在安装额外的AUR依赖: lib32-ncurses5-compat-libs..."
        if install_aur_package "lib32-ncurses5-compat-libs"; then
            show_message "AUR包 lib32-ncurses5-compat-libs 已安装"
        else
            show_error "无法安装 lib32-ncurses5-compat-libs，服务器可能无法正常运行"
        fi
    fi
}

check_server_dir() {
    if [ -z "$SERVER_DIR" ]; then
        show_error "请先安装游戏服务器!"
        return 1
    fi
    return 0
}

get_game_short_name() {
    if [ -z "$GAME_NAME" ]; then
        show_error "未选择游戏！"
        return 1
    fi
    
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    if [ -z "$game_short_name" ]; then
        show_error "无法获取游戏短名称！"
        return 1
    fi
    
    echo "$game_short_name"
}

# 设置服务器账户
set_server_user() {
    local users=$(awk -F':' '{ if ($3 >= 1000 && $3 <= 65534) print $1 }' /etc/passwd)
    local current_user=$(id -un)
    local user_list=()
    local i=1
    
    # 生成用户列表选项
    for user in $users; do
        user_list+=($i "已存在: $user")
        i=$((i+1))
    done
    user_list+=($i "创建新账户")
    
    # 如果已有配置，使用配置中的用户
    local default_user="$STEAM_USER"
    [ -z "$default_user" ] && default_user="gameserver"

    clear_screen
    show_title "选择游戏服务器账户"
    echo -e "${BLUE}请选择用于运行游戏服务器的账户\n\n(推荐使用非root账户)${NC}\n"
    
    # 显示选项
    for ((j=0; j<${#user_list[@]}; j+=2)); do
        echo -e "${CYAN}[${user_list[j]}]${NC} ${user_list[j+1]}"
    done
    
    echo -e "\n${YELLOW}请输入选项编号:${NC}"
    
    # 读取用户选择
    while true; do
        read -p "请选择: " choice
        if [[ $choice -ge 1 && $choice -le $i ]]; then
            break
        else
            echo -e "${RED}无效的选项，请重新输入！${NC}"
        fi
    done
    
    # 处理选择
    if [ $choice -eq $i ]; then
        # 创建新账户
        STEAM_USER=$(get_input "创建新账户" "请输入新账户名称:" "$default_user")
        if [ -z "$STEAM_USER" ]; then
            return 1
        fi
        
        # 检查账户是否已存在
        if id "$STEAM_USER" &>/dev/null; then
            show_error "账户 '$STEAM_USER' 已存在！"
            return 1
        fi
        
        # 创建新账户
        useradd -m -s /bin/bash "$STEAM_USER"
        local password=$(openssl rand -base64 12)
        echo "$STEAM_USER:$password" | chpasswd
        show_message "已创建用户 '$STEAM_USER'\n密码: $password"
    else
        # 选择现有账户
        local existing_users=($users)
        local selected_index=$((choice-1))
        STEAM_USER="${existing_users[$selected_index]}"
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
    local choice=$(show_menu "SteamCMD 安装选项" "请选择SteamCMD安装方式" \
        "1" "自动安装最新版SteamCMD" \
        "2" "使用已安装的SteamCMD" \
        "3" "返回")
    
    case $choice in
        1)
            clear_screen
            show_title "安装SteamCMD"
            echo -e "${BLUE}正在下载并安装SteamCMD...${NC}\n"
            
            mkdir -p "$STEAM_HOME/steamcmd"
            cd "$STEAM_HOME/steamcmd"
            axel -q "$STEAMCMD_URL"
            tar -xzf steamcmd_linux.tar.gz
            rm steamcmd_linux.tar.gz
            chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
            
            STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
            save_config
            show_message "SteamCMD 已安装到: $STEAMCMD_PATH"
            ;;
        2)
            while true; do
                # 使用配置中的路径作为默认值
                local default_path="$STEAMCMD_PATH"
                [ -z "$default_path" ] && default_path="/usr/games/steamcmd/steamcmd.sh"
                
                local steam_path=$(get_input "输入SteamCMD路径" "请输入已安装的steamcmd脚本完整路径:" "$default_path")
                
                if [ -z "$steam_path" ]; then
                    show_error "路径不能为空！"
                    continue
                fi
                
                if [ ! -f "$steam_path" ]; then
                    show_error "指定的路径不存在或不是文件: $steam_path"
                    continue
                fi
                
                STEAMCMD_PATH="$steam_path"
                save_config
                show_message "已使用: $STEAMCMD_PATH SteamCMD文件"
                break
            done
            ;;
        3)
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
        local custom_dir=$(get_input "选择安装位置" "请输入 $GAME_NAME 服务器的安装路径:" "$default_dir")
        
        if [ -z "$custom_dir" ]; then
            show_error "安装路径不能为空!"
            continue
        fi
        
        # 检查路径是否有效
        if [[ "$custom_dir" != /* ]]; then
            show_error "请提供绝对路径 (以/开头)!"
            continue
        fi
        
        # 检查父目录是否存在
        local parent_dir=$(dirname "$custom_dir")
        if [ ! -d "$parent_dir" ]; then
            if confirm "目录不存在" "父目录 '$parent_dir' 不存在，是否创建?" "yes"; then
                mkdir -p "$parent_dir" || {
                    show_error "无法创建父目录: $parent_dir"
                    continue
                }
            else
                continue
            fi
        fi
        
        # 如果目标目录已经存在，检查是否为空
        if [ -d "$custom_dir" ]; then
            if [ "$(ls -A "$custom_dir")" ]; then
                if ! confirm "警告" "目录 '$custom_dir' 非空！继续安装将覆盖现有文件。是否继续?" "no"; then
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
        show_error "尚未安装SteamCMD! 请先安装SteamCMD。"
        return 1
    fi
    
    # 保存配置
    save_config
    
    # 让用户选择安装位置
    get_install_location
    
    local app_id="${GAME_APPS[$GAME_NAME]}"
    
    # 创建临时日志文件
    local log_file="/tmp/steamcmd_install_$app_id.log"
    > "$log_file"  # 清空日志文件
    
    clear_screen
    show_title "下载游戏服务器"
    echo -e "${BLUE}正在安装 $GAME_NAME 服务器，请耐心等待...\n" >&2
    echo -e "${YELLOW}详细信息请查看日志: $log_file${NC}\n" >&2
    
    # 执行安装并捕获输出
    if [ "$app_id" == "222860" ]; then
        # 下载L4D2的特殊方式 - 先下载Windows版本
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
        
        # 然后下载Linux版本
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    else
        # 其他游戏正常下载
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    fi

    # 检查安装结果
    if grep -qi "Success!" "$log_file"; then
        mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
        show_message "成功安装 $GAME_NAME 服务器到: $SERVER_DIR"
    else
        if grep -qi "Error! App '$app_id' state is 0x[0-9a-fA-F]\+ after update job" "$log_file"; then
            error_code=$(grep -o "0x[0-9a-fA-F]\+" "$log_file" | head -n 1)

            case "$error_code" in
                "0x202")
                    error_msg="SteamCMD操作失败(错误代码: $error_code)\n\n"
                    error_msg+="原因：硬盘空间不足"
                    ;;
                *)
                    error_msg="SteamCMD操作失败(未知错误代码: $error_code)\n\n"
                    error_msg+="请检查日志以获取详细信息：\n$(cat "$log_file")"
                    ;;
            esac
            mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null

            # 显示错误信息
            show_error "$error_msg"
        else
            # 其他错误（非状态码错误）
            show_title "安装失败 - 日志内容"
            cat "$log_file"
            echo -e "\n${YELLOW}按Enter键继续...${NC}"
            read
        fi

        return
    fi
}

# 安装SourceMod和Metamod:Source
install_sourcemod() {
    if [ -z "$GAME_NAME" ]; then
        show_error "未选择游戏，请先选择游戏！"
        return 1
    fi
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1

    # 插件安装的目标目录
    local addons_dir="$SERVER_DIR/$game_short_name/"
    
    chown "$STEAM_USER:$STEAM_USER" "$addons_dir"

    local error_file=$(mktemp)
    clear_screen
    show_title "安装插件"
    echo -e "${BLUE}正在下载并安装SourceMod+Metamod...${NC}\n"
    
    local total_steps=4
    local current_step=1
    
    # 下载Metamod:Source
    show_progress "安装进度" "下载Metamod:Source" "$((current_step * 100 / total_steps))"
    axel -q -n 10 "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz" -o $SERVER_DIR/mms.tar.gz
    if [ ! -s $SERVER_DIR/mms.tar.gz ]; then
        echo -e "\n${RED}[Error]${NC} Metamod:Source下载失败！" > "$error_file"
        echo ""
    else
        current_step=$((current_step + 1))
        
        # 下载SourceMod
        show_progress "安装进度" "下载SourceMod" "$((current_step * 100 / total_steps))"
        axel -q -n 10 "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7210-linux.tar.gz" -o $SERVER_DIR/sourcemod.tar.gz
        if [ ! -s $SERVER_DIR/sourcemod.tar.gz ]; then
            echo -e "\n${RED}[Error]${NC} SourceMod下载失败！" > "$error_file"
            echo ""
        else
            current_step=$((current_step + 1))
            
            # 解压Metamod
            show_progress "安装进度" "解压Metamod" "$((current_step * 100 / total_steps))"
            tar -xzf $SERVER_DIR/mms.tar.gz -C "$addons_dir"
            current_step=$((current_step + 1))
            
            # 解压SourceMod
            show_progress "安装进度" "解压SourceMod" "$((current_step * 100 / total_steps))"
            tar -xzf $SERVER_DIR/sourcemod.tar.gz -C "$addons_dir"
            
            rm $SERVER_DIR/mms.tar.gz $SERVER_DIR/sourcemod.tar.gz
            chown -R "$STEAM_USER:$STEAM_USER" "$addons_dir"
            echo ""
        fi
    fi
    
    if [ -s "$error_file" ]; then
        local error_msg=$(cat "$error_file")
        rm "$error_file"
        show_error "$error_msg"
        return 1
    fi
    rm "$error_file"

    show_message "SourceMod和Metamod:Source已安装到: $addons_dir"
}

manage_start_scripts() {
    check_server_dir || return
    
    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1
    
    # 游戏目录
    local game_dir="$SERVER_DIR/$game_short_name"
    # 默认脚本路径
    local script_path="$game_dir/start.sh"
    
    # 检查现有启动脚本
    local has_script="0"
    if [ -f "$script_path" ]; then
        has_script="1"
    fi
    
    while true; do
        clear_screen
        show_title "管理启动脚本 ($game_dir)"
        echo -e "${YELLOW}选择操作：${NC}\n"
        echo -e "${YELLOW}1.${NC} 创建启动脚本"
        echo -e "${YELLOW}2.${NC} 创建游戏服务器systemctl"
        echo -e "${YELLOW}3.${NC} 返回"
        read -p "请输入 [1-3]: " choice
        
        case $choice in
            1)
                create_start_script ;;  
            2)
                if [ ! -f "$SERVER_DIR/start.sh" ]; then
                    show_error "未找到启动脚本！请先创建启动脚本"
                else
                    create_systemd_service
                fi
                ;;
            *) 
                return 
                ;;
        esac
    done
}

manage_systemd_service() {
    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1
    
    # 服务名称
    local service_name="${game_short_name}server.service"
    local service_path="/etc/systemd/system/$service_name"
    
    # 检查服务是否存在
    if [ ! -f "$service_path" ]; then
        show_error "未找到 $service_name 服务！请先创建 systemd 服务。"
        return 1
    fi
    
    # 服务管理菜单
    while true; do
        clear_screen
        show_title "管理服务: $service_name"
        echo -e "${BLUE}选择操作：${NC}\n"
        echo "1. 启动服务"
        echo "2. 停止服务"
        echo "3. 重启服务"
        echo "4. 查看服务状态"
        echo "5. 启用开机自启"
        echo "6. 禁用开机自启"
        echo "7. 返回"
        echo -e "\n${YELLOW}请输入选项编号 (1-7):${NC}"
        read -p "请输入: " choice
        
        case $choice in
            1)
                systemctl start "$service_name"
                show_message "服务 $service_name 已启动"
                ;;
            2)
                systemctl stop "$service_name"
                show_message "服务 $service_name 已停止"
                ;;
            3)
                systemctl restart "$service_name"
                show_message "服务 $service_name 已重启"
                ;;
            4)
                clear
                echo -e "${YELLOW}=== $service_name 状态 ===${NC}"
                systemctl status "$service_name"
                echo -e "\n${YELLOW}按 Enter 返回...${NC}"
                read
                ;;
            5)
                systemctl enable "$service_name"
                show_message "服务 $service_name 已设置为开机自启"
                ;;
            6)
                systemctl disable "$service_name"
                show_message "服务 $service_name 已禁用开机自启"
                ;;
            *) 
                return 
                ;;
        esac
    done
}

# 创建启动脚本
create_start_script() {
    local script_path="$SERVER_DIR/start.sh"
    local default_port=$(( RANDOM % 1000 + 27015 ))

    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1

    local game_dir="$SERVER_DIR/$game_short_name"
    local steamcmd_dir=$(dirname "$STEAMCMD_PATH")
    local game_update="$steamcmd_dir/$game_short_name-update.txt"
    local cfg_dir="$game_dir/cfg"
    
    # 获取配置文件名
    local config_name="server.cfg"
    
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    local app_id="${GAME_APPS[$GAME_NAME]}"
    
    # 游戏特定的默认地图
    local default_map=""
    case "$GAME_NAME" in
        "Team Fortress 2") default_map="cp_5gorge" ;;
        "Left 4 Dead 2") default_map="c2m1_highway" ;;
        "No More Room in Hell") default_map="nmo_broadway" ;;
        "Garry's Mod") default_map="gm_construct" ;;
        *) default_map="dm_mario_kart" ;;
    esac

    local gmod_workshop_collection=""
    local gmod_gamemode=""
    if [ "$GAME_NAME" = "Garry's Mod" ]; then
        local workshop_collection="0"
        if [ -f "$SERVER_DIR/workshop_collection.txt" ]; then
            workshop_collection=$(cat "$SERVER_DIR/workshop_collection.txt")
        fi
        gmod_workshop_collection="+host_workshop_collection ${workshop_collection} "
        gmod_gamemode="+gamemode sandbox "
    fi

    cat > "$game_update" << EOF
login anonymous \\
force_install_dir "$SERVER_DIR" \\
app_update $app_id \\
quit
EOF
    
    cat > "$script_path" << EOF
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
    
    # 创建基础配置文件
    local config_path="$cfg_dir/server.cfg"
    if [ ! -f "$config_path" ]; then
        cat > "$config_path" << EOF
// ${GAME_NAME} 服务器配置
// 显示在服务器浏览器和计分版的服务器名字,PS:L4D2服务器服务器配置文件中这个hostname是无效的要使用插件进行更改
hostname "${GAME_NAME} 服务器"
// 是否需要给服务器上密码,留空即无密码
sv_password ""
// 使用控制台rcon的密码,玩家(或者网站/软件)可以通过这个直接向服务器发送相关指令(必须要填写的)
rcon_password "$(openssl rand -hex 10)"
// 控制台作弊(0/1)
// https://developer.valvesoftware.com/wiki/Sv_cheats
sv_cheats "0"
// 允许玩家使用自定义的内容-1/0/1/2)
// https://developer.valvesoftware.com/wiki/Pure_Servers
sv_pure "0"
EOF
        chown "$STEAM_USER:$STEAM_USER" "$config_path"
    fi
    
    chmod +x "$script_path"
    chown "$STEAM_USER:$STEAM_USER" "$script_path"
    
    show_message "启动脚本已创建: $script_path\n\n游戏短名称: $game_short_name\n默认地图: $default_map\n默认端口: $default_port\n使用账户: $STEAM_USER\n配置文件: $config_name"
}

create_systemd_service() {
    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1

    local service_path="/etc/systemd/system/${GAME_SHORT_NAMES[$GAME_NAME]}server.service"

    cat > "$service_path" << EOF
[Unit]
Description=${GAME_NAME} Server
After=network.target

[Service]
User=$STEAM_USER
Group=$STEAM_USER
WorkingDirectory=$SERVER_DIR
ExecStart=screen -SDm ${GAME_SHORT_NAMES[$GAME_NAME]}server $SERVER_DIR/start.sh
ExecStop=screen -S ${GAME_SHORT_NAMES[$GAME_NAME]}server -X quit
RestartSec=15
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    show_message "Systemd 服务已创建: $service_path\n打开控制台关键词: ${game_short_name}"
    systemctl daemon-reload
    # 使用默认游戏短名称作为默认别名
    local default_alias="$game_short_name"
    
    # 询问是否使用自定义别名
    clear_screen
    show_title "自定义别名"
    echo "请输入自定义别名（留空则使用默认别名: $default_alias）:"
    echo
    read -p "别名: " alias_input
    
    # 处理输入：如果留空则使用默认值
    local final_alias="$default_alias"
    if [ -n "$alias_input" ]; then
        final_alias="$alias_input"
    fi
    
    # 构建别名行
    local alias_line="alias $final_alias='sudo su -c \"screen -d -r ${game_short_name}server\" $STEAM_USER'"

    # 检查/etc/profile中是否已存在该别名
    if ! grep -qF "$alias_line" /etc/profile; then
        echo "$alias_line" >> /etc/profile
        source /etc/profile
        show_message "已添加别名: $final_alias"
    else
        show_message "别名已存在，无需重复添加"
    fi
}

# 显示服务器信息
show_server_info() {
    load_config
    clear_screen
    show_title "脚本配置信息"
    echo -e "${GREEN}游戏服务器账户:${NC} $STEAM_USER"
    echo -e "${GREEN}账户主目录:${NC} $STEAM_HOME"
    echo -e "${GREEN}SteamCMD路径:${NC} ${STEAMCMD_PATH:-"未设置"}"
    echo -e "${GREEN}游戏名称:${NC} ${GAME_NAME:-"未选择"}"
    if [ -n "$SERVER_DIR" ]; then
        echo -e "${GREEN}安装位置:${NC} $SERVER_DIR"
        echo -e "${GREEN}磁盘使用:${NC} $(du -sh "$SERVER_DIR" | cut -f1)"
    else
        echo -e "${GREEN}安装位置:${NC} 未设置"
    fi
    echo
    read -p "按回车返回..." _
}

# 显示配置文件内容
show_config() {
    clear_screen
    show_title "脚本配置文件内容"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}配置文件:${NC} $CONFIG_FILE\n"
        cat "$CONFIG_FILE"
        echo
    else
        show_error "配置文件不存在: $CONFIG_FILE"
    fi
    read -p "按回车返回..." _
}

# 管理SteamCMD
manage_steamcmd() {
    clear_screen
    show_title "管理 SteamCMD"
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "${YELLOW}1.${NC} 安装SteamCMD"
    echo -e "${YELLOW}2.${NC} 重新安装SteamCMD"
    echo -e "${YELLOW}3.${NC} 更改现有的SteamCMD路径"
    echo -e "${YELLOW}4.${NC} 返回主菜单"
    echo
    read -p "请输入选择 [1-4]: " choice
    
    case $choice in
        1) install_steamcmd ;;        2) 
            # 删除现有安装
            if [ -n "$STEAMCMD_PATH" ] && [ -f "$STEAMCMD_PATH" ]; then
                if confirm "确定要删除现有安装并重新安装SteamCMD吗？\n\n当前路径: $STEAMCMD_PATH"; then
                    rm -rf "$(dirname "$STEAMCMD_PATH")"
                    STEAMCMD_PATH=""
                    save_config
                fi
            fi
            install_steamcmd 
            ;;        3) 
            while true; do
                clear_screen
                show_title "输入 SteamCMD 路径"
                echo -e "当前路径: ${GREEN}$STEAMCMD_PATH${NC}\n"
                read -p "请输入已安装的 steamcmd 脚本完整路径: " steam_path
                
                if [ -z "$steam_path" ]; then
                    show_error "路径不能为空！"
                    continue
                fi
                
                if [ ! -f "$steam_path" ]; then
                    show_error "指定的路径不存在或不是文件: $steam_path"
                    continue
                fi
                
                STEAMCMD_PATH="$steam_path"
                save_config
                show_message "已更新 SteamCMD 路径为: $STEAMCMD_PATH"
                break
            done
            ;;        4|*) return ;;        *)
            show_error "无效的选择，请重新输入！"
            ;;
    esac
}

# 管理游戏服务器
manage_game_server() {
    clear_screen
    local menu_title="管理游戏服务器"
    if [ -n "$GAME_NAME" ]; then
        menu_title+=" [当前游戏: $GAME_NAME]"
    else
        menu_title+=" [未选择游戏]"
    fi

    show_title "$menu_title"
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "${YELLOW}1.${NC} 安装新游戏服务器"
    echo -e "${YELLOW}2.${NC} 更新现有游戏服务器"
    echo -e "${YELLOW}3.${NC} 验证现有游戏服务器"
    echo -e "${YELLOW}4.${NC} 更改安装位置"
    echo -e "${YELLOW}5.${NC} 选择/切换游戏"
    echo -e "${YELLOW}6.${NC} 删除游戏服务器"
    echo -e "${YELLOW}7.${NC} 返回主菜单"
    echo
    read -p "请输入选择 [1-7]: " choice

    case $choice in
        1) download_game ;;
        2)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                show_error "未选择游戏或未设置安装路径！"
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_update_$app_id.log"
            > "$log_file"
            
            clear_screen
            show_title "更新游戏服务器"
            echo -e "${CYAN}正在更新 $GAME_NAME，请耐心等待...${NC}\n"
            echo "详细信息请查看日志: $log_file"
            echo

            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" +quit" 2>&1 | tee "$log_file"

            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
                show_message "更新完成 $GAME_NAME 服务器路径: $SERVER_DIR"
            else
                if grep -qi "Error! App '$app_id' state is 0x[0-9a-fA-F]\+ after update job" "$log_file"; then
                    error_code=$(grep -o "0x[0-9a-fA-F]\+" "$log_file" | head -n 1)

                    case "$error_code" in
                        "0x202")
                            error_msg="SteamCMD操作失败(错误代码: $error_code)\n\n"
                            error_msg+="原因：硬盘空间不足"
                            ;;
                        *)
                            error_msg="SteamCMD操作失败(未知错误代码: $error_code)\n\n"
                            error_msg+="请检查日志以获取详细信息：\n$(cat "$log_file")"
                            ;;
                    esac
                    mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null

                    # 显示错误信息
                    show_error "$error_msg"
                else
                    # 其他错误（非状态码错误）
                    clear_screen
                    show_title "安装失败"
                    echo "日志内容："
                    echo
                    cat "$log_file"
                    echo
                    read -p "按回车返回..." _
                fi

                return
            fi
            ;;
        3)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                show_error "未选择游戏或未设置安装路径！"
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_validate_$app_id.log"
            > "$log_file"
            
            clear_screen
            show_title "验证游戏服务器"
            echo -e "${CYAN}正在验证 $GAME_NAME，请耐心等待...${NC}\n"
            echo "详细信息请查看日志: $log_file"
            echo

            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee "$log_file"

            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
                show_message "验证完成 $GAME_NAME 服务器路径: $SERVER_DIR"
            else
                if grep -qi "Error! App '$app_id' state is 0x[0-9a-fA-F]\+ after update job" "$log_file"; then
                    error_code=$(grep -o "0x[0-9a-fA-F]\+" "$log_file" | head -n 1)

                    case "$error_code" in
                        "0x202")
                            error_msg="SteamCMD操作失败(错误代码: $error_code)\n\n"
                            error_msg+="原因：硬盘空间不足"
                            ;;
                        *)
                            error_msg="SteamCMD操作失败(未知错误代码: $error_code)\n\n"
                            error_msg+="请检查日志以获取详细信息：\n$(cat "$log_file")"
                            ;;
                    esac
                    mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null

                    # 显示错误信息
                    show_error "$error_msg"
                else
                    # 其他错误（非状态码错误）
                    clear_screen
                    show_title "安装失败"
                    echo "日志内容："
                    echo
                    cat "$log_file"
                    echo
                    read -p "按回车返回..." _
                fi

                return
            fi
            ;;
        4)
            if [ -z "$GAME_NAME" ]; then
                show_error "请先选择游戏！"
                return
            fi
            
            get_install_location
            show_message "游戏安装位置已更新为: $SERVER_DIR"
            ;;
        5)
            clear_screen
            show_title "切换游戏"
            echo "请选择游戏："
            echo "1) Team Fortress 2"
            echo "2) Left 4 Dead 2"
            echo "3) No More Room in Hell"
            echo "4) Garry's Mod"
            echo "5) Counter-Strike: Source"
            echo "6) 返回"
            echo
            read -p "请输入选择 [1-6]: " game_choice

            local new_game
            case $game_choice in
                1) new_game="Team Fortress 2" ;;
                2) new_game="Left 4 Dead 2" ;;
                3) new_game="No More Room in Hell" ;;
                4) new_game="Garry's Mod" ;;
                5) new_game="Counter-Strike: Source" ;;
                6|*) return ;;
            esac

            if [ -n "$new_game" ]; then
                GAME_NAME="$new_game"
                save_config
                show_message "当前游戏已切换为: $GAME_NAME"
            fi
            ;;
        6)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                show_error "未选择游戏或未设置安装路径！"
                return
            fi
            
            if ! confirm "您确定要完全删除以下游戏服务器吗？\n\n游戏: $GAME_NAME\n路径: $SERVER_DIR\n\n此操作不可恢复！"; then
                return
            fi
            
            if ! confirm "再次确认：您确定要永久删除 '$GAME_NAME' 服务器及其所有文件吗？"; then
                return
            fi
            
            # 停止并删除systemd服务
            local service_name="${GAME_SHORT_NAMES[$GAME_NAME]}server.service"
            if [ -f "/etc/systemd/system/$service_name" ]; then
                systemctl stop "$service_name" >/dev/null 2>&1
                systemctl disable "$service_name" >/dev/null 2>&1
                rm -f "/etc/systemd/system/$service_name"
                systemctl daemon-reload
            fi

            # 删除别名
            local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
            if [ -n "$game_short_name" ]; then
                # 删除包含特定命令的别名行
                sed -i "\|alias .*screen -d -r ${game_short_name}server|d" /etc/profile
                source /etc/profile
            fi
            
            # 删除服务器文件
            if [ -d "$SERVER_DIR" ]; then
                rm -rf "$SERVER_DIR"
                show_message "已成功删除 $GAME_NAME 服务器及其所有文件"
                
                # 清理配置
                SERVER_DIR=""
                GAME_NAME=""
                save_config
            else
                show_error "找不到服务器目录: $SERVER_DIR"
            fi
            ;;

        7|*) return ;;        *)
            show_error "无效的选择，请重新输入！"
            ;;

    esac
}

# 管理SM
manage_sm_mms() {
    check_server_dir || return

    clear_screen
    show_title "管理SM"
    echo -e "${YELLOW}1.${NC} 安装 SourceMod+Metamod:Source[v12]"
    echo -e "${YELLOW}2.${NC} 更新 SourceMod+Metamod:Source[v12]"
    echo -e "${YELLOW}3.${NC} 卸载 SourceMod+Metamod:Source[v12]"
    echo -e "${YELLOW}4.${NC} 返回主菜单"
    echo
    read -p "请输入选择 [1-4]: " choice
    echo

    case $choice in
        1) 
            # 检查是否已安装
            if [ -d "$SERVER_DIR/addons/sourcemod" ]; then
                if confirm "SourceMod 已安装，是否重新安装？"; then
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
                show_error "未选择游戏，请先选择游戏！"
                return 1
            fi
            local game_short_name
            game_short_name=$(get_game_short_name) || return 1
        
            local addons_dir="$SERVER_DIR/$game_short_name/addons"
        
            if [ ! -d "$addons_dir/sourcemod" ]; then
                show_error "SourceMod 未安装，请先安装！"
                return
            fi

            if [ ! -d "$addons_dir/metamod" ]; then
                show_error "Metamod:Source 未安装，请先安装！"
                return
            fi

            local error_file=$(mktemp)
            
            show_progress "正在更新 SourceMod+Metamod:Source..." <<'EOF'
                echo 20
                echo -e "${GREEN}[Info]${NC} 下载最新 Metamod:Source..."
                MM_INDEX_URL="https://www.metamodsource.net/mmsdrop/1.12/"
                MM_LATEST_NAME=$(curl -s "https://www.metamodsource.net/mmsdrop/1.12/mmsource-latest-linux")
                MM_FILENAME=$(echo "$MM_LATEST_NAME" | tr -d '\r\n')
                MM_DOWNLOAD_URL="${MM_INDEX_URL}${MM_FILENAME}"
                axel -q -n 10 "$MM_DOWNLOAD_URL" -o "$SERVER_DIR/$MM_FILENAME"
                if [ ! -s "$SERVER_DIR/$MM_FILENAME" ]; then
                    echo -e "${RED}[Error]${NC} Metamod:Source下载失败！" > "$error_file"
                    exit 1
                fi

                echo 50
                echo -e "${GREEN}[Info]${NC} 下载最新 SourceMod..."
                SM_INDEX_URL="https://sm.alliedmods.net/smdrop/1.12/"
                SM_LATEST_NAME=$(curl -s "https://sm.alliedmods.net/smdrop/1.12/sourcemod-latest-linux")
                SM_FILENAME=$(echo "$SM_LATEST_NAME" | tr -d '\r\n')
                SM_DOWNLOAD_URL="${SM_INDEX_URL}${SM_FILENAME}"
                axel -q -n 10 "$SM_DOWNLOAD_URL" -o "$SERVER_DIR/$SM_FILENAME"
                if [ ! -s "$SERVER_DIR/$SM_FILENAME" ]; then
                    echo -e "${RED}[Error]${NC} SourceMod下载失败！" > "$error_file"
                    exit 1
                fi

                echo 80
                # 创建临时目录
                local temp_dir=$(mktemp -d)

                # 解压 Metamod:Source
                tar -xzf "$SERVER_DIR/$MM_FILENAME" -C "$temp_dir"
                cp -rf "$temp_dir/addons/metamod/"* "$addons_dir/metamod/"

                # 解压 SourceMod
                tar -xzf "$SERVER_DIR/$SM_FILENAME" -C "$temp_dir"
                local sm_dirs=("bin" "extensions" "gamedata" "plugins" "scripting")
                for dir in "${sm_dirs[@]}"; do
                    if [ -d "$temp_dir/addons/sourcemod/$dir" ]; then
                        cp -rf "$temp_dir/addons/sourcemod/$dir/"* "$addons_dir/sourcemod/$dir/"
                    fi
                done

                rm -rf "$temp_dir"
                rm "$SERVER_DIR/$MM_FILENAME" "$SERVER_DIR/$SM_FILENAME"

                chown -R "$STEAM_USER:$STEAM_USER" "$addons_dir"
                echo 100
EOF

            if [ -s "$error_file" ]; then
                error_msg=$(cat "$error_file")
                rm "$error_file"
                show_error "$error_msg"
                return
            fi
            rm "$error_file"

            show_message "SourceMod 和 Metamod:Source 已更新到最新版本"
            ;;
        3)
            if [ -z "$GAME_NAME" ]; then
                show_error "未选择游戏，请先选择游戏！"
                return 1
            fi
            local game_short_name
            game_short_name=$(get_game_short_name) || return 1
        
            local addons_dir="$SERVER_DIR/$game_short_name/"

            if [ ! -d "$addons_dir/sourcemod" ]; then
                show_error "SourceMod 未安装！"
                return
            fi

            if confirm "确定要卸载 SourceMod 和 Metamod:Source 吗？"; then
                rm -rf "$SERVER_DIR/addons/sourcemod"
                rm -rf "$addons_dir/addons/metamod"
                show_message "SourceMod 和 Metamod:Source 已卸载"
            fi
            ;;
        *) return ;;
    esac
}

manage_workshop() {
    check_server_dir || return

    local workshop_dir="$SERVER_DIR/garrysmod/addons/workshop"
    mkdir -p "$workshop_dir"
    
    # 检查是否已设置集合ID
    local collection_id=""
    if [ -f "$SERVER_DIR/workshop_collection.txt" ]; then
        collection_id=$(cat "$SERVER_DIR/workshop_collection.txt")
    fi

    while true; do
        clear_screen
        show_title "管理创意工坊内容 (Garry's Mod)"
        echo "当前集合ID: ${collection_id:-未设置}"
        echo
        echo -e "${YELLOW}1.${NC} 设置创意工坊集合ID"
        echo -e "${YELLOW}2.${NC} 返回"
        echo
        read -p "请输入选择 [1-2]: " choice
        echo

        case $choice in
            1)
                local new_id
                get_input "请输入创意工坊集合ID:" "$collection_id"
                new_id=$input_value
                
                if [ -n "$new_id" ]; then
                    echo "$new_id" > "$SERVER_DIR/workshop_collection.txt"
                    collection_id="$new_id"

                    # 自动更新启动脚本
                    if [ -f "$SERVER_DIR/start.sh" ]; then
                        update_start_script_collection "$new_id"
                        show_message "已更新启动脚本中的创意工坊集合ID: $new_id"
                    else
                        show_message "启动脚本不存在，请先创建启动脚本"
                    fi
                fi
                ;;
            *) 
                return 
                ;;
        esac
    done
}

update_start_script_collection() {
    local collection_id="$1"
    local script_path="$SERVER_DIR/start.sh"
    
    # 检查文件是否存在
    if [ ! -f "$script_path" ]; then
        return 1
    fi
    
    # 更新集合ID
    sed -i "/host_workshop_collection/c\    +host_workshop_collection $collection_id \\\\" "$script_path"
}

manage_source_python() {
    check_server_dir || return

    # 检查游戏是否支持 Source.Python
    local supported_games=("Left 4 Dead 2" "Team Fortress 2" "Counter-Strike: Source")
    local is_supported=0
    
    for game in "${supported_games[@]}"; do
        if [ "$GAME_NAME" == "$game" ]; then
            is_supported=1
            break
        fi
    done

    if [ $is_supported -eq 0 ]; then
        show_error "当前游戏 $GAME_NAME 不支持 Source.Python"
        return
    fi

    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1
    
    # 游戏短名称到下载标识的映射
    declare -A SP_GAME_ID_MAP=(
        ["tf"]="tf2"
        ["left4dead2"]="l4d2"
        ["cstrike"]="css"
    )
    
    local game_id="${SP_GAME_ID_MAP[$game_short_name]}"
    if [ -z "$game_id" ]; then
        show_error "无法获取游戏下载标识！"
        return 1
    fi
    
    local addons_dir="$SERVER_DIR/$game_short_name/addons"
    local sp_dir="$addons_dir/source-python"
    
    while true; do
        clear_screen
        show_title "管理 Source.Python ($GAME_NAME)"
        echo -e "${YELLOW}1.${NC} 安装 Source.Python"
        echo -e "${YELLOW}2.${NC} 删除 Source.Python"
        echo -e "${YELLOW}3.${NC} 使用本地文件安装Source.Python"
        echo -e "${YELLOW}4.${NC} 返回"
        echo
        read -p "请输入选择 [1-4]: " choice
        echo

        case $choice in
            1)
                # 如果是Arch Linux系统，安装额外依赖
                if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
                    show_progress "正在安装 Source.Python 的额外依赖..." <<'EOF'
                        echo 10
                        echo "检测到Arch Linux系统，安装额外依赖..."

                        # 创建临时目录
                        local temp_dir=$(mktemp -d)
                        
                        # 定义依赖包URL
                        local deps=(
                            "https://blog.tyhh10.xyz/file/arch-zst-file/execstack-20130503-10-x86_64.pkg.tar.zst"
                            "https://blog.tyhh10.xyz/file/arch-zst-file/lib32-libffi7-3.3-2-x86_64.pkg.tar.zst"
                        )
                        
                        # 下载并安装每个依赖
                        for dep_url in "${deps[@]}"; do
                            local dep_file="${dep_url##*/}"
                            echo 20
                            echo -e "${GREEN}[Info]${NC} 下载 $dep_file..."
                            axel -q -n 5 "$dep_url" -o "$temp_dir/$dep_file"
                            
                            echo 40
                            echo -e "${GREEN}[Info]${NC} 安装 $dep_file..."
                            pacman -U --noconfirm --overwrite=* "$temp_dir/$dep_file" >/dev/null 2>&1
                        done
                        
                        # 清理临时目录
                        rm -rf "$temp_dir"
                        echo 60
EOF
                fi
                
                # 创建临时目录
                local temp_dir=$(mktemp -d)
                if [ ! -d "$temp_dir" ]; then
                    show_error "无法创建临时目录！"
                    return 1
                fi
                
                show_progress "正在安装 Source.Python[$game_id]..." <<'EOF'
                    echo 20
                    echo "获取最新下载链接..."
                    
                    local full_url="http://downloads.sourcepython.com/release/742/source-python-$game_id-July-06-2025.zip"
                    
                    echo 30
                    echo "下载 Source.Python ($game_id)..."
                    echo "URL: $full_url"
                    
                    # 下载 Source.Python
                    axel -q -n 10 "$full_url" -o "$temp_dir/source-python.zip"
                    
                    if [ ! -s "$temp_dir/source-python.zip" ]; then
                        echo -e "${RED}[Error]${NC} 下载失败: $full_url" > "$temp_dir/error.log"
                        exit 1
                    fi
                    
                    echo 60
                    echo "解压文件..."
                    
                    # 创建目标目录
                    mkdir -p "$sp_dir"
                    
                    # 解压到临时目录
                    unzip -q "$temp_dir/source-python.zip" -d "$temp_dir"
                    
                    echo 80
                    echo "安装文件..."
                    
                    # 移动文件到游戏目录
                    cp -r "$temp_dir/"* "$SERVER_DIR/$game_short_name"
                    
                    # 设置权限
                    chown -R "$STEAM_USER:$STEAM_USER" "$sp_dir"
                    
                    echo 100
                    sleep 1
EOF
                
                # 检查安装结果
                if [ -f "$temp_dir/error.log" ]; then
                    local error_msg=$(cat "$temp_dir/error.log")
                    rm -rf "$temp_dir"
                    show_error "$error_msg"
                elif [ -f "$temp_dir/warning.log" ]; then
                    local warning_msg=$(cat "$temp_dir/warning.log")
                    rm -rf "$temp_dir"
                    show_message "Source.Python ($game_id) 已安装，但有警告:\n\n$warning_msg"
                else
                    rm -rf "$temp_dir"
                    execstack -c "$addons_dir/source-python/bin/core.so"
                    show_message "Source.Python ($game_id) 已安装到:\n$sp_dir\n\n启动服务器后使用 'sp info' 命令验证安装"
                fi
                ;;
                
            2)
                # 卸载 Source.Python
                if [ ! -d "$sp_dir" ]; then
                    show_error "Source.Python 未安装！"
                    continue
                fi

                if confirm "确定要删除 Source.Python 吗？此操作不可恢复！"; then
                    show_progress "正在删除 Source.Python..." <<'EOF'
                        echo 10
                        echo -e "${GREEN}[Info]${NC} 删除文件..."
                        rm -rf "$addons_dir/source-python"
                        rm -rf "$addons_dir/source-python.dll"
                        rm -rf "$addons_dir/source-python.so"
                        rm -rf "$addons_dir/source-python.vdf"

                        # 确保完全卸载所有组件
                        echo 20
                        echo -e "${GREEN}[Info]${NC} 验证删除..."
                        rm -rf "$sp_dir/addons/source-python" 2>/dev/null

                        echo 30
                        #sleep 1
EOF

                    show_message "Source.Python 已卸载\n\n所有相关文件和目录已被删除"
                fi
                ;;
            3)
                if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
                    show_progress "正在安装 Source.Python 的额外依赖..." <<'EOF'
                        echo 10
                        echo "检测到Arch Linux系统，安装额外依赖..."

                        # 创建临时目录
                        local temp_dir=$(mktemp -d)
                        
                        # 定义依赖包URL
                        local deps=(
                            "https://blog.tyhh10.xyz/file/arch-zst-file/execstack-20130503-10-x86_64.pkg.tar.zst"
                            "https://blog.tyhh10.xyz/file/arch-zst-file/lib32-libffi7-3.3-2-x86_64.pkg.tar.zst"
                        )
                        
                        # 下载并安装每个依赖
                        for dep_url in "${deps[@]}"; do
                            local dep_file="${dep_url##*/}"
                            echo 20
                            echo -e "${GREEN}[Info]${NC} 下载 $dep_file..."
                            axel -q -n 5 "$dep_url" -o "$temp_dir/$dep_file"
                            
                            echo 40
                            echo -e "${GREEN}[Info]${NC} 安装 $dep_file..."
                            pacman -U --noconfirm --overwrite=* "$temp_dir/$dep_file" >/dev/null 2>&1
                        done
                        
                        # 清理临时目录
                        rm -rf "$temp_dir"
                        echo 60
EOF
                fi

                # 使用本地文件
                local test_file="source-python.zip"
                if [ ! -f "$test_file" ]; then
                    show_error "当前目录下未找到文件: $test_file\n\n请将文件放置到当前目录: $(pwd)"
                    continue
                fi

                # 创建临时目录
                local temp_dir=$(mktemp -d)
                
                show_progress "正在使用本地文件安装 Source.Python..." <<'EOF'
                    echo 20
                    echo "使用本地文件安装 Source.Python..."

                    # 复制文件到临时目录
                    cp "$test_file" "$temp_dir/source-python.zip"
                    
                    echo 40
                    echo "解压文件..."
                    # 创建目标目录
                    mkdir -p "$sp_dir"
                    
                    # 解压到临时目录
                    unzip -q "$temp_dir/source-python.zip" -d "$temp_dir"
                    
                    echo 70
                    echo "安装文件..."

                    # 移动文件到游戏目录
                    cp -r "$temp_dir/"* "$SERVER_DIR/$game_short_name"
                    
                    # 设置权限
                    chown -R "$STEAM_USER:$STEAM_USER" "$sp_dir"
                    
                    echo 100
                    #sleep 1
EOF
                
                # 清理临时目录
                rm -rf "$temp_dir"
                execstack -c "$addons_dir/source-python/bin/core.so"
                show_message "Source.Python 已通过本地文件安装到:\n$sp_dir\n\n启动服务器后使用 'sp info' 命令验证安装"
                ;;
            *)  
                return 
                ;;
        esac
    done
}

# 显示关于信息
show_about() {
    clear_screen
    show_title "关于"
    echo -e "${CYAN}服务器管理脚本 v1.0.8${NC}"
    echo -e "${GREEN}作者:${NC} TYHH10"
    echo -e "${GREEN}创建日期:${NC} 2025-07-07\n"
    echo -e "这个脚本,就纯粹就为了偷懒然后用AI跑的一个脚本awa"
    echo -e "结果花了一个下午，再加一个上午:(\n"
    echo -e "${YELLOW}注意:${NC}主要面向是单服务器,多服务器可能效果不佳\n"
    echo -e "${GREEN}功能说明:${NC}"
    echo -e "- 在Linux系统上安装和配置Source引擎游戏服务器"
    echo -e "- 自动安装游戏依赖项和SM+MM:S(SM 12版本)"
    echo -e "- 提供服务器启动脚本创建功能\n"
    read -p "按回车返回..." _
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

        # 根据当前游戏动态设置菜单项5
        local menu_option_5=""
        local menu_title_5=""
        if [ "$GAME_NAME" = "Garry's Mod" ]; then
            menu_option_5="5" 
            menu_title_5="管理创意工坊内容"
        else
            menu_option_5="5" 
            menu_title_5="管理SM+MM:S[v12]"
        fi

        # 显示主菜单
        clear_screen
        show_title "服务器管理脚本"
        echo -e "${GREEN}OS:${NC} $OS_INFO"
        echo -e "${GREEN}游戏服务器账户:${NC} $account_info"
        echo -e "${GREEN}游戏:${NC} $game_info"
        echo -e "${GREEN}安装路径:${NC} $install_info"
        echo
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "${YELLOW}1.${NC} 安装游戏服务器依赖"
        echo -e "${YELLOW}2.${NC} 管理游戏服务器账户"
        echo -e "${YELLOW}3.${NC} 管理SteamCMD"
        echo -e "${YELLOW}4.${NC} 管理游戏服务器"
        echo -e "${YELLOW}5.${NC} $menu_title_5"
        echo -e "${YELLOW}6.${NC} 管理启动脚本"
        echo -e "${YELLOW}7.${NC} 管理游戏服务器systemctl服务"
        echo -e "${YELLOW}8.${NC} 管理source.python"
        echo -e "${YELLOW}9.${NC} 查看脚本配置信息"
        echo -e "${YELLOW}10.${NC} 查看脚本配置文件"
        echo -e "${YELLOW}11.${NC} 关于本脚本"
        echo -e "${YELLOW}12.${NC} 完成并退出"
        echo
        read -p "请输入选择 [1-12]: " choice
        echo

        case $choice in
            1) detect_os; install_dependencies ;;
            2) set_server_user ;;
            3) 
                if [ -z "$STEAM_USER" ]; then
                    show_error "请先设置游戏服务器账户!"
                    continue
                fi
                manage_steamcmd 
                ;;
            4) 
                if [ -z "$STEAMCMD_PATH" ]; then
                    show_error "请先安装SteamCMD!"
                    continue
                fi
                
                if [ -z "$STEAM_USER" ]; then
                    show_error "请先设置游戏服务器账户!"
                    continue
                fi
                
                manage_game_server
                ;;
            5) 
                if [ "$GAME_NAME" = "Garry's Mod" ]; then
                    manage_workshop
                else
                    manage_sm_mms
                fi
                ;;
            6) 
                check_server_dir || return
                manage_start_scripts 
                ;;
            7) if [ -z "$GAME_NAME" ]; then
                    show_error "请先选择游戏！"
                    continue
                fi
                manage_systemd_service
                ;;
            8) manage_source_python ;;
            9) show_server_info ;;
            10) show_config ;;
            11) show_about ;;
            12) 
                if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                    if confirm "您尚未完成全部设置，确定要退出吗？"; then
                        save_config
                        exit 0
                    fi
                else
                    local script_name="start.sh"
                    show_title "安装和配置完成！"
                    echo -e "启动命令:\nsu $STEAM_USER && cd \"$SERVER_DIR\" && ./$script_name\n如果是使用systemd,进入后台后使用快捷键Ctrl + a + d来退出\n(不要直接Ctrl + c这样会结束服务器进程)"
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
    clear_screen
    show_title "服务器管理脚本"
    echo -e "${CYAN}欢迎使用服务器管理脚本${NC}\n"
    echo -e "本脚本将协助安装TF2/L4D2/NMRIH等服务器\n"
    echo -e "${GREEN}配置文件:${NC} $CONFIG_FILE"
    echo
    read -p "按回车继续..." _
    main_menu
}

# 执行主函数
main