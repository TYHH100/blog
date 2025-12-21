#!/bin/bash

install_steamcmd() {
    if [ -z "$STEAM_USER" ]; then
        whiptail --msgbox "请先设置运行用户！" 8 60; return
    fi

    local install_dir="$STEAM_HOME/steamcmd"
    mkdir -p "$install_dir"
    
    (
        cd "$install_dir"
        echo 10; echo "XXX\n下载 SteamCMD...\nXXX"
        axel -q -n 5 "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
        echo 50; echo "XXX\n解压...\nXXX"
        tar -xzf steamcmd_linux.tar.gz
        rm steamcmd_linux.tar.gz
        chown -R "$STEAM_USER:$STEAM_USER" "$install_dir"
        echo 100
    ) | whiptail --gauge "正在安装 SteamCMD" 8 60 0

    STEAMCMD_PATH="$install_dir/steamcmd.sh"
    save_user_config
    whiptail --msgbox "SteamCMD 安装成功: $STEAMCMD_PATH" 8 60
}

menu_steamcmd() {
    local choice=$(whiptail --menu "SteamCMD 管理" 12 60 3 \
        "1" "自动安装 SteamCMD" \
        "2" "指定现有路径" \
        "3" "返回主菜单" 3>&1 1>&2 2>&3)
        
    case $choice in
        1) install_steamcmd ;;
        2) 
            STEAMCMD_PATH=$(input_box "路径设置" "输入 steamcmd.sh 绝对路径" "")
            save_user_config 
            ;;
    esac
}