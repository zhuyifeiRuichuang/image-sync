# Image Sync Project Memory

## 项目概述
- 名称: image-sync
- 仓库: https://github.com/zhuyifeiRuichuang/image-sync.git
- 功能: 基于 GitHub Actions + Issue 的容器镜像多架构同步工具
- 核心技术: skopeo (多架构镜像复制)

## 关键文件
- `.github/workflows/sync-image.yml` - 主工作流
- `.github/ISSUE_TEMPLATE/sync-image.yml` - Issue 模板
- `scripts/sync-image.sh` - 镜像同步脚本 (9个参数)
- `.github/registry-config-example` - 配置示例

## 核心命名规则 (重要!)
- 腾讯云/华为云/阿里云：扁平命名空间，只取镜像名最后一段
  - nginxinc/nginx:latest → ruichuangdev/nginx:latest (NOT nginxinc/nginx)
- Docker Hub/Quay/GHCR/私有仓库：支持嵌套路径，保留完整路径
  - nginxinc/nginx:latest → username/nginxinc/nginx:latest

## 支持的仓库类型
dockerhub, ghcr, quay, tencent, huawei, aliyun, private
- 腾讯云/华为云/阿里云需配置 REGISTRY_NAMESPACE (必填)

## 部署注意事项
- 需在仓库 Settings → Secrets and variables → Actions 配置:
  - Variables: REGISTRY_TYPE, REGISTRY_URL, REGISTRY_NAMESPACE
  - Secrets: REGISTRY_USERNAME, REGISTRY_PASSWORD
- 需在仓库 Issues → Labels 预创建 `image-sync` 标签
- 需手动 git push（沙箱环境无 credential helper）
- 工作流需 actions/checkout@v4 步骤
