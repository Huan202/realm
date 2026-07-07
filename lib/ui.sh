
# 每次更新OCR脚本
download_realm_ocr_script() {
    local script_url="https://raw.githubusercontent.com/Huan202/realm/main/xw_realm_OCR.sh"
    local target_path="/etc/realm/xw_realm_OCR.sh"

    echo -e "${GREEN}正在下载最新realm配置识别脚本...${NC}"

    mkdir -p "$(dirname "$target_path")"

    if download_from_sources "$script_url" "$target_path"; then
        chmod +x "$target_path"
        return 0
    else
        echo -e "${RED}请检查网络连接${NC}"
        return 1
    fi
}

import_realm_config() {
    local ocr_script="/etc/realm/xw_realm_OCR.sh"

    if ! download_realm_ocr_script; then
        echo -e "${RED}无法下载配置识别脚本，功能暂时不可用${NC}"
        read -p "按回车键返回..."
        return 1
    fi

    bash "$ocr_script" "$RULES_DIR"

    echo ""
    read -p "按回车键返回..."
}

rules_management_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== 转发配置管理 ===${NC}"
        echo ""

        local status=$(svc_status_text)
        if [ "$status" = "active" ]; then
            echo -e "服务状态: ${GREEN}●${NC} 运行中"
        else
            echo -e "服务状态: ${RED}●${NC} 已停止"
        fi

        local enabled_count=0
        local disabled_count=0
        if [ -d "$RULES_DIR" ]; then
            for rule_file in "${RULES_DIR}"/rule-*.conf; do
                if [ -f "$rule_file" ]; then
                    if read_rule_file "$rule_file"; then
                        if [ "$ENABLED" = "true" ]; then
                            enabled_count=$((enabled_count + 1))
                        else
                            disabled_count=$((disabled_count + 1))
                        fi
                    fi
                fi
            done
        fi

        if [ "$enabled_count" -gt 0 ] || [ "$disabled_count" -gt 0 ]; then
            local total_count=$((enabled_count + disabled_count))
            echo -e "配置模式: ${GREEN}多规则模式${NC} (${GREEN}$enabled_count${NC} 启用 / ${YELLOW}$disabled_count${NC} 禁用 / 共 $total_count 个)"

            if [ "$enabled_count" -gt 0 ]; then
                local has_relay_rules=false
                local relay_count=0
                for rule_file in "${RULES_DIR}"/rule-*.conf; do
                    if [ -f "$rule_file" ]; then
                        if read_rule_file "$rule_file" && [ "$ENABLED" = "true" ] && [ "$RULE_ROLE" = "1" ]; then
                            if [ "$has_relay_rules" = false ]; then
                                echo -e "${GREEN}中转服务器:${NC}"
                                has_relay_rules=true
                            fi
                            relay_count=$((relay_count + 1))
                            local security_display=$(get_security_display "$SECURITY_LEVEL" "$WS_PATH" "$WS_HOST")
                            local display_target=$(smart_display_target "$REMOTE_HOST")
                            local rule_display_name="$RULE_NAME"
                            local display_ip="${NAT_LISTEN_IP:-::}"
                            local through_display="${THROUGH_IP:-::}"
                            echo -e "  • ${GREEN}$rule_display_name${NC}: ${LISTEN_IP:-$display_ip}:$LISTEN_PORT → $through_display → $display_target:$REMOTE_PORT"
                            local note_display=""
                            if [ -n "$RULE_NOTE" ]; then
                                note_display=" | 备注: ${GREEN}$RULE_NOTE${NC}"
                            fi
                            get_rule_status_display "$security_display" "$note_display"

                        fi
                    fi
                done

                local has_exit_rules=false
                local exit_count=0
                for rule_file in "${RULES_DIR}"/rule-*.conf; do
                    if [ -f "$rule_file" ]; then
                        if read_rule_file "$rule_file" && [ "$ENABLED" = "true" ] && [ "$RULE_ROLE" = "2" ]; then
                            if [ "$has_exit_rules" = false ]; then
                                if [ "$has_relay_rules" = true ]; then
                                    echo ""
                                fi
                                echo -e "${GREEN}服务端服务器 (双端Realm架构):${NC}"
                                has_exit_rules=true
                            fi
                            exit_count=$((exit_count + 1))
                            local security_display=$(get_security_display "$SECURITY_LEVEL" "$WS_PATH" "$WS_HOST")
                            # 服务端服务器使用FORWARD_TARGET而不是REMOTE_HOST
                            local target_host="${FORWARD_TARGET%:*}"
                            local target_port="${FORWARD_TARGET##*:}"
                            local display_target=$(smart_display_target "$target_host")
                            local rule_display_name="$RULE_NAME"
                            local display_ip="::"
                            echo -e "  • ${GREEN}$rule_display_name${NC}: ${LISTEN_IP:-$display_ip}:$LISTEN_PORT → $display_target:$target_port"
                            local note_display=""
                            if [ -n "$RULE_NOTE" ]; then
                                note_display=" | 备注: ${GREEN}$RULE_NOTE${NC}"
                            fi
                            get_rule_status_display "$security_display" "$note_display"

                        fi
                    fi
                done
            fi

            if [ "$disabled_count" -gt 0 ]; then
                echo -e "${YELLOW}禁用的规则:${NC}"
                for rule_file in "${RULES_DIR}"/rule-*.conf; do
                    if [ -f "$rule_file" ]; then
                        if read_rule_file "$rule_file" && [ "$ENABLED" = "false" ]; then
                            if [ "$RULE_ROLE" = "2" ]; then
                                local target_host="${FORWARD_TARGET%:*}"
                                local target_port="${FORWARD_TARGET##*:}"
                                local display_target=$(smart_display_target "$target_host")
                                echo -e "  • ${GRAY}$RULE_NAME${NC}: $LISTEN_PORT → $display_target:$target_port (已禁用)"
                            else
                                local display_target=$(smart_display_target "$REMOTE_HOST")
                                local through_display="${THROUGH_IP:-::}"
                                echo -e "  • ${GRAY}$RULE_NAME${NC}: $LISTEN_PORT → $through_display → $display_target:$REMOTE_PORT (已禁用)"
                            fi
                        fi
                    fi
                done
            fi
        else
            echo -e "配置模式: ${BLUE}暂无配置${NC}"
        fi
        echo ""

        echo "请选择操作:"
        echo -e "${GREEN}1.${NC} 一键导出/导入配置"
        echo -e "${GREEN}2.${NC} 添加新配置"
        echo -e "${GREEN}3.${NC} 编辑现有规则"
        echo -e "${GREEN}4.${NC} 删除配置"
        echo -e "${GREEN}5.${NC} 启用/禁用中转规则"
        echo -e "${BLUE}6.${NC} 负载均衡管理"
        echo -e "${YELLOW}7.${NC} 开启/关闭 MPTCP"
        echo -e "${CYAN}8.${NC} 开启/关闭 Proxy Protocol"
        echo -e "${GREEN}0.${NC} 返回主菜单"
        echo ""

        read -p "请输入选择 [0-8]: " choice
        echo ""

        case $choice in
            1)
                while true; do
                    clear
                    echo -e "${GREEN}=== 配置文件管理 ===${NC}"
                    echo ""
                    echo "请选择操作:"
                    echo -e "${GREEN}1.${NC} 导出配置包(包含查看配置)"
                    echo -e "${GREEN}2.${NC} 导入配置包"
                    echo -e "${GREEN}3.${NC} 识别realm配置文件并导入"
                    echo -e "${GREEN}0.${NC} 返回上级菜单"
                    echo ""
                    read -p "请输入选择 [0-3]: " sub_choice
                    echo ""

                    case $sub_choice in
                        1)
                            export_config_with_view
                            ;;
                        2)
                            import_config_package
                            ;;
                        3)
                            import_realm_config
                            ;;
                        0)
                            break
                            ;;
                        *)
                            echo -e "${RED}无效选择，请重新输入${NC}"
                            read -p "按回车键继续..."
                            ;;
                    esac
                done
                ;;
            2)
                interactive_add_rule
                if [ $? -eq 0 ]; then
                    echo -e "${YELLOW}正在重启服务以应用新配置...${NC}"
                    service_restart
                fi
                read -p "按回车键继续..."
                ;;
            3)
                edit_rule_interactive
                ;;
            4)
                echo -e "${YELLOW}=== 删除配置 ===${NC}"
                echo ""
                if list_rules_with_info "management"; then
                    echo ""
                    read -p "请输入要删除的规则ID(多ID使用逗号,分隔): " rule_input

                    if [ -z "$rule_input" ]; then
                        echo -e "${RED}错误: 请输入规则ID${NC}"
                    else
                        if [[ "$rule_input" == *","* ]]; then
                            batch_delete_rules "$rule_input"
                        else
                            if [[ "$rule_input" =~ ^[0-9]+$ ]]; then
                                delete_rule "$rule_input"
                            else
                                echo -e "${RED}无效的规则ID${NC}"
                            fi
                        fi

                        if [ $? -eq 0 ]; then
                            echo -e "${YELLOW}正在重启服务以应用配置更改...${NC}"
                            service_restart
                        fi
                    fi
                fi
                read -p "按回车键继续..."
                ;;
            5)
                echo -e "${YELLOW}=== 启用/禁用中转规则 ===${NC}"
                echo ""
                if list_rules_with_info "management"; then
                    echo ""
                    read -p "请输入要切换状态的规则ID: " rule_id
                    if [[ "$rule_id" =~ ^[0-9]+$ ]]; then
                        toggle_rule "$rule_id"
                        if [ $? -eq 0 ]; then
                            echo -e "${YELLOW}正在重启服务以应用状态更改...${NC}"
                            service_restart
                        fi
                    else
                        echo -e "${RED}无效的规则ID${NC}"
                    fi
                fi
                read -p "按回车键继续..."
                ;;
            6)
                load_balance_management_menu
                ;;
            7)
                mptcp_management_menu
                ;;
            8)
                proxy_management_menu
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请输入 0-8${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 卸载函数
uninstall_realm() {
    echo -e "${RED}⚠️  危险操作: 即将彻底卸载 xwPF Realm 全部组件${NC}"
    echo ""
    echo -e "${YELLOW}将删除以下内容:${NC}"
    echo "  - realm 服务、realm 内核和 /etc/realm 配置目录"
    echo "  - pf 主脚本、lib 模块目录和快捷命令"
    echo "  - 故障转移、链路测试、配置识别脚本"
    echo "  - 端口流量狗 dog、配置目录和相关定时任务/服务"
    echo "  - health-check、MPTCP 配置和 systemd/OpenRC 残留"
    echo ""
    read -p "确认彻底卸载请输入 DELETE: " confirm_uninstall
    if [ "$confirm_uninstall" != "DELETE" ]; then
        echo -e "${BLUE}已取消卸载${NC}"
        return 0
    fi

    uninstall_realm_stage_one
    uninstall_script_files
    uninstall_extra_components
    echo -e "${GREEN}🗑️  xwPF Realm 已彻底卸载完成${NC}"
    echo -e "${YELLOW}提示: 如当前 shell 仍记得旧命令路径，可执行 hash -r 刷新缓存${NC}"
    exit 0
}

# 第一阶段：清理 Realm 相关
uninstall_realm_stage_one() {
    echo -e "${YELLOW}正在停止 Realm 和健康检查服务...${NC}"
    stop_disable_service "realm"
    stop_disable_service "realm-health-check.timer"
    stop_disable_service "realm-health-check.service"

    # 停止健康检查服务（通过 xwFailover.sh）
    if [ -f "/etc/realm/xwFailover.sh" ]; then
        bash "/etc/realm/xwFailover.sh" stop >/dev/null 2>&1
    fi
    pgrep -x "realm" >/dev/null 2>&1 && { pkill -x "realm"; sleep 2; pkill -9 -x "realm" 2>/dev/null; }

    echo -e "${YELLOW}正在删除 Realm 内核、配置和服务文件...${NC}"
    cleanup_files_by_paths "$REALM_PATH" "$CONFIG_DIR" "$SYSTEMD_PATH" "/etc/realm"
    [ -f "/etc/init.d/realm" ] && rm -f "/etc/init.d/realm"
    rm -f /etc/systemd/system/realm-health-check.service
    rm -f /etc/systemd/system/realm-health-check.timer
    rm -f /var/lock/realm-health-check.lock
    rm -f /tmp/realm* /var/tmp/realm* /var/log/realm*.log 2>/dev/null

    [ -f "/etc/sysctl.d/90-enable-MPTCP.conf" ] && rm -f "/etc/sysctl.d/90-enable-MPTCP.conf"
    command -v ip >/dev/null 2>&1 && ip mptcp endpoint flush 2>/dev/null
    svc_daemon_reload
}

# 第二阶段：清理脚本文件
uninstall_script_files() {
    echo -e "${YELLOW}正在删除 xwPF 主脚本和模块...${NC}"
    rm -f "$INSTALL_DIR/xwPF.sh"
    [ -d "$LIB_DIR" ] && rm -rf "$LIB_DIR"

    # 清理 pf 快捷命令（symlink 或 wrapper）
    local exec_dirs=("/usr/local/bin" "/usr/bin" "/bin" "/opt/bin" "/root/bin")
    for dir in "${exec_dirs[@]}"; do
        [ -f "$dir/pf" ] && grep -q "xwPF" "$dir/pf" 2>/dev/null && rm -f "$dir/pf"
        [ -L "$dir/pf" ] && rm -f "$dir/pf"
    done
}

# 停止并禁用服务，兼容 systemd/OpenRC
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

# 第三阶段：清理附加组件
uninstall_extra_components() {
    echo -e "${YELLOW}正在删除故障转移、链路测试、OCR 和端口流量狗...${NC}"
    stop_disable_service "port-traffic-dog.service"
    stop_disable_service "port-traffic-dog.timer"

    rm -f /usr/local/bin/xwFailover.sh
    rm -f /usr/local/bin/speedtest.sh
    rm -f /usr/local/bin/port-traffic-dog.sh
    rm -f /usr/local/bin/dog
    rm -f /etc/realm/xwFailover.sh
    rm -f /etc/realm/speedtest.sh
    rm -f /etc/realm/xw_realm_OCR.sh
    rm -rf /etc/port-traffic-dog

    rm -f /etc/systemd/system/port-traffic-dog.service
    rm -f /etc/systemd/system/port-traffic-dog.timer
    rm -f /tmp/speedtest_* /tmp/port-traffic-dog* 2>/dev/null

    if command -v crontab >/dev/null 2>&1; then
        local temp_cron="/tmp/xwpf_uninstall_cron_$$"
        crontab -l 2>/dev/null | grep -v "port-traffic-dog" | grep -v "端口流量狗" > "$temp_cron" || true
        crontab "$temp_cron" 2>/dev/null || true
        rm -f "$temp_cron"
    fi

    svc_daemon_reload
    command -v systemctl >/dev/null 2>&1 && systemctl reset-failed >/dev/null 2>&1 || true
}

# 文件路径清理函数
cleanup_files_by_paths() {
    for path in "$@"; do
        if [ -f "$path" ]; then
            rm -f "$path"
        elif [ -d "$path" ]; then
            rm -rf "$path"
        fi
    done
}

# 文件模式清理函数
cleanup_files_by_pattern() {
    local pattern="$1"
    local search_dirs="${2:-/}"

    IFS=' ' read -ra dirs_array <<< "$search_dirs"
    for dir in "${dirs_array[@]}"; do
        [ -d "$dir" ] && find "$dir" -name "*${pattern}*" -type f 2>/dev/null | while read -r file; do
            [ -f "$file" ] && rm -f "$file"
        done &
    done
    wait
}

# 显示转发目标地址（处理本地地址和多地址）
smart_display_target() {
    local target="$1"

    # 处理多地址情况
    if [[ "$target" == *","* ]]; then
        # 分割多地址
        IFS=',' read -ra addresses <<< "$target"
        local display_addresses=()

        for addr in "${addresses[@]}"; do
            addr=$(echo "$addr" | xargs)  # 去除空格
            local display_addr="$addr"

            if [[ "$addr" == "127.0.0.1" ]] || [[ "$addr" == "localhost" ]]; then
                # IPv4本地地址时显示IPv4公网IP
                local public_ipv4=$(get_public_ip ipv4)
                if [ -n "$public_ipv4" ]; then
                    display_addr="$public_ipv4"
                fi
            elif [[ "$addr" == "::1" ]]; then
                # IPv6本地地址时显示IPv6公网IP
                local public_ipv6=$(get_public_ip ipv6)
                if [ -n "$public_ipv6" ]; then
                    display_addr="$public_ipv6"
                fi
            fi

            display_addresses+=("$display_addr")
        done

        # 重新组合地址
        local result=""
        for i in "${!display_addresses[@]}"; do
            if [ $i -gt 0 ]; then
                result="$result,"
            fi
            result="$result${display_addresses[i]}"
        done
        echo "$result"
    else
        # 单地址处理
        if [[ "$target" == "127.0.0.1" ]] || [[ "$target" == "localhost" ]]; then
            # IPv4本地地址时显示IPv4公网IP
            local public_ipv4=$(get_public_ip ipv4)
            if [ -n "$public_ipv4" ]; then
                echo "$public_ipv4"
            else
                echo "$target"
            fi
        elif [[ "$target" == "::1" ]]; then
            # IPv6本地地址时显示IPv6公网IP
            local public_ipv6=$(get_public_ip ipv6)
            if [ -n "$public_ipv6" ]; then
                echo "$public_ipv6"
            else
                echo "$target"
            fi
        else
            echo "$target"
        fi
    fi
}

# 显示简要状态信息（避免网络请求）
show_brief_status() {
    echo ""
    echo -e "${BLUE}=== 当前状态 ===${NC}"

    # 检查 realm 二进制文件是否存在
    if [ ! -f "${REALM_PATH}" ] || [ ! -x "${REALM_PATH}" ]; then
        echo -e " Realm状态：${RED} 未安装 ${NC}"
        echo -e "${YELLOW}请选择 1. 安装(更新)程序,脚本 ${NC}"
        return
    fi

    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${YELLOW}=== 配置缺失 ===${NC}"
        echo -e "${BLUE}Realm 已安装但配置缺失，请运行 安装配置/添加配置 来初始化配置${NC}"
        return
    fi

    # 正常状态显示
    local status=$(svc_status_text)
    if [ "$status" = "active" ]; then
        echo -e "服务状态: ${GREEN}●${NC} 运行中"
    else
        echo -e "服务状态: ${RED}●${NC} 已停止"
    fi

    # 检查是否有多规则配置
    local has_rules=false
    local enabled_count=0
    local disabled_count=0
    if [ -d "$RULES_DIR" ]; then
        for rule_file in "${RULES_DIR}"/rule-*.conf; do
            if [ -f "$rule_file" ]; then
                if read_rule_file "$rule_file"; then
                    if [ "$ENABLED" = "true" ]; then
                        has_rules=true
                        enabled_count=$((enabled_count + 1))
                    else
                        disabled_count=$((disabled_count + 1))
                    fi
                fi
            fi
        done
    fi

    if [ "$has_rules" = true ] || [ "$disabled_count" -gt 0 ]; then
        # 多规则模式
        local total_count=$((enabled_count + disabled_count))
        echo -e "配置模式: ${GREEN}多规则模式${NC} (${GREEN}$enabled_count${NC} 启用 / ${YELLOW}$disabled_count${NC} 禁用 / 共 $total_count 个)"

        # 按服务器类型分组显示启用的规则
        if [ "$enabled_count" -gt 0 ]; then
            # 中转服务器规则
            local has_relay_rules=false
            local relay_count=0
            for rule_file in "${RULES_DIR}"/rule-*.conf; do
                if [ -f "$rule_file" ]; then
                    if read_rule_file "$rule_file" && [ "$ENABLED" = "true" ] && [ "$RULE_ROLE" = "1" ]; then
                        if [ "$has_relay_rules" = false ]; then
                            echo -e "${GREEN}中转服务器:${NC}"
                            has_relay_rules=true
                        fi
                        relay_count=$((relay_count + 1))
                        # 显示详细的转发配置信息
                        local security_display=$(get_security_display "$SECURITY_LEVEL" "$WS_PATH" "$WS_HOST")
                        local display_target=$(smart_display_target "$REMOTE_HOST")
                        local rule_display_name="$RULE_NAME"
                        local display_ip="${NAT_LISTEN_IP:-::}"
                        local through_display="${THROUGH_IP:-::}"
                        echo -e "  • ${GREEN}$rule_display_name${NC}: ${LISTEN_IP:-$display_ip}:$LISTEN_PORT → $through_display → $display_target:$REMOTE_PORT"
                        local note_display=""
                        if [ -n "$RULE_NOTE" ]; then
                            note_display=" | 备注: ${GREEN}$RULE_NOTE${NC}"
                        fi
                        # 显示状态信息
                        get_rule_status_display "$security_display" "$note_display"

                    fi
                fi
            done

            # 服务端服务器规则
            local has_exit_rules=false
            local exit_count=0
            for rule_file in "${RULES_DIR}"/rule-*.conf; do
                if [ -f "$rule_file" ]; then
                    if read_rule_file "$rule_file" && [ "$ENABLED" = "true" ] && [ "$RULE_ROLE" = "2" ]; then
                        if [ "$has_exit_rules" = false ]; then
                            if [ "$has_relay_rules" = true ]; then
                                echo ""
                            fi
                            echo -e "${GREEN}服务端服务器 (双端Realm架构):${NC}"
                            has_exit_rules=true
                        fi
                        exit_count=$((exit_count + 1))
                        # 显示详细的转发配置信息
                        local security_display=$(get_security_display "$SECURITY_LEVEL" "$WS_PATH" "$WS_HOST")
                        # 服务端服务器使用FORWARD_TARGET而不是REMOTE_HOST
                        local target_host="${FORWARD_TARGET%:*}"
                        local target_port="${FORWARD_TARGET##*:}"
                        local display_target=$(smart_display_target "$target_host")
                        local rule_display_name="$RULE_NAME"
                        local display_ip="::"
                        echo -e "  • ${GREEN}$rule_display_name${NC}: ${LISTEN_IP:-$display_ip}:$LISTEN_PORT → $display_target:$target_port"
                        local note_display=""
                        if [ -n "$RULE_NOTE" ]; then
                            note_display=" | 备注: ${GREEN}$RULE_NOTE${NC}"
                        fi
                        # 显示状态信息
                        get_rule_status_display "$security_display" "$note_display"

                    fi
                fi
            done
        fi

        # 显示禁用的规则（简要）
        if [ "$disabled_count" -gt 0 ]; then
            echo -e "${YELLOW}禁用的规则:${NC}"
            for rule_file in "${RULES_DIR}"/rule-*.conf; do
                if [ -f "$rule_file" ]; then
                    if read_rule_file "$rule_file" && [ "$ENABLED" = "false" ]; then
                        # 根据规则角色使用不同的字段
                        if [ "$RULE_ROLE" = "2" ]; then
                            # 服务端服务器使用FORWARD_TARGET
                            local target_host="${FORWARD_TARGET%:*}"
                            local target_port="${FORWARD_TARGET##*:}"
                            local display_target=$(smart_display_target "$target_host")
                            echo -e "  • ${WHITE}$RULE_NAME${NC}: $LISTEN_PORT → $display_target:$target_port (已禁用)"
                        else
                            # 中转服务器使用REMOTE_HOST
                            local display_target=$(smart_display_target "$REMOTE_HOST")
                            local through_display="${THROUGH_IP:-::}"
                            echo -e "  • ${WHITE}$RULE_NAME${NC}: $LISTEN_PORT → $through_display → $display_target:$REMOTE_PORT (已禁用)"
                        fi
                    fi
                fi
            done
        fi
    else
        echo -e "转发规则: ${YELLOW}暂无${NC} (可通过 '转发配置管理' 添加)"
    fi
    echo ""
}

# 获取安全级别显示文本
get_security_display() {
    local security_level="$1"
    local ws_path="$2"
    local tls_server_name="$3"

    case "$security_level" in
        "standard")
            echo "默认传输"
            ;;
        "ws")
            echo "ws (host: $tls_server_name) (路径: $ws_path)"
            ;;
        "tls_self")
            local display_sni="${tls_server_name:-$DEFAULT_SNI_DOMAIN}"
            echo "TLS自签证书 (SNI: $display_sni)"
            ;;
        "tls_ca")
            echo "TLS CA证书 (域名: $tls_server_name)"
            ;;
        "ws_tls_self")
            local display_sni="${TLS_SERVER_NAME:-$DEFAULT_SNI_DOMAIN}"
            echo "wss 自签证书 (host: $tls_server_name) (路径: $ws_path) (SNI: $display_sni)"
            ;;
        "ws_tls_ca")
            local display_sni="${TLS_SERVER_NAME:-$DEFAULT_SNI_DOMAIN}"
            echo "wss CA证书 (host: $tls_server_name) (路径: $ws_path) (SNI: $display_sni)"
            ;;
        "ws_"*)
            echo "$security_level (路径: $ws_path)"
            ;;
        *)
            echo "$security_level"
            ;;
    esac
}

