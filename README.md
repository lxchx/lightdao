# 氢岛 (lightdao)

[![](https://img.shields.io/badge/DeepWiki-AI%20Docs-blue)](https://deepwiki.com/lxchx/lightdao)

> 一个轻量的、跨平台的 NMBXD 第三方客户端。

本项目是一个基于 [Flutter](https://flutter.dev) 构建的非官方 NMBXD 论坛客户端，旨在提供一个简洁、流畅、多功能的论坛浏览体验。

> **⚠️ 注意**
>
> 本项目使用 Flutter 构建，具备跨平台能力。但目前仅 **Android 端** 经过了较为充分的测试，其他平台（iOS, Web, 桌面端）可能存在未知问题，仅作为技术预览或实验性支持。

## 🏛️ 项目架构解析

本项目已接入 DeepWiki，你可以访问下方链接查看由 AI 自动生成的项目架构图、文件关系、流程图等详细解析。

[**在 DeepWiki 中查看项目解析**](https://deepwiki.com/lxchx/lightdao)

## ✨ 功能特性

- **基础功能**: 具备完整的论坛浏览、串查看、回复、时间线收藏和内容过滤等基础功能。

- **特色功能**:
    - **只看PO**: 支持在串内只看原PO的回复，快速浏览关键信息。
    - **原图模式**: 可切换至原图模式，查看未经压缩的高清图片。
    - **引用展开**: 在回复列表中直接内联展开被引用的内容，无需跳转。

- **界面与主题**:
    - **Material 3 设计**: 采用最新的 Material Design 3 设计语言。
    - **高度自定义主题**: 支持 Material 3 动态取色，并可高度自定义主题颜色和夜间模式（含AMOLED纯黑模式）。
    - **宽屏优化**: 针对平板和桌面端等宽屏设备，自动切换为更高效的多栏布局。
    - **个性化图标**: 内置多款应用图标供用户选择。

## 🔒 第三方服务说明

> **本客户端为第三方客户端，不受X岛官方支持。**
>
> 氢岛（lightdao）由爱好者开发维护，不是X岛官方出品，也不受X岛官方支持。

为了提供论坛浏览以外的功能（检查更新、可选的加速线路），本客户端会与X岛官方以外的服务器通信。首次启动时会用一页不可跳过的说明征求同意，同意之后才会继续；之后也可以在「设置 - 网络 - 第三方服务」里改主意。下面是那一页的完整内容。

下面没有列到的都是X岛官方服务器，不属于第三方：www.nmbxd.com、www.nmbxd1.com、图片 image.nmb.best、公告 nmb.ovear.info。

### 会连接哪些第三方服务器

- **GitHub（api.github.com、github.com）**
  用途：检查是否有新版本、下载新版本的安装包（app-release.apk）。
  发出：网络 IP、客户端 User-Agent、版本接口与安装包的请求地址；不发送你的饼干、账号或浏览内容。
- **api.nmb.best（第三方镜像线路）**
  用途：在设置里选中它、或让「自动」测速选中它时，看串、发串、拉取列表等请求会经过这台服务器。
  发出：全部请求内容与请求头，包括你的饼干、IP、User-Agent。
- **api.nmb.fastmirror.org（第三方镜像线路）**
  用途与上面相同：选中它之后，看串、发串等请求会经过这台服务器，同样会经手你的饼干、IP、User-Agent 与全部请求内容。
- **自定义线路（设置里「自定义」填写的域名）**
  用途：如果你在设置里自己填了一条线路，看串、发串等请求会全部经过它；这台服务器由你指定，本客户端无法得知它如何处理数据。
- **「自动」测速**
  用途：设置保持「自动」时，客户端会依次连上面每条线路测一次速度，再挑最快的那条。测速请求本身也会发到第三方服务器。

### 第三方会收到什么数据

- **请求内容**：包括你正在看的串、板块与时间线，发出的回复和串，以及附带的表情、图片地址等；经过第三方线路时这些内容对那台服务器是可见的。
- **饼干与网络信息**：经过第三方线路时，登录用的饼干、网络 IP、User-Agent 都会被那台服务器看到，它可以用这些信息关联你的浏览行为。

### 数据如何留存

上述请求由各第三方服务器按它自己的策略处理与保存，本客户端无法查看、修改或删除它们的日志，也不知道它们保存多久。X岛无法保证这些第三方服务器上的数据安全，本客户端也不对第三方服务器的行为负责。

### 内容来源

本客户端显示的所有内容均来源于X岛，官网地址：<https://www.nmbxd.com>

### 不同意的后果

不同意也可以继续使用，且不影响主要功能：

- 看时间线、看串、发串、看图、收藏等全部照常可用，请求只走X岛官方线路（www.nmbxd.com、www.nmbxd1.com，图片走 image.nmb.best，公告走 nmb.ovear.info）。
- 不能使用第三方镜像线路与自定义线路，也不会做自动测速选线；你在设置里保存的线路不会被删除，同意后照原样生效。
- 不能检查更新，也不能下载更新包（需要访问 GitHub）。想更新时可以在这里或设置里重新同意第三方服务。

## 🛠️ 技术栈

- **核心框架**: [Flutter](https://flutter.dev)
- **编程语言**: [Dart](https://dart.dev)
- **代码生成**: [build_runner](https://pub.dev/packages/build_runner)
- **状态管理**: Provider

## 🚀 快速开始

请确保你已经安装并配置好了 [Flutter SDK](https://flutter.cn/docs/get-started/install)。

### 1. 克隆项目

```bash
git clone https://github.com/lxchx/lightdao.git
cd lightdao-temp
```

### 2. 初始化子模块

本项目依赖 git submodules，请运行以下命令来初始化它们：

```bash
git submodule update --init --recursive
```

### 3. 安装依赖

在项目根目录下运行，获取所有 Dart/Flutter 依赖包：

```bash
flutter pub get
```

### 4. 生成代码

项目中使用 `build_runner` 来生成部分必要的代码（例如 `*.g.dart` 文件）。请运行：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. 首次构建特别说明 (重要)

由于 Flutter 的一个已知问题，在 **首次编译或调试 Android 版本** 时，可能会遇到编译失败。

**解决方法一：(推荐) 执行脚本**

项目提供了自动化脚本来处理此问题。根据你的需要执行：

- **首次 Debug 构建**: `bash ./scripts/first-build.sh --debug`
- **首次 Release 构建**: `bash ./scripts/first-build.sh --local`

**解决方法二：手动修改**

1.  打开 `android/app/src/main/AndroidManifest.xml` 文件。
2.  找到被 `build-first-time-comment` 注释包围的内容。
3.  将这部分内容 **反注释** (即移除注释符号 `<!--` 和 `-->`)。
4.  进行一次成功的编译。
5.  成功编译后，**务必将这部分内容重新注释掉**，否则应用会显示两个图标。

### 6. 运行与构建

- **运行开发版本**:
  ```bash
  flutter run
  ```

- **构建发布版本**:
  ```bash
  # 构建 Android APK
  flutter build apk --release

  # 构建 Android App Bundle (用于上架 Google Play)
  flutter build appbundle --release

  # 构建 iOS 应用
  flutter build ios --release

  # 构建 Web 应用
  flutter build web

  # 构建其他桌面平台 (macos, windows, linux)
  flutter build <platform> --release
  ```

## 📂 目录结构

```
.
├── android/          # Android 原生项目代码
├── assets/           # 应用所需的静态资源 (如图标、图片)
├── ios/              # iOS 原生项目代码
├── lib/              # Flutter 应用核心代码
│   ├── data/         # 数据模型、常量和数据源
│   ├── main.dart     # 应用主入口
│   ├── ui/           # UI 界面和组件
│   └── utils/        # 工具类和辅助函数
├── macos/            # macOS 原生项目代码
├── packages/         # 本地依赖包
├── scripts/          # 构建和格式化脚本
├── test/             # 测试代码
├── web/              # Web 项目相关文件
├── windows/          # Windows 原生项目代码
└── pubspec.yaml      # 项目配置文件，包含依赖、版本等信息
```

## 🤝 如何贡献

欢迎提交 Pull Request 或 Issue 来帮助改进项目。



## 发布新版本

使用 用法: scripts/make-release.sh <version> [--push]
示例: scripts/make-release.sh 1.4.8        # 本地创建 v1.4.8
      scripts/make-release.sh 1.4.8 --push # 创建并推送到远端 创建规范的 release：

❌ 工作区有未提交的改动，请先 commit
 M .github/workflows/main.yaml
 M ios/Flutter/Debug.xcconfig
 M ios/Flutter/Release.xcconfig
 M macos/Flutter/Flutter-Debug.xcconfig
 M macos/Flutter/Flutter-Release.xcconfig
?? ios/Podfile
?? macos/Podfile
?? scripts/make-release.sh
❌ 工作区有未提交的改动，请先 commit
 M .github/workflows/main.yaml
 M ios/Flutter/Debug.xcconfig
 M ios/Flutter/Release.xcconfig
 M macos/Flutter/Flutter-Debug.xcconfig
 M macos/Flutter/Flutter-Release.xcconfig
?? ios/Podfile
?? macos/Podfile
?? scripts/make-release.sh

脚本会：
- 自动规范化换行（ → ）
- 去除多余空行和注释
- 检查 tag 是否已存在、工作区是否干净
- 创建 annotated tag（CI 要求）
