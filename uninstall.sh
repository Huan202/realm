#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

stop_disable_service() {
    local service_name="$1"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$service_name" >/dev/null 2>&1 || true
        systemctl disable "$service_name" >/dev/null 2>&1 || true
    fi
    if command -v rc-service >/dev/null 2>&1; then
        rc-service "$service_name" stop >/dev/null 2>&1 || true
    fi
    if command -v rc-update >/dev/null 2>&1; then
        rc-update del "$service_name" default >/dev/null 2>&1 || true
    fi
}

reload_services() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl reset-failed >/dev/null 2>&1 || true
    fi
}

remove_cron_entries() {
    if command -v crontab >/dev/null 2>&1; then
        local temp_cron="/tmp/xwpf_uninstall_cron_$$"
        crontab -l 2>/dev/null | grep -v "port-traffic-dog" | grep -v "端口流量狗" > "$temp_cron" || true
        crontab "$temp_cron" 2>/dev/null || true
        rm -f "$temp_cron"
    fi
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 root 权限运行${NC}"
        echo "例如: sudo bash uninstall.sh"
        exit 1
    fi
}

confirm_uninstall() {
    if [ "${REALM_XWPF_UNINSTALL_CONFIRM:-}" = "DELETE" ]; then
        return 0
    fi

    echo -e "${RED}⚠️  危险操作: 即将彻底卸载 xwPF Realm 全部组件${NC}"
    echo ""
    echo -e "${YELLOW}将删除以下内容:${NC}"
    echo "  - realm 服务、realm 内核和 /etc/realm 配置目录"
    echo "  - pf 主脚本、lib 模块目录和快捷命令"
    echo "  - 故障转移、链路测试、配置识别脚本"
    echo "  - 端口流量狗 dog、配置目录和相关定时任务/服务"
    echo "  - health-check、MPTCP 配置和 systemd/OpenRC 残留"
    echo ""
    read -p "确认彻底卸载？(y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消卸载${NC}"
        exit 0
    fi
}

main() {
    require_root
    confirm_uninstall

    echo -e "${YELLOW}正在停止服务...${NC}"
    stop_disable_service "realm"
    stop_disable_service "realm-health-check.timer"
    stop_disable_service "realm-health-check.service"
    stop_disable_service "port-traffic-dog.service"
    stop_disable_service "port-traffic-dog.timer"

    if [ -f "/etc/realm/xwFailover.sh" ]; then
        bash "/etc/realm/xwFailover.sh" stop >/dev/null 2>&1 || true
    fi
    pgrep -x "realm" >/dev/null 2>&1 && { pkill -x "realm"; sleep 2; pkill -9 -x "realm" 2>/dev/null || true; }

    echo -e "${YELLOW}正在删除文件和配置...${NC}"
    rm -f /usr/local/bin/realm
    rm -f /usr/local/bin/pf
    rm -f /usr/local/bin/xwPF.sh
    rm -rf /usr/local/bin/lib
    rm -f /usr/local/bin/xwFailover.sh
    rm -f /usr/local/bin/speedtest.sh
    rm -f /usr/local/bin/port-traffic-dog.sh
    rm -f /usr/local/bin/dog

    rm -rf /etc/realm
    rm -rf /etc/port-traffic-dog
    rm -f /etc/init.d/realm
    rm -f /etc/systemd/system/realm.service
    rm -f /etc/systemd/system/realm-health-check.service
    rm -f /etc/systemd/system/realm-health-check.timer
    rm -f /etc/systemd/system/port-traffic-dog.service
    rm -f /etc/systemd/system/port-traffic-dog.timer
    rm -f /etc/sysctl.d/90-enable-MPTCP.conf

    rm -f /var/lock/realm-health-check.lock
    rm -f /tmp/realm* /var/tmp/realm* /var/log/realm*.log 2>/dev/null || true
    rm -f /tmp/speedtest_* /tmp/port-traffic-dog* 2>/dev/null || true

    remove_cron_entries
    command -v ip >/dev/null 2>&1 && ip mptcp endpoint flush 2>/dev/null || true
    reload_services

    echo -e "${GREEN}✓ xwPF Realm 已彻底卸载完成${NC}"
    echo -e "${YELLOW}提示: 如当前 shell 仍记得旧命令路径，可执行 hash -r 刷新缓存${NC}"
}

main "$@"