get_gmt8_time() {
    TZ='GMT-8' date "$@"
}

# 下载故障转移管理脚本
download_failover_script() {
    local script_url="https://raw.githubusercontent.com/Huan202/realm/main/xwFailover.sh"
    local target_path="/etc/realm/xwFailover.sh"

    echo -e "${GREEN}正在下载最新故障转移脚本...${NC}"

    mkdir -p "$(dirname "$target_path")"

    if download_from_sources "$script_url" "$target_path"; then
        chmod +x "$target_path"
        return 0
    else
        echo -e "${RED}请检查网络连接${NC}"
        return 1
    fi
}

# 下载中转网络链路测试脚本
download_speedtest_script() {
    local script_url="https://raw.githubusercontent.com/Huan202/realm/main/speedtest.sh"
    local target_path="/etc/realm/speedtest.sh"

    echo -e "${GREEN}正在下载最新测速脚本...${NC}"

    mkdir -p "$(dirname "$target_path")"

    if download_from_sources "$script_url" "$target_path"; then
        chmod +x "$target_path"
        return 0
    else
        echo -e "${RED}请检查网络连接${NC}"
        return 1
    fi
}
# 中转网络链路测试菜单
speedtest_menu() {
    local speedtest_script="/etc/realm/speedtest.sh"

    if ! download_speedtest_script; then
        echo -e "${RED}无法下载测速脚本，功能暂时不可用${NC}"
        read -p "按回车键返回主菜单..."
        return 1
    fi

    echo -e "${BLUE}启动测速工具...${NC}"
    echo ""
    bash "$speedtest_script"

    echo ""
    read -p "按回车键返回主菜单..."
}

