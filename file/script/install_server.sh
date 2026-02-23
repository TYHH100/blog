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

# 命令行参数解析
USE_WHIPTAIL=true
GAME_OPTION=""
USER_OPTION=""
DIR_OPTION=""
STEAMCMD_PATH_OPTION=""
VALIDATE_GAME=false
UPDATE_GAME=false
AUTO_INSTALL=false

# 解析命令行参数
# 检查游戏短名称并转换为完整名称
check_game_short_name() {
    local short_name=$1
    for game in "${!GAME_SHORT_NAMES[@]}"; do
        if [ "${GAME_SHORT_NAMES[$game]}" = "$short_name" ]; then
            echo "$game"
            return 0
        fi
    done
    # 如果不是短名称，返回原始值
    echo "$short_name"
}

# 检查简化的游戏缩写并转换为完整名称
check_simplified_game_abbreviation() {
    local abbreviation=$1
    # 定义简化缩写映射
    declare -A SIMPLIFIED_ABBREVIATIONS=(
        ["tf2"]="Team Fortress 2" 
        ["l4d2"]="Left 4 Dead 2" 
        ["nmrih"]="No More Room in Hell" 
        ["gmod"]="Garry's Mod" 
        ["css"]="Counter-Strike: Source" 
    )
    
    # 检查是否为简化缩写
    if [ -n "${SIMPLIFIED_ABBREVIATIONS[$abbreviation]}" ]; then
        echo "${SIMPLIFIED_ABBREVIATIONS[$abbreviation]}"
        return 0
    fi
    
    # 如果不是简化缩写，返回原始值
    echo "$abbreviation"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-whiptail|-nw)
                USE_WHIPTAIL=false
                shift
                ;;
            --game|-g)
                GAME_OPTION="$2"
                # 首先检查是否为简化缩写
                GAME_OPTION=$(check_simplified_game_abbreviation "$GAME_OPTION")
                # 然后检查是否为标准短名称
                GAME_OPTION=$(check_game_short_name "$GAME_OPTION")
                shift 2
                ;;
            --user|-u)
                USER_OPTION="$2"
                shift 2
                ;;
            --dir|-d)
                DIR_OPTION="$2"
                shift 2
                ;;
            --steamcmd-dir|-scd)
                STEAMCMD_PATH_OPTION="$2"
                shift 2
                ;;
            --validate-game|-scvd)
                VALIDATE_GAME=true
                shift
                ;;
            --update-game|-scud)
                UPDATE_GAME=true
                shift
                ;;
            --auto-install|-ai)
                AUTO_INSTALL=true
                shift
                ;;
            --help|-h)
                echo -e "用法: $0 [选项](以下内容仅是测试,请谨慎使用!)"
                echo -e "选项:"
                echo -e "  --no-whiptail, -nw    不使用whiptail进行交互式操作"
                echo -e "  --game, -g <游戏名称>  指定游戏 (tf2, l4d2, nmrih, gmod, css)"
                echo -e "  --user, -u <用户名>   指定Steam用户"
                echo -e "  --dir, -d <路径>      指定安装目录"
                echo -e "  --steamcmd-dir, -scd <路径>    指定SteamCMD路径"
                echo -e "  --validate-game, -scvd         验证游戏服务器文件"
                echo -e "  --update-game, -scud         更新游戏服务器"
                echo -e "  --auto-install, -ai   自动下载并运行自动安装脚本"
                echo -e "  --help, -h            显示帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                echo -e "使用 --help 查看可用选项"
                exit 1
                ;;
        esac
    done
}

# 调用参数解析
parse_arguments "$@"

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

# 检查whiptail是否安装，未安装则自动安装（如果需要）
if [ "$USE_WHIPTAIL" = true ] && ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${BLUE}[Info]${NC} whiptail 未安装，正在尝试自动安装..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y whiptail
    elif command -v yum >/dev/null 2>&1; then
        yum install -y newt
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm libnewt
    else
        echo -e "${RED}[Error]${NC} 无法自动安装 whiptail，请手动安装后重试。"
        exit 1
    fi
    # 再次检测
    if ! command -v whiptail >/dev/null 2>&1; then
        echo -e "${RED}[Error]${NC} whiptail 安装失败，请手动安装后重试。"
        exit 1
    fi
elif [ "$USE_WHIPTAIL" = false ]; then
    echo -e "${BLUE}[Info]${NC} 以无whiptail模式运行..."
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
        local prebuilt_url="https://tyhh100.github.io/blog/file/arch-zst-file/lib32-ncurses5-compat-libs-6.5-3-x86_64.pkg.tar.zst"
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

