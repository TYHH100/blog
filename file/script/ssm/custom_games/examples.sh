#!/bin/bash
# =============================================================================
# SSM (Source Server Manager) — 自定义游戏定义参考模板
# =============================================================================
# 本文件是 custom_games 的完整示例和参考文件。
# 你可以直接复制本文件中的代码段，修改后用于定义自己的游戏。
#
# 文件命名要求: 必须以 .sh 结尾，放在 custom_games/ 目录下
# 加载机制: SSM 启动时自动 source 该目录下所有 .sh 文件
#
# 目录:
#   1. 快速入门 — 最简 Source 引擎游戏配置
#   2. 标准配置 — 带依赖的 Source 引擎游戏
#   3. 高级配置 — 非 Source 引擎游戏
#   4. 钩子函数详解
#      a) 安装后处理  — install_dependencies_{short_name}()
#      b) 自定义启动脚本 — override_start_script_{short_name}()
#      c) 自定义更新脚本 — override_update_script_{short_name}()
#      d) 自定义配置生成 — override_config_gen_{short_name}()
#      e) 游戏选择后置  — on_game_selected_{short_name}()
#      f) 配置加载后置  — on_config_loaded_{short_name}()
#   5. 服务器变体选择菜单 — menu_select_variant_{short_name}()
#   6. 注册全局变量参考
# =============================================================================

# =============================================================================
# 快速提示
# =============================================================================
# - 所有 GAME_* 变量都是全局关联数组 (GAME_APPS, GAME_SHORT_NAMES 等)
# - game_xxx 局部变量仅在当前脚本中可见，赋值给 GAME_XXX[] 后才会永久注册
# - short_name 是内部标识，用于命名钩子函数
# - 已有内置游戏: tf, tf2classified, left4dead2, garrysmod, cstrike, nmrih, barotrauma
# - 不能与内置游戏或已有自定义游戏重名

# =============================================================================
# 以下所有示例均定义为 函数/变量块，不会自动执行。
# 用户在创建自己的游戏定义时，直接复制对应的代码块进行修改即可。
# =============================================================================


# =============================================================================
# 1. 快速入门 — 最简 Source 引擎游戏配置
# =============================================================================
# 适用于: 标准 Source 引擎游戏（如 CS:S, HL2:DM, DOD:S 等）
# 仅需要: 游戏名, App ID, 短名称, 默认地图
#
# 复制此代码块，修改变量即可使用。
# =============================================================================

if false; then  # 示例代码，不会实际执行（用户复制时删除 "if false; then" 和 "fi"）

# --- 用户需修改的区域开始 ---
game_name="Examples"           # 显示名称（支持中文和空格）
game_app_id="0000000"                # Steam App ID（在 SteamDB 查询）
game_short_name="my_game"            # 短名称（仅限小写字母和下划线，唯一标识）
game_default_map="de_dust2"          # 默认地图
# --- 用户需修改的区域结束 ---

# 游戏高级配置（Source 引擎使用默认值即可）
game_engine="source"                 # 引擎类型: source | unreal | unity | generic | other
game_platform_order="linux"          # 下载平台: linux | windows（大多数游戏只需 linux）
game_download_verify="standard"      # 验证模式: standard | dual_platform

# 注册游戏基本信息
GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"

# 注册游戏高级配置
GAME_ENGINES["$game_name"]="$game_engine"
GAME_PLATFORM_ORDERS["$game_name"]="$game_platform_order"
GAME_DOWNLOAD_VERIFIES["$game_name"]="$game_download_verify"

fi


# =============================================================================
# 2. 标准配置 — 带依赖的 Source 引擎游戏
# =============================================================================
# 适用于: 需要在另一个游戏基础上运行的模组/衍生游戏
# 例如: TF2 Classified 依赖 Team Fortress 2
#
# 额外功能:
#   - game_dependencies: 指定依赖的游戏名称（必须与已注册的游戏名完全一致）
#   - install_dependencies_{short_name}(): 安装后处理函数（修复库文件等）
# =============================================================================

if false; then  # 示例代码，不会实际执行

