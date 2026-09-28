#!/usr/bin/env bash
#
# 墨阅 Reader —— Flutter 运行环境一键安装脚本
#
# 用法：
#   ./setup_env.sh                  # 安装 Flutter + Android SDK（完整，可打 APK）
#   ./setup_env.sh --no-android     # 只装 Flutter（可 analyze / test，不能打 APK）
#   ./setup_env.sh --cn             # 走国内镜像（storage.flutter-io.cn / pub.flutter-io.cn）
#   FLUTTER_VERSION=3.35.1 ./setup_env.sh
#
# 装好后：
#   source ~/.moyue_env
#   cd <项目目录> && flutter pub get && flutter analyze && flutter test
#   flutter build apk --release
#
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.1}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/flutter-sdk}"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$HOME/android-sdk}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-35}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-35.0.0}"
CMDLINE_TOOLS_VERSION="${CMDLINE_TOOLS_VERSION:-11076708}"

USE_CN=0
WANT_ANDROID=1
for arg in "$@"; do
  case "$arg" in
    --cn) USE_CN=1 ;;
    --no-android) WANT_ANDROID=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数：$arg（用 --help 查看用法）"; exit 1 ;;
  esac
done

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m ✗\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 镜像
if [ "$USE_CN" = "1" ]; then
  FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
  PUB_HOSTED_URL="https://pub.flutter-io.cn"
else
  FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com"
  PUB_HOSTED_URL="https://pub.dev"
fi
export FLUTTER_STORAGE_BASE_URL PUB_HOSTED_URL

# ---------------------------------------------------------------- 系统依赖
install_sys_deps() {
  log "检查系统依赖"
  if command -v apt-get >/dev/null 2>&1; then
    local pkgs=(curl git unzip xz-utils zip libglu1-mesa)
    command -v java >/dev/null 2>&1 || pkgs+=(openjdk-17-jdk-headless)
    local missing=()
    for p in "${pkgs[@]}"; do
      dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
      log "安装：${missing[*]}"
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
    fi
  elif command -v brew >/dev/null 2>&1; then
    command -v java >/dev/null 2>&1 || brew install --cask temurin@17
    brew install git unzip
  else
    warn "未识别的包管理器，请自行安装：curl git unzip xz-utils JDK17"
  fi
  ok "系统依赖就绪"
}

# ---------------------------------------------------------------- Flutter SDK
install_flutter() {
  if [ -x "$INSTALL_DIR/flutter/bin/flutter" ]; then
    log "Flutter 已存在于 $INSTALL_DIR/flutter，跳过下载"
  else
    mkdir -p "$INSTALL_DIR"
    local tarball="$INSTALL_DIR/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    local url="$FLUTTER_STORAGE_BASE_URL/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    log "下载 Flutter $FLUTTER_VERSION"
    log "来源：$url"
    curl -fSL --retry 3 --progress-bar -o "$tarball" "$url" \
      || die "Flutter 下载失败，可尝试 --cn 走国内镜像"
    log "解压到 $INSTALL_DIR"
    tar -xJf "$tarball" -C "$INSTALL_DIR"
    rm -f "$tarball"
  fi
  ok "Flutter SDK 就绪"
}

