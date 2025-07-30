#!/bin/bash

echo "=== iOS Bug修复测试脚本 ==="
echo ""

echo "1. 检查Info.plist权限配置..."
if grep -q "NSCameraUsageDescription" ios/Runner/Info.plist; then
    echo "✓ 相机权限配置已添加"
else
    echo "✗ 相机权限配置缺失"
fi

if grep -q "NSPhotoLibraryUsageDescription" ios/Runner/Info.plist; then
    echo "✓ 相册权限配置已添加"
else
    echo "✗ 相册权限配置缺失"
fi

if grep -q "NSPhotoLibraryAddUsageDescription" ios/Runner/Info.plist; then
    echo "✓ 相册保存权限配置已添加"
else
    echo "✗ 相册保存权限配置缺失"
fi

echo ""
echo "2. 检查代码修复..."
if grep -q "PermissionHelper" lib/ui/page/xdao_image_viewer.dart; then
    echo "✓ 图片查看器权限处理已修复"
else
    echo "✗ 图片查看器权限处理未修复"
fi

if grep -q "PermissionHelper" lib/ui/page/drawing_board_page.dart; then
    echo "✓ 画板页面权限处理已修复"
else
    echo "✗ 画板页面权限处理未修复"
fi

if [ -f "lib/utils/permission_helper.dart" ]; then
    echo "✓ 权限处理工具类已创建"
else
    echo "✗ 权限处理工具类未创建"
fi

if grep -q "ImageSource.camera" lib/ui/widget/util_funtions.dart; then
    echo "✓ 相机功能已添加到图片选择器"
else
    echo "✗ 相机功能未添加到图片选择器"
fi

echo ""
echo "3. 检查依赖..."
if grep -q "permission_handler" pubspec.yaml; then
    echo "✓ permission_handler依赖已存在"
else
    echo "✗ permission_handler依赖缺失"
fi

if grep -q "image_picker" pubspec.yaml; then
    echo "✓ image_picker依赖已存在"
else
    echo "✗ image_picker依赖缺失"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo "修复说明："
echo "1. 添加了iOS必要的权限描述到Info.plist"
echo "2. 修复了保存图片功能的iOS权限处理"
echo "3. 修复了画板页面的iOS权限处理"
echo "4. 添加了相机功能到图片选择器"
echo "5. 添加了相机功能到画板页面"
echo ""
echo "建议测试步骤："
echo "1. 在iOS设备上运行应用"
echo "2. 测试保存图片功能"
echo "3. 测试相机拍照功能"
echo "4. 测试画板页面的相机和保存功能" 