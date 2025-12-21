#!/bin/bash

install_dependencies() {
    msg_info "正在检测并安装依赖..."
    
    local cmds=""
    if [[ "$OS_INFO" == *"ubuntu"* ]] || [[ "$OS_INFO" == *"debian"* ]]; then
        dpkg --add-architecture i386
        apt-get update
        cmds="lib32z1 libbz2-1.0:i386 lib32gcc-s1 lib32stdc++6 libcurl3-gnutls:i386 libsdl2-2.0-0:i386 screen unzip axel"
        apt-get install -y $cmds
    elif [[ "$OS_INFO" == *"centos"* ]] || [[ "$OS_INFO" == *"almalinux"* ]]; then
        cmds="glibc.i686 libstdc++.i686 libcurl.i686 zlib.i686 ncurses-libs.i686 screen unzip axel"
        yum install -y $cmds
    elif [[ "$OS_INFO" == *"arch"* ]]; then
        # 检查multilib仓库是否已启用
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            # 启用multilib仓库
            msg_info "启用Arch Linux的multilib仓库..."
            cp /etc/pacman.conf /etc/pacman.conf.bak
            echo [multilib] >> /etc/pacman.conf
            echo Include = /etc/pacman.d/mirrorlist >> /etc/pacman.conf
            # 更新软件包列表
            pacman -Sy
        fi
        local prebuilt_url="https://blog.tyhh10.xyz/file/arch-zst-file/lib32-ncurses5-compat-libs-6.5-3-x86_64.pkg.tar.zst"
        local temp_pkg="/tmp/lib32-ncurses5-compat-libs.pkg.tar.zst"
        pacman -Sy --noconfirm lib32-gcc-libs lib32-libcurl-gnutls lib32-openssl screen unzip axel
        axel -n 10 "$prebuilt_url" -o "$temp_pkg"
        pacman -Uy --noconfirm "$temp_pkg"
        rm -f "$temp_pkg"
    else
        msg_warn "无法自动检测操作系统类型，请手动安装依赖"
        return
    fi
    
    whiptail --msgbox "依赖安装完成！" 8 60
}

set_server_user() {
    local users=$(awk -F':' '{ if ($3 >= 1000 && $3 <= 65534) print $1 }' /etc/passwd)
    local user_list=""
    for u in $users; do user_list+="$u User "; done
    
    STEAM_USER=$(whiptail --title "选择运行用户" --menu "建议使用非root用户" 15 60 5 \
        $user_list "NEW_USER" "创建新用户" 3>&1 1>&2 2>&3)
    
    if [ "$STEAM_USER" == "NEW_USER" ]; then
        STEAM_USER=$(input_box "创建用户" "请输入用户名:" "gameserver")
        if [ -n "$STEAM_USER" ]; then
            useradd -m -s /bin/bash "$STEAM_USER"
            local password=$(openssl rand -base64 24)
            echo "$STEAM_USER:$password" | chpasswd
            msg_ok "用户 $STEAM_USER 已创建，密码为 $password"
        fi
    fi
    
    if [ -n "$STEAM_USER" ]; then
        STEAM_HOME=$(eval echo ~$STEAM_USER)
        save_user_config
    fi
}