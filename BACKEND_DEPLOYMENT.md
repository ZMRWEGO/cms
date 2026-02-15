# ReactPress 后端部署指南

## 目录

- [1. 部署架构](#1-部署架构)
- [2. 服务器准备](#2-服务器准备)
- [3. 获取代码](#3-获取代码)
- [4. 数据库配置](#4-数据库配置)
- [5. 环境变量配置](#5-环境变量配置)
- [6. 安装依赖](#6-安装依赖)
- [7. 构建项目](#7-构建项目)
- [8. 配置 PM2](#8-配置-pm2)
- [9. 配置 Nginx](#9-配置-nginx)
- [10. 配置防火墙](#10-配置防火墙)
- [11. 启动服务](#11-启动服务)
- [12. 验证测试](#12-验证测试)
- [13. 常见问题](#13-常见问题)

---

## 1. 部署架构

### 1.1 单独部署后端的优势

**为什么只部署后端到服务器？**

```
┌──────────────────┐
│   服务器        │
│                  │
│  ┌──────────┐   │
│  │ 后端     │   │  ← 部署到服务器
│  │ NestJS  │   │
│  └────┬─────┘   │
│       │         │
│  ┌────▼─────┐   │
│  │ MySQL    │   │  ← 部署到服务器
│  └──────────┘   │
└──────────────────┘
        ▲
        │ API 调用
        │
┌───────┴──────────┐
│   前端          │
│  - 本地开发       │
│  - Vercel 部署   │
│  - 其他托管       │
└──────────────────┘
```

### 1.2 优势说明

| 优势 | 说明 |
|------|------|
| **节省资源** | 只运行后端 + MySQL，内存占用 ~500MB |
| **灵活扩展** | 前端可部署到任意平台（Vercel/Netlify/本地）|
| **独立维护** | 前后端版本独立，互不影响 |
| **成本优化** | 2G 服务器完全够用，无需升级 |

### 1.3 资源需求

| 组件 | 内存占用 | CPU 占用 |
|------|---------|---------|
| NestJS 后端 | 150-200MB | 低 |
| MySQL 数据库 | 200-300MB | 中 |
| Nginx | 20-50MB | 低 |
| 系统开销 | 200-300MB | - |
| **总计** | **~600-850MB** | **低-中** |

---

## 2. 服务器准备

### 2.1 系统要求

- **操作系统**：Ubuntu 20.04/22.04 或 CentOS 7/8
- **内存**：建议 >= 1GB
- **磁盘**：建议 >= 20GB
- **网络**：开放端口 80, 443, 3306（可选）

### 2.2 安装基础工具

#### 更新系统

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS
sudo yum update -y
```

#### 安装必要工具

```bash
# Ubuntu/Debian
sudo apt install -y \
  git \
  curl \
  wget \
  vim \
  build-essential

# CentOS
sudo yum install -y \
  git \
  curl \
  wget \
  vim \
  gcc-c++
```

### 2.3 安装 Node.js 18

#### 使用 NodeSource 仓库（推荐）

```bash
# 下载安装脚本
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# 安装 Node.js
sudo apt-get install -y nodejs

# 验证安装
node -v   # 应显示 v18.x.x
npm -v    # 应显示 9.x.x 或更高
```

#### 使用 NVM（可选）

```bash
# 安装 NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新加载配置
source ~/.bashrc

# 安装 Node.js 18
nvm install 18
nvm use 18

# 设为默认版本
nvm alias default 18
```

### 2.4 安装 pnpm

```bash
# 全局安装 pnpm
npm install -g pnpm

# 验证安装
pnpm -v
```

### 2.5 安装 PM2

```bash
# 全局安装 PM2
npm install -g pm2

# 验证安装
pm2 -v

# 设置开机自启
pm2 startup
# 按提示执行输出的命令
```

---

## 3. 获取代码

### 方式 A：直接克隆（推荐用于开发）

```bash
# 安装 Git（如果未安装）
sudo apt install -y git

# 进入工作目录
cd /var/www
sudo mkdir -p reactpress
cd reactpress

# 克隆代码（推荐 Fork 到你自己的仓库）
git clone https://github.com/YOUR_USERNAME/reactpress.git .

# 或使用原始仓库（不推荐，无法提交修改）
git clone https://github.com/fecommunity/reactpress.git .

# 设置目录权限
sudo chown -R $USER:$USER /var/www/reactpress
```

### 方式 B：本地构建后上传（推荐用于生产）

#### 在本地构建

```bash
# 在本地开发机器上
cd reactpress

# 安装依赖
pnpm install

# 构建后端
pnpm run build:server

# 打包构建产物
cd server
tar -czf server-build.tar.gz dist public package.json
```

#### 上传到服务器

```bash
# 在本地执行
scp server/server-build.tar.gz user@your-server:/tmp/

# 或使用 rsync
rsync -avz --progress \
  server/dist/ \
  user@your-server:/var/www/reactpress/server/dist/
```

#### 在服务器解压

```bash
# SSH 登录服务器
ssh user@your-server

# 创建目录
sudo mkdir -p /var/www/reactpress/server
cd /var/www/reactpress/server

# 解压构建产物
tar -xzf /tmp/server-build.tar.gz

# 清理临时文件
rm /tmp/server-build.tar.gz
```

### 方式 C：发布到私有 npm 仓库（企业级方案）

适用于企业内部项目，需要搭建私有 npm 仓库（如 Verdaccio）。

---

## 4. 数据库配置

### 4.1 安装 MySQL

#### Ubuntu/Debian

```bash
# 安装 MySQL 8.0
sudo apt install -y mysql-server

# 启动 MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# 检查状态
sudo systemctl status mysql
```

#### CentOS

```bash
# 安装 MySQL
sudo yum install -y mysql-server

# 启动 MySQL
sudo systemctl start mysqld
sudo systemctl enable mysqld

# 检查状态
sudo systemctl status mysqld
```

### 4.2 安全配置

```bash
# 运行安全配置向导
sudo mysql_secure_installation

# 按提示操作：
# 1. 设置 root 密码
# 2. 删除匿名用户
# 3. 禁止 root 远程登录
# 4. 删除测试数据库
# 5. 重新加载权限表
```

### 4.3 创建数据库和用户

#### 登录 MySQL

```bash
# 使用 root 登录
sudo mysql

# 或使用密码登录
mysql -u root -p
```

#### 执行 SQL 命令

```sql
-- 创建数据库
CREATE DATABASE reactpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建专用用户（更安全）
CREATE USER 'reactpress'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- 授权用户访问数据库
GRANT ALL PRIVILEGES ON reactpress.* TO 'reactpress'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

-- 查看创建结果
SHOW DATABASES;
SELECT User, Host FROM mysql.user;

-- 退出
EXIT;
```

### 4.4 优化 MySQL 配置（小内存服务器）

编辑 MySQL 配置文件：

```bash
sudo vim /etc/mysql/my.cnf
# 或
sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf
```

添加以下配置：

```ini
[mysqld]
# 基本配置
default-storage-engine=InnoDB
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 内存优化（适合 1-2GB 内存服务器）
innodb_buffer_pool_size=128M
innodb_log_file_size=32M
innodb_flush_log_at_trx_commit=2

# 连接优化
max_connections=100
thread_stack=128K

# 查询缓存（小内存环境关闭）
query_cache_size=0
query_cache_type=0

# 临时表大小
tmp_table_size=16M
max_heap_table_size=16M

# 超时设置
wait_timeout=300
interactive_timeout=300

# 日志配置
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow-query.log
long_query_time=2

# 二进制日志（可选，用于备份恢复）
log-bin=/var/log/mysql/mysql-bin.log
expire_logs_days=7
max_binlog_size=100M

# 数据目录
datadir=/var/lib/mysql
socket=/var/run/mysqld/mysqld.sock

# 网络配置
bind-address=127.0.0.1
```

重启 MySQL：

```bash
sudo systemctl restart mysql

# 验证配置
sudo systemctl status mysql
```

### 4.5 测试数据库连接

```bash
# 使用新用户测试连接
mysql -u reactpress -p reactpress

# 如果成功登录，执行测试查询
SHOW TABLES;

# 退出
EXIT;
```

---

## 5. 环境变量配置

### 5.1 创建 .env 文件

```bash
# 进入项目根目录
cd /var/www/reactpress

# 创建环境变量文件
vim .env
```

### 5.2 环境变量配置

```env
# ========================================
# 数据库配置
# ========================================
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=reactpress
DB_PASSWD=your_secure_password_here
DB_DATABASE=reactpress

# ========================================
# 服务器配置
# ========================================
# 后端 API 地址（用于生成链接、邮件等）
SERVER_SITE_URL=https://api.yourdomain.com

# ========================================
# 客户端配置（用于 CORS）
# ========================================
# 前端地址（开发时用 localhost，生产用实际域名）
CLIENT_SITE_URL=https://blog.yourdomain.com

# ========================================
# 其他配置（可选）
# ========================================
# GitHub OAuth（如果使用）
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret

# JWT 密钥（生产环境必须修改）
JWT_SECRET=your_very_long_random_secret_key_here

# 阿里云 OSS（如果使用）
OSS_REGION=oss-cn-hangzhou
OSS_ACCESS_KEY_ID=your_access_key
OSS_ACCESS_KEY_SECRET=your_secret_key
OSS_BUCKET=your_bucket_name

# SMTP 邮件配置（如果使用）
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_email_password
SMTP_FROM=noreply@yourdomain.com
```

### 5.3 保护环境变量文件

```bash
# 设置文件权限（仅所有者可读写）
chmod 600 .env

# 或使用 chattr（更严格，root 用户也需要额外权限才能修改）
sudo chattr +i .env  # 防止删除
sudo chattr -i .env  # 取消保护（如需修改）
```

---

## 6. 安装依赖

### 6.1 安装项目依赖

```bash
# 进入项目目录
cd /var/www/reactpress

# 安装所有依赖（包括 toolkit）
pnpm install

# 仅安装生产依赖（推荐用于生产环境）
pnpm install --prod
```

### 6.2 处理安装问题

#### 问题：node-gyp 编译失败

```bash
# 安装编译工具
sudo apt install -y build-essential python3

# 清理缓存后重新安装
pnpm store prune
pnpm install
```

#### 问题：权限问题

```bash
# 不要使用 sudo 安装 npm 包
# 如果遇到权限问题，修复目录所有权
sudo chown -R $USER:$USER ~/.npm
sudo chown -R $USER:$USER /var/www/reactpress
```

---

## 7. 构建项目

### 7.1 构建后端

```bash
# 进入项目根目录
cd /var/www/reactpress

# 构建后端
pnpm run build:server

# 构建成功后会输出
# ✓ Built in 45s
```

### 7.2 检查构建产物

```bash
# 检查构建目录
ls -la server/dist/

# 应该看到以下文件：
# main.js
# main.js.map
# modules/
# utils/
# ...
```

### 7.3 复制静态资源（如果需要）

```bash
# 某些项目需要复制 public 目录到 dist
cp -r server/public server/dist/public
```

---

## 8. 配置 PM2

### 8.1 创建 PM2 配置文件

```bash
# 创建配置文件
vim /var/www/reactpress/server/ecosystem.config.js
```

### 8.2 PM2 配置内容

```javascript
module.exports = {
  apps: [
    {
      name: 'reactpress-server',

      // 启动脚本
      script: './dist/main.js',

      // 应用根目录
      cwd: '/var/www/reactpress/server',

      // 实例数量（1.4 CPU * 核心数，小内存服务器用 1）
      instances: 1,

      // 执行模式（fork 或 cluster）
      exec_mode: 'fork',

      // 自动重启
      autorestart: true,

      // 监听文件变化（生产环境关闭）
      watch: false,

      // 最大内存限制（根据服务器内存调整）
      max_memory_restart: '400M',

      // Node.js 参数
      node_args: '--max-old-space-size=384',

      // 环境变量
      env: {
        NODE_ENV: 'production',
        NODE_OPTIONS: '--max-old-space-size=384',
        TZ: 'Asia/Shanghai',
      },

      // 日志文件
      error_file: '/var/log/reactpress/error.log',
      out_file: '/var/log/reactpress/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',

      // 日志合并
      combine_logs: true,

      // 合并日志时的时间格式
      time: true,

      // 进程管理
      min_uptime: '10s',
      max_restarts: 10,

      // 重启延迟
      restart_delay: 4000,
    },
  ],
};
```

### 8.3 创建日志目录

```bash
# 创建日志目录
sudo mkdir -p /var/log/reactpress

# 设置权限
sudo chown -R $USER:$USER /var/log/reactpress

# 设置日志轮转（防止日志文件过大）
sudo vim /etc/logrotate.d/reactpress
```

添加以下内容：

```
/var/log/reactpress/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 $USER $USER
    sharedscripts
    postrotate
        pm2 reload reactpress-server
    endscript
}
```

### 8.4 PM2 进程管理命令

```bash
# 启动应用
pm2 start ecosystem.config.js

# 查看状态
pm2 status

# 查看日志
pm2 logs reactpress-server

# 查看实时日志
pm2 logs reactpress-server --lines 100

# 停止应用
pm2 stop reactpress-server

# 重启应用
pm2 restart reactpress-server

# 删除应用
pm2 delete reactpress-server

# 重载应用（零停机）
pm2 reload reactpress-server

# 保存进程列表
pm2 save

# 设置开机自启
pm2 startup
# 按提示执行输出的命令

# 查看详细信息
pm2 show reactpress-server

# 重置重启次数
pm2 reset reactpress-server
```

---

## 9. 配置 Nginx

### 9.1 安装 Nginx

```bash
# Ubuntu/Debian
sudo apt install -y nginx

# CentOS
sudo yum install -y nginx

# 启动 Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# 验证状态
sudo systemctl status nginx
```

### 9.2 创建站点配置

```bash
# 创建配置文件
sudo vim /etc/nginx/sites-available/reactpress-api
```

### 9.3 HTTP 配置（开发/测试）

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name api.yourdomain.com;

    # 日志配置
    access_log /var/log/nginx/reactpress-api-access.log;
    error_log /var/log/nginx/reactpress-api-error.log;

    # 请求体大小限制
    client_max_body_size 10M;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # API 代理配置
    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;

        # 请求头设置
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # 缓存绕过
        proxy_cache_bypass $http_upgrade;
    }

    # 健康检查端点（可选）
    location /health {
        proxy_pass http://localhost:3002/health;
        access_log off;
    }

    # 静态文件缓存（如果有）
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:3002;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

### 9.4 HTTPS 配置（生产环境）

#### 使用 Certbot 获取免费 SSL 证书

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取证书并自动配置 Nginx
sudo certbot --nginx -d api.yourdomain.com

# 按提示操作：
# 1. 输入邮箱地址
# 2. 同意服务条款
# 3. 选择是否分享邮箱
# 4. Certbot 会自动修改 Nginx 配置
```

Certbot 会自动将配置修改为：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name api.yourdomain.com;

    # HTTP 自动跳转 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name api.yourdomain.com;

    # SSL 证书配置（Certbot 自动添加）
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # 其他配置与 HTTP 相同...
}
```

### 9.5 启用站点配置

```bash
# 创建软链接到 sites-enabled
sudo ln -s /etc/nginx/sites-available/reactpress-api \
           /etc/nginx/sites-enabled/reactpress-api

# 删除默认配置（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重新加载 Nginx
sudo systemctl reload nginx
```

### 9.6 强制 HTTPS（推荐）

如果已配置 HTTPS，建议强制使用：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name api.yourdomain.com;

    # 强制跳转 HTTPS
    return 301 https://$server_name$request_uri;
}
```

---

## 10. 配置防火墙

### 10.1 UFW（Ubuntu）

```bash
# 安装 UFW
sudo apt install -y ufw

# 允许 SSH
sudo ufw allow 22/tcp

# 允许 HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 允许 MySQL（如果需要远程连接）
sudo ufw allow 3306/tcp

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status verbose
```

### 10.2 firewalld（CentOS）

```bash
# 安装 firewalld
sudo yum install -y firewalld

# 启动并设置开机自启
sudo systemctl start firewalld
sudo systemctl enable firewalld

# 允许服务
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh

# 允许 MySQL（如果需要）
sudo firewall-cmd --permanent --add-service=mysql

# 重新加载
sudo firewall-cmd --reload

# 查看状态
sudo firewall-cmd --list-all
```

---

## 11. 启动服务

### 11.1 启动后端服务

```bash
# 进入项目目录
cd /var/www/reactpress

# 使用 PM2 启动服务
pm2 start server/ecosystem.config.js

# 查看启动日志
pm2 logs reactpress-server --lines 50

# 查看服务状态
pm2 status
```

### 11.2 配置开机自启

```bash
# 保存当前进程列表
pm2 save

# 设置开机自启
pm2 startup

# 按提示执行输出的命令，例如：
# sudo env PATH=$PATH:/usr/bin pm2 startup systemd -
#   -u yourusername
#   -c /home/yourusername/.pm2
```

### 11.3 检查服务状态

```bash
# 查看 PM2 进程
pm2 status

# 查看进程详细信息
pm2 show reactpress-server

# 查看实时日志
pm2 logs reactpress-server

# 查看系统服务
sudo systemctl status nginx
sudo systemctl status mysql
```

---

## 12. 验证测试

### 12.1 本地测试

#### 测试后端服务

```bash
# 测试端口是否监听
netstat -tlnp | grep 3002
# 或
ss -tlnp | grep 3002

# 应该看到：
# tcp  0  0.0.0.0:3002  0.0.0.0:*  LISTEN  12345/node
```

#### 测试 API 端点

```bash
# 测试健康检查
curl http://localhost:3002/health

# 测试 API 根路径
curl http://localhost:3002/api

# 测试数据库连接
curl http://localhost:3002/api/test-db
```

### 12.2 远程测试

#### 从本地机器测试

```bash
# 测试 HTTP
curl http://api.yourdomain.com/api

# 测试 HTTPS
curl https://api.yourdomain.com/api

# 测试 CORS
curl -I -H "Origin: https://blog.yourdomain.com" \
  https://api.yourdomain.com/api

# 应该看到：
# Access-Control-Allow-Origin: https://blog.yourdomain.com
```

#### 浏览器测试

1. 访问 `https://api.yourdomain.com/api`
2. 检查返回的 JSON 数据
3. 打开浏览器开发者工具（F12）
4. 查看 Network 标签，检查请求头

### 12.3 性能测试

#### 使用 ab 工具

```bash
# 安装 Apache Bench
sudo apt install -y apache2-utils

# 测试 API 性能
ab -n 1000 -c 10 https://api.yourdomain.com/api/articles

# 查看结果：
# - Requests per second: xxx [#/sec]
# - Time per request: xxx [ms]
```

#### 使用 wrk 工具（更高级）

```bash
# 安装 wrk
sudo apt install -y wrk

# 测试 API 性能
wrk -t4 -c100 -d30s https://api.yourdomain.com/api/articles
```

---

## 13. 常见问题

### 13.1 服务启动失败

#### 问题：端口被占用

```bash
# 错误信息
Error: listen EADDRINUSE: address already in use :::3002

# 查看占用端口的进程
sudo lsof -i :3002

# 或
sudo netstat -tlnp | grep 3002

# 杀死占用端口的进程
kill -9 <PID>

# 或 PM2 重启
pm2 restart reactpress-server
```

#### 问题：模块未找到

```bash
# 错误信息
Error: Cannot find module '@fecommunity/reactpress-toolkit'

# 解决方案：重新安装依赖
cd /var/www/reactpress
pnpm install

# 或安装 toolkit
pnpm install --filter @fecommunity/reactpress-toolkit
```

#### 问题：数据库连接失败

```bash
# 错误信息
Error: connect ECONNREFUSED 127.0.0.1:3306

# 检查 MySQL 状态
sudo systemctl status mysql

# 检查数据库是否存在
mysql -u reactpress -p reactpress

# 检查 .env 配置
cat /var/www/reactpress/.env | grep DB_
```

### 13.2 内存不足

#### 问题：OOM Killer 杀死进程

```bash
# 查看系统日志
sudo dmesg | grep -i 'killed process'

# 可能看到：
# Out of memory: Kill process 12345 (node) score 900
```

**解决方案：**

1. 降低 PM2 内存限制
   ```javascript
   max_memory_restart: '300M',  // 从 400M 降到 300M
   ```

2. 优化 MySQL 配置
   ```ini
   innodb_buffer_pool_size=64M
   max_connections=50
   ```

3. 增加 Swap 空间
   ```bash
   # 创建 2GB swap 文件
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile

   # 永久生效
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

### 13.3 CORS 错误

#### 问题：前端无法调用后端 API

**浏览器错误：**
```
Access to fetch at 'https://api.yourdomain.com/api' from origin
'https://blog.yourdomain.com' has been blocked by CORS policy
```

**解决方案：**

1. 检查后端 CORS 配置
   ```typescript
   // server/src/main.ts
   app.enableCors({
     origin: [
       'https://blog.yourdomain.com',  // 确保包含前端域名
       'http://localhost:3001',       // 本地开发
     ],
     credentials: true,
   });
   ```

2. 修改后重新构建
   ```bash
   cd /var/www/reactpress
   pnpm run build:server
   pm2 restart reactpress-server
   ```

3. 验证 CORS 头
   ```bash
   curl -I -H "Origin: https://blog.yourdomain.com" \
     https://api.yourdomain.com/api
   ```

### 13.4 SSL 证书问题

#### 问题：证书过期或无效

```bash
# 重新获取证书
sudo certbot renew --force-renewal

# 或重新申请
sudo certbot --nginx -d api.yourdomain.com --force-renewal

# 检查证书状态
sudo certbot certificates
```

#### 问题：HTTP 仍可访问

确保 Nginx 配置了 HTTP 到 HTTPS 的重定向：

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

### 13.5 日志问题

#### 问题：日志文件过大

```bash
# 配置日志轮转（见 8.3 节）
sudo vim /etc/logrotate.d/reactpress

# 手动清理日志
pm2 flush
pm2 logs reactpress-server --lines 1000

# 或直接删除
> /var/log/reactpress/out.log
> /var/log/reactpress/error.log
```

---

## 附录 A：维护命令速查

### PM2 命令

```bash
# 查看状态
pm2 status

# 查看日志
pm2 logs reactpress-server

# 重启服务
pm2 restart reactpress-server

# 重载服务（零停机）
pm2 reload reactpress-server

# 停止服务
pm2 stop reactpress-server

# 删除进程
pm2 delete reactpress-server

# 清理日志
pm2 flush

# 保存进程列表
pm2 save
```

### 系统服务命令

```bash
# Nginx
sudo systemctl status nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx

# MySQL
sudo systemctl status mysql
sudo systemctl start mysql
sudo systemctl stop mysql
sudo systemctl restart mysql
```

### 监控命令

```bash
# 查看系统资源
htop

# 查看磁盘使用
df -h

# 查看内存使用
free -h

# 查看 PM2 监控
pm2 monit
```

---

## 附录 B：备份恢复

### 数据库备份

```bash
# 备份脚本
cat > /var/www/reactpress/scripts/backup-db.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/reactpress"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
mysqldump -u reactpress -p'your_password' reactpress | \
  gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 保留最近 7 天的备份
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete

echo "Database backup completed: db_$DATE.sql.gz"
EOF

# 添加执行权限
chmod +x /var/www/reactpress/scripts/backup-db.sh

# 手动执行备份
/var/www/reactpress/scripts/backup-db.sh
```

### 定时备份

```bash
# 编辑 crontab
crontab -e

# 每天凌晨 3 点备份数据库
0 3 * * * /var/www/reactpress/scripts/backup-db.sh
```

### 数据库恢复

```bash
# 解压备份
gunzip /var/backups/reactpress/db_20260215_030000.sql.gz

# 恢复数据库
mysql -u reactpress -p reactpress < /var/backups/reactpress/db_20260215_030000.sql
```

---

## 总结

部署后端到服务器的关键步骤：

1. ✅ **服务器准备** - 安装 Node.js、MySQL、PM2、Nginx
2. ✅ **获取代码** - Git 克隆或本地构建后上传
3. ✅ **数据库配置** - 创建数据库和用户，优化配置
4. ✅ **环境变量** - 配置 .env 文件
5. ✅ **安装依赖** - pnpm install
6. ✅ **构建项目** - pnpm run build:server
7. ✅ **配置 PM2** - 创建 ecosystem.config.js
8. ✅ **配置 Nginx** - 反向代理 + SSL 证书
9. ✅ **启动服务** - pm2 start
10. ✅ **验证测试** - 本地 + 远程测试

完成这些步骤后，你的后端服务就可以正常运行了！
