# Image Sync Project Memory

## 项目概述
- 名称: image-sync
- 仓库: https://github.com/zhuyifeiRuichuang/image-sync.git
- 功能: 基于 GitHub Actions + Issue 的容器镜像多架构同步工具
- 核心技术: skopeo (多架构镜像复制)

## 关键文件
- `.github/workflows/sync-image.yml` - 主工作流
- `.github/ISSUE_TEMPLATE/sync-image.yml` - Issue 模板
- `scripts/sync-image.sh` - 镜像同步脚本
- `.github/registry-config-example` - 配置示例

## 支持的仓库类型
dockerhub, ghcr, quay, tencent, huawei, aliyun, private
- 腾讯云/华为云/阿里云需配置 REGISTRY_NAMESPACE (必填)
- 密码通过 GitHub Secrets 保护，仓库地址通过 Variables 存储(非保密)

## 部署注意事项
- 需在 GitHub 仓库 Settings → Secrets and variables → Actions 中配置:
  - Variables: REGISTRY_TYPE, REGISTRY_URL, REGISTRY_NAMESPACE
  - Secrets: REGISTRY_USERNAME, REGISTRY_PASSWORD
- git push 因网络问题失败，需手动推送
