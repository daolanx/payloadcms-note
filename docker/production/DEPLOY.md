# 部署文档

## 服务器要求

- 阿里云 ECS（推荐 2 核 4G）
- 已安装宝塔面板 + Docker 管理器
- 域名已解析到 ECS IP

## 一、首次配置（一次性）

### 1. 准备环境变量文件

将 `.env.local` 上传到服务器 `/www/wwwroot/notes/` 目录：

```
/www/wwwroot/notes/.env.local
```

可参考 `.env.example` 填写所有变量。

### 2. 配置 ACR 镜像仓库

1. 宝塔 → Docker 管理器 → 镜像仓库 → 添加仓库
2. 填写：
   - 仓库地址：`registry.cn-hangzhou.aliyuncs.com`（或你的 ACR 地址）
   - 用户名：ACR 用户名
   - 密码：ACR 密码

### 3. 创建容器

1. 宝塔 → Docker 管理器 → 镜像列表 → 搜索你的镜像
2. 点击「创建容器」
3. 配置：
   - 容器名称：`notes-app`
   - 端口映射：`127.0.0.1:3000:3000`
   - 环境变量：从 `.env.local` 读取（或在面板中手动添加）
   - 重启策略：始终重启
4. 启动容器

### 4. 配置网站和反向代理

1. 宝塔 → 网站 → 添加站点
   - 域名：填写你的域名
   - PHP 版本：选择「纯静态」
2. 点击站点名称 → 反向代理 → 添加反向代理
   - 代理名称：`notes-app`
   - 目标 URL：`http://127.0.0.1:3000`

### 5. 配置 SSL 证书

1. 点击站点名称 → SSL
2. 选择「Let's Encrypt」→ 勾选域名 → 申请
3. 证书自动续期，无需再管

### 6. Nginx 额外配置

点击站点名称 → 配置 → 在 `location /` 块中添加：

```nginx
proxy_set_header Origin "https://$host";
```

这是 Payload CMS CSRF 防护所需的。

### 7. 验证

- 访问 `https://你的域名`，确认页面正常
- 访问 `https://你的域名/admin`，确认 CMS 后台可登录
- 测试上传图片，确认 OSS 链路正常

## 二、日常更新

开发者推送新版本后：

1. 宝塔 → Docker 管理器 → 镜像列表
2. 找到对应镜像 → 点击「拉取更新」
3. 容器列表 → 找到 `notes-app` → 点击「重启」

完成。

## 三、故障排查

```bash
# 查看容器日志
docker logs notes-app

# 查看容器状态
docker ps -a

# 进入容器调试
docker exec -it notes-app sh

# 重启容器
docker restart notes-app
```

## 四、文件说明

| 文件 | 用途 |
|------|------|
| `Dockerfile` | 构建镜像（CI 使用） |
| `compose.yaml` | 启动容器配置 |
| `.env.local` | 环境变量（不入 Git） |
| `.env.example` | 环境变量参考 |
| `DEPLOY.md` | 本文档 |
