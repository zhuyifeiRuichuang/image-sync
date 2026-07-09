#!/bin/bash
set -euo pipefail

# ===========================================
# 容器镜像同步脚本
# 支持多架构（amd64/arm64）镜像同步
# ===========================================

# --- 输入参数 ---
SOURCE_IMAGE_NAME="${1}"   # 镜像名称（如 mysql 或 nginxinc/nginx）
SOURCE_IMAGE_TAG="${2:-latest}"  # 镜像tag，默认latest
SOURCE_REGISTRY="${3:-docker.io}" # 源仓库地址
TARGET_REGISTRY="${4}"      # 目标仓库地址
TARGET_NAMESPACE="${5}"     # 目标命名空间
TARGET_USERNAME="${6}"      # 目标仓库用户名
TARGET_PASSWORD="${7}"      # 目标仓库密码/Token
ARCHITECTURES="${8:-amd64 arm64}" # 要同步的架构列表
REGISTRY_TYPE="${9:-dockerhub}"   # 目标仓库类型：dockerhub/ghcr/quay/tencent/huawei/aliyun/private

# --- 构造源镜像完整引用 ---
# 判断镜像名称是否已包含仓库地址
# 如果镜像名称包含 '/' 且第一部分包含 '.' 或 ':'，则视为完整引用
construct_source_ref() {
  local name="${SOURCE_IMAGE_NAME}"
  local tag="${SOURCE_IMAGE_TAG}"
  local registry="${SOURCE_REGISTRY}"

  # 检查镜像名是否已经包含完整的仓库地址
  local first_part
  first_part=$(echo "${name}" | cut -d'/' -f1)

  if echo "${first_part}" | grep -qE '\.|:|localhost'; then
    # 镜像名已包含仓库地址，直接使用
    echo "docker://${name}:${tag}"
  else
    # 需要拼接仓库地址
    if [ "${registry}" = "docker.io" ]; then
      # Docker Hub：官方镜像在 library/ 下，但 skopeo/docker pull 会自动处理
      echo "docker://${name}:${tag}"
    else
      echo "docker://${registry}/${name}:${tag}"
    fi
  fi
}

# --- 构造目标镜像完整引用 ---
# 规则：
#   腾讯云/华为云/阿里云：命名空间是扁平的，不支持嵌套路径
#     → 只取镜像名的最后一段（如 nginxinc/nginx → nginx）
#   Docker Hub/Quay/GHCR/私有仓库：命名空间支持嵌套路径
#     → 保留完整镜像路径（如 nginxinc/nginx → nginxinc/nginx）
construct_target_ref() {
  local name="${SOURCE_IMAGE_NAME}"
  local tag="${SOURCE_IMAGE_TAG}"
  local registry="${TARGET_REGISTRY}"
  local namespace="${TARGET_NAMESPACE}"
  local registry_type="${REGISTRY_TYPE}"

  # 先从镜像名中提取纯镜像路径（去掉可能嵌入的源仓库地址）
  local image_path="${name}"
  local first_part
  first_part=$(echo "${name}" | cut -d'/' -f1)

  if echo "${first_part}" | grep -qE '\.|:|localhost'; then
    # 镜像名已包含源仓库地址，去掉仓库部分
    image_path=$(echo "${name}" | cut -d'/' -f2-)
    if [ -z "${image_path}" ]; then
      image_path="${first_part}"
    fi
  fi

  # 根据目标仓库类型决定命名方式
  case "${registry_type}" in
    tencent|huawei|aliyun)
      # 扁平命名空间：只取最后一段
      # nginxinc/nginx → nginx
      # prometheus/node-exporter → node-exporter
      # mysql → mysql（无斜杠则直接用）
      local last_segment
      if echo "${image_path}" | grep -q '/'; then
        last_segment=$(echo "${image_path}" | rev | cut -d'/' -f1 | rev)
      else
        last_segment="${image_path}"
      fi
      echo "docker://${registry}/${namespace}/${last_segment}:${tag}"
      ;;
    dockerhub|ghcr|quay|private|*)
      # 支持嵌套路径：保留完整路径
      # nginxinc/nginx → nginxinc/nginx
      # mysql → mysql
      echo "docker://${registry}/${namespace}/${image_path}:${tag}"
      ;;
  esac
}

# --- 获取不含 docker:// 前缀的可读镜像名 ---
get_readable_source() {
  local ref
  ref=$(construct_source_ref)
  echo "${ref#docker://}"
}

get_readable_target() {
  local ref
  ref=$(construct_target_ref)
  echo "${ref#docker://}"
}

# --- 登录目标仓库 ---
login_target_registry() {
  echo "🔐 正在登录目标镜像仓库: ${TARGET_REGISTRY}"

  if echo "${TARGET_PASSWORD}" | skopeo login "${TARGET_REGISTRY}" \
    -u "${TARGET_USERNAME}" --password-stdin \
    --tls-verify=true 2>&1; then
    echo "✅ 登录成功"
  else
    echo "❌ 登录失败，请检查 REGISTRY_USERNAME 和 REGISTRY_PASSWORD 配置"
    return 1
  fi
}