check_server_dir() {
    if [ -z "$SERVER_DIR" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "请先安装游戏服务器!" 8 60
        else
            echo -e "${RED}[Error]${NC} 请先安装游戏服务器!"
        fi
        return 1
    fi
    return 0
}

get_game_short_name() {
    if [ -z "$GAME_NAME" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "未选择游戏！" 8 60
        else
            echo -e "${RED}[Error]${NC} 未选择游戏！"
        fi
        return 1
    fi
    
    local game_short_name="${GAME_SHORT_NAMES[$GAME_NAME]}"
    if [ -z "$game_short_name" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "无法获取游戏短名称！" 8 60
        else
            echo -e "${RED}[Error]${NC} 无法获取游戏短名称！"
        fi
        return 1
    fi
    
    echo "$game_short_name"
}

# 设置服务器账户
set_server_user() {
    local users=$(awk -F':' '{ if ($3 >= 1000 && $3 <= 65534) print $1 }' /etc/passwd)
    local current_user=$(id -un)
    
    # 如果已有配置，使用配置中的用户
    local default_user="$STEAM_USER"
    [ -z "$default_user" ] && default_user="gameserver"

    if [ "$USE_WHIPTAIL" = true ]; then
        # 使用whiptail模式
        local user_list=""
        
        # 生成用户列表选项
        for user in $users; do
            user_list+="$user 已存在 "
        done

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
    else
        # 使用命令行模式
        local user_list=()
        local i=1
        local cancelled=false
        
        # 处理Ctrl+C信号
        function cleanup() {
            cancelled=true
            echo -e "\n\033[1;44m 提示 \033[0m \033[31m操作已取消\033[0m\n"
            return 1
        }
        
        # 设置信号捕获
        trap "cleanup" INT
        
        # 生成用户列表选项
        for user in $users; do
            user_list+=($i "已存在: $user")
            i=$((i+1))
        done
        user_list+=($i "创建新账户")

        clear
        echo -e "${YELLOW}=== 选择游戏服务器账户 ===${NC}"
        echo -e "请选择用于运行游戏服务器的账户\n"
        echo -e "${RED}(推荐使用非root账户)${NC}"
        
        # 显示选项
        for ((j=0; j<${#user_list[@]}; j+=2)); do
            echo -e "${CYAN}[${user_list[j]}]${NC} ${user_list[j+1]}"
        done
        
        echo -e "\n${YELLOW}请输入选项编号:${NC}"
        
        # 读取用户选择
        while true; do
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            read -e -p "请选择: " choice
            
            # 如果用户取消操作（cancelled标志被设置）
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            if [[ $choice -ge 1 && $choice -le $i ]]; then
                break
            else
                echo -e "${RED}[Error]${NC} 无效的选项，请重新输入"
            fi
        done
        
        # 取消信号捕获
        trap - INT
        
        # 处理选择
        if [ $choice -eq $i ]; then
            # 创建新账户
            while true; do
                read -e -p "请输入新账户名称 [$default_user]: " STEAM_USER_input
                STEAM_USER=${STEAM_USER_input:-$default_user}
                
                if [ -z "$STEAM_USER" ]; then
                    echo -e "${RED}[Error]${NC} 账户名称不能为空"
                    continue
                fi
                
                # 检查账户是否已存在
                if id "$STEAM_USER" &>/dev/null; then
                    echo -e "${RED}[Error]${NC} 账户 '$STEAM_USER' 已存在！"
                    continue
                fi
                
                break
            done
            
            # 创建新账户
            useradd -m -s /bin/bash "$STEAM_USER"
            local password=$(openssl rand -base64 12)
            echo "$STEAM_USER:$password" | chpasswd
            echo -e "${GREEN}[Success]${NC} 已创建用户 '$STEAM_USER'"
            echo -e "${GREEN}[Success]${NC} 密码: $password"
            echo -e "${YELLOW}[Warning]${NC} 请记住此密码！"
        else
            # 选择现有账户
            local existing_users=($users)
            local selected_index=$((choice-1))
            STEAM_USER="${existing_users[$selected_index]}"
        fi
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
    local choice
    
    if [ "$USE_WHIPTAIL" = true ]; then
        # 使用whiptail模式
        choice=$(whiptail --title "SteamCMD 安装选项" --menu "请选择SteamCMD安装方式" 15 60 4 \
            "1" "自动安装最新版SteamCMD" \
            "2" "使用已安装的SteamCMD" 3>&1 1>&2 2>&3)
    else
        # 使用命令行模式
        local cancelled=false
        
        # 处理Ctrl+C信号
        function cleanup() {
            cancelled=true
            echo -e "\n\033[1;44m 提示 \033[0m \033[31m操作已取消\033[0m\n"
            return 1
        }
        
        # 设置信号捕获
        trap "cleanup" INT
        
        clear
        echo -e "${YELLOW}=== SteamCMD 安装选项 ===${NC}"
        echo -e "请选择SteamCMD安装方式\n"
        echo -e "${CYAN}[1]${NC} 自动安装最新版SteamCMD"
        echo -e "${CYAN}[2]${NC} 使用已安装的SteamCMD"
        echo -e "${CYAN}[0]${NC} 取消"
        
        while true; do
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            read -e -p "\n请选择 [1-2]: " choice
            
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            if [[ $choice =~ ^[120]$ ]]; then
                break
            else
                echo -e "${RED}[Error]${NC} 无效的选项，请输入1、2或0"
            fi
        done
        
        trap - INT
        
        if [ "$choice" = "0" ]; then
            return 1
        fi
    fi
    
    case $choice in
        1)
            if [ "$USE_WHIPTAIL" = true ]; then
                (
                    mkdir -p "$STEAM_HOME/steamcmd"
                    cd "$STEAM_HOME/steamcmd"
                    axel -q "$STEAMCMD_URL"
                    tar -xzf steamcmd_linux.tar.gz
                    rm steamcmd_linux.tar.gz
                    chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
                    
                    STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
                    save_config
                ) | whiptail --title "安装SteamCMD" --gauge "正在安装SteamCMD..." 8 70 0
                
                if [ $? -eq 0 ]; then
                    whiptail --title "安装成功" --msgbox "SteamCMD 已安装到: $STEAMCMD_PATH" 8 70
                fi
            else
                echo -e "${BLUE}[Info]${NC} 正在安装SteamCMD..."
                mkdir -p "$STEAM_HOME/steamcmd"
                cd "$STEAM_HOME/steamcmd"
                axel -q "$STEAMCMD_URL"
                tar -xzf steamcmd_linux.tar.gz
                rm steamcmd_linux.tar.gz
                chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
                
                STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
                save_config
                echo -e "${GREEN}[Success]${NC} SteamCMD 已安装到: $STEAMCMD_PATH"
            fi
            ;;
        2)
            if [ "$USE_WHIPTAIL" = true ]; then
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
            else
                while true; do
                    # 使用配置中的路径作为默认值
                    local default_path="$STEAMCMD_PATH"
                    [ -z "$default_path" ] && default_path="/usr/games/steamcmd/steamcmd.sh"
                    
                    clear
                    echo -e "${YELLOW}=== 输入SteamCMD路径 ===${NC}"
                    read -e -p "请输入已安装的steamcmd脚本完整路径 [$default_path]: " steam_path_input
                    local steam_path=${steam_path_input:-$default_path}
                    
                    if [ -z "$steam_path" ]; then
                        echo -e "${RED}[Error]${NC} 路径不能为空！"
                        echo -e "${YELLOW}[提示]${NC} 按Enter使用默认路径或输入自定义路径"
                        read -p "按Enter继续..." _
                        continue
                    fi
                    
                    if [ ! -f "$steam_path" ]; then
                        echo -e "${RED}[Error]${NC} 指定的路径不存在或不是文件: $steam_path"
                        echo -e "${YELLOW}[提示]${NC} 请检查路径是否正确"
                        read -p "按Enter继续..." _
                        continue
                    fi
                    
                    STEAMCMD_PATH="$steam_path"
                    save_config
                    echo -e "${GREEN}[Success]${NC} 已使用: $STEAMCMD_PATH SteamCMD文件"
                    break
                done
            fi
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
    
    local cancelled=false
    
    if [ "$USE_WHIPTAIL" = true ]; then
        # 使用whiptail模式
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
    else
        # 使用命令行模式
        # 处理Ctrl+C信号
        function cleanup() {
            cancelled=true
            echo -e "\n\033[1;44m 提示 \033[0m \033[31m操作已取消\033[0m\n"
            return 1
        }
        
        # 设置信号捕获
        trap "cleanup" INT
        
        while true; do
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            clear
            echo -e "${YELLOW}=== 选择安装位置 ===${NC}"
            echo -e "请输入 $GAME_NAME 服务器的安装路径:"
            read -e -p "[$default_dir]: " custom_dir_input
            local custom_dir=${custom_dir_input:-$default_dir}
            
            if $cancelled; then
                trap - INT
                return 1
            fi
            
            if [ -z "$custom_dir" ]; then
                echo -e "${RED}[Error]${NC} 安装路径不能为空!"
                read -p "按Enter继续..." _
                continue
            fi
            
            # 检查路径是否有效
            if [[ "$custom_dir" != /* ]]; then
                echo -e "${RED}[Error]${NC} 请提供绝对路径 (以/开头)!"
                read -p "按Enter继续..." _
                continue
            fi
            
            # 检查父目录是否存在
            local parent_dir=$(dirname "$custom_dir")
            if [ ! -d "$parent_dir" ]; then
                echo -e "${YELLOW}[提示]${NC} 父目录 '$parent_dir' 不存在"
                read -e -p "是否创建 [Y/n]: " create_dir
                create_dir=${create_dir:-Y}
                
                if [[ $create_dir =~ ^[Yy]$ ]]; then
                    mkdir -p "$parent_dir" || {
                        echo -e "${RED}[Error]${NC} 无法创建父目录: $parent_dir"
                        read -p "按Enter继续..." _
                        continue
                    }
                else
                    continue
                fi
            fi
            
            # 如果目标目录已经存在，检查是否为空
            if [ -d "$custom_dir" ]; then
                if [ "$(ls -A "$custom_dir")" ]; then
                    echo -e "${YELLOW}[Warning]${NC} 目录 '$custom_dir' 非空！继续安装将覆盖现有文件。"
                    read -e -p "是否继续 [y/N]: " continue_install
                    continue_install=${continue_install:-N}
                    
                    if [[ ! $continue_install =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
            fi
            
            # 取消信号捕获
            trap - INT
            
            SERVER_DIR="$custom_dir"
            
            # 创建目录并设置权限
            mkdir -p "$SERVER_DIR"
            chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
            
            # 保存配置
            save_config
            
            echo -e "${GREEN}[Success]${NC} 已设置安装位置: $SERVER_DIR"
            break
        done
    fi
}

# 下载游戏服务器
download_game() {
    if [ -z "$STEAMCMD_PATH" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "尚未安装SteamCMD! 请先安装SteamCMD。" 8 60
        else
            echo -e "\n${RED}[Error]${NC} 尚未安装SteamCMD! 请先安装SteamCMD。"
            read -p "按Enter继续..." _
        fi
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
    
    # 显示开始安装信息
    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "开始安装" --msgbox "正在下载安装 $GAME_NAME 服务器...\n此过程可能需要一些时间，请耐心等待。" 10 70
    else
        clear
        echo -e "${GREEN}=== 开始安装 $GAME_NAME 服务器 ===${NC}"
        echo -e "正在下载安装文件...\n此过程可能需要一些时间，请耐心等待。"
        echo -e "安装进度将实时显示在屏幕上...\n"
    fi
    
    # 执行安装并捕获输出
    if [ "$app_id" == "222860" ]; then
        # 下载L4D2的特殊方式 - 先下载Windows版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "${YELLOW}[Step 1/2]${NC} 正在下载Windows版本文件..."
        fi
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType windows +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
        
        # 然后下载Linux版本
        if [ "$USE_WHIPTAIL" != true ]; then
            echo -e "\n${YELLOW}[Step 2/2]${NC} 正在下载Linux版本文件..."
        fi
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +@sSteamCmdForcePlatformType linux +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    else
        # 其他游戏正常下载
        su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    fi

    # 检查安装结果
    if grep -qi "Success!" "$log_file"; then
        mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "完成" --msgbox "成功安装 $GAME_NAME 服务器到: $SERVER_DIR" 9 70
        else
            echo -e "\n${GREEN}[Success]${NC} 成功安装 $GAME_NAME 服务器到: $SERVER_DIR"
            echo -e "安装日志已保存至: $SERVER_DIR/install.log"
            read -p "按Enter继续..." _
        fi
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
            if [ "$USE_WHIPTAIL" = true ]; then
                whiptail --title "安装失败" --msgbox "$error_msg" 20 70
            else
                echo -e "\n${RED}[Error]${NC} 安装失败!"
                echo -e "$error_msg"
                echo -e "\n错误日志已保存至: $SERVER_DIR/install.log"
                read -p "按Enter继续..." _
            fi
        else
            # 其他错误（非状态码错误）
            mv "$log_file" "$SERVER_DIR/install.log" 2>/dev/null
            if [ "$USE_WHIPTAIL" = true ]; then
                whiptail --title "安装失败" --textbox "$SERVER_DIR/install.log" 20 70
            else
                echo -e "\n${RED}[Error]${NC} 安装失败!"
                echo -e "错误详情:\n"
                cat "$SERVER_DIR/install.log"
                echo -e "\n错误日志已保存至: $SERVER_DIR/install.log"
                read -p "按Enter继续..." _
            fi
        fi

        return
    fi
}

# 安装SourceMod和Metamod:Source
install_sourcemod() {
    if [ -z "$GAME_NAME" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "未选择游戏，请先选择游戏！" 8 60
        else
            echo -e "\n${RED}[Error]${NC} 未选择游戏，请先选择游戏！"
            read -p "按Enter继续..." _
        fi
        return 1
    fi
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1

    # 插件安装的目标目录
    local addons_dir="$SERVER_DIR/$game_short_name/"
    
    chown "$STEAM_USER:$STEAM_USER" "$addons_dir"

    local error_file=$(mktemp)
    local error_occurred=false
    
    if [ "$USE_WHIPTAIL" = true ]; then
        {
            echo 30
            echo "下载Metamod:Source..."
            axel -q -n 10 "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz" -o $SERVER_DIR/mms.tar.gz
            if [ ! -s $SERVER_DIR/mms.tar.gz ]; then
                echo -e "${RED}[Error]${NC} Metamod:Source下载失败！" > "$error_file"
                exit 1
            fi
            
            echo 60
            echo "下载SourceMod..."
            axel -q -n 10 "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7210-linux.tar.gz" -o $SERVER_DIR/sourcemod.tar.gz
            if [ ! -s $SERVER_DIR/sourcemod.tar.gz ]; then
                echo -e "${RED}[Error]${NC} SourceMod下载失败！" > "$error_file"
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
    else
        # 命令行模式
        clear
        echo -e "${GREEN}=== 安装SourceMod和Metamod:Source ===${NC}"
        echo -e "[30%] 下载Metamod:Source..."
        axel -n 10 "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz" -o $SERVER_DIR/mms.tar.gz
        if [ ! -s $SERVER_DIR/mms.tar.gz ]; then
            echo -e "${RED}[Error]${NC} Metamod:Source下载失败！" > "$error_file"
            error_occurred=true
        fi
        
        if [ ! "$error_occurred" = true ]; then
            echo -e "[60%] 下载SourceMod..."
            axel -n 10 "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7210-linux.tar.gz" -o $SERVER_DIR/sourcemod.tar.gz
            if [ ! -s $SERVER_DIR/sourcemod.tar.gz ]; then
                echo -e "${RED}[Error]${NC} SourceMod下载失败！" > "$error_file"
                error_occurred=true
            fi
        fi
        
        if [ ! "$error_occurred" = true ]; then
            echo -e "[80%] 安装到服务器目录..."
            tar -xzf $SERVER_DIR/mms.tar.gz -C "$addons_dir"
            tar -xzf $SERVER_DIR/sourcemod.tar.gz -C "$addons_dir"

            rm $SERVER_DIR/mms.tar.gz $SERVER_DIR/sourcemod.tar.gz
            chown -R "$STEAM_USER:$STEAM_USER" "$addons_dir"
            echo -e "[100%] 安装完成！"
        fi
    fi
    
    if [ -s "$error_file" ]; then
        local error_msg=$(cat "$error_file")
        rm "$error_file"
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "安装失败" --msgbox "$error_msg" 8 70
        else
            echo -e "\n${RED}[Error]${NC} 安装失败!"
            echo -e "$error_msg"
            read -p "按Enter继续..." _
        fi
        return 1
    fi
    rm "$error_file"

    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "安装完成" --msgbox "SourceMod和Metamod:Source已安装到: $addons_dir" 9 70
    else
        echo -e "\n${GREEN}[Success]${NC} SourceMod和Metamod:Source已安装到: $addons_dir"
        read -p "按Enter继续..." _
    fi
}

manage_start_scripts() {
    check_server_dir || return
    
    # 获取游戏短名称
    local game_short_name
    game_short_name=$(get_game_short_name) || return 1
    
    # 游戏目录
    local game_dir="$SERVER_DIR/$game_short_name"
    # 默认启动脚本路径
    local script_path="$game_dir/start.sh"
    
    # 检查现有启动脚本
    local has_script="0"
    if [ -f "$script_path" ]; then
        has_script="1"
    fi
    
    # 菜单选项
    local choices=(
        "1" "创建启动脚本"
        "2" "创建游戏服务器systemctl"
        "3" "返回"
    )
    
    while true; do
        if [ "$USE_WHIPTAIL" = true ]; then
            local choice=$(whiptail --title "管理启动脚本 ($game_dir)" --menu "选择操作" 16 60 6 \
                "${choices[@]}" 3>&1 1>&2 2>&3)
        else
            clear
            echo -e "${BLUE}===== 管理启动脚本 ($game_dir) =====${NC}"
            echo -e "1) 创建启动脚本"
            echo -e "2) 创建游戏服务器systemctl"
            echo -e "3) 返回"
            echo -e ""
            read -e -p "请输入选择 [1-3]: " choice
        fi
        
        case $choice in
            1)
                create_start_script ;;
            2)
                if [ ! -f "$SERVER_DIR/start.sh" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "未找到启动脚本！请先创建启动脚本" 8 60
                    else
                        echo -e "\n${RED}[Error]${NC} 未找到启动脚本！请先创建启动脚本"
                        read -p "按Enter继续..." _
                    fi
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
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "未找到 $service_name 服务！请先创建 systemd 服务。" 10 70
        else
            echo -e "\n${RED}[Error]${NC} 未找到 $service_name 服务！请先创建 systemd 服务。"
            read -p "按Enter继续..." _
        fi
        return 1
    fi
    
    # 服务管理菜单
    while true; do
        if [ "$USE_WHIPTAIL" = true ]; then
            local choice=$(whiptail --title "管理服务: $service_name" --menu "选择操作" 15 60 8 \
                "1" "启动服务" \
                "2" "停止服务" \
                "3" "重启服务" \
                "4" "查看服务状态" \
                "5" "启用开机自启" \
                "6" "禁用开机自启" \
                "7" "返回" 3>&1 1>&2 2>&3)
        else
            clear
            echo -e "${BLUE}===== 管理服务: $service_name =====${NC}"
            echo -e "1) 启动服务"
            echo -e "2) 停止服务"
            echo -e "3) 重启服务"
            echo -e "4) 查看服务状态"
            echo -e "5) 启用开机自启"
            echo -e "6) 禁用开机自启"
            echo -e "7) 返回"
            echo -e ""
            read -e -p "请输入选择 [1-7]: " choice
        fi
        
        case $choice in
            1)
                systemctl start "$service_name"
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已启动" --msgbox "服务 $service_name 已启动" 8 60
                else
                    echo -e "\n${GREEN}[Success]${NC} 服务 $service_name 已启动"
                    read -p "按Enter继续..." _
                fi
                ;;
            2)
                systemctl stop "$service_name"
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已停止" --msgbox "服务 $service_name 已停止" 8 60
                else
                    echo -e "\n${GREEN}[Success]${NC} 服务 $service_name 已停止"
                    read -p "按Enter继续..." _
                fi
                ;;
            3)
                systemctl restart "$service_name"
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已重启" --msgbox "服务 $service_name 已重启" 8 60
                else
                    echo -e "\n${GREEN}[Success]${NC} 服务 $service_name 已重启"
                    read -p "按Enter继续..." _
                fi
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
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已启用" --msgbox "服务 $service_name 已设置为开机自启" 9 70
                else
                    echo -e "\n${GREEN}[Success]${NC} 服务 $service_name 已设置为开机自启"
                    read -p "按Enter继续..." _
                fi
                ;;
            6)
                systemctl disable "$service_name"
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已禁用" --msgbox "服务 $service_name 已禁用开机自启" 9 70
                else
                    echo -e "\n${GREEN}[Success]${NC} 服务 $service_name 已禁用开机自启"
                    read -p "按Enter继续..." _
                fi
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
    
    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "启动脚本创建" --msgbox "启动脚本已创建: $script_path\n\n游戏短名称: $game_short_name\n默认地图: $default_map\n默认端口: $default_port\n使用账户: $STEAM_USER\n配置文件: $config_name" 14 70
    else
        echo -e "\n${GREEN}===== 启动脚本创建成功 =====${NC}"
        echo -e "启动脚本已创建: $script_path"
        echo -e "游戏短名称: $game_short_name"
        echo -e "默认地图: $default_map"
        echo -e "默认端口: $default_port"
        echo -e "使用账户: $STEAM_USER"
        echo -e "配置文件: $config_name"
        echo -e ""
        read -p "按Enter继续..." _
    fi
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

    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "Systemd 服务创建" --msgbox "Systemd 服务已创建: $service_path\n打开控制台关键词: ${game_short_name}" 8 60
    else
        echo -e "\n${GREEN}[Success]${NC} Systemd 服务已创建: $service_path"
        echo -e "打开控制台关键词: ${game_short_name}"
        read -p "按Enter继续..." _
    fi
    
    systemctl daemon-reload
    # 使用默认游戏短名称作为默认别名
    local default_alias="$game_short_name"
    local final_alias="$default_alias"
    
    # 询问是否使用自定义别名
    if [ "$USE_WHIPTAIL" = true ]; then
        local alias_input=$(whiptail --title "自定义别名" --inputbox "请输入自定义别名（留空则使用默认别名: $default_alias）:" 10 60 "$default_alias" 3>&1 1>&2 2>&3)
        
        # 处理输入：如果留空则使用默认值
        if [ -n "$alias_input" ]; then
            final_alias="$alias_input"
        fi
    else
        echo -e "\n${BLUE}===== 自定义别名 =====${NC}"
        echo -e "默认别名: $default_alias"
        read -e -p "请输入自定义别名（留空则使用默认别名）: " alias_input
        
        # 处理输入：如果留空则使用默认值
        if [ -n "$alias_input" ]; then
            final_alias="$alias_input"
        fi
    fi
    
    # 构建别名行
    local alias_line="alias $final_alias='sudo su -c \"screen -d -r ${game_short_name}server\" $STEAM_USER'"

    # 检查/etc/profile中是否已存在该别名
    if ! grep -qF "$alias_line" /etc/profile; then
        echo "$alias_line" >> /etc/profile
        source /etc/profile
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "别名添加" --msgbox "已添加别名: $final_alias" 10 70
        else
            echo -e "\n${GREEN}[Success]${NC} 已添加别名: $final_alias"
            echo -e "使用命令 '$final_alias' 可直接连接到服务器控制台"
            read -p "按Enter继续..." _
        fi
    else
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "别名已存在" --msgbox "别名已存在，无需重复添加" 8 60
        else
            echo -e "\n${BLUE}[Info]${NC} 别名已存在，无需重复添加"
            read -p "按Enter继续..." _
        fi
    fi
}

# 显示服务器信息
show_server_info() {
    load_config
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
    
    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "脚本配置信息" --msgbox "$info" 16 70
    else
        clear
        echo -e "${BLUE}===== 脚本配置信息 =====${NC}"
        echo -e "游戏服务器账户: $STEAM_USER"
        echo -e "账户主目录: $STEAM_HOME"
        echo -e "SteamCMD路径: ${STEAMCMD_PATH:-"未设置"}"
        echo -e "游戏名称: ${GAME_NAME:-"未选择"}"
        if [ -n "$SERVER_DIR" ]; then
            echo -e "安装位置: $SERVER_DIR"
            echo -e "磁盘使用: $(du -sh "$SERVER_DIR" | cut -f1)"
        else
            echo -e "安装位置: 未设置"
        fi
        echo -e ""
        read -p "按Enter继续..." _
    fi
}

# 显示配置文件内容
show_config() {
    if [ -f "$CONFIG_FILE" ]; then
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "脚本配置文件内容" --textbox "$CONFIG_FILE" 20 70
        else
            echo -e "${YELLOW}=== 脚本配置文件内容 ===${NC}"
            cat "$CONFIG_FILE"
            echo -e "${YELLOW}========================${NC}"
            read -p "按Enter继续..." _
        fi
    else
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "配置文件" --msgbox "配置文件不存在: $CONFIG_FILE" 10 60
        else
            echo -e "${RED}[Error]${NC} 配置文件不存在: $CONFIG_FILE"
        fi
    fi
}

# 管理SteamCMD
manage_steamcmd() {
    local choice
    
    if [ "$USE_WHIPTAIL" = true ]; then
        choice=$(whiptail --title "管理 SteamCMD" --menu "选择操作" 15 60 4 \
            "1" "安装SteamCMD" \
            "2" "重新安装SteamCMD" \
            "3" "更改现有的SteamCMD路径" \
            "4" "返回主菜单" 3>&1 1>&2 2>&3)
    else
        clear
        echo -e "${BLUE}=== 管理 SteamCMD ===${NC}"
        echo -e "1) 安装SteamCMD"
        echo -e "2) 重新安装SteamCMD"
        echo -e "3) 更改现有的SteamCMD路径"
        echo -e "4) 返回主菜单"
        echo -e ""
        read -e -p "请输入选择 [1-4]: " choice
    fi
    
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
                local steam_path
                local default_path="$STEAMCMD_PATH"
                
                if [ "$USE_WHIPTAIL" = true ]; then
                    steam_path=$(whiptail --title "输入 SteamCMD 路径" --inputbox "请输入已安装的 steamcmd 脚本完整路径:" 10 70 "$default_path" 3>&1 1>&2 2>&3)
                else
                    echo -e "${BLUE}=== 输入 SteamCMD 路径 ===${NC}"
                    read -e -p "请输入已安装的 steamcmd 脚本完整路径 [$default_path]: " steam_path_input
                    steam_path=${steam_path_input:-$default_path}
                fi
                
                if [ -z "$steam_path" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "路径不能为空！" 8 60
                    else
                        echo -e "${RED}[Error]${NC} 路径不能为空！"
                        read -p "按Enter继续..." _
                    fi
                    continue
                fi
                
                if [ ! -f "$steam_path" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "指定的路径不存在或不是文件: $steam_path" 10 70
                    else
                        echo -e "${RED}[Error]${NC} 指定的路径不存在或不是文件: $steam_path"
                        read -p "按Enter继续..." _
                    fi
                    continue
                fi
                
                STEAMCMD_PATH="$steam_path"
                save_config
                
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "设置成功" --msgbox "已更新 SteamCMD 路径为: $STEAMCMD_PATH" 8 70
                else
                    echo -e "${GREEN}[Success]${NC} 已更新 SteamCMD 路径为: $STEAMCMD_PATH"
                    read -p "按Enter继续..." _
                fi
                break
            done
            ;;
        *) return ;;
    esac
}

# 管理游戏服务器
manage_game_server() {
    local menu_title="管理游戏服务器"
    local choice
    
    if [ -n "$GAME_NAME" ]; then
        menu_title+=" [当前游戏: $GAME_NAME]"
    else
        menu_title+=" [未选择游戏]"
    fi

    if [ "$USE_WHIPTAIL" = true ]; then
        choice=$(whiptail --title "$menu_title" --menu "选择操作" 15 60 8 \
            "1" "安装新游戏服务器" \
            "2" "更新现有游戏服务器" \
            "3" "验证现有游戏服务器" \
            "4" "更改安装位置" \
            "5" "选择/切换游戏" \
            "6" "删除游戏服务器" \
            "7" "返回主菜单" 3>&1 1>&2 2>&3)
    else
        clear
        echo -e "${BLUE}=== $menu_title ===${NC}"
        echo -e "1) 安装新游戏服务器"
        echo -e "2) 更新现有游戏服务器"
        echo -e "3) 验证现有游戏服务器"
        echo -e "4) 更改安装位置"
        echo -e "5) 选择/切换游戏"
        echo -e "6) 删除游戏服务器"
        echo -e "7) 返回主菜单"
        echo -e ""
        read -e -p "请输入选择 [1-7]: " choice
    fi

    case $choice in
        1) download_game ;;
        2)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "未选择游戏或未设置安装路径！" 8 60
                else
                    echo -e "${RED}[Error]${NC} 未选择游戏或未设置安装路径！"
                    read -p "按Enter继续..." _
                fi
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_update_$app_id.log"
            > "$log_file"
            
            if [ "$USE_WHIPTAIL" = true ]; then
                whiptail --infobox "正在更新 $GAME_NAME，请耐心等待...\n\n详细信息请查看日志: $log_file" 9 70
            else
                echo -e "${BLUE}[Info]${NC} 正在更新 $GAME_NAME，请耐心等待...\n详细信息请查看日志: $log_file"
            fi

            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" +quit" 2>&1 | tee "$log_file"

            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/update.log" 2>/dev/null
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "完成" --msgbox "更新完成 $GAME_NAME 服务器路径: $SERVER_DIR" 9 70
                else
                    echo -e "${GREEN}[Success]${NC} 更新完成 $GAME_NAME 服务器路径: $SERVER_DIR"
                    read -p "按Enter继续..." _
                fi
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
                    mv "$log_file" "$SERVER_DIR/update.log" 2>/dev/null
                    
                    # 错误信息已在上面显示
                else
                    # 其他错误（非状态码错误）
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "安装失败" --textbox "$log_file" 20 70
                    else
                        echo -e "${RED}[Error]${NC} 安装失败\n详细错误信息:\n"
                        cat "$log_file"
                        read -p "按Enter继续..." _
                    fi
                fi

                return
            fi
            ;;
        3)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "未选择游戏或未设置安装路径！" 8 60
                else
                    echo -e "${RED}[Error]${NC} 未选择游戏或未设置安装路径！"
                    read -p "按Enter继续..." _
                fi
                return
            fi
            
            local app_id="${GAME_APPS[$GAME_NAME]}"
            
            # 创建临时日志文件
            local log_file="/tmp/steamcmd_validate_$app_id.log"
            > "$log_file"
            
            if [ "$USE_WHIPTAIL" = true ]; then
                whiptail --infobox "正在验证 $GAME_NAME，请耐心等待...\n\n详细信息请查看日志: $log_file" 9 70
            else
                echo -e "${BLUE}[Info]${NC} 正在验证 $GAME_NAME，请耐心等待...\n详细信息请查看日志: $log_file"
            fi

            su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee "$log_file"

            if grep -qi "Success!" "$log_file"; then
                mv "$log_file" "$SERVER_DIR/validate.log" 2>/dev/null
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "完成" --msgbox "验证完成 $GAME_NAME 服务器路径: $SERVER_DIR" 9 70
                else
                    echo -e "${GREEN}[Success]${NC} 验证完成 $GAME_NAME 服务器路径: $SERVER_DIR"
                    read -p "按Enter继续..." _
                fi
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
                    mv "$log_file" "$SERVER_DIR/validate.log" 2>/dev/null

                    # 显示错误信息
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "验证失败" --msgbox "$error_msg" 20 70
                    else
                        echo -e "${RED}[Error]${NC} 验证失败\n$error_msg"
                        read -p "按Enter继续..." _
                    fi
                else
                    # 其他错误（非状态码错误）
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "验证失败" --textbox "$log_file" 20 70
                    else
                        echo -e "${RED}[Error]${NC} 验证失败\n详细错误信息:\n"
                        cat "$log_file"
                        read -p "按Enter继续..." _
                    fi
                fi

                return
            fi
            ;;
        4)
            if [ -z "$GAME_NAME" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "请先选择游戏！" 8 60
                else
                    echo -e "${RED}[Error]${NC} 请先选择游戏！"
                    read -p "按Enter继续..." _
                fi
                return
            fi
            
            get_install_location
            if [ "$USE_WHIPTAIL" = true ]; then
                whiptail --title "位置已更改" --msgbox "游戏安装位置已更新为: $SERVER_DIR" 9 70
            else
                echo -e "${GREEN}[Success]${NC} 游戏安装位置已更新为: $SERVER_DIR"
                read -p "按Enter继续..." _
            fi
            ;;
        5)
            local new_game
            
            if [ "$USE_WHIPTAIL" = true ]; then
                new_game=$(whiptail --title "切换游戏" --menu "选择游戏" 15 45 5 \
                    "Team Fortress 2" "" \
                    "Left 4 Dead 2" "" \
                    "No More Room in Hell" "" \
                    "Garry's Mod" "" \
                    "Counter-Strike: Source" "" 3>&1 1>&2 2>&3)
            else
                clear
                echo -e "${BLUE}=== 切换游戏 ===${NC}"
                echo -e "1) Team Fortress 2"
                echo -e "2) Left 4 Dead 2"
                echo -e "3) No More Room in Hell"
                echo -e "4) Garry's Mod"
                echo -e "5) Counter-Strike: Source"
                echo -e ""
                read -e -p "请输入选择 [1-5] 或按Enter取消: " game_choice
                
                case "$game_choice" in
                    1) new_game="Team Fortress 2" ;;
                    2) new_game="Left 4 Dead 2" ;;
                    3) new_game="No More Room in Hell" ;;
                    4) new_game="Garry's Mod" ;;
                    5) new_game="Counter-Strike: Source" ;;
                    *) new_game="" ;;
                esac
            fi

            if [ -n "$new_game" ]; then
                GAME_NAME="$new_game"
                save_config
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "已切换" --msgbox "当前游戏已切换为: $GAME_NAME" 9 70
                else
                    echo -e "${GREEN}[Success]${NC} 当前游戏已切换为: $GAME_NAME"
                    read -p "按Enter继续..." _
                fi
            fi
            ;;
        6)
            if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "未选择游戏或未设置安装路径！" 8 60
                else
                    echo -e "${RED}[Error]${NC} 未选择游戏或未设置安装路径！"
                    read -p "按Enter继续..." _
                fi
                return
            fi
            
            local confirm_delete=false
            
            if [ "$USE_WHIPTAIL" = true ]; then
                if ! whiptail --title "确认删除" --yesno "您确定要完全删除以下游戏服务器吗？\n\n游戏: $GAME_NAME\n路径: $SERVER_DIR\n\n此操作不可恢复！" 12 70; then
                    return
                fi
                
                if ! whiptail --title "最后确认" --yesno "再次确认：您确定要永久删除 '$GAME_NAME' 服务器及其所有文件吗？" 10 70; then
                    return
                fi
                confirm_delete=true
            else
                clear
                echo -e "${RED}=== 确认删除 ===${NC}"
                echo -e "您确定要完全删除以下游戏服务器吗？"
                echo -e ""
                echo -e "游戏: $GAME_NAME"
                echo -e "路径: $SERVER_DIR"
                echo -e ""
                echo -e "${RED}此操作不可恢复！${NC}"
                echo -e ""
                read -e -p "确认删除? [y/N]: " first_confirm
                
                if [[ "$first_confirm" =~ ^[Yy]$ ]]; then
                    echo -e ""
                    echo -e "${RED}=== 最后确认 ===${NC}"
                    echo -e "再次确认：您确定要永久删除 '$GAME_NAME' 服务器及其所有文件吗？"
                    echo -e ""
                    read -e -p "请输入 yes 确认删除: " second_confirm
                    
                    if [[ "$second_confirm" == "yse" ]]; then
                        confirm_delete=true
                    fi
                fi
            fi
            
            if [ "$confirm_delete" != true ]; then
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
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "删除成功" --msgbox "已成功删除 $GAME_NAME 服务器及其所有文件" 9 70
                else
                    echo -e "${GREEN}[Success]${NC} 已成功删除 $GAME_NAME 服务器及其所有文件"
                    read -p "按Enter继续..." _
                fi
                
                # 清理配置
                SERVER_DIR=""
                GAME_NAME=""
                save_config
            else
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "找不到服务器目录: $SERVER_DIR" 9 70
                else
                    echo -e "${RED}[Error]${NC} 找不到服务器目录: $SERVER_DIR"
                    read -p "按Enter继续..." _
                fi
            fi
            ;;

        *) return ;;
    esac
}

# 管理SM
manage_sm_mms() {
    check_server_dir || return

    local choice=$(whiptail --title "管理SM" --menu "选择操作" 15 60 5 \
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
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "错误" --msgbox "未选择游戏，请先选择游戏！" 8 60
                else
                    echo -e "${RED}[Error]${NC} 未选择游戏，请先选择游戏！"
                    read -p "按Enter继续..." _
                fi
                return 1
            fi
            local game_short_name
            game_short_name=$(get_game_short_name) || return 1
        
            local addons_dir="$SERVER_DIR/$game_short_name/addons"
        
            if [ ! -d "$addons_dir/sourcemod" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "未安装" --msgbox "SourceMod 未安装，请先安装！" 8 60
                else
                    echo -e "${RED}[Error]${NC} SourceMod 未安装，请先安装！"
                    read -p "按Enter继续..." _
                fi
                return
            fi

            if [ ! -d "$addons_dir/metamod" ]; then
                if [ "$USE_WHIPTAIL" = true ]; then
                    whiptail --title "未安装" --msgbox "Metamod:Source 未安装，请先安装！" 8 60
                else
                    echo -e "${RED}[Error]${NC} Metamod:Source 未安装，请先安装！"
                    read -p "按Enter继续..." _
                fi
                return
            fi

            local error_file=$(mktemp)
            {
                echo 20
                echo -e "${BLUE}[Info]${NC} 下载最新 Metamod:Source..."
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
                echo -e "${BLUE}[Info]${NC} 下载最新 SourceMod..."
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
            local game_short_name
            game_short_name=$(get_game_short_name) || return 1
        
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
        local choice=$(whiptail --title "管理创意工坊内容 (Garry's Mod)" --menu "当前集合ID: ${collection_id:-未设置}" 15 60 5 \
            "1" "设置创意工坊集合ID" 3>&1 1>&2 2>&3)

        case $choice in
            1)
                local new_id=$(whiptail --title "设置创意工坊集合ID" --inputbox "请输入创意工坊集合ID:" 8 60 "$collection_id" 3>&1 1>&2 2>&3)
                if [ -n "$new_id" ]; then
                    echo "$new_id" > "$SERVER_DIR/workshop_collection.txt"
                    collection_id="$new_id"

                    # 自动更新启动脚本
                    if [ -f "$SERVER_DIR/start.sh" ]; then
                        update_start_script_collection "$new_id"
                        whiptail --title "启动脚本已更新" --msgbox "已更新启动脚本中的创意工坊集合ID: $new_id" 8 70
                    else
                        whiptail --title "注意" --msgbox "启动脚本不存在，请先创建启动脚本" 8 60
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
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "不支持" --msgbox "当前游戏 $GAME_NAME 不支持 Source.Python" 10 70
        else
            echo -e "${RED}[Error]${NC} 当前游戏 $GAME_NAME 不支持 Source.Python"
            read -p "按Enter继续..." _
        fi
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
        if [ "$USE_WHIPTAIL" = true ]; then
            whiptail --title "错误" --msgbox "无法获取游戏下载标识！" 8 60
        else
            echo -e "${RED}[Error]${NC} 无法获取游戏下载标识！"
            read -p "按Enter继续..." _
        fi
        return 1
    fi
    
    local addons_dir="$SERVER_DIR/$game_short_name/addons"
    local sp_dir="$addons_dir/source-python"
    
    while true; do
        if [ "$USE_WHIPTAIL" = true ]; then
            local choice=$(whiptail --title "管理 Source.Python ($GAME_NAME)" --menu "选择操作" 15 60 4 \
                "1" "安装 Source.Python" \
                "2" "删除 Source.Python" \
                "3" "使用本地文件安装Source.Python" \
                "4" "返回" 3>&1 1>&2 2>&3)
        else
            clear
            echo -e "${BLUE}===== 管理 Source.Python ($GAME_NAME) =====${NC}"
            echo -e "1) 安装 Source.Python"
            echo -e "2) 删除 Source.Python"
            echo -e "3) 使用本地文件安装Source.Python"
            echo -e "4) 返回"
            echo -e ""
            read -e -p "请输入选择 [1-4]: " choice
        fi

        case $choice in
            1)
                # 如果是Arch Linux系统，安装额外依赖
                if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
                    (
                        echo 10
                        echo "检测到Arch Linux系统，安装额外依赖..."

                        # 创建临时目录
                        local temp_dir=$(mktemp -d)
                        
                        # 定义依赖包URL
                        local deps=(
                            "https://tyhh100.github.io/blog/file/arch-zst-file/execstack-20130503-10-x86_64.pkg.tar.zst"
                            "https://tyhh100.github.io/blog/file/arch-zst-file/lib32-libffi7-3.3-2-x86_64.pkg.tar.zst"
                        )
                        
                        # 下载并安装每个依赖
                        for dep_url in "${deps[@]}"; do
                            local dep_file="${dep_url##*/}"
                            echo 20
                            echo -e "${BLUE}[Info]${NC} 下载 $dep_file..."
                            axel -q -n 5 "$dep_url" -o "$temp_dir/$dep_file"
                            
                            echo 40
                            echo -e "${BLUE}[Info]${NC} 安装 $dep_file..."
                            pacman -U --noconfirm --overwrite=* "$temp_dir/$dep_file" >/dev/null 2>&1
                        done
                        
                        # 清理临时目录
                        rm -rf "$temp_dir"
                        echo 60
                    ) | whiptail --title "安装 Arch Linux 依赖" --gauge "正在安装 Source.Python 的额外依赖..." 8 70 0
                fi
                
                # 创建临时目录
                local temp_dir=$(mktemp -d)
                if [ ! -d "$temp_dir" ]; then
                    whiptail --title "错误" --msgbox "无法创建临时目录！" 8 60
                    return 1
                fi
                (
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
                ) | whiptail --title "安装 Source.Python" --gauge "正在安装 Source.Python[$game_id]..." 8 70 0
                
                # 检查安装结果
                if [ -f "$temp_dir/error.log" ]; then
                    local error_msg=$(cat "$temp_dir/error.log")
                    rm -rf "$temp_dir"
                    whiptail --title "安装失败" --msgbox "$error_msg" 10 70
                elif [ -f "$temp_dir/warning.log" ]; then
                    local warning_msg=$(cat "$temp_dir/warning.log")
                    rm -rf "$temp_dir"
                    whiptail --title "安装成功（有警告）" --msgbox "Source.Python ($game_id) 已安装，但有警告:\n\n$warning_msg" 12 70
                else
                    rm -rf "$temp_dir"
                    execstack -c "$addons_dir/source-python/bin/core.so"
                    whiptail --title "安装成功" --msgbox "Source.Python ($game_id) 已安装到:\n$sp_dir\n\n启动服务器后使用 'sp info' 命令验证安装" 12 70
                fi
                ;;
                
            2)
                # 卸载 Source.Python
                if [ ! -d "$sp_dir" ]; then
                    whiptail --title "未安装" --msgbox "Source.Python 未安装！" 8 60
                    continue
                fi

                if whiptail --title "确认卸载" --yesno "确定要删除 Source.Python 吗？此操作不可恢复！" 10 60; then
                    (
                        echo 10
                        echo -e "${BLUE}[Info]${NC} 删除文件..."
                        rm -rf "$addons_dir/source-python"
                        rm -rf "$addons_dir/source-python.dll"
                        rm -rf "$addons_dir/source-python.so"
                        rm -rf "$addons_dir/source-python.vdf"

                        # 确保完全卸载所有组件
                        echo 20
                        echo -e "${BLUE}[Info]${NC} 验证删除..."
                        rm -rf "$sp_dir/addons/source-python" 2>/dev/null

                        echo 30
                        #sleep 1
                    ) | whiptail --title "删除 Source.Python" --gauge "正在删除 Source.Python..." 8 70 0

                    whiptail --title "删除完成" --msgbox "Source.Python 已卸载\n\n所有相关文件和目录已被删除" 9 70
                fi
                ;;
            3)
                if [[ "$OS_INFO" == *"arch"* ]] || [[ "$OS_INFO" == *"manjaro"* ]] || [[ "$OS_INFO" == *"artix"* ]]; then
                    (
                        echo 10
                        echo "检测到Arch Linux系统，安装额外依赖..."

                        # 创建临时目录
                        local temp_dir=$(mktemp -d)
                        
                        # 定义依赖包URL
                        local deps=(
                            "https://tyhh100.github.io/blog/file/arch-zst-file/execstack-20130503-10-x86_64.pkg.tar.zst"
                            "https://tyhh100.github.io/blog/file/arch-zst-file/lib32-libffi7-3.3-2-x86_64.pkg.tar.zst"
                        )
                        
                        # 下载并安装每个依赖
                        for dep_url in "${deps[@]}"; do
                            local dep_file="${dep_url##*/}"
                            echo 20
                            echo -e "${BLUE}[Info]${NC} 下载 $dep_file..."
                            axel -q -n 5 "$dep_url" -o "$temp_dir/$dep_file"
                            
                            echo 40
                            echo -e "${BLUE}[Info]${NC} 安装 $dep_file..."
                            pacman -U --noconfirm --overwrite=* "$temp_dir/$dep_file" >/dev/null 2>&1
                        done
                        
                        # 清理临时目录
                        rm -rf "$temp_dir"
                        echo 60
                    ) | whiptail --title "安装 Arch Linux 依赖" --gauge "正在安装 Source.Python 的额外依赖..." 8 70 0
                fi

                # 使用本地文件
                local test_file="source-python.zip"
                if [ ! -f "$test_file" ]; then
                    whiptail --title "文件不存在" --msgbox "当前目录下未找到文件: $test_file\n\n请将文件放置到当前目录: $(pwd)" 12 70
                    continue
                fi

                # 创建临时目录
                local temp_dir=$(mktemp -d)
                (
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
                ) | whiptail --title "安装 Source.Python" --gauge "正在使用本地文件安装 Source.Python..." 8 70 0
                
                # 清理临时目录
                rm -rf "$temp_dir"
                execstack -c "$addons_dir/source-python/bin/core.so"
                whiptail --title "安装成功" --msgbox "Source.Python 已通过本地文件安装到:\n$sp_dir\n\n启动服务器后使用 'sp info' 命令验证安装" 12 70
                ;;
            *)  
                return 
                ;;
        esac
    done
}

# 显示关于信息
show_about() {
    local about_info=""
    about_info+="服务器管理脚本 v1.0.7\n"
    about_info+="作者: TYHH10\n"
    about_info+="创建日期: 2025-07-07\n\n"
    about_info+="这个脚本,就纯粹就为了偷懒然后用AI跑的一个脚本awa\n"
    about_info+="结果花了一个下午，再加一个上午:(\n"
    about_info+="注意:主要面向是单服务器,多服务器可能效果不佳\n"
    about_info+="功能说明:\n"
    about_info+="- 在Linux系统上安装和配置Source引擎游戏服务器\n"
    about_info+="- 自动安装游戏依赖项和SM+MM:S(SM 12版本)\n"
    about_info+="- 提供服务器启动脚本创建功能\n\n"
    
    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "关于" --msgbox "$about_info" 18 70
    else
        clear
        echo -e "${BLUE}===== 关于 =====${NC}"
        echo -e "服务器管理脚本 v1.0.7"
        echo -e "作者: TYHH10"
        echo -e "创建日期: 2025-07-07"
        echo -e ""
        echo -e "这个脚本,就纯粹就为了偷懒然后用AI跑的一个脚本awa"
        echo -e "结果花了一个下午，再加一个上午:（"
        echo -e "注意:主要面向是单服务器,多服务器可能效果不佳"
        echo -e "功能说明:"
        echo -e "- 在Linux系统上安装和配置Source引擎游戏服务器"
        echo -e "- 自动安装游戏依赖项和SM+MM:S(SM 12版本)"
        echo -e "- 提供服务器启动脚本创建功能"
        echo -e ""
        read -p "按Enter继续..." _
    fi
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

        if [ "$USE_WHIPTAIL" = true ]; then
            local choice=$(whiptail --title "服务器管理脚本" --menu "\nOS: $OS_INFO| 游戏服务器账户: $account_info\n游戏: $game_info" 22 70 12 \
                "1" "安装游戏服务器依赖" \
                "2" "管理游戏服务器账户" \
                "3" "管理SteamCMD" \
                "4" "管理游戏服务器" \
                "$menu_option_5" "$menu_title_5" \
                "6" "管理启动脚本" \
                "7" "管理游戏服务器systemctl服务" \
                "8" "管理source.python" \
                "9" "查看脚本配置信息" \
                "10" "查看脚本配置文件" \
                "11" "关于本脚本" \
                "12" "完成并退出" 3>&1 1>&2 2>&3)
        else
            clear
            echo -e "${BLUE}===== 服务器管理脚本 =====${NC}"
            echo -e "OS: $OS_INFO | 游戏服务器账户: $account_info"
            echo -e "游戏: $game_info | 安装位置: $install_info"
            echo -e ""
            echo -e "1) 安装游戏服务器依赖"
            echo -e "2) 管理游戏服务器账户"
            echo -e "3) 管理SteamCMD"
            echo -e "4) 管理游戏服务器"
            echo -e "5) $menu_title_5"
            echo -e "6) 管理启动脚本"
            echo -e "7) 管理游戏服务器systemctl服务"
            echo -e "8) 管理source.python"
            echo -e "9) 查看脚本配置信息"
            echo -e "10) 查看脚本配置文件"
            echo -e "11) 关于本脚本"
            echo -e "12) 完成并退出"
            echo -e ""
            read -e -p "请输入选择 [1-12]: " choice
        fi

        case $choice in
            1) detect_os; install_dependencies ;;
            2) set_server_user ;;
            3) 
                if [ -z "$STEAM_USER" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "请先设置游戏服务器账户!" 8 60
                    else
                        echo -e "\n${RED}[Error]${NC} 请先设置游戏服务器账户!"
                        read -p "按Enter继续..." _
                    fi
                    continue
                fi
                manage_steamcmd 
                ;;
            4) 
                if [ -z "$STEAMCMD_PATH" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "请先安装SteamCMD!" 8 60
                    else
                        echo -e "\n${RED}[Error]${NC} 请先安装SteamCMD!"
                        read -p "按Enter继续..." _
                    fi
                    continue
                fi
                
                if [ -z "$STEAM_USER" ]; then
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "请先设置游戏服务器账户!" 8 60
                    else
                        echo -e "\n${RED}[Error]${NC} 请先设置游戏服务器账户!"
                        read -p "按Enter继续..." _
                    fi
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
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "错误" --msgbox "请先选择游戏！" 8 60
                    else
                        echo -e "\n${RED}[Error]${NC} 请先选择游戏！"
                        read -p "按Enter继续..." _
                    fi
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
                    if [ "$USE_WHIPTAIL" = true ]; then
                        if whiptail --title "确认退出" --yesno "您尚未完成全部设置，确定要退出吗？" --defaultno --yes-button "退出" --no-button "返回" 10 60; then
                            save_config
                            exit 0
                        fi
                    else
                        echo -e "\n${YELLOW}[Warning]${NC} 您尚未完成全部设置"
                        read -e -p "确定要退出吗？(y/n): " confirm_exit
                        if [ "$confirm_exit" = "y" ] || [ "$confirm_exit" = "Y" ]; then
                            save_config
                            exit 0
                        fi
                    fi
                else
                    local script_name="start.sh"
                    if [ "$USE_WHIPTAIL" = true ]; then
                        whiptail --title "完成" --msgbox "安装和配置完成！\n\n启动命令:\nsu $STEAM_USER && cd \"$SERVER_DIR\" && ./$script_name\n如果是使用systemd,进入后台后使用快捷键Ctrl + a + d来退出\n(不要直接Ctrl + c这样会结束服务器进程)" 12 70
                    else
                        echo -e "\n${GREEN}===== 安装和配置完成！ =====${NC}"
                        echo -e "启动命令:"
                        echo -e "su $STEAM_USER && cd \"$SERVER_DIR\" && ./$script_name"
                        echo -e ""
                        echo -e "注意事项:"
                        echo -e "如果是使用systemd,进入后台后使用快捷键Ctrl + a + d来退出"
                        echo -e "(不要直接Ctrl + c这样会结束服务器进程)"
                        read -p "按Enter退出..." _
                    fi
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
    if [ "$USE_WHIPTAIL" = true ]; then
        whiptail --title "服务器管理脚本" --msgbox "欢迎使用服务器管理脚本\n本脚本将协助安装TF2/L4D2/NMRIH等服务器\n\n配置文件: $CONFIG_FILE" 12 70
    else
        clear
        echo -e "${GREEN}====================================${NC}"
        echo -e "${GREEN}       欢迎使用服务器管理脚本       ${NC}"
        echo -e "${GREEN}====================================${NC}"
        echo -e "本脚本将协助安装TF2/L4D2/NMRIH等服务器"
        echo -e ""
        echo -e "配置文件: $CONFIG_FILE"
        echo -e ""
        read -p "按Enter继续..." _
    fi
    main_menu
}

