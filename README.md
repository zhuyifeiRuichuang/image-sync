# 🔄 Image Sync - 容器镜像同步工具

基于 GitHub Actions + Issue 的容器镜像自动同步工具。用户通过提交 Issue 指定要同步的镜像，Action 自动将镜像的 amd64 和 arm64 架构同步到已配置的目标仓库。

## ✨ 功能特性

- 📝 **Issue 驱动**：通过提交 Issue 触发镜像同步，操作简单直观
- 🏗️ **多架构支持**：自动同步 amd64 (x86_64) 和 arm64 (aarch64) 架构
- 🔒 **安全认证**：用户名/密码通过 GitHub Secrets 存储，日志自动屏蔽为 `***`
- 📊 **自动反馈**：在 Issue 中自动评论同步结果，包含原镜像和目标镜像信息
- 🌐 **多云支持**：支持 Docker Hub、GHCR、Quay、腾讯云、华为云、阿里云及私有仓库
- ⚡ **失败检测**：未配置仓库时自动反馈，源镜像不存在时自动报错
- 🎯 **配置简单**：只需配置仓库地址、命名空间和密码，无需选择仓库类型

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

## 🚀 首次使用配置

首次使用需要完成以下 4 步配置，**按顺序执行**：

### 第 1 步：Fork 仓库

将此仓库 Fork 到你的 GitHub 账户下，或作为模板创建新仓库。

### 第 2 步：创建 `image-sync` 标签 ⚠️ 必须手动创建

> **这一步不能跳过！** 如果没有预先创建标签，Issue 模板无法自动添加标签，Action 不会被触发。

1. 进入你的仓库，点击 **Issues** 标签页
2. 点击 **New Issue**，在右侧点击 **Labels** 旁边的新建按钮
3. 创建标签：
   - 名称：`image-sync`
   - 颜色：随意选择（建议 `#0075ca` 蓝色）
4. 保存标签

或者直接通过 URL 创建：
- 访问 `https://github.com/<你的用户名>/image-sync/labels`
- 点击 **New label**
- 填写名称 `image-sync`，选择颜色，点击 **Create label**

### 第 3 步：配置 Secrets 和 Variables

进入仓库 **Settings → Secrets and variables → Actions**，配置以下内容：

#### Variables（非敏感信息，可在日志中显示）

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `REGISTRY_URL` | 目标仓库地址（docker login 时使用的地址） | `ccr.ccs.tencentyun.com` |
| `REGISTRY_NAMESPACE` | 目标命名空间 | `ruichuangdev` |

#### Secrets（敏感信息，日志自动屏蔽为 `***`）

| Secret 名 | 说明 | 示例 |
|-----------|------|------|
| `REGISTRY_USERNAME` | 目标仓库用户名 | `your-username` |
| `REGISTRY_PASSWORD` | 目标仓库密码或 Token | `your-token` |

> ⚠️ **密码说明**：REGISTRY_PASSWORD 是 `docker login` 时输入的密码。各云平台的 AK/SK **不能**直接用于 docker login，需要使用固定密码或 Token。

#### 各平台仓库地址参考

| 平台 | REGISTRY_URL | REGISTRY_NAMESPACE | REGISTRY_PASSWORD |
|------|-------------|--------------------|-------------------|
| **腾讯云** | `ccr.ccs.tencentyun.com` | 你的命名空间（如 `ruichuangdev`） | TCR **固定密码**（⚠️ 不是临时登录密码，不是 API SecretKey） |
| **华为云** | `swr.cn-north-4.myhuaweicloud.com` | 你的组织名（如 `myorg`） | SWR **长期登录密码**（⚠️ 不是 AK/SK） |
| **阿里云** | `registry.cn-hangzhou.aliyuncs.com` | 你的命名空间（如 `mynamespace`） | ACR **固定密码**（⚠️ 不是主账号 AK/SK） |
| **Docker Hub** | `docker.io` | 你的 Docker Hub 用户名 | **Access Token**（Account Settings → Security → New Access Token） |
| **GHCR** | `ghcr.io` | GitHub 用户名或组织名 | **Fine-grained PAT**（需 Packages: Read and write 权限） |
| **Quay** | `quay.io` | Quay 组织名 | **Robot Account Token**（Organization → Robot Accounts → Create） |
| **私有仓库** | 自定义域名（如 `registry.company.com`） | 项目名 | 仓库密码 |

