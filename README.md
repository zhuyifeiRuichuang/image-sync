# 🔄 Image Sync - 容器镜像同步工具

基于 GitHub Actions + Issue 的容器镜像自动同步工具。通过提交 Issue 指定要同步的镜像，Action 自动将镜像的所有架构同步到已配置的目标仓库，并在 Issue 中反馈同步结果。

## ✨ 功能特性

- 📝 **Issue 驱动** — 提交 Issue 即可触发同步，操作简单直观
- 🏗️ **多架构同步** — 自动同步镜像支持的所有架构（amd64、arm64、arm 等），使用 `skopeo copy --all`
- 🔒 **安全认证** — 用户名/密码通过 GitHub Secrets 存储，日志自动屏蔽为 `***`
- 📊 **自动反馈** — 同步完成后在 Issue 中评论结果，包含源镜像、目标镜像和已同步架构
- 🌐 **多云支持** — 支持 Docker Hub、GHCR、Quay、腾讯云、华为云、阿里云及私有仓库
- ⚡ **失败检测** — 未配置仓库、登录失败、源镜像不存在时均自动反馈具体原因
- 🎯 **配置简单** — 只需配置仓库地址、命名空间和登录密码，无需选择仓库类型

## 🏠 同步后镜像命名规则

统一使用**扁平命名空间**，只取镜像名的最后一段：

```
{仓库地址}/{命名空间}/{镜像名最后一段}:{Tag}
```

| 原始镜像 | 同步后镜像 |
|---------|-----------|
| `docker.io/apache/seatunnel:2.3.13` | `ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13` |
| `docker.io/library/mysql:8.4.10` | `ccr.ccs.tencentyun.com/ruichuangdev/mysql:8.4.10` |
| `docker.io/nginxinc/nginx:latest` | `ccr.ccs.tencentyun.com/ruichuangdev/nginx:latest` |
| `quay.io/prometheus/node-exporter:v1.8.0` | `ccr.ccs.tencentyun.com/ruichuangdev/node-exporter:v1.8.0` |

> 所有目标仓库均使用扁平命名空间（只取镜像名最后一段），无论 Docker Hub、腾讯云、华为云还是阿里云。

## ✅ 已验证的镜像平台

理论上支持所有标准容器镜像仓库，以下平台已实际验证可用：

| 平台 | REGISTRY_URL | 特点 |
|------|-------------|------|
| **Docker Hub** | `docker.io` | 上传速度快；下载需配置加速 |
| **Quay** | `quay.io` | 上传速度快；中国地区可直接访问 |
| **腾讯云 TCR** | 随区域变化（见下方） | 非中国地区上传快；可公开下载 |
| **华为云 SWR** | 随区域变化（见下方） | 中国地区速度优于腾讯云海外；个人版无法公开拉取 |
| **阿里云 ACR** | 随区域变化（见下方） | 上传速度较慢；可公开下载 |
| **私有仓库** | 自定义 | 需自行确保网络可达 |

> ⚠️ **腾讯云、华为云、阿里云的镜像仓库地址随所选区域变化，没有统一的标准地址。** 下文各平台章节中给出的地址仅为**示例**，并非真实可用地址。请登录各云平台控制台，从实际的访问凭证或登录指令中获取你所在区域的真实仓库地址。

---

## 🚀 首次使用配置

首次使用需要完成以下 **5 步**配置，请按顺序执行：

### 第 1 步：Fork 仓库

将此仓库 Fork 到你的 GitHub 账户下，或作为模板创建新仓库。

### 第 2 步：创建 `image-sync` 标签

> ⚠️ **这一步不能跳过！** 如果没有预先创建标签，Issue 模板无法自动添加标签，Action 不会被触发。

**方法一：通过 Labels 页面创建**

1. 进入你的仓库，点击 **Issues** 标签页
2. 点击右侧 **Labels** → **New label**
3. 填写：
   - 名称：`image-sync`
   - 颜色：建议 `#0075ca`（蓝色）
4. 点击 **Create label**

**方法二：直接访问 URL**

访问 `https://github.com/<你的用户名>/<仓库名>/labels`，点击 **New label**，填写名称 `image-sync`，保存。

### 第 3 步：获取云平台镜像仓库登录信息

根据你要使用的目标仓库，从对应云平台控制台获取以下 4 项信息：

| 配置项 | 说明 | 获取方式 |
|--------|------|---------|
| **REGISTRY_URL** | `docker login` 时使用的仓库地址 | 云平台控制台的访问凭证 / 登录指令 |
| **REGISTRY_NAMESPACE** | 命名空间或组织名 | 云平台控制台创建 |
| **REGISTRY_USERNAME** | 登录用户名 | 云平台控制台的访问凭证 |
| **REGISTRY_PASSWORD** | 登录密码或 Token | 云平台控制台生成 |