# SteamCMD 验证游戏服务器
task_validate_game() {
    # 设置从命令行参数获取的值
    if [ -n "$GAME_OPTION" ]; then
        GAME_NAME="$GAME_OPTION"
    fi
    if [ -n "$USER_OPTION" ]; then
        STEAM_USER="$USER_OPTION"
    fi
    if [ -n "$DIR_OPTION" ]; then
        SERVER_DIR="$DIR_OPTION"
    fi
    
    # 检查必要的变量
    if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ] || [ -z "$STEAM_USER" ]; then
        echo -e "${RED}[Error]${NC} 缺少必要参数。验证游戏服务器需要指定游戏、用户和安装目录。"
        exit 1
    fi
    
    # 检查用户是否存在，不存在则创建
    if ! id "$STEAM_USER" &>/dev/null; then
        echo -e "${YELLOW}[Warning]${NC} 用户 '$STEAM_USER' 不存在，正在创建..."
        useradd -m -s /bin/bash "$STEAM_USER"
        local password=$(openssl rand -base64 12)
        echo "$STEAM_USER:$password" | chpasswd
        echo -e "${GREEN}[Success]${NC} 已创建用户 '$STEAM_USER'"
        echo -e "${GREEN}[Success]${NC} 密码: $password"
    fi
    
    # 设置账户主目录
    STEAM_HOME=$(eval echo ~$STEAM_USER)
    
    # 设置SteamCMD路径
    if [ -n "$STEAMCMD_PATH_OPTION" ]; then
        STEAMCMD_PATH="$STEAMCMD_PATH_OPTION"
    elif [ -z "$STEAMCMD_PATH" ]; then
        # 尝试默认路径
        STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
        if [ ! -f "$STEAMCMD_PATH" ]; then
            echo -e "${YELLOW}[Warning]${NC} 找不到SteamCMD，正在安装..."
            # 安装SteamCMD
            mkdir -p "$STEAM_HOME/steamcmd"
            cd "$STEAM_HOME/steamcmd"
            wget -q https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
            tar -xf steamcmd_linux.tar.gz
            rm steamcmd_linux.tar.gz
            chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
            STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
            echo -e "${GREEN}[Success]${NC} SteamCMD已安装到: $STEAMCMD_PATH"
        fi
    fi
    
    # 创建服务器目录（如果不存在）
    if [ ! -d "$SERVER_DIR" ]; then
        echo -e "${YELLOW}[Warning]${NC} 服务器目录不存在: $SERVER_DIR"
        echo -e "${BLUE}[Info]${NC} 创建服务器目录..."
        mkdir -p "$SERVER_DIR"
        chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
    fi
    
    echo -e "${GREEN}===== 开始验证游戏服务器 =====${NC}"
    echo -e "游戏: $GAME_NAME"
    echo -e "用户: $STEAM_USER"
    echo -e "目录: $SERVER_DIR"
    echo -e "SteamCMD: $STEAMCMD_PATH"
    echo -e ""
    
    # 获取游戏的app_id
    local app_id=${GAME_APPS[$GAME_NAME]}
    if [ -z "$app_id" ]; then
        echo -e "${RED}[Error]${NC} 不支持的游戏: $GAME_NAME"
        exit 1
    fi
    
    # 创建日志文件
    local log_file="$SERVER_DIR/validate.log"
    
    echo -e "${BLUE}[Info]${NC} 开始验证游戏文件..."
    echo -e "${BLUE}[Info]${NC} 日志文件: $log_file"
    
    # 执行验证命令
    su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" validate +quit" 2>&1 | tee -a "$log_file"
    
    echo -e "\n${GREEN}===== 游戏验证完成 =====${NC}"
    exit 0
}