# 故障转移管理菜单
failover_management_menu() {
    local failover_script="/etc/realm/xwFailover.sh"

    if ! download_failover_script; then
        echo -e "${RED}无法下载故障转移脚本，功能暂时不可用${NC}"
        read -p "按回车键返回主菜单..."
        return 1
    fi

    # 直接调用故障转移配置功能
    bash "$failover_script" toggle
}

# 端口流量狗
port_traffic_dog_menu() {
    local script_url="https://raw.githubusercontent.com/Huan202/realm/main/port-traffic-dog.sh"
    local dog_script="/usr/local/bin/port-traffic-dog.sh"

    # 脚本不存在或不可执行时才下载
    if [[ ! -f "$dog_script" || ! -x "$dog_script" ]]; then
        echo -e "${GREEN}正在下载端口流量狗脚本...${NC}"
        mkdir -p "$(dirname "$dog_script")"
        if ! download_from_sources "$script_url" "$dog_script"; then
            echo -e "${RED}无法下载端口流量狗脚本，请检查网络连接${NC}"
            read -p "按回车键返回主菜单..."
            return 1
        fi
        chmod +x "$dog_script"
    fi

    echo -e "${BLUE}启动端口流量狗...${NC}"
    echo ""
    bash "$dog_script"
    echo ""
    read -p "按回车键返回主菜单..."
}