# --- 检查源镜像是否存在及其架构信息 ---
inspect_source_image() {
  local source_ref
  source_ref=$(construct_source_ref)

  echo "🔍 正在检查源镜像: ${source_ref#docker://}"

  # 尝试 inspect 源镜像
  local inspect_output
  if ! inspect_output=$(skopeo inspect --raw "${source_ref}" 2>&1); then
    echo "❌ 源镜像不存在或无法访问: ${source_ref#docker://}"
    echo "ERROR_DETAIL: ${inspect_output}"
    return 1
  fi

  echo "✅ 源镜像存在"

  # 解析架构信息
  local available_archs=""
  # 检查是否是 manifest list (多架构)
  if echo "${inspect_output}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'manifests' in data:
    for m in data['manifests']:
        plat = m.get('platform', {})
        arch = plat.get('architecture', '')
        if arch:
            print(arch)
else:
    arch = data.get('architecture', '')
    if arch:
        print(arch)
" 2>/dev/null; then
    available_archs=$(echo "${inspect_output}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
archs = []
if 'manifests' in data:
    for m in data['manifests']:
        plat = m.get('platform', {})
        arch = plat.get('architecture', '')
        if arch:
            archs.append(arch)
else:
    arch = data.get('architecture', '')
    if arch:
        archs.append(arch)
print(' '.join(archs))
" 2>/dev/null)
  fi

  if [ -z "${available_archs}" ]; then
    available_archs="unknown"
  fi

  echo "📋 源镜像可用架构: ${available_archs}"
  echo "AVAILABLE_ARCHS=${available_archs}"
}

# --- 同步镜像（支持多架构） ---
sync_image() {
  local source_ref
  source_ref=$(construct_source_ref)
  local target_ref
  target_ref=$(construct_target_ref)

  echo "🔄 开始同步镜像"
  echo "   源: ${source_ref#docker://}"
  echo "   目标: ${target_ref#docker://}"
  echo "   架构: ${ARCHITECTURES}"

  local sync_success=true
  local synced_archs=""
  local failed_archs=""

  # 先尝试用 --all 同步整个 manifest list（多架构）
  echo ""
  echo "📦 尝试同步多架构 manifest list..."

  if skopeo copy --all \
    --retry-times 3 \
    --src-tls-verify=true \
    --dest-tls-verify=true \
    "${source_ref}" "${target_ref}" 2>&1; then
    echo "✅ 多架构 manifest list 同步成功"
    synced_archs="${ARCHITECTURES}"
  else
    echo "⚠️ 多架构 manifest list 同步失败，尝试逐架构同步..."

    # 逐架构同步
    for arch in ${ARCHITECTURES}; do
      echo ""
      echo "📦 同步架构: ${arch}"

      if skopeo copy \
        --override-arch "${arch}" \
        --retry-times 3 \
        --src-tls-verify=true \
        --dest-tls-verify=true \
        "${source_ref}" "${target_ref}" 2>&1; then
        echo "✅ 架构 ${arch} 同步成功"
        synced_archs="${synced_archs} ${arch}"
      else
        echo "⚠️ 架构 ${arch} 同步失败，源镜像可能不支持该架构"
        failed_archs="${failed_archs} ${arch}"
      fi
    done
  fi

  # 检查是否有任何架构同步成功
  if [ -z "${synced_archs}" ]; then
    echo "❌ 所有架构同步失败"
    sync_success=false
  fi

  echo ""
  echo "=========================================="
  if [ "${sync_success}" = true ]; then
    echo "📊 同步结果汇总"
    echo "   已同步架构: ${synced_archs}"
    if [ -n "${failed_archs}" ]; then
      echo "   未同步架构: ${failed_archs}（源镜像不支持）"
    fi
    echo "   源镜像: $(get_readable_source)"
    echo "   目标镜像: $(get_readable_target)"
    echo "SYNC_STATUS=success"
  else
    echo "❌ 同步失败"
    echo "SYNC_STATUS=failed"
  fi
  echo "=========================================="
}

# --- 验证同步结果 ---
verify_sync() {
  local target_ref
  target_ref=$(construct_target_ref)

  echo ""
  echo "🔍 验证同步结果..."

  local verify_output
  if verify_output=$(skopeo inspect --raw "${target_ref}" 2>&1); then
    echo "✅ 目标镜像验证成功"

    # 解析已同步的架构
    local target_archs=""
    target_archs=$(echo "${verify_output}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
archs = []
if 'manifests' in data:
    for m in data['manifests']:
        plat = m.get('platform', {})
        arch = plat.get('architecture', '')
        if arch:
            archs.append(arch)
else:
    arch = data.get('architecture', '')
    if arch:
        archs.append(arch)
print(' '.join(archs))
" 2>/dev/null || echo "unknown")

    echo "📋 目标镜像架构: ${target_archs}"
    echo "TARGET_ARCHS=${target_archs}"
  else
    echo "⚠️ 无法验证目标镜像: ${verify_output}"
    echo "TARGET_ARCHS=unknown"
  fi
}

# ===========================================
# 主流程
# ===========================================
main() {
  echo "🚀 容器镜像同步工具"
  echo "=========================================="
  echo "源镜像: ${SOURCE_IMAGE_NAME}:${SOURCE_IMAGE_TAG}"
  echo "源仓库: ${SOURCE_REGISTRY}"
  echo "目标仓库类型: ${REGISTRY_TYPE}"
  echo "目标仓库: ${TARGET_REGISTRY}"
  echo "目标命名空间: ${TARGET_NAMESPACE}"
  echo "=========================================="
  echo ""

  # 1. 登录目标仓库
  login_target_registry

  # 2. 检查源镜像
  inspect_source_image

  # 3. 同步镜像
  sync_image

  # 4. 验证结果
  verify_sync

  echo ""
  echo "✅ 同步流程完成"
  echo "SOURCE_IMAGE=$(get_readable_source)"
  echo "TARGET_IMAGE=$(get_readable_target)"
}

main