# SteamCMD 更新游戏服务器
task_update_game() {
    # 设置从命令行参数获取的值
    if [ -n "$GAME_OPTION" ]; then
        GAME_NAME="$GAME_OPTION"
    fi
    if [ -n "$USER_OPTION" ]; then
        STEAM_USER="$USER_OPTION"
    fi
    if [ -n "$DIR_OPTION" ]; then
        SERVER_DIR="$DIR_OPTION"
    fi
    
    # 检查必要的变量
    if [ -z "$GAME_NAME" ] || [ -z "$SERVER_DIR" ] || [ -z "$STEAM_USER" ]; then
        echo -e "${RED}[Error]${NC} 缺少必要参数。更新游戏服务器需要指定游戏、用户和安装目录。"
        exit 1
    fi
    
    # 检查用户是否存在，不存在则创建
    if ! id "$STEAM_USER" &>/dev/null; then
        echo -e "${YELLOW}[Warning]${NC} 用户 '$STEAM_USER' 不存在，正在创建..."
        useradd -m -s /bin/bash "$STEAM_USER"
        local password=$(openssl rand -base64 12)
        echo "$STEAM_USER:$password" | chpasswd
        echo -e "${GREEN}[Success]${NC} 已创建用户 '$STEAM_USER'"
        echo -e "${GREEN}[Success]${NC} 密码: $password"
    fi
    
    # 设置账户主目录
    STEAM_HOME=$(eval echo ~$STEAM_USER)
    
    # 设置SteamCMD路径
    if [ -n "$STEAMCMD_PATH_OPTION" ]; then
        STEAMCMD_PATH="$STEAMCMD_PATH_OPTION"
    elif [ -z "$STEAMCMD_PATH" ]; then
        # 尝试默认路径
        STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
        if [ ! -f "$STEAMCMD_PATH" ]; then
            echo -e "${YELLOW}[Warning]${NC} 找不到SteamCMD，正在安装..."
            # 安装SteamCMD
            mkdir -p "$STEAM_HOME/steamcmd"
            cd "$STEAM_HOME/steamcmd"
            wget -q https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
            tar -xf steamcmd_linux.tar.gz
            rm steamcmd_linux.tar.gz
            chown -R "$STEAM_USER:$STEAM_USER" "$STEAM_HOME/steamcmd"
            STEAMCMD_PATH="$STEAM_HOME/steamcmd/steamcmd.sh"
            echo -e "${GREEN}[Success]${NC} SteamCMD已安装到: $STEAMCMD_PATH"
        fi
    fi
    
    # 创建服务器目录（如果不存在）
    if [ ! -d "$SERVER_DIR" ]; then
        echo -e "${YELLOW}[Warning]${NC} 服务器目录不存在: $SERVER_DIR"
        echo -e "${BLUE}[Info]${NC} 创建服务器目录..."
        mkdir -p "$SERVER_DIR"
        chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
    fi
    
    echo -e "${GREEN}===== 开始更新游戏服务器 =====${NC}"
    echo -e "游戏: $GAME_NAME"
    echo -e "用户: $STEAM_USER"
    echo -e "目录: $SERVER_DIR"
    echo -e "SteamCMD: $STEAMCMD_PATH"
    echo -e ""
    
    # 获取游戏的app_id
    local app_id=${GAME_APPS[$GAME_NAME]}
    if [ -z "$app_id" ]; then
        echo -e "${RED}[Error]${NC} 不支持的游戏: $GAME_NAME"
        exit 1
    fi
    
    # 创建日志文件
    local log_file="$SERVER_DIR/update.log"
    
    echo -e "${BLUE}[Info]${NC} 开始更新游戏文件..."
    echo -e "${BLUE}[Info]${NC} 日志文件: $log_file"
    
    # 执行更新命令（不验证）
    su - "$STEAM_USER" -c "cd \"$SERVER_DIR\" && \"$STEAMCMD_PATH\" +force_install_dir \"$SERVER_DIR\" +login anonymous +app_update \"$app_id\" +quit" 2>&1 | tee -a "$log_file"
    
    echo -e "\n${GREEN}===== 游戏更新完成 =====${NC}"
    exit 0
}

