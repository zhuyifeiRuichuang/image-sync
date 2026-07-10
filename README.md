# 🔄 Image Sync - 容器镜像同步工具

基于 GitHub Actions + Issue 的容器镜像自动同步工具。用户通过提交 Issue 指定要同步的镜像，Action 自动将镜像的 amd64 和 arm64 架构同步到已配置的目标仓库。

## ✨ 功能特性

- 📝 **Issue 驱动**：通过提交 Issue 触发镜像同步，操作简单直观
- 🏗️ **多架构支持**：自动同步 amd64 (x86_64) 和 arm64 (aarch64) 架构
- 🔒 **安全认证**：用户名/密码通过 GitHub Secrets 存储，日志自动屏蔽
- 📊 **自动反馈**：在 Issue 中自动评论同步结果，包含原镜像和目标镜像信息
- 🌐 **多云支持**：支持 Docker Hub、GHCR、Quay、腾讯云、华为云、阿里云及私有仓库
- ⚡ **失败检测**：未配置仓库时自动反馈，源镜像不存在时自动报错
- 🎯 **配置简单**：只需配置仓库地址和命名空间，无需选择仓库类型

## 🏠 同步后镜像命名规则

统一使用扁平命名空间，只取镜像名的最后一段：

命名规则：`{仓库地址}/{命名空间}/{镜像名最后一段}:{Tag}`

| 原始镜像 | 同步后镜像 |
|---------|-----------|
| `docker.io/apache/seatunnel:2.3.13` | `ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13` |
| `docker.io/library/mysql:8.4.10` | `ccr.ccs.tencentyun.com/ruichuangdev/mysql:8.4.10` |
| `docker.io/nginxinc/nginx:latest` | `ccr.ccs.tencentyun.com/ruichuangdev/nginx:latest` |
| `quay.io/prometheus/node-exporter:v1.8.0` | `ccr.ccs.tencentyun.com/ruichuangdev/node-exporter:v1.8.0` |

> 所有目标仓库均使用扁平命名空间（只取镜像名最后一段），无论 Docker Hub、腾讯云、华为云还是阿里云。

## 🚀 快速开始

### 1. Fork 或使用此仓库

将此仓库 Fork 到你的 GitHub 账户下，或作为模板创建新仓库。

### 2. 配置目标仓库

进入仓库 **Settings → Secrets and variables → Actions**，配置以下内容：

#### Variables（非敏感信息）

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `REGISTRY_URL` | 目标仓库地址（docker login 时使用的地址） | `ccr.ccs.tencentyun.com` |
| `REGISTRY_NAMESPACE` | 目标命名空间 | `ruichuangdev` |

#### Secrets（敏感信息，日志自动屏蔽）

| Secret 名 | 说明 | 示例 |
|-----------|------|------|
| `REGISTRY_USERNAME` | 目标仓库用户名 | `your-username` |
| `REGISTRY_PASSWORD` | 目标仓库密码或 Token | `your-token` |

#### 各平台仓库地址参考

| 平台 | 仓库地址示例 |
|------|-------------|
| 腾讯云 | `ccr.ccs.tencentyun.com` |
| 华为云（华北-北京四） | `swr.cn-north-4.myhuaweicloud.com` |
| 阿里云（华东1-杭州） | `registry.cn-hangzhou.aliyuncs.com` |
| Docker Hub | `docker.io` |
| GHCR | `ghcr.io` |
| Quay | `quay.io` |
| 私有仓库 | 自定义地址 |

### 3. 提交 Issue 同步镜像

1. 在仓库中点击 **New Issue**
2. 选择 **🔄 容器镜像同步请求** 模板
3. 填写完整的镜像地址（必须包含仓库地址，如 `docker.io/apache/seatunnel:2.3.13`）
4. 提交 Issue，Action 自动运行

#### Issue 填写示例

```
docker.io/apache/seatunnel:2.3.13
docker.io/library/mysql:8.4.10
docker.io/nginxinc/nginx:latest
quay.io/prometheus/node-exporter:latest
ghcr.io/owner/repo:tag
```

> ⚠️ 必须填写完整的镜像地址（包含仓库地址），不能只写 `apache/seatunnel:2.3.13`。

### 4. 查看同步结果

Action 运行完成后会自动在 Issue 中评论结果：

**成功示例：**
```
## ✅ 容器镜像同步成功

| 项目 | 值 |
|------|----|
| 原始镜像 | docker.io/apache/seatunnel:2.3.13 |
| 同步后镜像 | ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13 |

### 已同步架构
✅ amd64 (x86_64)
✅ arm64 (aarch64)

docker pull ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13
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
用户提交 Issue (完整镜像地址)
        │
        ▼
GitHub Actions 触发 (labeled 事件)
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
2. **命名空间**：`REGISTRY_NAMESPACE` 必填，对应目标仓库的命名空间/组织
3. **仓库地址**：`REGISTRY_URL` 必填，填写 `docker login` 时使用的地址
4. **架构限制**：如果源镜像不支持某个架构（如只有 amd64），该架构会跳过并在反馈中标注
5. **私有源镜像**：当前仅支持同步公有源镜像，私有源镜像需要额外配置源仓库认证
6. **镜像地址**：Issue 中必须填写完整的镜像地址（包含仓库地址），不能只写镜像路径

## 🌍 华为云/阿里云各区域仓库地址

### 华为云 SWR 区域地址

| 区域 | 仓库地址 |
|------|----------|
| 华北-北京四 | `swr.cn-north-4.myhuaweicloud.com` |
| 华北-北京一 | `swr.cn-north-1.myhuaweicloud.com` |
| 华东-上海二 | `swr.cn-east-2.myhuaweicloud.com` |
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
| 中国香港 | `registry.cn-hongkong.aliyuncs.com` |
| 美国-弗吉尼亚 | `registry.us-east-1.aliyuncs.com` |

## 📜 License

MIT License