# --- 用户需修改的区域开始 ---
game_name="Examples"
game_app_id="0000000"
game_short_name="mymod"
game_default_map="de_dust2"
game_dependencies="Counter-Strike: Source"  # 依赖的基础游戏（必须是已注册的游戏名）
# --- 用户需修改的区域结束 ---

# 游戏高级配置
game_engine="source"
game_platform_order="linux"
game_download_verify="standard"

# 注册游戏基本信息
GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"

# 注册游戏高级配置
GAME_ENGINES["$game_name"]="$game_engine"
GAME_PLATFORM_ORDERS["$game_name"]="$game_platform_order"
GAME_DOWNLOAD_VERIFIES["$game_name"]="$game_download_verify"

# 注册游戏依赖（仅在 game_dependencies 非空时注册）
if [ -n "$game_dependencies" ]; then
    GAME_DEPENDENCIES["$game_name"]="$game_dependencies"
fi

# --- 安装后处理函数示例 ---
# 此函数会在游戏安装/更新完成后自动调用
# 函数名必须为: install_dependencies_{short_name}()
install_dependencies_mymod() {
    msg_info "正在执行 $game_name 安装后处理..."

    # 示例: 修复库文件符号链接
    if [ -d "$SERVER_DIR/bin/linux64" ]; then
        if [ -f "$SERVER_DIR/bin/linux64/libmymod_srv.so" ]; then
            if [ -f "$SERVER_DIR/bin/linux64/libmymod.so" ]; then
                rm "$SERVER_DIR/bin/linux64/libmymod.so"
            fi
            ln -s "libmymod_srv.so" "$SERVER_DIR/bin/linux64/libmymod.so"
            msg_ok "已修复 libmymod.so 符号链接"
        fi
    fi

    # 示例: 配置 steamclient.so
    local steam_dir="$(eval echo ~$STEAM_USER)/.steam/sdk64"
    if [ ! -d "$steam_dir" ]; then
        mkdir -p "$steam_dir"
    fi
    if [ -f "$SERVER_DIR/linux64/steamclient.so" ]; then
        ln -sf "$SERVER_DIR/linux64/steamclient.so" "$steam_dir/steamclient.so"
        msg_ok "已添加 steamclient.so 符号链接"
    fi

    msg_ok "$game_name 安装后处理完成"
}

fi


# =============================================================================
# 3. 高级配置 — 非 Source 引擎游戏
# =============================================================================
# 适用于: 使用其他引擎或自研引擎的游戏
# 例如: Barotrauma、7 Days to Die等
#
# 差异点:
#   - game_engine="other"（或 unreal / unity / generic）
#   - 需要额外注册启动命令、工作目录、配置目录等
#   - 需自定义 install_dependencies_{short_name}() 处理安装后逻辑
# =============================================================================

if false; then  # 示例代码，不会实际执行

# --- 用户需修改的区域开始 ---
game_name="Examples"
game_app_id="0000000"
game_short_name="my_other_game"
game_default_map=""                  # 非 Source 引擎通常没有"地图"概念，可留空
# --- 用户需修改的区域结束 ---

# 游戏高级配置
game_engine="other"                  # 非 Source 引擎
game_platform_order="linux"
game_download_verify="standard"

# 注册游戏基本信息
GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"

# 注册游戏高级配置
GAME_ENGINES["$game_name"]="$game_engine"
GAME_PLATFORM_ORDERS["$game_name"]="$game_platform_order"
GAME_DOWNLOAD_VERIFIES["$game_name"]="$game_download_verify"

# 注册非 Source 引擎游戏的额外配置（根据实际情况选填）
GAME_START_CMDS["$game_name"]="./MyGameServer"       # 服务器可执行文件（相对于安装目录）
GAME_START_ARGS["$game_name"]="-batchmode -nographics -port 27015"  # 启动参数
GAME_WORKDIRS["$game_name"]="$SERVER_DIR"             # 工作目录（通常就是安装目录）
GAME_CFG_DIRS["$game_name"]="$SERVER_DIR/config"      # 配置文件目录