# 自动创建空白配置文件
create_default_config() {
    # 空白值
    local default_user=""
    local default_game=""
    local default_dir=""
    local default_steamcmd=""
    
    echo -e "${BLUE}[Info]${NC} 创建空白配置文件: $CONFIG_FILE"
    
    # 创建配置文件目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 创建配置文件
    cat > "$CONFIG_FILE" << EOF
# 服务器管理脚本配置文件
# 创建于: $(date)

# 游戏服务器账户
CONFIG_STEAM_USER="$default_user"
# 游戏名称
CONFIG_GAME_NAME="$default_game"
# 游戏服务器安装目录
CONFIG_SERVER_DIR="$default_dir"
# SteamCMD路径
CONFIG_STEAMCMD_PATH="$default_steamcmd"
EOF

    echo -e "${GREEN}[Success]${NC} 空白配置文件已创建"
}

# 自动安装函数 - 当提供了所有必要参数时直接执行安装
#auto_install() {
    # 设置全局变量
#    GAME_NAME="$GAME_OPTION"
#    STEAM_USER="$USER_OPTION"
#    SERVER_DIR="$DIR_OPTION"
    
    # 如果提供了SteamCMD路径，设置它
#    if [ -n "$STEAMCMD_PATH_OPTION" ]; then
#        STEAMCMD_PATH="$STEAMCMD_PATH_OPTION"
#    fi
    
    # 设置账户主目录