# ---------------------------------------------------------------- Android SDK
install_android() {
  [ "$WANT_ANDROID" = "1" ] || { warn "跳过 Android SDK（--no-android）"; return 0; }
  log "安装 Android SDK 到 $ANDROID_SDK_DIR"
  mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"

  if [ ! -x "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
    local zip="$ANDROID_SDK_DIR/cmdline-tools.zip"
    curl -fSL --retry 3 --progress-bar \
      -o "$zip" "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" \
      || die "Android cmdline-tools 下载失败"
    rm -rf "$ANDROID_SDK_DIR/cmdline-tools/tmp"
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools/tmp"
    unzip -q "$zip" -d "$ANDROID_SDK_DIR/cmdline-tools/tmp"
    mv "$ANDROID_SDK_DIR/cmdline-tools/tmp/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
    rm -rf "$ANDROID_SDK_DIR/cmdline-tools/tmp" "$zip"
  fi

  export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  export ANDROID_HOME="$ANDROID_SDK_DIR"
  local sm="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"

  yes | "$sm" --licenses >/dev/null 2>&1 || true
  "$sm" --install "platform-tools" "platforms;android-${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}" \
    || die "Android 组件安装失败"
  ok "Android SDK 就绪（platform ${ANDROID_PLATFORM} / build-tools ${ANDROID_BUILD_TOOLS}）"
}

write_env() {
  cat > "$HOME/.moyue_env" <<EOF
# 墨阅 Reader 运行环境 —— 使用方式：source ~/.moyue_env
export FLUTTER_ROOT="$INSTALL_DIR/flutter"
export PATH="\$FLUTTER_ROOT/bin:\$PATH"
export PUB_HOSTED_URL="$PUB_HOSTED_URL"
export FLUTTER_STORAGE_BASE_URL="$FLUTTER_STORAGE_BASE_URL"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
export ANDROID_HOME="$ANDROID_SDK_DIR"
export PATH="\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH"
EOF
  ok "已写入 $HOME/.moyue_env"
}

verify() {
  log "校验环境"
  # shellcheck disable=SC1090
  source "$HOME/.moyue_env"
  flutter --version 2>&1 | head -3
  flutter config --android-sdk "$ANDROID_SDK_DIR" >/dev/null 2>&1 || true
  ok "flutter 可用"
  if [ "$WANT_ANDROID" = "1" ]; then
    flutter doctor --android-licenses >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------- 平台目录
ensure_platform() {
  cd "$PROJECT_DIR"
  if [ ! -d "$PROJECT_DIR/android" ]; then
    log "生成 android/ 平台目录"
    # shellcheck disable=SC1090
    source "$HOME/.moyue_env"
    flutter create --platforms=android --project-name moyue_reader \
      --org com.moyue . || die "flutter create 失败"
  else
    log "android/ 已存在，跳过生成"
  fi
  ok "平台目录就绪"
}

# Edge-TTS / AI 需要联网，官方模板默认不带 INTERNET 权限
patch_permissions() {
  local manifest="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"
  [ -f "$manifest" ] || { warn "未找到 AndroidManifest.xml，跳过权限补丁"; return 0; }
  if grep -q 'android.permission.INTERNET' "$manifest"; then
    ok "INTERNET 权限已存在"
    return 0
  fi
  log "注入 INTERNET 权限"
  python3 - "$manifest" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
perm = '    <uses-permission android:name="android.permission.INTERNET"/>\n'
if '<uses-permission' in s:
    s = re.sub(r'(\s*)(<uses-permission)', r'\1<uses-permission android:name="android.permission.INTERNET"/>\n\1\2', s, count=1)
else:
    s = s.replace('<manifest', '<!-- 墨阅：Edge-TTS 与 AI 需要联网 -->\n' + perm + '<manifest', 1)
open(p, 'w', encoding='utf-8').write(s)
print('  已写入 INTERNET 权限')
PY
  ok "权限补丁完成"
}

main() {
  log "目标：Flutter ${FLUTTER_VERSION} → ${INSTALL_DIR}"
  [ "$USE_CN" = "1" ] && log "使用国内镜像"
  install_sys_deps
  install_flutter
  install_android
  write_env
  verify
  if [ "$WANT_ANDROID" = "1" ]; then
    ensure_platform
    patch_permissions
  fi
  cat <<EOF

\033[1;32m环境安装完成\033[0m

接下来：
  source ~/.moyue_env
  cd $(pwd)
  flutter pub get
  flutter analyze          # 静态检查
  flutter test             # 单元测试
  flutter build apk --debug    # 打调试包
  flutter build apk --release  # 打正式包（需先配置签名）

提示：执行 flutter doctor 可查看还有什么缺失。
EOF
}

main "$@"
