# Image Sync Project Memory

## 项目概述
- 名称: image-sync
- 仓库: https://github.com/zhuyifeiRuichuang/image-sync.git
- 功能: 基于 GitHub Actions + Issue 的容器镜像多架构同步工具
- 核心技术: skopeo v1.23.0 (从 lework/skopeo-binary 下载 binary)

## 关键文件
- `.github/workflows/sync-image.yml` - 主工作流 (仅 labeled 事件触发)
- `.github/ISSUE_TEMPLATE/sync-image.yml` - Issue 模板 (只有镜像完整地址字段)
- `scripts/sync-image.sh` - 镜像同步脚本 (8个参数，无 REGISTRY_TYPE)
- `.github/registry-config-example` - 配置示例

## 核心命名规则 (重要!)
- **所有平台统一使用扁平命名空间**，只取镜像名最后一段
- docker.io/apache/seatunnel:2.3.13 → ccr.ccs.tencentyun.com/ruichuangdev/seatunnel:2.3.13
- docker.io/nginxinc/nginx:latest → ccr.ccs.tencentyun.com/ruichuangdev/nginx:latest

## 配置项 (4项)
- Variables: REGISTRY_URL (docker login 地址), REGISTRY_NAMESPACE (命名空间)
- Secrets: REGISTRY_USERNAME, REGISTRY_PASSWORD
- 无 REGISTRY_TYPE，无 GHCR_NAMESPACE

## 部署注意事项
- 需在仓库 Settings → Secrets and variables → Actions 配置4项
- 需在仓库 Issues → Labels 预创建 `image-sync` 标签
- 需手动 git push（沙箱环境无 credential helper）
- 工作流需 actions/checkout@v4 步骤
- skopeo 需下载 binary (apt 版太旧不支持 --retry-times 等)
- 需创建 v2 格式 registries.conf 覆盖 ubuntu runner 默认的 v1 格式

## Issue 触发机制
- 仅通过 `labeled` 事件触发 (避免 opened+labeled 重复运行)
- concurrency group 按 issue number 去重
- 增加 Issue 状态检查：只有 open 状态的 Issue 才触发同步 (`github.event.issue.state == 'open')
