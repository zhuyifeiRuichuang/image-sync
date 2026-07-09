# 🔄 Image Sync - 容器镜像同步工具

基于 GitHub Actions + Issue 的容器镜像自动同步工具。用户通过提交 Issue 指定要同步的镜像，Action 自动将镜像的 amd64 和 arm64 架构同步到已配置的目标仓库。

## ✨ 功能特性

- 📝 **Issue 驱动**：通过提交 Issue 触发镜像同步，操作简单直观
- 🏗️ **多架构支持**：自动同步 amd64 (x86_64) 和 arm64 (aarch64) 架构
- 🔒 **安全认证**：用户名/密码通过 GitHub Secrets 存储，日志自动屏蔽
- 📊 **自动反馈**：在 Issue 中自动评论同步结果，包含原镜像和目标镜像信息
- 🌐 **多云支持**：支持 Docker Hub、GHCR、Quay、腾讯云、华为云、阿里云及私有仓库
- ⚡ **失败检测**：未配置仓库时自动反馈，源镜像不存在时自动报错

## 🏠 支持的目标仓库

| 仓库类型 | 仓库地址 | 命名空间要求 | 说明 |
|----------|----------|-------------|------|
| `dockerhub` | `docker.io` | 可选（默认为用户名） | Docker Hub 官方仓库 |
| `ghcr` | `ghcr.io` | 可选（默认为 GitHub 用户名） | GitHub Container Registry |
| `quay` | `quay.io` | 可选 | Red Hat Quay 仓库 |
| `tencent` | `ccr.ccs.tencentyun.com` | **必填** | 腾讯云容器镜像服务 |
| `huawei` | `swr.cn-north-4.myhuaweicloud.com` | **必填** | 华为云 SWR（可指定区域） |
| `aliyun` | `registry.cn-hangzhou.aliyuncs.com` | **必填** | 阿里云 ACR（可指定区域） |
| `private` | 用户自定义 | 可选 | 私有镜像仓库 |

### 同步后镜像命名规则

以腾讯云为例：

| 原始镜像 | 同步后镜像 |
|---------|-----------|
| `mysql:8.4.10` | `ccr.ccs.tencentyun.com/ruichuangdev/mysql:8.4.10` |
| `nginxinc/nginx:latest` | `ccr.ccs.tencentyun.com/ruichuangdev/nginxinc/nginx:latest` |
| `quay.io/prometheus/node-exporter:v1.8.0` | `ccr.ccs.tencentyun.com/ruichuangdev/prometheus/node-exporter:v1.8.0` |

命名规则：`{仓库地址}/{命名空间}/{原镜像路径}:{Tag}`

## 🚀 快速开始

### 1. Fork 或使用此仓库

将此仓库 Fork 到你的 GitHub 账户下，或作为模板创建新仓库。

### 2. 配置目标仓库

进入仓库 **Settings → Secrets and variables → Actions**，配置以下内容：

#### Variables（非敏感信息）

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `REGISTRY_TYPE` | 目标仓库类型 | `tencent` |
| `REGISTRY_URL` | 目标仓库地址（部分类型有默认值） | `ccr.ccs.tencentyun.com` |
| `REGISTRY_NAMESPACE` | 目标命名空间（腾讯/华为/阿里云必填） | `ruichuangdev` |
| `GHCR_NAMESPACE` | GHCR 专用命名空间（可选） | `your-github-org` |

#### Secrets（敏感信息，日志自动屏蔽）

| Secret 名 | 说明 | 示例 |
|-----------|------|------|
| `REGISTRY_USERNAME` | 目标仓库用户名 | `your-username` |
| `REGISTRY_PASSWORD` | 目标仓库密码或 Token | `your-token` |

#### 各平台密码/Token 获取方式

- **Docker Hub**：Account Settings → Security → New Access Token
- **GHCR**：GitHub PAT (需 `write:packages` 权限)
- **Quay**：Account Settings → API Token → Generate Token
- **腾讯云**：容器镜像服务控制台 → 获取登录密码
- **华为云**：SWR 控制台 → 获取登录密码
- **阿里云**：ACR 控制台 → 获取登录密码

### 3. 提交 Issue 同步镜像

1. 在仓库中点击 **New Issue**
2. 选择 **🔄 容器镜像同步请求** 模板
3. 填写镜像名称和 Tag
4. 提交 Issue，Action 自动运行

#### Issue 填写示例

**同步 Docker Hub 官方镜像：**
- 镜像名称：`mysql`
- 镜像 Tag：`8.4.10`

