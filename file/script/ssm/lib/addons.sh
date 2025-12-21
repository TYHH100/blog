#!/bin/bash

install_sourcemod_metamod() {
    if [ -z "$SERVER_DIR" ]; then whiptail --msgbox "未设置服务器路径" 8 60; return; fi
    
    local short_name=${GAME_SHORT_NAMES[$GAME_NAME]}
    local target_dir="$SERVER_DIR/$short_name"
    local addons_dir="$SERVER_DIR/$short_name/addons"
    local sm_url="https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7210-linux.tar.gz"
    local mm_url="https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz"

    msg_info "下载Metamod:Source..."
    axel -n 10 $mm_url -o $SERVER_DIR/mms.tar.gz
    if [ ! -s $SERVER_DIR/mms.tar.gz ]; then
        msg_err "Metamod:Source下载失败！"
        exit 1
    fi
            
    msg_info "下载SourceMod..."
    axel -n 10 $sm_url -o $SERVER_DIR/sm.tar.gz
    if [ ! -s $SERVER_DIR/sm.tar.gz ]; then
        msg_err "SourceMod下载失败！"
        exit 1
    fi
            
    msg_info "安装到服务器目录..."
    tar -xzf $SERVER_DIR/mms.tar.gz -C "$target_dir"
    tar -xzf $SERVER_DIR/sm.tar.gz -C "$target_dir"

    rm $SERVER_DIR/mms.tar.gz $SERVER_DIR/sm.tar.gz
    chown -R "$STEAM_USER:$STEAM_USER" "$target_dir"

    whiptail --msgbox "SM+MM:S安装完成！" 8 60
}

menu_addons() {
    local choice=$(whiptail --menu "插件管理" 12 60 3 \
        "1" "安装 SourceMod + Metamod" \
        "2" "管理创意工坊 (GMod)" \
        "3" "返回主菜单" 3>&1 1>&2 2>&3)
    
    case $choice in
        1) install_sourcemod_metamod ;;
        2) whiptail --msgbox "功能开发中..." 8 60 ;;
    esac
}