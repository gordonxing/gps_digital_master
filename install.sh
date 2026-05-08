#!/usr/bin/env bash
# ============================================================
# 车联网私有化平台 - 一键安装部署脚本
# 版本: 1.0.0
# 支持系统: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ============================================================
set -o pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# ======================== 颜色定义 ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ======================== 默认参数 ========================
SKIP_CONFIG=false
SKIP_MAP=false
OFFLINE=false
REGISTRY="crpi-kb0ss7zdstcgbqc6.cn-guangzhou.personal.cr.aliyuncs.com/lucky-service"
DATA_DIR="${SCRIPT_DIR}/data"
PG_WAIT_TIMEOUT=60
HEALTH_CHECK_TIMEOUT=120

# ======================== 日志函数 ========================
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
step()    { echo -e "\n${BLUE}${BOLD}>>> $* ${NC}"; }
banner()  { echo -e "${CYAN}$*${NC}"; }

# ======================== 帮助信息 ========================
show_help() {
    cat <<EOF
车联网私有化平台 一键安装脚本 v${SCRIPT_VERSION}

用法: sudo bash install.sh [选项]

选项:
  --skip-config    跳过配置引导，使用默认值直接部署
  --offline        离线模式，跳过镜像拉取（使用本地已有镜像）
  --help           显示此帮助信息

示例:
  sudo bash install.sh                        # 交互式完整安装
  sudo bash install.sh --skip-config          # 使用默认配置快速安装
  sudo bash install.sh --offline              # 离线安装

EOF
    exit 0
}

# ======================== 参数解析 ========================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-config) SKIP_CONFIG=true ;;
            --offline)     OFFLINE=true ;;
            --help|-h)     show_help ;;
            *)
                error "未知参数: $1"
                echo "使用 --help 查看帮助信息"
                exit 1
                ;;
        esac
        shift
    done
}

# ======================== Banner ========================
show_banner() {
    banner "
 ╔════════════════════════════════════════════════════╗
 ║         车联网私有化平台 · 一键部署工具           ║
 ║                  v${SCRIPT_VERSION}                          ║
 ╚════════════════════════════════════════════════════╝
"
}

# ======================== Root 检查 ========================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 权限运行此脚本"
        echo "  sudo bash install.sh"
        exit 1
    fi
}

# ======================== Step 1: 系统版本检测 ========================
check_os() {
    step "Step 1/11: 检测操作系统版本"

    if [[ ! -f /etc/os-release ]]; then
        error "无法识别操作系统，仅支持 Ubuntu 20.04 / 22.04 / 24.04 LTS"
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        error "不支持的操作系统: ${ID}。仅支持 Ubuntu 20.04 / 22.04 / 24.04 LTS"
        exit 1
    fi

    case "$VERSION_ID" in
        20.04|22.04|24.04)
            info "操作系统: Ubuntu ${VERSION_ID} LTS ✓"
            ;;
        *)
            error "不支持的 Ubuntu 版本: ${VERSION_ID}。仅支持 20.04 / 22.04 / 24.04 LTS"
            exit 1
            ;;
    esac
}

# ======================== Step 2: Docker 检测/安装 ========================
check_docker() {
    step "Step 2/11: 检测 Docker 环境"

    local need_install=false

    if ! command -v docker &>/dev/null; then
        warn "Docker 未安装，将自动安装..."
        need_install=true
    else
        info "Docker 已安装: $(docker --version)"
    fi

    if $need_install; then
        install_docker
    fi

    # 检查 docker compose v2
    if docker compose version &>/dev/null; then
        info "Docker Compose V2 已就绪: $(docker compose version --short)"
    else
        error "Docker Compose V2 不可用，请确认 Docker 版本 >= 20.10"
        exit 1
    fi

    # 确保 docker 服务运行中
    if ! systemctl is-active --quiet docker; then
        systemctl start docker
        info "Docker 服务已启动"
    fi
}

install_docker() {
    info "正在安装 Docker CE..."

    # 使用官方脚本安装
    if curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
    else
        # 备用: apt 安装
        warn "官方脚本下载失败，尝试 apt 安装..."
        apt-get update -qq
        apt-get install -y -qq docker.io docker-compose-plugin
    fi

    # 启动并设置开机自启
    systemctl enable docker
    systemctl start docker

    # 将当前 sudo 用户加入 docker 组
    if [[ -n "${SUDO_USER}" ]]; then
        usermod -aG docker "${SUDO_USER}"
        info "已将用户 ${SUDO_USER} 加入 docker 组（重新登录后生效）"
    fi

    info "Docker 安装完成"
}