fi


# =============================================================================
# 4b. 自定义启动脚本生成 — override_start_script_{short_name}()
# =============================================================================
# 触发时机: 创建服务器启动脚本时调用
# 参数:
#   $1 — install_dir（游戏安装目录）
#   $2 — script_file（启动脚本目标路径）
# 不定义此函数时，SSM 会自动生成标准启动脚本（仅适用于 Source 引擎游戏）
#
# 适用于: 需要特殊启动参数、端口选择、路径配置的非标准游戏
# =============================================================================

if false; then  # 示例代码，不会实际执行

override_start_script_my_game() {
    local install_dir=$1
    local script_file=$2

    local default_port=$(( RANDOM % 1000 + 27015 ))
    local default_map=${GAME_DEFAULT_MAPS[$GAME_NAME]:-"de_dust2"}
    local cfg_dir="$install_dir/${game_short_name}/cfg"
    local config_name="server.cfg"

    # 创建配置目录
    if [ ! -d "$cfg_dir" ]; then
        mkdir -p "$cfg_dir"
    fi

    # 创建默认服务器配置文件
    if [ ! -f "$cfg_dir/$config_name" ]; then
        cat > "$cfg_dir/$config_name" << CONFIG_EOF
// $game_name 服务器配置
hostname "$game_name 服务器"
sv_password ""
rcon_password "$(openssl rand -hex 30)"
sv_cheats "0"
sv_pure "0"
CONFIG_EOF
        chown "$STEAM_USER:$STEAM_USER" "$cfg_dir/$config_name"
    fi

    # 创建启动脚本
    msg_info "正在创建 $game_name 启动脚本..."
    cat > "$script_file" << SCRIPT_EOF
#!/bin/bash
./srcds_linux64 \\
    -ip "0.0.0.0" \\
    -port "$default_port" \\
    +maxplayers "24" \\
    +map "$default_map" \\
    +exec "$config_name"
SCRIPT_EOF

    msg_info "$game_name 启动脚本已创建"
}

fi


# =============================================================================
# 4c. 自定义更新脚本生成 — override_update_script_{short_name}()
# =============================================================================
# 触发时机: 生成 SteamCMD 更新脚本时调用
# 参数:
#   $1 — update_script_path（更新脚本目标路径）
# 不定义此函数时，SSM 自动生成标准更新脚本（force_install_dir + app_update）
#
# 适用于: 需要先更新依赖游戏、或使用特殊更新逻辑的游戏（如 TF2 Classified）
# =============================================================================

if false; then  # 示例代码，不会实际执行

override_update_script_my_game() {
    local update_script_path=$1

    msg_info "正在创建 $game_name 特殊更新脚本..."

    cat > "$update_script_path" << UPDATE_EOF
login anonymous
force_install_dir "$SERVER_DIR"
app_update $game_app_id
quit
UPDATE_EOF

    msg_info "$game_name 更新脚本已创建"
}

fi


# =============================================================================
# 4d. 自定义配置生成 — override_config_gen_{short_name}()
# =============================================================================
# 触发时机: 生成服务器配置文件时调用
# 参数:
#   $1 — install_dir（游戏安装目录）
#   $2 — cfg_dir（配置目录）
#   $3 — config_name（配置文件名）
# 不定义此函数时，SSM 使用默认配置生成逻辑
#
# 适用于: 需要自动生成复杂配置文件的游戏
# =============================================================================

if false; then  # 示例代码，不会实际执行

override_config_gen_my_game() {
    local install_dir=$1
    local cfg_dir=$2
    local config_name=$3

    # 创建配置目录
    if [ ! -d "$cfg_dir" ]; then
        mkdir -p "$cfg_dir"
    fi

    # 示例: 生成 XML 格式配置文件（适用于非 Source 引擎游戏）
    cat > "$cfg_dir/$config_name" << CONFIG_EOF
<?xml version="1.0" encoding="utf-8"?>
<ServerConfig>
    <ServerName>$game_name 服务器</ServerName>
    <MaxPlayers>16</MaxPlayers>
    <Port>27015</Port>
    <Password></Password>
    <AdminPassword>$(openssl rand -hex 30)</AdminPassword>
</ServerConfig>
CONFIG_EOF

    chown "$STEAM_USER:$STEAM_USER" "$cfg_dir/$config_name"
    msg_ok "$game_name 配置文件已生成"
}