#    STEAM_HOME=$(eval echo ~$STEAM_USER)
    
#    echo -e "${GREEN}===== 开始自动安装 =====${NC}"
#    echo -e "游戏: $GAME_NAME"
#    echo -e "用户: $STEAM_USER"
#    echo -e "目录: $SERVER_DIR"
#    if [ -n "$STEAMCMD_PATH" ]; then
#        echo -e "SteamCMD: $STEAMCMD_PATH"
#    fi
#    echo -e ""
    
    # 1. 检查操作系统
#    detect_os
#    echo -e "${BLUE}[Info]${NC} 检测到操作系统: $OS_INFO"
    
    # 2. 安装依赖
#    echo -e "${BLUE}[Info]${NC} 开始安装游戏服务器依赖..."
#    install_dependencies
    
    # 3. 检查用户是否存在，不存在则创建
#    if ! id "$STEAM_USER" &>/dev/null; then
#        echo -e "${YELLOW}[Warning]${NC} 用户 '$STEAM_USER' 不存在，正在创建..."
#        useradd -m -s /bin/bash "$STEAM_USER"
#        local password=$(openssl rand -base64 12)
#        echo "$STEAM_USER:$password" | chpasswd
#        echo -e "${GREEN}[Success]${NC} 已创建用户 '$STEAM_USER'"
#        echo -e "${GREEN}[Success]${NC} 密码: $password"
        
        # 设置用户组权限
