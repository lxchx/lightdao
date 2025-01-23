#!/bin/bash

# 获取当前脚本的目录
SCRIPT_DIR=$(dirname "$0")

# 构建AndroidManifest.xml的相对路径
MANIFEST_PATH="$SCRIPT_DIR/../android/app/src/main/AndroidManifest.xml"

# 取消注释以通过flutter编译条件
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/ {
    # 匹配起始行（<!--<intent-filter>...）
    s/^\([[:space:]]*\)<!--\(.*intent-filter.*\)/\1\2/
    # 匹配结束行（</intent-filter>-->）
    s/^\([[:space:]]*\)\(.*intent-filter.*\)-->/\1\2/
}' "$MANIFEST_PATH"
# 构建APK，此时将有两个启动图标
echo 'run "flutter build apk --release" once...'
flutter build apk --release
rm "$SCRIPT_DIR/../build/app/outputs/flutter-apk/app-release.apk"

# 重新注释
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/ {
    # 匹配起始行（<intent-filter>...）
    s/^\([[:space:]]*\)\(<intent-filter>\)/\1<!--\2/
    # 匹配结束行（</intent-filter>）
    s/^\([[:space:]]*\)\(<\/intent-filter>\)/\1\2-->/
}' "$MANIFEST_PATH"
# 正确构建APK
echo 'run "flutter build apk --release" twice...'
flutter build apk --release
