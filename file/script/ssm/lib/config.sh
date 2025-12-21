#!/bin/bash

CONFIG_FILE="/etc/source_server_manager.conf"
CUSTOM_GAME_DIR="$BASE_DIR/custom_games"

# 游戏定义
declare -A GAME_APPS=(
    ["Team Fortress 2"]="232250"
    ["Left 4 Dead 2"]="222860"
    ["No More Room in Hell"]="317670"
    ["Garry's Mod"]="4020"
    ["Counter-Strike: Source"]="232330"
)

declare -A GAME_SHORT_NAMES=(
    ["Team Fortress 2"]="tf"
    ["Left 4 Dead 2"]="left4dead2"
    ["No More Room in Hell"]="nmrih"
    ["Garry's Mod"]="garrysmod"
    ["Counter-Strike: Source"]="cstrike"
)

load_custom_games() {
    if [ -d "$CUSTOM_GAME_DIR" ]; then
        for game_file in "$CUSTOM_GAME_DIR"/*.sh; do
            if [ -f "$game_file" ]; then
                source "$game_file"
            fi
        done
    fi
}

# 全局变量初始化
STEAM_USER=""
STEAM_HOME=""
SERVER_DIR=""
GAME_NAME=""
STEAMCMD_PATH=""

load_user_config() {
    load_custom_games

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        # 恢复环境
        [ -n "$CFG_STEAM_USER" ] && STEAM_USER="$CFG_STEAM_USER" && STEAM_HOME=$(eval echo ~$STEAM_USER)
        [ -n "$CFG_SERVER_DIR" ] && SERVER_DIR="$CFG_SERVER_DIR"
        [ -n "$CFG_GAME_NAME" ] && GAME_NAME="$CFG_GAME_NAME"
        [ -n "$CFG_STEAMCMD_PATH" ] && STEAMCMD_PATH="$CFG_STEAMCMD_PATH"
    fi
}

save_user_config() {
    cat > "$CONFIG_FILE" << EOF
CFG_STEAM_USER="$STEAM_USER"
CFG_SERVER_DIR="$SERVER_DIR"
CFG_GAME_NAME="$GAME_NAME"
CFG_STEAMCMD_PATH="$STEAMCMD_PATH"
EOF
}

show_config_info() {
    whiptail --title "当前配置" --msgbox \
        "用户: $STEAM_USER\n主目录: $STEAM_HOME\n游戏: $GAME_NAME\n安装位置: $SERVER_DIR\nSteamCMD: $STEAMCMD_PATH" 12 70
}