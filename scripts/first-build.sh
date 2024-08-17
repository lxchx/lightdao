#!/bin/bash

# 获取当前脚本的目录
SCRIPT_DIR=$(dirname "$0")

# 构建AndroidManifest.xml的相对路径
MANIFEST_PATH="$SCRIPT_DIR/../android/app/src/main/AndroidManifest.xml"

# 取消注释AndroidManifest.xml中的特定代码块
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/s/<!--//' "$MANIFEST_PATH"
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/s/-->//' "$MANIFEST_PATH"

# 第一次构建APK
flutter build apk --release

# 再次注释AndroidManifest.xml中的特定代码块
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/s/^/<!-- /' "$MANIFEST_PATH"
sed -i '/<!-- START: build-first-time-comment -->/,/<!-- END: build-first-time-comment -->/s/$/ -->/' "$MANIFEST_PATH"

# 第二次构建APK
flutter build apk --release