fi


# =============================================================================
# 4e. 游戏选择后置钩子 — on_game_selected_{short_name}()
# =============================================================================
# 触发时机: 用户选择该游戏后立即调用
# 适用于: 需要动态修改注册信息的游戏（如 Barotrauma 的变体处理）
# 注意: 此函数在每次选择游戏时都会调用，包括首次选择
# =============================================================================

if false; then  # 示例代码，不会实际执行

on_game_selected_my_game() {
    # 示例: 确保 App ID 是最新的（某些游戏可能因变体不同而改变 App ID）
    GAME_APPS["$game_name"]="$game_app_id"
    msg_info "已选择 $game_name，App ID: ${GAME_APPS[$game_name]}"
}

fi


# =============================================================================
# 4f. 配置加载后置钩子 — on_config_loaded_{short_name}()
# =============================================================================
# 触发时机: 加载用户配置文件后调用
# 适用于: 需要在配置加载后执行额外初始化逻辑的游戏
# =============================================================================

if false; then  # 示例代码，不会实际执行

on_config_loaded_my_game() {
    # 示例: 检查并确保某些变量已正确初始化
    if [ -z "${GAME_VARIANT:-}" ]; then
        GAME_VARIANT="official"
    fi
}

fi


# =============================================================================
# 5. 服务器变体选择菜单 — menu_select_variant_{short_name}()
# =============================================================================
# 触发时机: 在"游戏管理"菜单中显示为额外选项
# 适用于: 有多个服务器版本/变体的游戏（如 Barotrauma 的官方版/LuaCs/PEP）
#
# 工作机制:
#   - 定义此函数后，SSM 菜单中会显示"选择服务器版本"选项
#   - 选择一个变体后，应将其保存到 GAME_VARIANT 变量中
#   - 用 save_user_config 将选择持久化
# =============================================================================

if false; then  # 示例代码，不会实际执行

menu_select_variant_my_game() {
    local current="${GAME_VARIANT:-official}"

    local options=(
        "official" "官方版 — 原版服务器
        如果已经安装了其他版本请选择[验证文件完整性]而不是[下载/安装服务器]"
        "experimental" "实验版 — 包含最新功能和修复"
        "lite" "精简版 — 最小化安装，仅保留核心功能"
    )

    local title="选择 $game_name 服务器版本"
    local text="当前版本: "
    case "$current" in
        official)     text+="官方版" ;;
        experimental) text+="实验版" ;;
        lite)         text+="精简版" ;;
        *)            text+="未选择" ;;
    esac

    local choice
    choice=$(menu_select "$title" "$text" "${options[@]}")

    if [ -n "$choice" ] && [ "$choice" != "$current" ]; then
        GAME_VARIANT="$choice"
        save_user_config
        msg_ok "已选择 $game_name 服务器版本: $choice"
    fi
}

fi


# =============================================================================
# 6. 注册全局变量参考
# =============================================================================
# 以下是所有可用的 GAME_* 全局关联数组和系统变量参考
# 注意：此代码块仅供查看参考，不会实际执行
# =============================================================================

if false; then  # 参考信息，不会实际执行

# ========== 必须注册的变量 ==========
GAME_APPS["游戏名"]="Steam App ID"                   # 必须 — Steam 应用 ID
GAME_SHORT_NAMES["游戏名"]="short_name"               # 必须 — 短名称（唯一标识）
GAME_DEFAULT_MAPS["游戏名"]="map_name"                # 必须 — 默认地图（非 Source 可留空）

# ========== 高级配置（推荐注册） ==========
GAME_ENGINES["游戏名"]="source"                       # 引擎类型: source/unreal/unity/generic/other
GAME_PLATFORM_ORDERS["游戏名"]="linux"                # 平台: linux/windows
GAME_DOWNLOAD_VERIFIES["游戏名"]="standard"           # 验证: standard/dual_platform

