# ReactPress 前后端分离部署指南

## 目录

- [1. 方案概述](#1-方案概述)
- [2. 域名规划](#2-域名规划)
- [3. Vercel 前端部署](#3-vercel-前端部署)
- [4. 后端服务器配置](#4-后端服务器配置)
- [5. DNS 配置](#5-dns-配置)
- [6. HTTPS 配置](#6-https-配置)
- [7. 项目配置修改](#7-项目配置修改)
- [8. 验证测试](#8-验证测试)
- [9. 常见问题](#9-常见问题)
- [10. 维护和监控](#10-维护和监控)

---

## 1. 方案概述

### 1.1 为什么选择前后端分离部署？

**传统部署方式**（所有服务在同一服务器）：

```
┌─────────────────────────────────────┐
│         2G 服务器                │
│                                  │
│  前端 (Next.js)     ~150MB       │
│  后端 (NestJS)     ~200MB       │
│  MySQL             ~300MB       │
│  Nginx             ~50MB        │
│  系统开销          ~200MB       │
│                                  │
│  总计: ~900MB (紧张！)           │
└─────────────────────────────────────┘
```

**推荐部署方式**（前后端分离）：

```
┌──────────────────┐         ┌─────────────────────┐
│   Vercel        │         │   2G 服务器        │
│  (免费托管)       │         │                     │
│                  │         │  后端 (NestJS)  200MB │
│  前端 (Next.js)  │         │  MySQL          300MB │
│  全球 CDN        │         │  Nginx          50MB  │
│  自动 HTTPS      │         │  系统开销       200MB │
└──────────────────┘         │  总计: ~750MB ✓     │
                            └─────────────────────┘
```

### 1.2 优势对比

| 对比项 | 传统部署 | 前后端分离部署 |
|--------|---------|--------------|
| **内存使用** | ~900MB（紧张） | ~750MB（充足） |
| **访问速度** | 取决于服务器带宽 | Vercel 全球 CDN 加速 |
| **稳定性** | 服务器宕机 = 全站不可用 | 前端永不宕机 |
| **HTTPS** | 需手动配置 SSL | Vercel 自动配置 |
| **成本** | 需要升级服务器配置 | Vercel 免费额度够用 |
| **扩展性** | 受限于服务器资源 | 前端无限扩展 |

### 1.3 架构示意

```
                用户浏览器
                     │
                     ▼
        ┌────────────────────────┐
        │  blog.myblog.com      │
        │  (Vercel CDN)        │
        │                      │
        │  ┌──────────────┐    │
        │  │ Next.js SPA  │    │
        │  │ 前端应用     │    │
        │  └──────┬───────┘    │
        └─────────┼────────────┘
                  │
                  │ API 请求
                  ▼
        ┌────────────────────────┐
        │ api.myblog.com        │
        │ (你的服务器)          │
        │                      │
        │ ┌──────────────────┐ │
        │ │  NestJS API     │ │
        │ │  (端口 3002)    │ │
        │ └────────┬─────────┘ │
        │          │           │
        │ ┌────────▼─────────┐ │
        │ │   MySQL         │ │
        │ │  (端口 3306)    │ │
        │ └─────────────────┘ │
        └─────────────────────┘
```

---

## 2. 域名规划

### 2.1 推荐的域名结构

假设你的域名是 `myblog.com`，推荐这样规划：

| 子域名 | 用途 | 托管位置 |
|--------|------|----------|
| `blog.myblog.com` | 前端应用（用户访问） | **Vercel** |
| `www.myblog.com` | 前端（可选，重定向到主域名） | **Vercel** |
| `api.myblog.com` | 后端 API 接口 | **你的服务器** |
| `admin.myblog.com` | 管理后台（可选） | **你的服务器** |

### 2.2 域名配置示例

```
# DNS 记录配置

blog    CNAME  →  cname.vercel-dns.com
www     CNAME  →  cname.vercel-dns.com
api     A      →  123.45.67.89 (你的服务器IP)
admin   A      →  123.45.67.89 (你的服务器IP)
```

### 2.3 环境变量规划

| 环境 | 前端 URL | 后端 API URL |
|------|----------|-------------|
| **本地开发** | http://localhost:3001 | http://localhost:3002/api |
| **Vercel 生产** | https://blog.myblog.com | https://api.myblog.com/api |

---

## 3. Vercel 前端部署

### 3.1 准备工作

#### 步骤 1：Fork 项目到 GitHub

1. 访问 [https://github.com/fecommunity/reactpress](https://github.com/fecommunity/reactpress)
2. 点击右上角 **Fork** 按钮
3. 项目会复制到你的 GitHub 账号下

#### 步骤 2：准备 GitHub 个人访问令牌（可选）

如果项目是私有的，需要配置访问权限：
1. GitHub → Settings → Developer settings → Personal access tokens
2. 生成新 token，勾选 `repo` 权限
3. 复制 token，在 Vercel 导入时使用

### 3.2 连接 Vercel

#### 步骤 1：注册/登录 Vercel

1. 访问 [vercel.com](https://vercel.com)
2. 点击 **Sign Up** 或 **Log In**
3. 使用 **GitHub 账号**登录（推荐，方便集成）
4. 授权 Vercel 访问你的 GitHub

#### 步骤 2：导入项目

1. 登录后点击 **Add New Project**
2. 选择 **Import Git Repository**
3. 找到你 Fork 的 `reactpress` 项目
4. 点击 **Import**

### 3.3 配置项目

#### 构建设置

Vercel 会自动识别 Next.js 项目，但我们需要修改一些设置：

```javascript
// 在 Vercel 项目配置中填写：

Framework Preset: Next.js

Build Command: pnpm run build:client
Output Directory: client/.next

Install Command: pnpm install
```

#### 环境变量配置

在 **Environment Variables** 部分添加：

| Key | Value | Environment |
|-----|--------|-------------|
| `SERVER_API_URL` | `https://api.myblog.com` | Production |
| `NODE_ENV` | `production` | Production |

**重要**：`SERVER_API_URL` 必须指向你服务器的域名，不要用 localhost。

### 3.4 部署项目

1. 配置完成后点击 **Deploy**
2. 等待构建完成（首次约 3-5 分钟）
3. 部署成功后会得到一个 Vercel 默认域名：
   ```
   https://reactpress-xxx.vercel.app
   ```
4. 点击访问，确认前端正常运行

### 3.5 配置自定义域名

#### 步骤 1：在 Vercel 添加域名

1. 进入项目 **Settings** → **Domains**
2. 输入域名：`blog.myblog.com`
3. 点击 **Add**

#### 步骤 2：配置 DNS（详见第 5 节）

Vercel 会显示需要添加的 DNS 记录：
```
Type: CNAME
Name: blog
Value: cname.vercel-dns.com
```

#### 步骤 3：等待 DNS 生效

- 通常需要 **5-30 分钟**
- 可以用以下命令检查：
  ```bash
  # Linux/Mac
  dig blog.myblog.com

  # Windows
  nslookup blog.myblog.com
  ```

#### 步骤 4：确认证书

DNS 生效后，Vercel 会自动申请 SSL 证书：
1. 在 Domains 页面会看到证书状态
2. 通常几分钟内完成
3. 状态变为 **Valid Configuration**

---

## 4. 后端服务器配置

### 4.1 服务器环境准备

#### 系统要求

- **操作系统**: Ubuntu 20.04/22.04 或 CentOS 7/8
- **Node.js**: >= 16.5.0
- **MySQL**: 5.7 或 8.0
- **内存**: 建议 >= 1GB（前后端分离后）

#### 安装 Node.js

```bash
# 使用 NodeSource 仓库安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证安装
node -v
npm -v
```

#### 安装 pnpm

```bash
npm install -g pnpm
```

#### 安装 PM2

```bash
npm install -g pm2
```

### 4.2 安装 MySQL

#### Ubuntu/Debian

```bash
# 安装 MySQL
sudo apt update
sudo apt install mysql-server

# 安全配置
sudo mysql_secure_installation

# 登录 MySQL
sudo mysql
```

#### 创建数据库和用户

```sql
-- 在 MySQL 命令行执行
CREATE DATABASE reactpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'reactpress'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON reactpress.* TO 'reactpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 4.3 优化 MySQL 配置

编辑 MySQL 配置文件：

```bash
sudo nano /etc/mysql/my.cnf
```

添加以下配置（适合 2G 内存服务器）：

```ini
[mysqld]
# 基本设置
default-storage-engine=InnoDB
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 内存优化（适合小内存）
innodb_buffer_pool_size=64M
innodb_log_file_size=32M
innodb_flush_log_at_trx_commit=2

# 连接优化
max_connections=50
thread_stack=128K

# 查询缓存（小内存环境关闭）
query_cache_size=0
query_cache_type=0

# 临时表大小限制
tmp_table_size=16M
max_heap_table_size=16M

# 日志配置
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow-query.log
long_query_time=2
```

重启 MySQL：

```bash
sudo systemctl restart mysql
```

### 4.4 部署后端代码

#### 方式 A：直接克隆代码

```bash
# 安装 Git
sudo apt install git

# 克隆代码（推荐使用你自己的 Fork）
cd /var/www
sudo git clone https://github.com/YOUR_USERNAME/reactpress.git
sudo chown -R $USER:$USER reactpress
cd reactpress
```

#### 方式 B：本地构建后上传

```bash
# 在本地构建
pnpm run build:server

# 打包上传到服务器
cd server
tar -czf server.tar.gz dist public package.json

# 上传到服务器
scp server.tar.gz user@your-server:/var/www/

# 在服务器解压
cd /var/www
tar -xzf server.tar.gz
```

### 4.5 配置后端环境变量

创建 `.env` 文件：

```bash
cd /var/www/reactpress
nano .env
```

添加配置：

```env
# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=reactpress
DB_PASSWD=your_secure_password
DB_DATABASE=reactpress

# 服务器配置
SERVER_SITE_URL=https://api.myblog.com

# 客户端配置（用于 CORS）
CLIENT_SITE_URL=https://blog.myblog.com
```

### 4.6 安装依赖

```bash
cd /var/www/reactpress
pnpm install --prod
```

### 4.7 配置 PM2

修改 PM2 配置文件 `server/ecosystem.config.js`：

```javascript
module.exports = {
  apps: [
    {
      name: 'reactpress-server',
      script: './dist/main.js',
      cwd: '/var/www/reactpress/server',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '350M',
      node_args: '--max-old-space-size=320',
      env: {
        NODE_ENV: 'production',
        NODE_OPTIONS: '--max-old-space-size=320',
      },
      error_file: '/var/log/reactpress/error.log',
      out_file: '/var/log/reactpress/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
    },
  ],
};
```

创建日志目录：

```bash
sudo mkdir -p /var/log/reactpress
sudo chown -R $USER:$USER /var/log/reactpress
```

### 4.8 配置 CORS

修改后端代码以允许前端域名访问。

编辑 `server/src/main.ts`，找到 `app.enableCors` 配置：

```typescript
// 确保配置包含你的 Vercel 域名
app.enableCors({
  origin: [
    'https://blog.myblog.com',     // Vercel 前端域名
    'https://www.myblog.com',     // 可选：www 域名
    'http://localhost:3001',       // 本地开发
  ],
  credentials: true,
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
  allowedHeaders: 'Content-Type, Accept, Authorization',
});
```

修改后需要重新构建：

```bash
cd /var/www/reactpress
pnpm run build:server
pm2 restart reactpress-server
```

### 4.9 启动后端服务

```bash
cd /var/www/reactpress
pm2 start ecosystem.config.js
pm2 save
pm2 startup  # 按提示执行命令，设置开机自启
```

### 4.10 配置 Nginx

#### 安装 Nginx

```bash
sudo apt install nginx
```

#### 配置后端 API 域名

创建配置文件：

```bash
sudo nano /etc/nginx/sites-available/api.myblog.com
```

添加配置：

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name api.myblog.com;

    # 日志配置
    access_log /var/log/nginx/api.myblog.com.access.log;
    error_log /var/log/nginx/api.myblog.com.error.log;

    # 请求体大小限制
    client_max_body_size 10M;

    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 健康检查端点
    location /health {
        proxy_pass http://localhost:3002;
        access_log off;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/api.myblog.com /etc/nginx/sites-enabled/
sudo nginx -t  # 测试配置
sudo systemctl reload nginx
```

---

## 5. DNS 配置

### 5.1 域名服务商配置

登录你的域名服务商（阿里云、腾讯云、Cloudflare 等），添加以下 DNS 记录：

#### 完整配置示例

| 主机记录 | 类型 | 记录值 | TTL | 说明 |
|---------|------|--------|-----|------|
| `blog` | CNAME | `cname.vercel-dns.com` | 600 | 前端 Vercel |
| `www` | CNAME | `cname.vercel-dns.com` | 600 | 前端（可选）|
| `api` | A | `123.45.67.89` | 600 | 后端服务器 IP |
| `@` | A | `123.45.67.89` | 600 | 根域名（可选）|

### 5.2 各平台配置示例

#### 阿里云

1. 登录 [阿里云控制台](https://dc.console.aliyun.com)
2. 选择 **域名** → **解析设置**
3. 点击 **添加记录**

```
记录类型: CNAME
主机记录: blog
记录值: cname.vercel-dns.com
```

```
记录类型: A
主机记录: api
记录值: 你的服务器IP
```

#### 腾讯云（DNSPod）

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/cns)
2. 选择域名 → **DNS 解析**
3. 点击 **新增记录**

```
主机记录: blog
记录类型: CNAME
线路类型: 默认
记录值: cname.vercel-dns.com
```

#### Cloudflare

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 选择域名 → **DNS** → **Records**
3. 点击 **Add record**

```
Type: CNAME
Name: blog
Target: cname.vercel-dns.com
Proxy status: Proxied (橙色云朵)
```

```
Type: A
Name: api
IPv4 address: 你的服务器IP
Proxy status: DNS only (灰色云朵)
```

### 5.3 验证 DNS 配置

#### 使用在线工具

- [https://dnschecker.org](https://dnschecker.org)
- 输入域名，选择不同地区的 DNS 服务器查询

#### 使用命令行

```bash
# Linux/Mac
dig blog.myblog.com
dig api.myblog.com

# Windows
nslookup blog.myblog.com
nslookup api.myblog.com

# 查看详细解析过程
dig blog.myblog.com +trace
```

#### 正确的返回结果

```bash
$ dig blog.myblog.com

; ANSWER SECTION:
blog.myblog.com.  300  IN  CNAME  cname.vercel-dns.com.
cname.vercel-dns.com. 300 IN  A  76.76.21.21

$ dig api.myblog.com

; ANSWER SECTION:
api.myblog.com.  300  IN  A  123.45.67.89
```

---

## 6. HTTPS 配置

### 6.1 Vercel 前端 HTTPS（自动配置）

Vercel 会**自动为所有域名配置 SSL 证书**：

- 自动申请 Let's Encrypt 证书
- 自动续期
- 支持 HTTP/2

无需任何手动操作，配置好 DNS 后等待几分钟即可。

### 6.2 后端 HTTPS 配置

#### 使用 Certbot 获取免费 SSL 证书

##### 安装 Certbot

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

##### 获取证书

```bash
sudo certbot --nginx -d api.myblog.com
```

按提示操作：
1. 输入邮箱地址（用于证书到期提醒）
2. 同意服务条款
3. 选择是否分享邮箱
4. Certbot 会自动配置 Nginx

##### 证书自动续期

Certbot 会自动创建续期定时任务，验证：

```bash
sudo certbot renew --dry-run
```

#### Nginx 配置示例

Certbot 会自动更新 Nginx 配置：

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name api.myblog.com;

    # SSL 证书配置（Certbot 自动添加）
    ssl_certificate /etc/letsencrypt/live/api.myblog.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.myblog.com/privkey.pem;

    # SSL 优化配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 其他配置...
    location / {
        proxy_pass http://localhost:3002;
        # ... 其他代理配置
    }
}

# HTTP 自动跳转 HTTPS（Certbot 自动添加）
server {
    listen 80;
    listen [::]:80;
    server_name api.myblog.com;
    return 301 https://$server_name$request_uri;
}
```

### 6.3 强制 HTTPS（推荐）

#### 前端 Vercel

在 Vercel 项目设置中：
1. **Settings** → **Domains**
2. 找到你的域名
3. 确保 **"Force HTTPS"** 选项已开启

#### 后端 Nginx

确保 HTTP 请求重定向到 HTTPS：

```nginx
server {
    listen 80;
    server_name api.myblog.com;
    return 301 https://$server_name$request_uri;
}
```

---

## 7. 项目配置修改

### 7.1 修改前端 API 地址

#### 方式 A：使用环境变量（推荐）

在 Vercel 项目设置中添加环境变量：

| Key | Value | Environment |
|-----|--------|-------------|
| `SERVER_API_URL` | `https://api.myblog.com` | Production |

#### 方式 B：修改配置文件

修改 `client/next.config.js`：

```javascript
const getServerApiUrl = () => {
  if (process.env.NODE_ENV === 'production') {
    return 'https://api.myblog.com/api';  // 生产环境
  }
  return 'http://localhost:3002/api';      // 开发环境
};
```

### 7.2 确保跨域配置正确

后端 CORS 配置必须包含前端域名：

```typescript
// server/src/main.ts
app.enableCors({
  origin: [
    'https://blog.myblog.com',     // Vercel 生产域名
    'https://www.myblog.com',     // 可选
    'http://localhost:3001',       // 本地开发
  ],
  credentials: true,
});
```

### 7.3 更新站点配置

#### 站点 URL 配置

后端 `.env` 文件：

```env
# 后端自己的 URL
SERVER_SITE_URL=https://api.myblog.com

# 前端 URL（用于生成链接、邮件等）
CLIENT_SITE_URL=https://blog.myblog.com
```

#### 社交媒体配置

如果需要生成 sitemap、RSS 等，确保使用正确的域名：

```typescript
// sitemap 配置示例
const siteUrl = 'https://blog.myblog.com';
```

---

## 8. 验证测试

### 8.1 前端测试

#### 基本访问测试

1. 访问 `https://blog.myblog.com`
2. 检查页面是否正常加载
3. 打开浏览器开发者工具（F12）

#### Network 检查

在开发者工具的 **Network** 选项卡：

1. 刷新页面
2. 查看 API 请求：
   ```
   ✅ https://api.myblog.com/api/articles
   ❌ http://localhost:3002/api/articles  (错误！)
   ```
3. 确保所有请求都指向 `api.myblog.com`

#### Console 检查

查看控制台是否有错误：
```
❌ Mixed Content: The page at 'https://blog.myblog.com' was loaded over HTTPS,
   but requested an insecure resource 'http://api.myblog.com/api/...'.
   This request has been blocked; the content must be served over HTTPS.

✅ No errors
```

### 8.2 后端测试

#### API 健康检查

```bash
# 检查后端是否响应
curl https://api.myblog.com/api/health

# 返回示例
{"status":"ok","timestamp":"2025-02-14T10:30:00.000Z"}
```

#### 跨域测试

```bash
# 测试 CORS 头
curl -I -H "Origin: https://blog.myblog.com" \
  https://api.myblog.com/api/articles

# 应该看到
Access-Control-Allow-Origin: https://blog.myblog.com
```

### 8.3 SSL 证书测试

#### 在线工具

- [https://www.ssllabs.com/ssltest/](https://www.ssllabs.com/ssltest/)
- 输入域名，查看证书评级（目标是 A 或 A+）

#### 命令行

```bash
# 检查证书信息
openssl s_client -connect api.myblog.com:443 -servername api.myblog.com

# 检查证书有效期
echo | openssl s_client -connect api.myblog.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### 8.4 性能测试

#### 前端性能

使用 [Google PageSpeed Insights](https://pagespeed.web.dev/)：
- 输入 `https://blog.myblog.com`
- 查看性能评分和优化建议

#### 后端性能

```bash
# 使用 ab 工具测试
sudo apt install apache2-utils

ab -n 1000 -c 10 https://api.myblog.com/api/articles
```

---

## 9. 常见问题

### 9.1 前端问题

#### Q1: 页面显示"Cannot connect to API"

**可能原因**：
- 环境变量配置错误
- CORS 配置不正确
- 后端服务未启动

**解决方案**：
1. 检查 Vercel 环境变量中的 `SERVER_API_URL`
2. 检查后端 CORS 配置是否包含前端域名
3. 确认后端服务运行正常：`pm2 status`

#### Q2: Mixed Content 错误

**错误信息**：
```
Mixed Content: The page at 'https://blog.myblog.com' was loaded over HTTPS,
but requested an insecure resource 'http://api.myblog.com/api/...'.
```

**解决方案**：
- 确保 `SERVER_API_URL` 使用 `https://` 而不是 `http://`
- 检查代码中是否有硬编码的 HTTP 链接

#### Q3: API 请求被 CORS 阻止

**错误信息**：
```
Access to fetch at 'https://api.myblog.com/api/articles' from origin
'https://blog.myblog.com' has been blocked by CORS policy
```

**解决方案**：
1. 检查后端 CORS 配置
2. 确认 `credentials: true` 设置正确
3. 确保前端域名在 `allowedOrigins` 列表中

### 9.2 后端问题

#### Q1: 后端服务频繁重启

**可能原因**：
- 内存不足触发 OOM
- PM2 `max_memory_restart` 设置过低

**解决方案**：
```bash
# 查看日志
pm2 logs reactpress-server

# 调整内存限制
max_memory_restart: '400M'  # 增加到 400MB

# 优化 MySQL 配置
innodb_buffer_pool_size=64M  # 降低缓冲池大小
```

#### Q2: 数据库连接失败

**错误信息**：
```
Error: connect ECONNREFUSED 127.0.0.1:3306
```

**解决方案**：
```bash
# 检查 MySQL 状态
sudo systemctl status mysql

# 检查 MySQL 连接
sudo mysql -u reactpress -p

# 检查防火墙
sudo ufw allow 3306
```

#### Q3: SSL 证书无效

**解决方案**：
```bash
# 重新获取证书
sudo certbot --nginx -d api.myblog.com --force-renewal

# 检查证书状态
sudo certbot certificates
```

### 9.3 DNS 问题

#### Q1: 域名无法解析

**解决方案**：
1. 等待 DNS 传播（最多 48 小时，通常几分钟）
2. 清除本地 DNS 缓存：
   ```bash
   # Linux
   sudo systemd-resolve --flush-caches

   # Mac
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

   # Windows
   ipconfig /flushdns
   ```
3. 使用其他 DNS 服务器测试（如 8.8.8.8）

#### Q2: Vercel 显示域名配置错误

**解决方案**：
1. 检查 DNS 记录值是否正确：`cname.vercel-dns.com`
2. 确保没有重复的 CNAME 记录
3. 在 Vercel 删除域名后重新添加

---

## 10. 维护和监控

### 10.1 日志管理

#### PM2 日志

```bash
# 实时查看日志
pm2 logs reactpress-server

# 查看最近 100 行
pm2 logs reactpress-server --lines 100

# 清空日志
pm2 flush
```

#### Nginx 日志

```bash
# 访问日志
sudo tail -f /var/log/nginx/api.myblog.com.access.log

# 错误日志
sudo tail -f /var/log/nginx/api.myblog.com.error.log
```

#### 应用日志

```bash
# ReactPress 日志
tail -f /var/log/reactpress/out.log
tail -f /var/log/reactpress/error.log
```

### 10.2 性能监控

#### 系统资源监控

```bash
# 安装 htop
sudo apt install htop

# 实时监控
htop
```

#### PM2 监控

```bash
# 启动 PM2 监控界面
pm2 monit
```

#### 磁盘使用监控

```bash
# 检查磁盘使用
df -h

# 检查目录大小
du -sh /var/log/
```

### 10.3 自动化维护

#### 配置日志轮转

创建 `/etc/logrotate.d/reactpress`：

```
/var/log/reactpress/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        pm2 reload reactpress-server
    endscript
}
```

#### 数据库备份

创建备份脚本 `/var/www/reactpress/scripts/backup.sh`：

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/reactpress"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
mysqldump -u reactpress -p'password' reactpress | \
  gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 保留最近 7 天的备份
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete

echo "Backup completed: db_$DATE.sql.gz"
```

添加到定时任务：

```bash
# 编辑 crontab
crontab -e

# 每天凌晨 3 点执行备份
0 3 * * * /var/www/reactpress/scripts/backup.sh
```

#### 自动更新 PM2

```bash
# 设置自动拉取最新代码
pm2 install pm2-auto-update
pm2 set pm2-auto-update:notify true
```

### 10.4 监控告警（可选）

推荐使用免费监控服务：

- **UptimeRobot** - [https://uptimerobot.com](https://uptimerobot.com)
  - 免费监控 50 个网站
  - 5 分钟检测间隔
  - 邮件/短信告警

- **StatusCake** - [https://www.statuscake.com](https://www.statuscake.com)
  - 免费监控
  - 性能监控
  - SSL 证书监控

配置示例（UptimeRobot）：
```
Monitor Type: HTTPS
URL: https://api.myblog.com/health
Check Interval: 5 minutes
Alert: Email + SMS
```

### 10.5 更新部署

#### 更新后端

```bash
cd /var/www/reactpress
git pull origin master  # 或你的分支名
pnpm install
pnpm run build:server
pm2 restart reactpress-server
```

#### 更新前端（推送到 GitHub 后）

- Vercel 会**自动检测到代码更新**
- 自动触发新的部署
- 几分钟后即可上线

#### 零停机部署

```bash
# 使用 PM2 集群模式（2 核心可用 2 个实例）
pm2 scale reactpress-server 2

# 重载（不中断服务）
pm2 reload reactpress-server
```

---

## 附录 A：检查清单

### 部署前检查

- [ ] GitHub 仓库已 Fork
- [ ] 服务器已购买并配置
- [ ] 域名已购买并指向正确的 DNS
- [ ] MySQL 已安装并创建数据库
- [ ] Node.js 和 pnpm 已安装
- [ ] PM2 已安装

### 部署中检查

- [ ] Vercel 项目已创建并配置环境变量
- [ ] Vercel 域名已添加并配置 DNS
- [ ] 后端代码已部署到服务器
- [ ] 后端 .env 文件已配置
- [ ] PM2 配置已优化（内存限制）
- [ ] Nginx 已配置并测试
- [ ] 后端 CORS 配置包含前端域名
- [ ] SSL 证书已配置

### 部署后检查

- [ ] 前端 `https://blog.myblog.com` 可访问
- [ ] 后端 `https://api.myblog.com` 可访问
- [ ] API 请求正常（无 CORS 错误）
- [ ] SSL 证书有效（无 Mixed Content 警告）
- [ ] 页面性能良好（PageSpeed > 80）
- [ ] 日志和监控已配置
- [ ] 备份计划已设置

---

## 附录 B：快速命令参考

### 服务器管理

```bash
# 查看 PM2 状态
pm2 status

# 重启后端
pm2 restart reactpress-server

# 查看日志
pm2 logs reactpress-server

# 重载 Nginx
sudo systemctl reload nginx

# 查看 MySQL 状态
sudo systemctl status mysql

# 检查磁盘使用
df -h

# 检查内存使用
free -h
```

### DNS 检查

```bash
# 检查 DNS 解析
dig blog.myblog.com
dig api.myblog.com

# 检查 SSL 证书
openssl s_client -connect api.myblog.com:443 -servername api.myblog.com
```

### Git 操作

```bash
# 拉取最新代码
git pull origin master

# 查看当前分支
git branch

# 查看远程仓库
git remote -v
```

---

## 总结

采用前后端分离部署方案，你将获得：

✅ **更低的服务器资源占用**
- 从 ~900MB 降到 ~750MB
- 2G 服务器运行更稳定

✅ **更好的访问体验**
- Vercel 全球 CDN 加速
- 自动 HTTPS 证书
- 更快的页面加载速度

✅ **更高的可靠性**
- 前端永不宕机
- 后端可独立维护和升级
- 灵活的扩展能力

✅ **零额外成本**
- Vercel 免费额度完全够用
- Let's Encrypt 免费证书
- 无需升级服务器配置

开始部署吧！祝你顺利！