show_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== xwPF Realm全功能一键脚本 $SCRIPT_VERSION ===${NC}"
        echo -e "${GREEN}项目开源:${NC}https://github.com/Huan202/realm"
        echo -e "${GREEN}一个开箱即用、轻量可靠、灵活可控的 Realm 转发管理工具${NC}"
        echo -e "${GREEN}官方realm的全部功能+故障转移 | 快捷命令: pf${NC}"

        show_brief_status

        echo "请选择操作:"
        echo -e "${GREEN}1.${NC} 安装(更新)程序,脚本"
        echo -e "${BLUE}2.${NC} 转发配置管理"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 停止服务"
        echo -e "${GREEN}5.${NC} 查看日志"
        echo -e "${BLUE}6.${NC} 端口流量狗（统计端口流量）"
        echo -e "${BLUE}7.${NC} 中转网络链路测试"
        echo -e "${RED}8.${NC} 一键彻底卸载"
        echo -e "${YELLOW}0.${NC} 退出"
        echo ""

        read -p "请输入选择 [0-8]: " choice
        echo ""

        case $choice in
            1)
                smart_install
                exit 0
                ;;
            2)
                check_dependencies
                rules_management_menu
                ;;
            3)
                check_dependencies
                service_restart
                read -p "按回车键继续..."
                ;;
            4)
                check_dependencies
                service_stop
                read -p "按回车键继续..."
                ;;
            5)
                check_dependencies
                echo -e "${YELLOW}实时查看 Realm 日志 (按 Ctrl+C 返回菜单):${NC}"
                echo ""
                svc_logs
                ;;
            6)
                port_traffic_dog_menu
                ;;
            7)
                check_dependencies
                speedtest_menu
                ;;
            8)
                check_dependencies
                uninstall_realm
                read -p "按回车键继续..."
                ;;
            0)
                echo -e "${BLUE}感谢使用xwPF 网络转发管理脚本！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请输入 0-8${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 内置清理机制
cleanup_temp_files() {
    # 清理缓存文件（>10MB截断保留5MB）
    local cache_file="/tmp/realm_path_cache"
    if [ -f "$cache_file" ]; then
        local size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null || echo 0)
        if [ "$size" -gt 10485760 ]; then
            tail -c 5242880 "$cache_file" > "$cache_file.tmp" && mv "$cache_file.tmp" "$cache_file" 2>/dev/null
        fi
    fi

    # 清理过期标记文件（>5分钟）
    find /tmp -name "realm_config_update_needed" -mmin +5 -delete 2>/dev/null

    # 清理realm临时文件（>60分钟）
    find /tmp -name "*realm*" -type f -mmin +60 ! -path "*/realm/config*" ! -path "*/realm/rules*" -delete 2>/dev/null
}

# ---- 主逻辑 ----
main() {
    cleanup_temp_files

    detect_system

    # 检查特殊参数
    if [ "$1" = "--generate-config-only" ]; then
        # 只生成配置文件，不显示菜单
        generate_realm_config
        exit 0
    elif [ "$1" = "--restart-service" ]; then
        # 重启服务接口（供外部调用）
        service_restart
        exit $?
    fi

    check_root

    show_menu
}
