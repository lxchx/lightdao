#!/bin/bash

# 处理命令行参数
MODE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --secrets) MODE="secrets" ;;
        --local) MODE="local" ;;
        --debug) MODE="debug" ;;
        *) ;;
    esac
    shift
done

SCRIPT_DIR=$(dirname "$0")
MANIFEST_PATH="$SCRIPT_DIR/../android/app/src/main/AndroidManifest.xml"

# 取消注释
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/ {
    s/^\([[:space:]]*\)<!--\(.*intent-filter.*\)/\1\2/
    s/^\([[:space:]]*\)\(.*intent-filter.*\)-->/\1\2/
}' "$MANIFEST_PATH"

# 第一次构建
echo '运行首次构建...'
flutter build apk --release
rm "$SCRIPT_DIR/../build/app/outputs/flutter-apk/app-release.apk"

# 重新注释
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/ {
    s/^\([[:space:]]*\)\(<intent-filter>\)/\1<!--\2/
    s/^\([[:space:]]*\)\(<\/intent-filter>\)/\1\2-->/
}' "$MANIFEST_PATH"

# 根据模式构建
case $MODE in
    "secrets")
        echo '使用GitHub Secrets签名构建...'
        flutter build apk --release \
            --dart-define=KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD \
            --dart-define=KEY_ALIAS=$KEY_ALIAS \
            --dart-define=KEY_PASSWORD=$KEY_PASSWORD
        ;;
    "local")
        echo '尝试使用使用本地JKS文件构建...'
        flutter build apk --release
        ;;
esac