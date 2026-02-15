#!/bin/bash

#############################################
#  ReactPress 后端自动部署脚本
#  支持: Ubuntu/Debian/CentOS/Alpine
#############################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi

    print_info "检测到操作系统: $OS $OS_VERSION"
}

# 安装基础工具
install_base_tools() {
    print_header "安装基础工具"

    case $OS in
        ubuntu|debian)
            sudo apt-get update -y
            sudo apt-get install -y curl wget git vim build-essential
            ;;
        centos|rhel|fedora)
            sudo yum update -y
            sudo yum install -y curl wget git vim gcc-c++
            ;;
        alpine)
            apk update
            apk add curl wget git vim build-base
            ;;
        *)
            print_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    print_success "基础工具安装完成"
}

# 安装 Node.js 18
install_nodejs() {
    print_header "安装 Node.js 18"

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        print_info "Node.js 已安装: $NODE_VERSION"
        return
    fi

    case $OS in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        alpine)
            apk add nodejs npm
            ;;
    esac

    print_success "Node.js 安装完成: $(node -v)"
}

# 安装 pnpm
install_pnpm() {
    print_header "安装 pnpm"

    if command -v pnpm &> /dev/null; then
        print_info "pnpm 已安装: $(pnpm -v)"
        return
    fi

    npm install -g pnpm
    print_success "pnpm 安装完成: $(pnpm -v)"
}

# 安装 PM2
install_pm2() {
    print_header "安装 PM2"

    if command -v pm2 &> /dev/null; then
        print_info "PM2 已安装: $(pm2 -v)"
        return
    fi

    npm install -g pm2
    print_success "PM2 安装完成: $(pm2 -v)"
}

# 安装 MySQL
install_mysql() {
    print_header "安装 MySQL"

    if command -v mysql &> /dev/null; then
        print_info "MySQL 已安装"
        return
    fi

    case $OS in
        ubuntu|debian)
            sudo apt-get install -y mysql-server
            sudo systemctl start mysql
            sudo systemctl enable mysql
            ;;
        centos|rhel|fedora)
            sudo yum install -y mysql-server
            sudo systemctl start mysqld
            sudo systemctl enable mysqld
            ;;
        alpine)
            apk add mysql
            rc-service mysql start
            rc-update add mysql
            ;;
    esac

    print_success "MySQL 安装完成"
}

# 安装 Nginx（可选）
install_nginx() {
    print_header "安装 Nginx"

    if command -v nginx &> /dev/null; then
        print_info "Nginx 已安装"
        return
    fi

    case $OS in
        ubuntu|debian)
            sudo apt-get install -y nginx
            ;;
        centos|rhel|fedora)
            sudo yum install -y nginx
            ;;
        alpine)
            apk add nginx
            ;;
    esac

    sudo systemctl start nginx
    sudo systemctl enable nginx

    print_success "Nginx 安装完成"
}

# 创建项目目录
create_project_dir() {
    print_header "创建项目目录"

    sudo mkdir -p /var/www/reactpress
    sudo chown -R $USER:$USER /var/www/reactpress
    cd /var/www/reactpress

    print_success "项目目录创建完成: /var/www/reactpress"
}