# ========== 可选配置 ==========
GAME_DEPENDENCIES["游戏名"]="依赖游戏名"               # 依赖游戏（空格分隔多个）

# ========== 非 Source 引擎额外变量 ==========
GAME_START_CMDS["游戏名"]="./可执行文件"               # 启动命令
GAME_START_ARGS["游戏名"]="启动参数"                   # 启动参数
GAME_WORKDIRS["游戏名"]="工作目录路径"                 # 工作目录
GAME_CFG_DIRS["游戏名"]="配置目录路径"                 # 配置文件目录

# ========== 系统自动管理变量（无需手动设置） ==========
# GAME_DIRS["游戏名"]          — 安装目录（SSM 自动记录）
# GAME_NAME                   — 当前选择的游戏名（SSM 自动设置）
# GAME_VARIANT                — 当前选择的服务器变体（可选，由用户选择）
# SERVER_DIR                  — 当前游戏服务器安装目录绝对路径
# STEAM_USER                  — Steam 系统用户
# STEAM_HOME                  — Steam 用户家目录
# STEAMCMD_PATH               — SteamCMD 安装路径

# ========== 钩子函数命名规则 ==========
# 以下划线后的 short_name 区分:
#   install_dependencies_{short_name}()       — 安装后处理
#   override_start_script_{short_name}()      — 自定义启动脚本
#   override_update_script_{short_name}()     — 自定义更新脚本
#   override_config_gen_{short_name}()        — 自定义配置生成
#   on_game_selected_{short_name}()           — 游戏选择后置
#   on_config_loaded_{short_name}()           — 配置加载后置
#   menu_select_variant_{short_name}()        — 服务器变体选择菜单

fi


# =============================================================================
# 附录: 完整示例 — 一个真实可用的自定义游戏定义
# =============================================================================
# 以下是所有功能组合在一起的一个完整示例。
# 用户复制此代码块，修改变量即可直接使用。
# =============================================================================

if false; then  # 完整示例，不会实际执行

# ============================
# 用户配置区
# ============================
game_name="Examples"
game_app_id="0000000"
game_short_name="my_full_example"
game_default_map="de_dust2"
game_dependencies=""

# ============================
# 引擎配置
# ============================
game_engine="source"
game_platform_order="linux"
game_download_verify="standard"

# ============================
# 注册游戏
# ============================
GAME_APPS["$game_name"]="$game_app_id"
GAME_SHORT_NAMES["$game_name"]="$game_short_name"
GAME_DEFAULT_MAPS["$game_name"]="$game_default_map"
GAME_ENGINES["$game_name"]="$game_engine"
GAME_PLATFORM_ORDERS["$game_name"]="$game_platform_order"
GAME_DOWNLOAD_VERIFIES["$game_name"]="$game_download_verify"

if [ -n "$game_dependencies" ]; then
    GAME_DEPENDENCIES["$game_name"]="$game_dependencies"
fi

# ============================
# 安装后处理钩子
# ============================
install_dependencies_my_full_example() {
    msg_info "正在执行 $game_name 安装后处理..."

    # 修复 steamclient.so
    local steam_dir="$(eval echo ~$STEAM_USER)/.steam/sdk64"
    if [ ! -d "$steam_dir" ]; then
        mkdir -p "$steam_dir"
    fi
    if [ -f "$SERVER_DIR/linux64/steamclient.so" ]; then
        ln -sf "$SERVER_DIR/linux64/steamclient.so" "$steam_dir/steamclient.so"
        msg_ok "已添加 steamclient.so 符号链接"
    fi

    # 修正文件权限
    chown -R "$STEAM_USER:$STEAM_USER" "$SERVER_DIR" 2>/dev/null || true

    msg_ok "$game_name 安装后处理完成"
}

# ============================
# 游戏选择后置钩子
# ============================
on_game_selected_my_full_example() {
    GAME_APPS["$game_name"]="$game_app_id"
}

fi
