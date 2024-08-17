from PIL import Image
import os
import sys

# 获取控制台参数
if len(sys.argv) < 3:
    print("请提供源图标文件路径和输出图标文件名作为参数")
    sys.exit(1)

source_image_path = sys.argv[1]
output_image_name = sys.argv[2]

# 输出文件夹路径
output_dir = "./"

# 不同分辨率
resolutions = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

# 打开源图标
source_image = Image.open(source_image_path)

# 创建输出文件夹（如果不存在）
os.makedirs(output_dir, exist_ok=True)

# 生成并保存不同分辨率的图标
for folder, (width, height) in resolutions.items():
    output_path = os.path.join(output_dir, folder)
    os.makedirs(output_path, exist_ok=True)
    resized_image = source_image.resize((width, height), Image.LANCZOS)
    resized_image.save(os.path.join(output_path, output_image_name))

print("图标已成功生成并保存到相应文件夹中。")