#### 华为云各区域 REGISTRY_URL

| 区域 | REGISTRY_URL |
|------|-------------|
| 华北-北京四 | `swr.cn-north-4.myhuaweicloud.com` |
| 华北-北京一 | `swr.cn-north-1.myhuaweicloud.com` |
| 华东-上海二 | `swr.cn-east-2.myhuaweicloud.com` |
| 华南-广州 | `swr.cn-south-1.myhuaweicloud.com` |
| 东北-大连 | `swr.cn-northeast-1.myhuaweicloud.com` |

#### 阿里云各区域 REGISTRY_URL

| 区域 | REGISTRY_URL |
|------|-------------|
| 华东1-杭州 | `registry.cn-hangzhou.aliyuncs.com` |
| 华东2-上海 | `registry.cn-shanghai.aliyuncs.com` |
| 华北1-青岛 | `registry.cn-qingdao.aliyuncs.com` |
| 华北2-北京 | `registry.cn-beijing.aliyuncs.com` |
| 华南1-深圳 | `registry.cn-shenzhen.aliyuncs.com` |
| 华南3-广州 | `registry.cn-guangzhou.aliyuncs.com` |
| 中国香港 | `registry.cn-hongkong.aliyuncs.com` |
| 美国-弗吉尼亚 | `registry.us-east-1.aliyuncs.com` |

### 第 4 步：验证配置

建议先用一个小镜像测试配置是否正确：

1. 在本地终端验证 `docker login` 是否成功：
   ```bash
   docker login <REGISTRY_URL> -u <用户名>
   # 输入密码后应显示 "Login Succeeded"
   ```

2. 在仓库中提交一个测试 Issue：
   - 点击 **New Issue**
   - 选择 **🔄 容器镜像同步请求** 模板
   - 填写一个小镜像地址，如 `docker.io/library/alpine:latest`
   - 提交 Issue

3. 检查结果：
   - 进入 **Actions** 标签页，确认工作流已触发
   - 等待运行完成后，回到 Issue 查看自动评论
   - 如果显示 ✅ 同步成功，配置完成
   - 如果显示 ❌ 失败，参考下方 **常见问题排查**

## 📝 提交 Issue 同步镜像

配置完成后，随时通过提交 Issue 同步镜像：

1. 在仓库中点击 **New Issue**
2. 选择 **🔄 容器镜像同步请求** 模板
3. 填写完整的镜像地址（必须包含仓库地址）
4. 提交 Issue，Action 自动运行

#### Issue 填写示例

```
docker.io/apache/seatunnel:2.3.13
docker.io/library/mysql:8.4.10
docker.io/nginxinc/nginx:latest
quay.io/prometheus/node-exporter:latest
ghcr.io/owner/repo:tag
ccr.ccs.tencentyun.com/namespace/mysql:8.4.10
```

> ⚠️ 必须填写完整的镜像地址（包含仓库地址），不能只写 `apache/seatunnel:2.3.13`。

#### 同步结果

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

## 🔧 工作原理