#        usermod -aG sudo "$STEAM_USER" 2>/dev/null || true
#    fi
    
    # 4. 安装SteamCMD（如果没有指定路径）
#    if [ -z "$STEAMCMD_PATH" ]; then
#        echo -e "${BLUE}[Info]${NC} 开始安装SteamCMD..."
#        install_steamcmd
#    else
#        echo -e "${BLUE}[Info]${NC} 使用指定的SteamCMD路径"
#    fi
    
    # 5. 创建服务器目录（如果不存在）
#    if [ ! -d "$SERVER_DIR" ]; then
#        echo -e "${BLUE}[Info]${NC} 创建服务器目录: $SERVER_DIR"
#        mkdir -p "$SERVER_DIR"
#        chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR"
#    fi
    
    # 6. 安装游戏服务器
#    echo -e "${BLUE}[Info]${NC} 开始安装游戏服务器..."
#    download_game
    
    # 7. 保存配置
#    save_config
    
    # 8. 完成安装
#    echo -e "\n${GREEN}===== 安装和配置完成！ =====${NC}"
#    echo -e "启动命令:"
#    echo -e "su $STEAM_USER && cd \"$SERVER_DIR\" && ./start.sh"
#    echo -e ""
#    echo -e "注意事项:"
#    echo -e "如果是使用systemd,进入后台后使用快捷键Ctrl + a + d来退出"
#    echo -e "(不要直接Ctrl + c这样会结束服务器进程)"
#    
#    exit 0
#}

