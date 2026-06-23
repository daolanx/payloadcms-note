# 企业宣传站点

基于 Next.js + Payload CMS + PostgreSQL 的企业宣传网站，支持 CMS 内容编辑和持久化存储，部署到阿里云 Serverless 全家桶。

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Next.js 16 (App Router, standalone output) |
| CMS | Payload CMS 3 |
| 数据库 | PostgreSQL (阿里云 RDS Serverless) |
| 媒体存储 | 阿里云 OSS (S3 兼容协议) |
| 样式 | Tailwind CSS 4 + shadcn/ui (base-ui) |
| 富文本 | Lexical Editor |
| 部署 | 阿里云函数计算 FC + CDN |

## 架构

```
                    ┌──────────────────────────────────────────┐
                    │          阿里云 Serverless                │
                    │                                          │
Internet ──────►   │  ┌─────────┐  CDN 加速                    │
                    │  │  CDN    │ ────────►                   │
                    │  └─────────┘                             │
                    │       │                                  │
                    │       ▼                                  │
                    │  ┌─────────┐  :3000                      │
                    │  │   FC    │ Next.js + Payload           │
                    │  │ (Serverless) │                        │
                    │  └────┬────┘                             │
                    │       │                                  │
                    │  ┌────┴────┐       ┌──────────┐         │
                    │  │ RDS PG  │       │   OSS    │         │
                    │  │(Serverless) │   │ (媒体文件) │         │
                    │  └─────────┘       └──────────┘         │
                    └──────────────────────────────────────────┘
```

**核心组件：**
- **FC (函数计算)** — 运行 Next.js 应用，按请求计费，空闲时零成本
- **RDS PostgreSQL (Serverless)** — 数据库，自动扩缩容，按 RCU 计费
- **OSS (对象存储)** — 存储上传的图片和媒体文件
- **CDN** — 加速静态资源和页面访问

## 项目结构

```
├── src/
│   ├── app/
│   │   ├── (frontend)/          # 前台页面（拥有独立 layout）
│   │   │   ├── layout.tsx       # html/body 标签、字体、全局样式
│   │   │   ├── page.tsx         # 首页（用户列表展示）
│   │   │   └── globals.css
│   │   ├── (payload)/           # Payload CMS 后台（自动生成）
│   │   │   └── admin/
│   │   ├── api/
│   │   │   ├── [...slug]/       # Payload REST API（自动生成）
│   │   │   └── health/          # 健康检查端点
│   │   └── layout.tsx           # 根 layout（仅返回 children，避免嵌套 HTML）
│   ├── components/ui/           # shadcn/ui 组件
│   ├── lib/utils.ts
│   └── payload.config.ts        # Payload CMS 配置（collections、adapter 等）
├── scripts/
├── .env.example                 # 环境变量模板
└── next.config.ts               # Next.js 配置（standalone output）
```

### 路由组说明（关键）

- `(frontend)/` — 前台页面，拥有自己的 `layout.tsx`（包含 `<html>` `<body>` 标签）
- `(payload)/admin/` — Payload 管理后台，其自动生成的 layout 使用 `RootLayout` 渲染独立的 HTML 文档
- 根 `layout.tsx` — 仅返回 `<>{children}</>`，避免两套 HTML 嵌套冲突

## CMS 数据模型

| Collection | 说明 | 字段 |
|------------|------|------|
| `users` | 用户（带认证） | name, gender, avatar, email + 密码 |
| `pages` | 页面内容 | title, slug, content(richText), status |
| `media` | 上传素材（OSS 存储） | alt, + Payload 自动管理的文件元数据 |

- `users` 和 `pages` 需登录后操作
- `media` 公开可读，需登录后上传/修改

## 本地开发

### 环境要求

- Node.js 22+
- pnpm 9+
- PostgreSQL（本地或远程）

### 启动

```bash
# 安装依赖
pnpm install

# 配置环境变量
cp .env.example .env.local
# 编辑 .env.local 填入本地 PostgreSQL 连接串等配置

# 启动开发服务器（端口 3000）
pnpm dev
```

访问：
- 前台：http://localhost:3000
- CMS 后台：http://localhost:3000/admin

首次访问后台时 Payload 会自动创建数据库表结构。

## 部署到阿里云

### 步骤一：准备阿里云服务

#### 1. 创建 RDS PostgreSQL Serverless