# 获取代码
get_code() {
    print_header "获取后端代码"

    echo ""
    echo "请选择代码获取方式："
    echo "1) 从本地上传压缩包 (server.tar.gz)"
    echo "2) 从 Git 仓库克隆"
    echo "3) 使用本地已存在的代码"
    read -p "请输入选择 (1/2/3): " choice

    case $choice in
        1)
            print_info "请先上传 server.tar.gz 到服务器的 /tmp/ 目录"
            print_warning "支持的上传方式:"
            echo "  - scp: scp server.tar.gz user@server:/tmp/"
            echo "  - SFTP 工具: FileZilla, WinSCP"
            echo ""
            read -p "上传完成后按回车继续..." -r

            if [ ! -f "/tmp/server.tar.gz" ]; then
                print_error "未找到 /tmp/server.tar.gz"
                exit 1
            fi

            print_info "解压代码..."
            mkdir -p server
            tar -xzf /tmp/server.tar.gz -C server/
            rm /tmp/server.tar.gz
            print_success "代码解压完成"
            ;;

        2)
            read -p "请输入 Git 仓库地址: " git_url
            print_info "克隆代码仓库..."
            git clone $git_url temp_repo

            print_info "复制后端代码..."
            mkdir -p server
            cp -r temp_repo/server/* server/
            cp -r temp_repo/server/.env* server/ 2>/dev/null || true
            rm -rf temp_repo
            print_success "代码克隆完成"
            ;;

        3)
            print_warning "请确保后端代码已经在 /var/www/reactpress/server/ 目录下"
            print_info "当前目录: $(pwd)"
            read -p "确认继续? (y/n): " confirm
            if [ "$confirm" != "y" ]; then
                exit 1
            fi
            ;;

        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
}

# 配置环境变量
configure_env() {
    print_header "配置环境变量"

    if [ -f ".env" ]; then
        print_info ".env 文件已存在"
        read -p "是否重新配置? (y/n): " reconfigure
        if [ "$reconfigure" != "y" ]; then
            return
        fi
    fi

    # 获取配置信息
    read -p "请输入数据库密码 (默认: reactpress): " db_password
    db_password=${db_password:-reactpress}

    read -p "请输入服务器IP或域名 (默认: localhost): " server_url
    server_url=${server_url:-localhost}

    read -p "请输入前端URL (用于CORS, 默认: http://localhost:3001): " client_url
    client_url=${client_url:-http://localhost:3001}

    # 创建 .env 文件
    cat > .env <<EOF
# ========================================
# 数据库配置
# ========================================
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=reactpress
DB_PASSWD=$db_password
DB_DATABASE=reactpress

# ========================================
# 服务器配置
# ========================================
SERVER_SITE_URL=http://$server_url:3002

# ========================================
# 客户端配置 (用于 CORS)
# ========================================
CLIENT_SITE_URL=$client_url
EOF

    chmod 600 .env
    print_success "环境变量配置完成"
    print_info "数据库密码: $db_password"
}

# 配置 MySQL
setup_mysql() {
    print_header "配置 MySQL 数据库"

    # 从 .env 读取密码
    if [ -f ".env" ]; then
        db_password=$(grep DB_PASSWD .env | cut -d'=' -f2)
    else
        db_password="reactpress"
    fi

    print_info "创建数据库和用户..."

    case $OS in
        ubuntu|debian|centos|rhel|fedora)
            sudo mysql -e "CREATE DATABASE IF NOT EXISTS reactpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
            sudo mysql -e "CREATE USER IF NOT EXISTS 'reactpress'@'localhost' IDENTIFIED BY '$db_password';" 2>/dev/null || true
            sudo mysql -e "GRANT ALL PRIVILEGES ON reactpress.* TO 'reactpress'@'localhost';" 2>/dev/null || true
            sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
            ;;
        alpine)
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS reactpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
            mysql -u root -e "CREATE USER IF NOT EXISTS 'reactpress'@'localhost' IDENTIFIED BY '$db_password';" 2>/dev/null || true
            mysql -u root -e "GRANT ALL PRIVILEGES ON reactpress.* TO 'reactpress'@'localhost';" 2>/dev/null || true
            mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
            ;;
    esac

    print_success "MySQL 配置完成"
}

# 安装依赖
install_dependencies() {
    print_header "安装项目依赖"

    cd /var/www/reactpress/server

    print_info "安装生产依赖..."
    npm install --production

    print_success "依赖安装完成"
}

# 构建项目（如果需要）
build_project() {
    print_header "构建项目"

    if [ -d "dist" ]; then
        print_info "项目已构建，跳过"
        return
    fi

    print_warning "dist 目录不存在"
    read -p "是否需要构建项目? (需要安装全部依赖) (y/n): " need_build

    if [ "$need_build" = "y" ]; then
        print_info "安装全部依赖..."
        cd /var/www/reactpress
        npm install

        print_info "构建后端..."
        pnpm run build:server

        print_success "项目构建完成"
    else
        print_warning "跳过构建，确保 dist 目录存在"
    fi
}

# 配置 PM2
configure_pm2() {
    print_header "配置 PM2"

    # 创建 PM2 配置文件
    cat > /var/www/reactpress/ecosystem.config.js <<'EOF'
module.exports = {
  apps: [
    {
      name: 'reactpress-server',
      script: './dist/main.js',
      cwd: '/var/www/reactpress/server',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '350M',
      node_args: '--max-old-space-size=320',
      env: {
        NODE_ENV: 'production',
        NODE_OPTIONS: '--max-old-space-size=320',
        TZ: 'Asia/Shanghai',
      },
      error_file: '/var/log/reactpress/error.log',
      out_file: '/var/log/reactpress/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      combine_logs: true,
      time: true,
    },
  ],
};
EOF

    # 创建日志目录
    sudo mkdir -p /var/log/reactpress
    sudo chown -R $USER:$USER /var/log/reactpress

    print_success "PM2 配置完成"
}

# 启动服务
start_service() {
    print_header "启动后端服务"

    cd /var/www/reactpress

    print_info "启动 PM2 服务..."
    pm2 start ecosystem.config.js

    print_info "保存 PM2 进程列表..."
    pm2 save

    print_info "配置 PM2 开机自启..."
    pm2 startup | grep "sudo" | sh

    print_success "后端服务启动完成"
}

# 配置防火墙
configure_firewall() {
    print_header "配置防火墙"

    read -p "是否配置防火墙? (y/n): " setup_fw

    if [ "$setup_fw" != "y" ]; then
        return
    fi

    case $OS in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                sudo ufw allow 22/tcp
                sudo ufw allow 3002/tcp
                sudo ufw allow 80/tcp
                sudo ufw allow 443/tcp
                sudo ufw --force enable
                print_success "UFW 防火墙配置完成"
            else
                print_warning "未安装 UFW，跳过防火墙配置"
            fi
            ;;
        centos|rhel|fedora)
            if command -v firewall-cmd &> /dev/null; then
                sudo firewall-cmd --permanent --add-service=ssh
                sudo firewall-cmd --permanent --add-port=3002/tcp
                sudo firewall-cmd --permanent --add-service=http
                sudo firewall-cmd --permanent --add-service=https
                sudo firewall-cmd --reload
                print_success "firewalld 防火墙配置完成"
            else
                print_warning "未安装 firewalld，跳过防火墙配置"
            fi
            ;;
        alpine)
            print_warning "Alpine Linux 防火墙配置需要手动操作"
            ;;
    esac
}

# 显示部署结果
show_result() {
    print_header "部署完成"

    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}🎉 ReactPress 后端部署成功！${NC}"
    echo ""
    echo "后端地址: http://$SERVER_IP:3002"
    echo "API 地址: http://$SERVER_IP:3002/api"
    echo ""
    echo "常用命令:"
    echo "  查看状态: ${YELLOW}pm2 status${NC}"
    echo "  查看日志: ${YELLOW}pm2 logs reactpress-server${NC}"
    echo "  重启服务: ${YELLOW}pm2 restart reactpress-server${NC}"
    echo "  停止服务: ${YELLOW}pm2 stop reactpress-server${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 配置 Nginx 反向代理（可选）"
    echo "  2. 配置 SSL 证书（可选）"
    echo "  3. 测试 API 接口"
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ReactPress 后端自动部署脚本 v1.0  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""

    # 检测系统
    detect_os

    # 安装依赖
    install_base_tools
    install_nodejs
    install_pnpm
    install_pm2
    install_mysql
    install_nginx

    # 部署项目
    create_project_dir
    get_code
    configure_env
    setup_mysql
    install_dependencies
    build_project
    configure_pm2
    start_service

    # 配置系统
    configure_firewall

    # 显示结果
    show_result
}

# 运行主函数
main