# 从配置文件加载缺失参数
load_missing_params_from_config() {
    # 加载配置文件
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        # 如果命令行没有指定游戏，尝试从配置获取
        if [ -z "$GAME_OPTION" ] && [ -n "$CONFIG_GAME_NAME" ]; then
            GAME_OPTION="$CONFIG_GAME_NAME"
            echo -e "${BLUE}[Info]${NC} 从配置文件获取游戏: $GAME_OPTION"
        fi
        
        # 如果命令行没有指定用户，尝试从配置获取
        if [ -z "$USER_OPTION" ] && [ -n "$CONFIG_STEAM_USER" ]; then
            USER_OPTION="$CONFIG_STEAM_USER"
            echo -e "${BLUE}[Info]${NC} 从配置文件获取用户: $USER_OPTION"
        fi
        
        # 如果命令行没有指定目录，尝试从配置获取
        if [ -z "$DIR_OPTION" ] && [ -n "$CONFIG_SERVER_DIR" ]; then
            DIR_OPTION="$CONFIG_SERVER_DIR"
            echo -e "${BLUE}[Info]${NC} 从配置文件获取安装目录: $DIR_OPTION"
        fi
        
        # 如果命令行没有指定SteamCMD路径，尝试从配置获取
        if [ -z "$STEAMCMD_PATH_OPTION" ] && [ -n "$CONFIG_STEAMCMD_PATH" ] && [ -f "$CONFIG_STEAMCMD_PATH" ]; then
            STEAMCMD_PATH_OPTION="$CONFIG_STEAMCMD_PATH"
            echo -e "${BLUE}[Info]${NC} 从配置文件获取SteamCMD路径: $STEAMCMD_PATH_OPTION"
        fi
    else
        echo -e "${BLUE}[Info]${NC} 配置文件不存在: $CONFIG_FILE"
        # 创建空白配置文件
        create_default_config
        # 重新加载配置
        source "$CONFIG_FILE"
        
        # 尝试从新创建的配置获取参数
        if [ -z "$GAME_OPTION" ] && [ -n "$CONFIG_GAME_NAME" ]; then
            GAME_OPTION="$CONFIG_GAME_NAME"
            echo -e "${BLUE}[Info]${NC} 从空白配置获取游戏: $GAME_OPTION"
        fi
        if [ -z "$USER_OPTION" ] && [ -n "$CONFIG_STEAM_USER" ]; then
            USER_OPTION="$CONFIG_STEAM_USER"
            echo -e "${BLUE}[Info]${NC} 从空白配置获取用户: $USER_OPTION"
        fi
        if [ -z "$DIR_OPTION" ] && [ -n "$CONFIG_SERVER_DIR" ]; then
            DIR_OPTION="$CONFIG_SERVER_DIR"
            echo -e "${BLUE}[Info]${NC} 从空白配置获取安装目录: $DIR_OPTION"
        fi
    fi
}

# 检查是否提供了特定任务参数
if $VALIDATE_GAME || $UPDATE_GAME; then
    # 对于验证和更新任务，尝试从配置加载缺失参数
    load_missing_params_from_config
    
    if $VALIDATE_GAME; then
        # 执行验证任务
        check_root
        task_validate_game
    else
        # 执行更新任务
        check_root
        task_update_game
    fi
elif $AUTO_INSTALL; then
    # 自动安装模式：下载并运行自动安装脚本
    echo -e "${GREEN}===== 开始自动安装模式 =====${NC}"
    echo -e "${BLUE}[Info]${NC} 正在下载自动安装脚本..."
    
    # 自动安装脚本URL（使用本地文件路径）
    AUTO_INSTALL_SCRIPT_URL="https://tyhh100.github.io/blog/file/script/auto_install_server.sh"
    LOCAL_SCRIPT_PATH="/tmp/auto_install_server.sh"
    
    # 下载自动安装脚本
    if command -v axel >/dev/null 2>&1; then
        axel -q -n 10 "$AUTO_INSTALL_SCRIPT_URL" -o "$LOCAL_SCRIPT_PATH"
    else
        echo -e "${RED}[Error]${NC} 需要 axel 来下载自动安装脚本"
        exit 1
    fi
    
    # 检查下载是否成功
    if [ ! -f "$LOCAL_SCRIPT_PATH" ]; then
        echo -e "${RED}[Error]${NC} 自动安装脚本下载失败"
        exit 1
    fi
    
    # 设置执行权限
    chmod +x "$LOCAL_SCRIPT_PATH"
    
    echo -e "${GREEN}[Success]${NC} 自动安装脚本下载完成"
    echo -e "${BLUE}[Info]${NC} 正在启动自动安装脚本..."
    
    # 结束当前脚本并运行自动安装脚本
    exec "$LOCAL_SCRIPT_PATH"
else
    # 尝试从配置加载缺失参数
    load_missing_params_from_config
    
    # 执行主函数进入交互式模式
    # 无论是否有足够参数，都显示欢迎菜单
    check_root
    main
fi