# ======================== Step 3: 系统资源检测 ========================
check_resources() {
    step "Step 3/11: 检测系统资源"

    # 内存检测（单位 MB）
    local mem_total_mb
    mem_total_mb=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
    if [[ $mem_total_mb -lt 4096 ]]; then
        warn "可用内存: ${mem_total_mb}MB（建议最低 4096MB / 4GB）"
        warn "内存不足可能导致部分服务运行异常"
    else
        info "可用内存: ${mem_total_mb}MB ✓"
    fi

    # 磁盘检测（单位 GB）
    local disk_avail_gb
    disk_avail_gb=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
    if [[ $disk_avail_gb -lt 50 ]]; then
        warn "可用磁盘空间: ${disk_avail_gb}GB（建议最低 50GB）"
        warn "磁盘空间不足可能影响数据库和地图数据存储"
    else
        info "可用磁盘空间: ${disk_avail_gb}GB ✓"
    fi
}

# ======================== Step 4: 配置文件生成 ========================
setup_config() {
    step "Step 4/11: 生成配置文件"

    local env_file="${SCRIPT_DIR}/.env"

    if [[ -f "$env_file" ]]; then
        info ".env 配置文件已存在，跳过生成"
        return
    fi

    if [[ ! -f "${SCRIPT_DIR}/.env.template" ]]; then
        error "找不到 .env.template 模板文件"
        exit 1
    fi

    # 从模板复制
    cp "${SCRIPT_DIR}/.env.template" "$env_file"

    # 生成随机 SECRET（32位）
    local secret_key
    secret_key=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)

    # 生成随机 POSTGRES_PASSWORD（24位）
    local pg_password
    pg_password=$(head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)

    # 替换配置
    sed -i "s|SECRET=your-secret-key-at-least-32-chars|SECRET=${secret_key}|" "$env_file"
    sed -i "s|POSTGRES_PASSWORD=change_me_strong_password|POSTGRES_PASSWORD=${pg_password}|" "$env_file"

    # 同步更新 traccar.xml 中的数据库密码和外部服务地址
    if [[ -f "${SCRIPT_DIR}/traccar/traccar.xml" ]]; then
        sed -i "s|database.password'>change_me_strong_password|database.password'>${pg_password}|" "${SCRIPT_DIR}/traccar/traccar.xml"
        info "traccar.xml 配置已同步"
    fi

    info ".env 配置文件已生成"
    info "  SECRET 和 POSTGRES_PASSWORD 已自动生成随机值"

    if ! $SKIP_CONFIG; then
        echo ""
        warn "请在继续之前检查并编辑 .env 配置文件："
        echo "  文件位置: ${env_file}"
        echo ""
        echo "  重要配置项："
        echo "    DOMAIN         - 您的域名或服务器 IP（必改）"
        echo "    POSTGRES_PASSWORD - 数据库密码（已自动生成）"
        echo "    SECRET         - JWT 密钥（已自动生成）"
        echo ""
        read -rp "  是否现在编辑 .env 文件？[y/N] " edit_env
        if [[ "$edit_env" =~ ^[Yy]$ ]]; then
            if command -v vim &>/dev/null; then
                vim "$env_file"
            elif command -v nano &>/dev/null; then
                nano "$env_file"
            else
                warn "未找到编辑器，请手动编辑: vim ${env_file}"
            fi
        fi
        info "配置文件就绪"
    else
        info "已跳过配置引导（--skip-config），使用默认值"
    fi
}

# ======================== Step 5: 机器码生成 ========================
generate_machine_id() {
    step "Step 5/11: 生成机器码"

    local machine_id_file="${DATA_DIR}/.machine_id"

    # 确保 data 目录存在
    mkdir -p "$DATA_DIR"

    if [[ -f "$machine_id_file" ]] && [[ -s "$machine_id_file" ]]; then
        local existing_id
        existing_id=$(cat "$machine_id_file")
        info "机器码已存在: ${existing_id}"
        return
    fi

    # 调用 Python 脚本生成
    local gen_script="${SCRIPT_DIR}/scripts/generate_machine_id.py"
    if [[ -f "$gen_script" ]]; then
        local machine_id
        machine_id=$(python3 "$gen_script" --path "$machine_id_file")
        info "机器码已生成: ${machine_id}"
    else
        # 备用：纯 bash 生成
        local machine_id
        machine_id=$(head -c 64 /dev/urandom | sha256sum | head -c 32)
        echo -n "$machine_id" > "$machine_id_file"
        info "机器码已生成(bash): ${machine_id}"
    fi

    echo ""
    warn "请妥善保存此机器码，用于向供应商申请 License"
}