> ⚠️ **密码 ≠ AK/SK**：各云平台的 `REGISTRY_PASSWORD` 是 `docker login` 密码，**不是** API 的 Access Key / Secret Key。AK/SK 无法用于 docker login。

#### Docker Hub

1. 浏览器访问 [hub.docker.com](https://hub.docker.com/)，登录账号
2. 点击右上角头像 → **Account settings** → **Personal access tokens** → **Generate new token**
   - 权限选择：**Read & Write**
   - 有效期：建议选择永不过期
   - 生成后复制 Token，此即为 `REGISTRY_PASSWORD`
3. 访问 [hub.docker.com/repositories](https://hub.docker.com/repositories/)，确认你的用户名（即为 `REGISTRY_NAMESPACE`）
4. 访问 [hub.docker.com/repository-settings](https://hub.docker.com/repository-settings/default-privacy)，设置默认隐私为 **Public**（否则同步后的镜像无法公开拉取）

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | `docker.io` |
| REGISTRY_NAMESPACE | 你的 Docker Hub 用户名 |
| REGISTRY_USERNAME | 你的 Docker Hub 用户名 |
| REGISTRY_PASSWORD | Personal Access Token |

#### Quay

1. 浏览器访问 [quay.io](https://quay.io/)，登录账号
2. 选择旧版 UI，点击右上角头像 → **Account Settings** → **CLI Password**
3. 生成密码后复制，此即为 `REGISTRY_PASSWORD`

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | `quay.io` |
| REGISTRY_NAMESPACE | 你的 Quay 用户名 |
| REGISTRY_USERNAME | 你的 Quay 用户名 |
| REGISTRY_PASSWORD | CLI Password |

> ⚠️ 镜像上传后默认为私有，需在镜像仓库的 Settings 中将 **Repository Visibility** 设为 **Public** 才可公开拉取。

#### 腾讯云 TCR

1. 浏览器访问 [腾讯云 TCR 控制台](https://console.cloud.tencent.com/tcr/)
2. 选择区域，创建实例和命名空间
3. 进入 **实例管理** → **访问凭证**，获取：
   - 镜像仓库地址（`REGISTRY_URL`，随区域变化，下方仅为示例）
   - 登录用户名（`REGISTRY_USERNAME`）
   - 设置**固定密码**（`REGISTRY_PASSWORD`，⚠️ 不是临时登录密码，不是 API SecretKey）

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | 从控制台获取（示例：`ccr.ccs.tencentyun.com`） |
| REGISTRY_NAMESPACE | 你创建的命名空间 |
| REGISTRY_USERNAME | 从控制台获取 |
| REGISTRY_PASSWORD | **固定密码**（⚠️ 不是临时密码，不是 SecretKey） |

> ⚠️ **仓库地址随区域变化**，上方示例地址并非真实可用，请从控制台获取你所在区域的实际地址。
> ⚠️ 镜像上传后默认为私有，需在仓库信息中设置为**公开**才可公开拉取。
> 💡 建议选择非中国地区实例（如香港、新加坡），上传速度更快。

#### 华为云 SWR

1. 浏览器访问 [华为云 SWR 控制台](https://console.huaweicloud.com/swr/)
2. 创建组织（即为 `REGISTRY_NAMESPACE`）
3. 进入 **总览** → **登录指令**，获取：
   - 镜像仓库地址（`REGISTRY_URL`，随区域变化，下方仅为示例）
   - 登录用户名（`REGISTRY_USERNAME`）
   - 长期登录密码（`REGISTRY_PASSWORD`，⚠️ 不是 AK/SK）

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | 从登录指令获取（示例：`swr.cn-north-4.myhuaweicloud.com`） |
| REGISTRY_NAMESPACE | 你创建的组织名 |
| REGISTRY_USERNAME | 从登录指令获取 |
| REGISTRY_PASSWORD | **长期登录密码**（⚠️ 不是 AK/SK） |

> ⚠️ **仓库地址随区域变化**，上方示例地址并非真实可用，请从登录指令获取你所在区域的实际地址。
> ⚠️ 个人版 SWR 无法配置镜像公开拉取，只能登录华为云账户拉取，或共享给指定华为账户。

#### 阿里云 ACR

1. 浏览器访问 [阿里云 ACR 控制台](https://cr.console.aliyun.com/)
2. 创建个人版实例（无论选哪个区域，默认全球可用）
3. 创建命名空间（即为 `REGISTRY_NAMESPACE`），配置默认类型为**公开**
4. 进入 **访问凭证**，设置**固定密码**（即为 `REGISTRY_PASSWORD`）
5. 获取镜像仓库地址（`REGISTRY_URL`，随区域变化，下方仅为示例）

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | 从控制台获取（示例：`registry.cn-hangzhou.aliyuncs.com`） |
| REGISTRY_NAMESPACE | 你创建的命名空间 |
| REGISTRY_USERNAME | 从访问凭证获取 |
| REGISTRY_PASSWORD | **固定密码**（⚠️ 不是主账号 AK/SK） |

> ⚠️ **仓库地址随区域变化**，上方示例地址并非真实可用，请从访问凭证获取你所在区域的实际地址。
> 💡 个人版 ACR 上传速度较慢，企业版自带加速功能无需使用本工具。

#### 私有仓库

| 配置项 | 值 |
|--------|-----|
| REGISTRY_URL | 你的私有仓库地址（如 `registry.company.com`） |
| REGISTRY_NAMESPACE | 项目名 |
| REGISTRY_USERNAME | 仓库用户名 |
| REGISTRY_PASSWORD | 仓库密码 |

> 请确保私有仓库的网络可达性，GitHub Actions Runner 需能访问该仓库地址。

### 第 4 步：配置 GitHub Secrets 和 Variables

进入你 Fork 的仓库 → **Settings** → **Secrets and variables** → **Actions**，配置以下 4 项：

#### Variables（非敏感信息）

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `REGISTRY_URL` | 目标仓库地址（`docker login` 时使用的地址） | `ccr.ccs.tencentyun.com` |
| `REGISTRY_NAMESPACE` | 目标命名空间 | `ruichuangdev` |

#### Secrets（敏感信息，日志自动屏蔽为 `***`）

| Secret 名 | 说明 | 示例 |
|-----------|------|------|
| `REGISTRY_USERNAME` | 目标仓库用户名 | `your-username` |
| `REGISTRY_PASSWORD` | 目标仓库密码或 Token | `your-token` |

> ⚠️ **`REGISTRY_USERNAME` 和 `REGISTRY_PASSWORD` 必须配置为 Secret**，切勿配置为 Variable，否则密码会在日志中暴露。

### 第 5 步：验证配置

建议先用一个小镜像测试配置是否正确：

1. **本地验证登录**（可选但推荐）：
   ```bash
   docker login <你的REGISTRY_URL> -u <用户名>
   # 输入密码后应显示 "Login Succeeded"
   ```

2. **提交测试 Issue**：
   - 在仓库中点击 **New Issue**
   - 选择 **🔄 容器镜像同步请求** 模板
   - 填写小镜像地址：`docker.io/library/alpine:latest`
   - 提交 Issue

3. **检查结果**：
   - 进入 **Actions** 标签页，确认工作流已触发
   - 等待运行完成后，回到 Issue 查看自动评论
   - ✅ 显示同步成功 → 配置完成
   - ❌ 显示失败 → 参考下方 [常见问题排查](#-常见问题排查)

---

## 📝 提交 Issue 同步镜像

配置完成后，随时通过提交 Issue 同步镜像：

1. 在仓库中点击 **New Issue**
2. 选择 **🔄 容器镜像同步请求** 模板
3. 填写完整的镜像地址（必须包含仓库地址）
4. 提交 Issue，Action 自动运行

#### 填写示例

```
docker.io/apache/seatunnel:2.3.13
docker.io/library/mysql:8.4.10
docker.io/nginxinc/nginx:latest
quay.io/prometheus/node-exporter:v1.8.0
ghcr.io/owner/repo:tag
```

> ⚠️ 必须填写**完整的镜像地址**（包含仓库地址），不能只写 `apache/seatunnel:2.3.13`。

#### 同步结果

Action 运行完成后会自动在 Issue 中评论结果：

**成功示例：**

> ## ✅ 容器镜像同步成功
>
> | 项目 | 值 |
> |------|----|
> | 原始镜像 | `docker.io/apache/seatunnel:2.3.13` |
> | 同步后镜像 | `ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13` |
>
> ### 已同步架构
> ✅ amd64 (x86_64)
> ✅ arm64 (aarch64)

---

## 🔧 工作原理

```
用户提交 Issue（完整镜像地址 + image-sync 标签）
        │
        ▼
GitHub Actions 触发（labeled 事件）
  ┌─ Issue 模板自动附加标签 → 触发
  └─ 手动添加 image-sync 标签 → 触发
        │
        ▼
解析 Issue 内容 → 提取仓库地址、镜像名、Tag
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
同步所有架构（skopeo copy --all）
        │
        ▼
验证同步结果
        │
        ▼
评论反馈结果 + 关闭 Issue
```

> **触发机制**：Action 仅监听 `labeled` 事件，不监听 `opened`。Issue 模板自动附加 `image-sync` 标签时会触发 `labeled` 事件；手动添加该标签也会触发。这样避免了 `opened` + `labeled` 同时触发导致重复运行。

---

## ❓ 常见问题排查

### Action 未触发

**最常见原因：`image-sync` 标签未预先创建**

Issue 模板要求标签**必须在仓库中已经存在**才能自动添加。如果标签不存在，模板创建的 Issue 没有标签，Action 不会触发。

**解决方法：**

1. 进入仓库 **Issues** → **Labels** 页面
2. 确认 `image-sync` 标签存在（不存在则手动创建）
3. 回到之前的 Issue，手动添加 `image-sync` 标签触发同步

**其他可能原因：**
- Secrets 或 Variables 未配置 → Action 的 `if` 条件不满足
- Workflow 文件语法错误 → 进入 Actions 页面查看错误提示

### 登录目标仓库失败

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `unauthorized: authentication required` | 密码错误或类型不对 | 确认密码是 docker login 密码，不是 AK/SK |
| 腾讯云登录失败 | 使用了临时密码 | TCR 控制台 → 访问凭证 → **设置固定密码** |
| 华为云登录失败 | 使用了 AK/SK | SWR 控制台 → **获取长期登录指令**，提取密码 |
| 阿里云登录失败 | 使用了主账号 AK/SK | ACR 控制台 → 访问凭证 → **设置固定密码** |
| Docker Hub 登录失败 | 使用了账号密码 | Account Settings → Security → **New Access Token** |

**验证方法：** 在本地终端执行：

```bash
docker login <你的REGISTRY_URL> -u <用户名>
```

确认能成功登录后再配置到 GitHub Secrets。

### 源镜像不存在

Issue 评论显示 `❌ 源镜像不存在或无法访问`：

- 确认镜像名称和 Tag 拼写正确
- 确认镜像地址格式完整（必须包含仓库地址）
- 在本地验证：`docker pull <完整镜像地址>`
- 如果源镜像为私有镜像，当前不支持同步

### 同步超时（30 分钟）

大镜像跨国同步可能超过 30 分钟：

- 这是正常现象，不是卡死
- 在 Actions 日志中可以看到实时进度输出
- 如果频繁超时，考虑同步更小的镜像或使用更近的源仓库

### 同步日志中出现 `unknown` 架构

这是**正常现象**，不是同步失败。

现代镜像（使用 Docker Buildx 构建的）会在 manifest list 中附带 **attestation manifests**（构建证明书），其 platform 被标记为 `unknown/unknown`。脚本会自动过滤这些元数据，只在日志和 Issue 评论中显示真实架构。

**无需处理，多架构同步是完整的。**

### 密码是否会在日志中泄露？

不会。GitHub Actions 会自动将所有与已注册 Secrets 完全匹配的字符串在日志中替换为 `***`。脚本从不主动打印密码值。

---

## 📁 项目结构

```
image-sync/
├── .github/
│   ├── workflows/
│   │   └── sync-image.yml          # 主工作流（仅 labeled 事件触发）
│   ├── ISSUE_TEMPLATE/
│   │   └── sync-image.yml          # Issue 提交模板
│   └── registry-config-example     # 仓库配置参考
├── scripts/
│   └── sync-image.sh               # 镜像同步脚本
└── README.md                        # 说明文档
```

## ⚠️ 注意事项

1. **标签必须预创建** — 首次使用前必须在仓库中创建 `image-sync` 标签，否则 Issue 模板无法自动添加标签，Action 不触发
2. **密码必须用 Secret** — `REGISTRY_USERNAME` 和 `REGISTRY_PASSWORD` 必须配置为 Secret，切勿配置为 Variable
3. **仓库地址随区域变化** — 腾讯云、华为云、阿里云的仓库地址随所选区域变化，请从各自云平台控制台获取实际地址，文档中的地址仅为示例
4. **密码 ≠ AK/SK** — 各云平台的 `REGISTRY_PASSWORD` 是 `docker login` 密码，不是 API 的 Access Key / Secret Key
5. **镜像地址必须完整** — Issue 中必须填写包含仓库地址的完整镜像地址，不能只写镜像路径
6. **私有源镜像不支持** — 当前仅支持同步公有源镜像，私有源镜像需要额外配置源仓库认证
7. **架构自动同步** — `skopeo copy --all` 会同步源镜像支持的所有架构，不限于 amd64 和 arm64
8. **`unknown/unknown` 已过滤** — 日志中不再出现 Docker Buildx attestation manifests 的 `unknown/unknown` 架构

## 👨‍💻 开发者信息

本项目使用 [WorkBuddy](https://www.codebuddy.cn/) 搭配 **GLM-5.1** 和 **Kimi-K2.7** 模型，全流程 AI 开发完成——从项目架构设计、代码编写、问题调试到文档撰写，均由 AI 主导执行。

## 📜 License

MIT License