1. 阿里云控制台 → 云数据库 RDS → 创建实例
2. 选择 **PostgreSQL** → **Serverless** 版本
3. 配置：
   - RCU 范围：0.5 - 2（按需扩缩）
   - 存储：20GB 起步
   - 网络：选择 VPC（后续 FC 也要在同一 VPC）
4. 创建数据库 `payload`，设置账号密码
5. 记录连接地址：`rm-xxx.pg.rds.aliyuncs.com`

#### 2. 创建 OSS Bucket

1. 阿里云控制台 → 对象存储 OSS → 创建 Bucket
2. 选择同 Region（如 `oss-cn-hangzhou`）
3. 访问权限：私有（读写需要签名）
4. 创建 RAM 子账号，授予 `AliyunOSSFullAccess` 权限
5. 记录 AccessKey ID 和 Secret

#### 3. 创建函数计算 FC 服务

1. 阿里云控制台 → 函数计算 FC → 创建服务
2. 运行环境：Node.js 22
3. 网络配置：选择与 RDS 相同的 VPC
4. 域名配置：绑定自定义域名（可选，后续配置）

### 步骤二：配置环境变量

在 FC 控制台的环境变量中配置：

```bash
# Payload CMS
PAYLOAD_SECRET=<随机生成 32+ 位字符串>
NEXT_PUBLIC_SITE_URL=https://your-domain.com

# RDS PostgreSQL
DATABASE_URI=postgres://user:password@rm-xxx.pg.rds.aliyuncs.com:5432/payload

# OSS
OSS_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
OSS_BUCKET=your-media-bucket
OSS_ACCESS_KEY_ID=xxx
OSS_ACCESS_KEY_SECRET=xxx
```

> ⚠️ `PAYLOAD_SECRET` 一旦设定不要更换，否则已有的登录 session 全部失效。

### 步骤三：部署代码

#### 方式 A：FC 控制台上传 ZIP

```bash
# 本地构建
pnpm install
pnpm build

# 打包（排除 node_modules，FC 会自动安装）
zip -r payload-site.zip . -x "node_modules/*" ".git/*" "media/*" "data/*"

# 上传到 FC 控制台
```

#### 方式 B：Git 持续部署

1. FC 控制台 → 服务 → 基本信息 → 代码来源 → 选择 GitHub/Gitee
2. 配置仓库和分支
3. 构建命令：`pnpm install && pnpm build`
4. 启动命令：`node .next/standalone/server.js`

### 步骤四：配置 CDN 加速

1. 阿里云控制台 → CDN → 创建加速域名
2. 源站类型：选择 FC 服务域名
3. 缓存配置：
   - `/_next/static/*` → 缓存 30 天
   - `/media/*` → 缓存 7 天
   - 其他 → 不缓存（动态页面）

### 步骤五：配置 SSL（可选）

- CDN 控制台 → 域名管理 → HTTPS 设置
- 上传证书或使用免费证书

### 步骤六：验证

```bash
# 检查健康状态
curl https://your-domain.com/api/health
# 返回 {"status":"ok"} 即正常

# 访问管理后台
https://your-domain.com/admin

# 创建第一个管理员用户
```

## 成本估算

| 服务 | 计费方式 | 预估月费（低流量） |
|------|---------|------------------|
| FC 函数计算 | 按请求计费 | ¥0 - ¥5 |
| RDS PostgreSQL | 按 RCU 计费 | ¥10 - ¥50 |
| OSS 存储 | 按存储量 | ¥1 - ¥5 |
| CDN | 按流量 | ¥0 - ¥10 |
| **合计** | | **¥11 - ¥70/月** |

> 空闲时（无访问）接近零成本，有流量时按量计费。

## 常用命令

| 命令 | 说明 |
|------|------|
| `pnpm dev` | 本地开发服务器 |
| `pnpm build` | 生产构建 |
| `pnpm start` | 本地启动生产版本 |
| `pnpm lint` | 代码检查 |

## 数据持久化

| 存储位置 | 说明 | 持久化 |
|---------|------|--------|
| RDS PostgreSQL | 数据库内容（用户、页面等） | ✅ 阿里云自动备份 |
| OSS | 上传的媒体文件 | ✅ 阿里云 11 个 9 可靠性 |
| FC 本地磁盘 | 临时文件 | ❌ 函数销毁后清除 |

> FC 函数实例的本地磁盘是临时的，所有持久化数据必须存储在 RDS 或 OSS 中。
