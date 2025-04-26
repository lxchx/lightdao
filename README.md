# lightdao

一个基于Flutter的nmbxd第三方客户端

## 配置
(添加子模块)
```bash
git submodule update --init --recursive
```


> 由于flutter问题，首次编译或者调试时需要将android\app\src\main\AndroidManifest.xml的build-first-time-comment注释包围的内容反注释掉，否则会编译失败，编译成功一次后可以将其注释掉，否则会存在两个图标
>
> 也可以执行bash ./srcript/first-build.sh --local 或者 ./srcript/first-build.sh --debug 进行首次 release 或 debug 构建