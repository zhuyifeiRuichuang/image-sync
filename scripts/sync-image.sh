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
  log "🔐 正在登录目标镜像仓库: ${TARGET_REGISTRY}"

  local login_output
  local login_exit_code

  login_output=$(echo "${TARGET_PASSWORD}" | skopeo login "${TARGET_REGISTRY}" \
    -u "${TARGET_USERNAME}" --password-stdin \
    --tls-verify=true 2>&1) && login_exit_code=0 || login_exit_code=$?

  if [ ${login_exit_code} -eq 0 ]; then
    log "✅ 登录成功"
  else
    log "❌ 登录失败"
    echo "ERROR_TYPE=login_failed"
    echo "ERROR_DETAIL=登录目标仓库 ${TARGET_REGISTRY} 失败 (退出码: ${login_exit_code})。错误输出: ${login_output}"
    return 1
  fi
}

# --- 检查源镜像是否存在及其架构信息 ---
inspect_source_image() {
  local source_ref
  source_ref=$(construct_source_ref)

  log "🔍 正在检查源镜像: ${source_ref#docker://}"

  # 尝试 inspect 源镜像
  local inspect_output
  local inspect_exit_code

  inspect_output=$(skopeo inspect --raw "${source_ref}" 2>&1) && inspect_exit_code=0 || inspect_exit_code=$?

  if [ ${inspect_exit_code} -ne 0 ]; then
    log "❌ 源镜像不存在或无法访问: ${source_ref#docker://}"
    echo "ERROR_TYPE=source_image_not_found"
    echo "ERROR_DETAIL=源镜像 ${source_ref#docker://} 检查失败 (退出码: ${inspect_exit_code})。错误输出: ${inspect_output}"
    return 1
  fi

  log "✅ 源镜像存在"

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

  log "📋 源镜像可用架构: ${available_archs}"
  echo "AVAILABLE_ARCHS=${available_archs}"
}

# --- 工具函数：打印带时间戳的日志 ---
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- 运行命令并带进度心跳 ---
# 在后台运行命令，每 30 秒打印一次心跳，避免日志长时间无输出被 GitHub Actions 误判卡死
# 输出保存到全局变量 LAST_CMD_OUTPUT 供错误诊断使用
LAST_CMD_OUTPUT=""
LAST_CMD_EXIT_CODE=0

run_with_heartbeat() {
  local cmd="$1"
  local desc="$2"
  local start_time end_time elapsed
  start_time=$(date +%s)

  log "⏳ ${desc} 开始..."
  log "   命令: ${cmd}"

  # 使用临时文件捕获输出
  local tmp_output
  tmp_output=$(mktemp)

  # 后台执行命令，将输出重定向到临时文件
  eval "${cmd}" > "${tmp_output}" 2>&1 &
  local cmd_pid=$!

  # 进度心跳
  while kill -0 "${cmd_pid}" 2>/dev/null; do
    elapsed=$(($(date +%s) - start_time))
    log "⏳ ${desc} 进行中... 已耗时 ${elapsed} 秒"
    sleep 30
  done

  # 等待命令结束并获取退出码
  wait "${cmd_pid}"
  local exit_code=$?
  LAST_CMD_EXIT_CODE=${exit_code}

  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  # 保存输出到全局变量（截取最后 2000 字符防止过长）
  LAST_CMD_OUTPUT=$(cat "${tmp_output}" | tail -c 2000)

  # 打印完整输出
  echo ""
  echo "--- ${desc} 详细输出 (耗时 ${elapsed} 秒) ---"
  cat "${tmp_output}"
  echo "--- ${desc} 输出结束 ---"
  echo ""

  rm -f "${tmp_output}"

  return ${exit_code}
}