# ======================== Step 6: 数据目录创建 ========================
create_data_dirs() {
    step "Step 6/11: 创建数据持久化目录"

    local dirs=(
        "${DATA_DIR}/postgres"
        "${DATA_DIR}/redis"
        "${DATA_DIR}/traccar"
        "${DATA_DIR}/uploads"
        "${DATA_DIR}/logs"
        "${DATA_DIR}/ssl"
        "${DATA_DIR}/license"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done

    info "数据目录已就绪: ${DATA_DIR}/"
    echo "  ├── .machine_id        (机器码)"
    echo "  ├── postgres/           (PostgreSQL 数据)"
    echo "  ├── redis/              (Redis 数据)"
    echo "  ├── traccar/            (Traccar 数据)"
    echo "  ├── uploads/            (上传文件)"
    echo "  ├── logs/               (日志)"
    echo "  ├── ssl/                (SSL 证书)"
    echo "  └── license/            (License 文件)"

    # 权限修复：确保容器内 appuser (UID 1000) 有权读写
    info "修复数据目录权限..."
    chown -R 1000:1000 "$DATA_DIR"
}

# ======================== Step 7: 镜像拉取 ========================
pull_images() {
    step "Step 7/11: 拉取容器镜像"

    if $OFFLINE; then
        warn "离线模式，跳过镜像拉取（使用本地已有镜像）"
        return
    fi

    local images=(
        "${REGISTRY}/lucky_fastapi:latest"
        "${REGISTRY}/lucky_frontend:latest"
        "postgis/postgis:15-3.3"
        "redis:7-alpine"
        "${REGISTRY}/lucky-traccar:latest"
        "openresty/openresty:1.25.3.1-alpine"
    )

    local total=${#images[@]}
    local idx=0

    for img in "${images[@]}"; do
        idx=$((idx + 1))
        echo -e "${CYAN}  [${idx}/${total}]${NC} 拉取 ${img} ..."
        if docker pull "$img" 2>&1 | tail -1; then
            info "  ${img} ✓"
        else
            warn "  ${img} 拉取失败，可能需要手动处理"
        fi
    done

    info "镜像拉取完成"
}

# ======================== Step 8: 数据库初始化 ========================
init_database() {
    step "Step 8/11: 初始化数据库"

    # 加载 .env 中的数据库配置
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a

    # 启动 postgres 容器
    info "启动 PostgreSQL 容器..."
    docker compose up -d postgres

    # 等待 PostgreSQL 就绪
    info "等待 PostgreSQL 就绪（最长 ${PG_WAIT_TIMEOUT}s）..."
    local elapsed=0
    while [[ $elapsed -lt $PG_WAIT_TIMEOUT ]]; do
        if docker exec iot-postgres pg_isready -U "${POSTGRES_USER:-iot_admin}" -d "${POSTGRES_DB:-iot_platform}" &>/dev/null; then
            info "PostgreSQL 已就绪 (${elapsed}s)"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -ne "\r  等待中... ${elapsed}s"
    done
    echo ""

    if [[ $elapsed -ge $PG_WAIT_TIMEOUT ]]; then
        error "PostgreSQL 启动超时（${PG_WAIT_TIMEOUT}s），请检查日志: docker logs iot-postgres"
        exit 1
    fi

    # init_schemas.sql 已通过 docker-entrypoint-initdb.d 自动执行（仅首次初始化时）
    # 这里手动执行以确保幂等性
    info "初始化数据库 Schema..."
    if docker exec -i iot-postgres psql -U "${POSTGRES_USER:-iot_admin}" -d "${POSTGRES_DB:-iot_platform}" \
        < "${SCRIPT_DIR}/sql/init_schemas.sql" 2>/dev/null; then
        info "Schema 初始化完成（lucky / geo / traccar）"
    else
        warn "Schema 可能已存在，跳过"
    fi

    # 执行授权表
    if [[ -f "${SCRIPT_DIR}/sql/license_tables.sql" ]]; then
        info "创建授权管理表..."
        if docker exec -i iot-postgres psql -U "${POSTGRES_USER:-iot_admin}" -d "${POSTGRES_DB:-iot_platform}" \
            < "${SCRIPT_DIR}/sql/license_tables.sql" 2>/dev/null; then
            info "授权表创建完成"
        else
            warn "授权表可能已存在，跳过"
        fi
    fi

    info "数据库初始化完成"
    info "提示: 各服务启动时将自动执行 Alembic 数据库迁移"
}


# ======================== Step 10: 启动全部容器 ========================
start_services() {
    step "Step 10/11: 启动全部服务"

    info "正在启动所有容器..."
    docker compose up -d

    info "所有容器已启动"
}

# ======================== Step 11: 健康检查 ========================
health_check() {
    step "Step 11/11: 服务健康检查"

    local services=("iot-postgres" "iot-redis" "lucky-backend" "lucky-frontend" "traccar" "iot-gateway")
    local display_names=("PostgreSQL" "Redis" "Lucky 后端" "Lucky 前端" "Traccar" "OpenResty")
    local total=${#services[@]}
    local healthy=0
    local elapsed=0

    info "等待服务启动（最长 ${HEALTH_CHECK_TIMEOUT}s）..."
    echo ""

    while [[ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]] && [[ $healthy -lt $total ]]; do
        healthy=0
        for i in "${!services[@]}"; do
            local status
            status=$(docker inspect --format='{{.State.Health.Status}}' "${services[$i]}" 2>/dev/null || echo "unknown")
            local running
            running=$(docker inspect --format='{{.State.Status}}' "${services[$i]}" 2>/dev/null || echo "unknown")

            if [[ "$status" == "healthy" ]] || [[ "$running" == "running" && "$status" == "" ]]; then
                healthy=$((healthy + 1))
            fi
        done

        if [[ $healthy -lt $total ]]; then
            echo -ne "\r  已就绪: ${healthy}/${total}  等待中... ${elapsed}s  "
            sleep 5
            elapsed=$((elapsed + 5))
        fi
    done
    echo ""

    # 输出各服务状态
    echo ""
    for i in "${!services[@]}"; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "${services[$i]}" 2>/dev/null || echo "unknown")
        local running
        running=$(docker inspect --format='{{.State.Status}}' "${services[$i]}" 2>/dev/null || echo "unknown")

        if [[ "$status" == "healthy" ]]; then
            info "  ${display_names[$i]}: 运行中 ✓"
        elif [[ "$running" == "running" ]]; then
            warn "  ${display_names[$i]}: 运行中（健康检查未通过或无检查）"
        else
            error "  ${display_names[$i]}: 未就绪 (${running})"
        fi
    done

    echo ""
    if [[ $healthy -lt $total ]]; then
        warn "部分服务未完全就绪，可能需要更多时间启动"
        warn "使用 'docker compose logs -f' 查看日志"
    fi
}

# ======================== 完成输出 ========================
show_complete() {
    # 获取服务器 IP
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$server_ip" ]] && server_ip="YOUR_IP"

    # 读取机器码
    local machine_id="未生成"
    if [[ -f "${DATA_DIR}/.machine_id" ]]; then
        machine_id=$(cat "${DATA_DIR}/.machine_id")
    fi

    # 读取域名
    local domain="http://${server_ip}"
    if [[ -f "${SCRIPT_DIR}/.env" ]]; then
        local env_domain
        env_domain=$(grep -E '^DOMAIN=' "${SCRIPT_DIR}/.env" | cut -d'=' -f2)
        if [[ -n "$env_domain" && "$env_domain" != "http://your-domain.com" ]]; then
            domain="$env_domain"
        fi
    fi

    echo ""
    banner "============================================"
    banner "  车联网私有化系统 部署完成！"
    banner "============================================"
    echo ""
    echo -e "  管理后台:  ${GREEN}${domain}${NC}"
    echo -e "  API 文档:  ${GREEN}${domain}/api/docs${NC}"
    echo -e "  机器码:    ${CYAN}${machine_id}${NC}"
    echo ""
    echo "  请将机器码发送给供应商获取 License"
    echo "  License 导入方法: 管理后台 -> 系统设置 -> 授权管理"
    echo ""
    banner "============================================"
    echo ""
    echo "  常用管理命令:"
    echo "    查看服务状态:  cd ${SCRIPT_DIR} && docker compose ps"
    echo "    查看日志:      cd ${SCRIPT_DIR} && docker compose logs -f"
    echo "    重启服务:      cd ${SCRIPT_DIR} && docker compose restart"
    echo "    停止服务:      cd ${SCRIPT_DIR} && docker compose down"
    echo ""
}

# ======================== 主流程 ========================
main() {
    parse_args "$@"
    show_banner
    check_root
    check_os
    check_docker
    check_resources
    setup_config
    generate_machine_id
    create_data_dirs
    pull_images
    init_database
    start_services
    health_check
    show_complete
}

main "$@"