**同步带命名空间的镜像：**
- 需像名称：`nginxinc/nginx-prometheus-exporter`
- 镜像 Tag：`1.4.0`

**同步非 Docker Hub 镜像：**
- 镜像名称：`quay.io/prometheus/node-exporter`
- 需像 Tag：`v1.8.0`
- 源仓库：选择 `quay.io` 或在镜像名称中填写完整地址

### 4. 查看同步结果

Action 运行完成后会自动在 Issue 中评论结果：

**成功示例：**
```
## ✅ 容器镜像同步成功

| 项目 | 值 |
|------|----|
| 原始镜像 | `mysql:8.4.10` |
| 同步后镜像 | `ccr.ccs.tencentyun.com/ruichuangdev/mysql:8.4.10` |

### 已同步架构
✅ amd64 (x86_64)
✅ arm64 (aarch64)

docker pull ccr.ccs.tencentyun.com/ruichuangdev/mysql:8.4.10
```

**未配置仓库示例：**
```
## ❌ 未配置目标容器镜像仓库

当前仓库未完整配置目标容器镜像仓库，无法同步镜像。

### 缺少的配置项
- `REGISTRY_TYPE`
- `REGISTRY_NAMESPACE`
```

## 📁 项目结构

```
image-sync/
├── .github/
│   ├── workflows/
│   │   └── sync-image.yml          # GitHub Actions 工作流
│   ├── ISSUE_TEMPLATE/
│   │   └── sync-image.yml          # Issue 提交模板
│   └── registry-config-example     # 仓库配置示例
├── scripts/
│   └── sync-image.sh               # 镜像同步脚本
└── README.md                        # 说明文档
```

## 🔧 工作原理

```
用户提交 Issue (镜像名+Tag)
        │
        ▼
GitHub Actions 触发
        │
        ▼
解析 Issue 内容
        │
        ▼
检查仓库配置 ──── 未配置 ──→ 评论反馈 + 关闭 Issue
        │
        ▼ 已配置
安装 skopeo 工具
        │
        ▼
登录目标仓库
        │
        ▼
检查源镜像 ──── 不存在 ──→ 评论反馈失败
        │
        ▼ 存在
同步 amd64 + arm64 架构
        │
        ▼
验证同步结果
        │
        ▼
评论反馈结果 + 关闭 Issue
```

## ⚠️ 注意事项

1. **密码安全**：`REGISTRY_USERNAME` 和 `REGISTRY_PASSWORD` 必须配置为 **Secret**，切勿配置为 Variable
2. **命名空间**：腾讯云、华为云、阿里云必须配置 `REGISTRY_NAMESPACE`
3. **仓库地址**：华为云和阿里云的仓库地址因区域不同而异，请根据实际情况配置
4. **架构限制**：如果源镜像不支持某个架构（如只有 amd64），该架构会跳过并在反馈中标注
5. **私有源镜像**：当前仅支持同步公有源镜像，私有源镜像需要额外配置源仓库认证
6. **GHCR 权限**：使用 GHCR 需要确保 Actions 有 `packages: write` 权限

## 🌍 华为云/阿里云各区域仓库地址

### 华为云 SWR 区域地址

| 区域 | 仓库地址 |
|------|----------|
| 华北-北京四 | `swr.cn-north-4.myhuaweicloud.com` |
| 华北-北京一 | `swr.cn-north-1.myhuaweicloud.com` |
|华东-上海二| `swr.cn-east-2.myhuaweicloud.com` |
| 华南-广州 | `swr.cn-south-1.myhuaweicloud.com` |
| 东北-大连 | `swr.cn-northeast-1.myhuaweicloud.com` |

### 阿里云 ACR 区域地址

| 区域 | 仓库地址 |
|------|----------|
| 华东1-杭州 | `registry.cn-hangzhou.aliyuncs.com` |
| 华东2-上海 | `registry.cn-shanghai.aliyuncs.com` |
| 华北1-青岛 | `registry.cn-qingdao.aliyuncs.com` |
| 华北2-北京 | `registry.cn-beijing.aliyuncs.com` |
| 华南1-深圳 | `registry.cn-shenzhen.aliyuncs.com` |
| 华南3-广州 | `registry.cn-guangzhou.aliyuncs.com` |
| 香港 | `registry.cn-hongkong.aliyuncs.com` |
| 美国-弗吉尼亚 | `registry.us-east-1.aliyuncs.com` |

## 📜 License

MIT License