# --- 同步镜像（支持多架构） ---
sync_image() {
  local source_ref
  source_ref=$(construct_source_ref)
  local target_ref
  target_ref=$(construct_target_ref)

  log "🔄 开始同步镜像"
  log "   源: ${source_ref#docker://}"
  log "   目标: ${target_ref#docker://}"
  log "   架构: ${ARCHITECTURES}"

  local sync_success=true
  local synced_archs=""
  local failed_archs=""

  # 先获取镜像大小信息，帮助预估时间
  log "📊 正在获取源镜像信息..."
  local image_info
  image_info=$(skopeo inspect "${source_ref}" 2>/dev/null || echo "")
  if [ -n "${image_info}" ]; then
    local layers_count
    layers_count=$(echo "${image_info}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('Layers', [])))" 2>/dev/null || echo "unknown")
    log "📋 源镜像层数: ${layers_count}"
  fi

  # 先尝试用 --all 同步整个 manifest list（多架构）
  echo ""
  log "📦 尝试同步多架构 manifest list..."

  local copy_cmd
  copy_cmd="skopeo copy --all --verbose --retry-times 3 \
    --src-tls-verify=true \
    --dest-tls-verify=true \
    '${source_ref}' '${target_ref}'"

  local sync_all_output=""
  local sync_all_exit_code=0
  local sync_all_detail=""

  if run_with_heartbeat "${copy_cmd}" "同步多架构 manifest list"; then
    log "✅ 多架构 manifest list 同步成功"
    synced_archs="${ARCHITECTURES}"
  else
    sync_all_exit_code=$?
    sync_all_detail="${LAST_CMD_OUTPUT}"
    log "⚠️ 多架构 manifest list 同步失败 (退出码: ${sync_all_exit_code})，尝试逐架构同步..."

    # 逐架构同步
    local arch_fail_details=""
    for arch in ${ARCHITECTURES}; do
      echo ""
      log "📦 同步架构: ${arch}"

      copy_cmd="skopeo copy --override-arch '${arch}' --verbose --retry-times 3 \
        --src-tls-verify=true \
        --dest-tls-verify=true \
        '${source_ref}' '${target_ref}'"

      if run_with_heartbeat "${copy_cmd}" "同步架构 ${arch}"; then
        log "✅ 架构 ${arch} 同步成功"
        synced_archs="${synced_archs} ${arch}"
      else
        local arch_exit_code=$?
        log "⚠️ 架构 ${arch} 同步失败 (退出码: ${arch_exit_code})"
        failed_archs="${failed_archs} ${arch}"
        arch_fail_details="${arch_fail_details}架构 ${arch} 退出码: ${arch_exit_code}; 错误输出: ${LAST_CMD_OUTPUT}; "
      fi
    done

    # 保存多架构同步失败的详细信息
    sync_all_output="manifest list 同步退出码: ${sync_all_exit_code}; 详细输出: ${sync_all_detail}; 逐架构失败详情: ${arch_fail_details}"
  fi

  # 检查是否有任何架构同步成功
  if [ -z "${synced_archs}" ]; then
    log "❌ 所有架构同步失败"
    sync_success=false
    echo "ERROR_TYPE=sync_failed"
    # 截断过长的错误详情，保留最后 1500 字符
    echo "ERROR_DETAIL=所有架构同步失败。${sync_all_output}" | tail -c 1500
  elif [ -n "${failed_archs}" ]; then
    log "⚠️ 部分架构同步失败"
    # 截断过长的错误详情，保留最后 1500 字符
    echo "ERROR_TYPE=partial_sync_failed"
    echo "ERROR_DETAIL=部分架构同步失败: ${failed_archs}。${sync_all_output}" | tail -c 1500
  fi

  echo ""
  echo "=========================================="
  if [ "${sync_success}" = true ]; then
    log "📊 同步结果汇总"
    log "   已同步架构: ${synced_archs}"
    if [ -n "${failed_archs}" ]; then
      log "   未同步架构: ${failed_archs}（源镜像不支持）"
    fi
    log "   源镜像: $(get_readable_source)"
    log "   目标镜像: $(get_readable_target)"
    echo "SYNC_STATUS=success"
  else
    log "❌ 同步失败"
    echo "SYNC_STATUS=failed"
  fi
  echo "=========================================="
}

# --- 验证同步结果 ---
verify_sync() {
  local target_ref
  target_ref=$(construct_target_ref)

  log "🔍 验证同步结果..."

  local verify_output
  if verify_output=$(skopeo inspect --raw "${target_ref}" 2>&1); then
    log "✅ 目标镜像验证成功"

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

    log "📋 目标镜像架构: ${target_archs}"
    echo "TARGET_ARCHS=${target_archs}"
  else
    log "⚠️ 无法验证目标镜像: ${verify_output}"
    echo "TARGET_ARCHS=unknown"
  fi
}

# ===========================================
# 主流程
# ===========================================
main() {
  log "🚀 容器镜像同步工具"
  log "=========================================="
  log "源镜像: ${SOURCE_IMAGE_NAME}:${SOURCE_IMAGE_TAG}"
  log "源仓库: ${SOURCE_REGISTRY}"
  log "目标仓库类型: ${REGISTRY_TYPE}"
  log "目标仓库: ${TARGET_REGISTRY}"
  log "目标命名空间: ${TARGET_NAMESPACE}"
  log "=========================================="
  echo ""

  # 1. 登录目标仓库
  if ! login_target_registry; then
    log "❌ 主流程：登录失败，终止同步"
    echo "SYNC_STATUS=failed"
    # ERROR_TYPE 和 ERROR_DETAIL 已在 login_target_registry 中输出
    return 1
  fi

  # 2. 检查源镜像
  if ! inspect_source_image; then
    log "❌ 主流程：源镜像检查失败，终止同步"
    echo "SYNC_STATUS=failed"
    # ERROR_TYPE 和 ERROR_DETAIL 已在 inspect_source_image 中输出
    return 1
  fi

  # 3. 同步镜像
  sync_image
  # sync_image 内部已处理 ERROR_TYPE/ERROR_DETAIL

  # 4. 验证结果
  verify_sync

  log ""
  log "✅ 同步流程完成"
  echo "SOURCE_IMAGE=$(get_readable_source)"
  echo "TARGET_IMAGE=$(get_readable_target)"
}

main