```
用户提交 Issue (完整镜像地址 + image-sync 标签)
        │
        ▼
GitHub Actions 触发 (labeled 事件)
  ┌─ Issue 模板自动附加标签 → 触发
  └─ 手动添加 image-sync 标签 → 触发
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
登录目标仓库 ──── 失败 ──→ 评论反馈登录错误详情
        │
        ▼ 成功
检查源镜像 ──── 不存在 ──→ 评论反馈源镜像错误详情
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

> **触发机制说明**：Action 仅监听 `labeled` 事件，不监听 `opened`。当 Issue 模板自动附加 `image-sync` 标签时会触发 `labeled` 事件；手动添加该标签也会触发。这样避免了 `opened` + `labeled` 同时触发导致重复运行。

## ❓ 常见问题排查

### Issue 提交后 Action 未触发

**最常见原因：`image-sync` 标签未预先创建**

Issue 模板的 `labels` 字段要求标签**必须在仓库中已经存在**才能自动添加。如果标签不存在，模板创建的 Issue 没有标签，Action 不会触发。

**解决方法：**
1. 进入仓库 Issues → Labels 页面
2. 确认 `image-sync` 标签存在（如果不存在，手动创建）
3. 回到之前的 Issue，手动添加 `image-sync` 标签触发同步

**其他可能原因：**
- Secrets 或 Variables 未配置 → Action 的 `if` 条件不满足
- Workflow 文件语法错误 → 进入 Actions 页面查看是否有错误提示

### 登录目标仓库失败

**常见原因及解决方法：**

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `unauthorized: authentication required` | 密码错误或类型不对 | 确认密码是 docker login 密码，不是 AK/SK |
| 腾讯云登录失败 | 使用了临时密码而非固定密码 | TCR 控制台 → 访问凭证 → **设置固定密码** |
| 华为云登录失败 | 使用了 AK/SK | SWR 控制台 → **获取长期登录指令**，提取其中的密码 |
| 阿里云登录失败 | 使用了主账号 AK/SK | ACR 控制台 → **设置固定密码** |
| Docker Hub 登录失败 | 使用了账号密码而非 Token | hub.docker.com → Account Settings → Security → **New Access Token** |

**验证方法：** 在本地终端执行 `docker login <仓库地址> -u <用户名>`，确认能成功登录。

### 源镜像不存在

Issue 评论显示 `❌ 源镜像不存在或无法访问`：

- 确认镜像名称和 Tag 拼写正确
- 确认镜像地址格式完整（必须包含仓库地址，如 `docker.io/library/nginx:latest`）
- 在本地验证：`docker pull <完整镜像地址>`
- 如果源镜像为私有镜像，当前不支持同步

### 同步超时（30分钟）

大镜像跨国同步可能超过 30 分钟：

- 这是正常现象，不是卡死
- 在 Actions 日志中可以看到 `Copying blob ...` 的实时进度
- 如果频繁超时，考虑同步更小的镜像或使用更近的源仓库

### 同步日志中出现 `unknown` 架构？

这是**正常现象**，不是同步失败。

现代镜像（尤其是使用 Docker Buildx 构建的镜像）会在 manifest list 中附带 **attestation manifests**（构建证明书元数据）。这些元数据 manifest 的 platform 被标记为 `unknown/unknown`。

脚本已经会自动过滤这些 `unknown/unknown` 的 attestation manifests，只在日志和 Issue 评论中显示真正的架构（如 `amd64`、`arm64`、`arm`、`ppc64le` 等）。

**无需处理，多架构同步是完整的。**

### 密码是否会在日志中泄露？

不会。GitHub Actions 会自动将所有与已注册 Secrets 完全匹配的字符串在日志中替换为 `***`。脚本从不主动打印密码值。

## 📁 项目结构

```
image-sync/
├── .github/
│   ├── workflows/
│   │   └── sync-image.yml          # GitHub Actions 工作流
│   ├── ISSUE_TEMPLATE/
│   │   └── sync-image.yml          # Issue 提交模板
│   └── registry-config-example     # 仓库配置参考
├── scripts/
│   └── sync-image.sh               # 镜像同步脚本
└── README.md                        # 说明文档
```

## ⚠️ 注意事项

1. **标签必须预创建**：首次使用前必须在仓库中创建 `image-sync` 标签，否则 Issue 模板无法自动添加标签，Action 不触发
2. **密码安全**：`REGISTRY_USERNAME` 和 `REGISTRY_PASSWORD` 必须配置为 **Secret**，切勿配置为 Variable
3. **命名空间必填**：`REGISTRY_NAMESPACE` 是必填项，对应目标仓库的命名空间/组织
4. **仓库地址必填**：`REGISTRY_URL` 是必填项，填写 `docker login` 时使用的地址
5. **密码类型**：各云平台 REGISTRY_PASSWORD 是 `docker login` 的密码，**不是** API 的 AK/SK
6. **架构限制**：如果源镜像不支持某个架构（如只有 amd64），该架构会跳过并在反馈中标注
7. **`unknown` 架构**：日志中的 `unknown/unknown` 是 Docker Buildx 的 attestation 元数据，会被自动过滤，不影响同步
8. **私有源镜像**：当前仅支持同步公有源镜像，私有源镜像需要额外配置源仓库认证
9. **镜像地址**：Issue 中必须填写完整的镜像地址（包含仓库地址），不能只写镜像路径

## 📜 License

MIT License
