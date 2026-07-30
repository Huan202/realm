#!/bin/bash

# xwPF - Realm 端口转发管理工具
# Bootstrap 引导器 + 入口

# 安装路径
INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/xwpf"
SHORTCUT_PATH="/usr/local/bin/pf"

# 仓库地址
# 可通过环境变量切换到自己的 fork
REPO_OWNER="${REALM_XWPF_REPO_OWNER:-Huan202}"
REPO_NAME="${REALM_XWPF_REPO_NAME:-realm}"
REPO_BRANCH="${REALM_XWPF_REPO_BRANCH:-main}"
REPO_RAW_URL="${REALM_XWPF_RAW_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}}"
REPO_CACHE_BUST="${REALM_XWPF_CACHE_BUST:-$(date +%s)}"

# 模块列表（加载顺序）
LIB_FILES=("core.sh" "rules.sh" "server.sh" "realm.sh" "ui.sh")

# 颜色
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_NC='\033[0m'

# 下载函数
_download() {
    local url="$1" target="$2"
    curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$target" 2>/dev/null ||
    wget -qO "$target" "$url" 2>/dev/null
}

_cache_bust_url() {
    local url="$1"
    case "$url" in
        *\?*) echo "${url}&ts=${REPO_CACHE_BUST}" ;;
        *) echo "${url}?ts=${REPO_CACHE_BUST}" ;;
    esac
}

# 安装/更新脚本文件到系统（幂等）
_bootstrap() {
    echo -e "${_YELLOW}正在安装/更新脚本文件...${_NC}"

    local stage_dir
    stage_dir=$(mktemp -d) || return 1
    mkdir -p "$stage_dir/lib"

    # 先完整下载到临时目录，避免更新中断后新旧模块混用
    if _download "$(_cache_bust_url "$REPO_RAW_URL/xwPF.sh")" "$stage_dir/xwPF.sh"; then
        echo -e "  ${_GREEN}✓${_NC} xwPF.sh"
    else
        echo -e "  ${_RED}✗${_NC} xwPF.sh 下载失败"
        rm -rf "$stage_dir"
        return 1
    fi

    # 下载所有模块
    local failed=0
    for f in "${LIB_FILES[@]}"; do
        if _download "$(_cache_bust_url "$REPO_RAW_URL/lib/$f")" "$stage_dir/lib/$f"; then
            echo -e "  ${_GREEN}✓${_NC} lib/$f"
        else
            echo -e "  ${_RED}✗${_NC} lib/$f 下载失败"
            failed=1
        fi
    done

    if [ "$failed" -eq 1 ]; then
        rm -rf "$stage_dir"
        return 1
    fi

    # 所有文件到齐后再构建新目录，并通过重命名一次性切换
    local next_lib_dir="${LIB_DIR}.new.$$"
    local old_lib_dir="${LIB_DIR}.old.$$"
    local next_entry="${INSTALL_DIR}/.xwPF.sh.new.$$"
    mkdir -p "$(dirname "$LIB_DIR")" "$next_lib_dir"
    if ! install -m 0755 "$stage_dir/xwPF.sh" "$next_entry"; then
        rm -rf "$stage_dir" "$next_lib_dir"
        return 1
    fi
    for f in "${LIB_FILES[@]}"; do
        if ! install -m 0644 "$stage_dir/lib/$f" "$next_lib_dir/$f"; then
            rm -rf "$stage_dir" "$next_lib_dir"
            rm -f "$next_entry"
            return 1
        fi
    done
    rm -rf "$stage_dir"

    if [ -d "$LIB_DIR" ]; then
        mv "$LIB_DIR" "$old_lib_dir" || return 1
    fi
    if ! mv "$next_lib_dir" "$LIB_DIR" || ! mv -f "$next_entry" "$INSTALL_DIR/xwPF.sh"; then
        rm -rf "$LIB_DIR" "$next_lib_dir"
        [ -d "$old_lib_dir" ] && mv "$old_lib_dir" "$LIB_DIR"
        rm -f "$next_entry"
        return 1
    fi
    rm -rf "$old_lib_dir"

    # 清理旧版本的通用目录，仅移除本项目已知模块
    for f in "${LIB_FILES[@]}"; do
        rm -f "$INSTALL_DIR/lib/$f"
    done
    rmdir "$INSTALL_DIR/lib" 2>/dev/null || true

    # 创建快捷命令
    ln -sf "$INSTALL_DIR/xwPF.sh" "$SHORTCUT_PATH"
    echo -e "${_GREEN}✓ 快捷命令已创建: pf${_NC}"

    echo -e "${_GREEN}=== 脚本安装完成${_NC}"
    echo ""
}

# 加载模块
_load_libs() {
    if [ ! -d "$LIB_DIR" ] || [ ! -f "$LIB_DIR/core.sh" ]; then
        echo -e "${_RED}错误: 未找到模块目录，请先安装${_NC}"
        echo -e "${_BLUE}curl -fsSL ${REPO_RAW_URL}/install.sh | bash${_NC}"
        return 1
    fi

    for f in "${LIB_FILES[@]}"; do
        if [ -f "$LIB_DIR/$f" ]; then
            source "$LIB_DIR/$f"
        else
            echo -e "${_RED}错误: 缺少模块 $f${_NC}"
            return 1
        fi
    done
}

# 主入口
case "${1:-}" in
    install)
        [ "$(id -u)" -ne 0 ] && { echo -e "${_RED}错误: 需要 root 权限${_NC}"; exit 1; }
        _bootstrap || exit 1
        _load_libs || exit 1
        _SKIP_SCRIPT_UPDATE=1 smart_install
        ;;
    *)
        _load_libs || exit 1
        main "$@"
        ;;
esac
