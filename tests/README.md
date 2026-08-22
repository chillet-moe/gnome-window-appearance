# Tests

这里将保存扩展与 Mutter 实现共享的测试场景、渲染基准和 Fedora 包验证。

首批测试矩阵至少覆盖：

- 缩放：200%、250%、300%，并逐步补齐其他非整数倍率；
- 客户端：GTK、Qt、JetBrains Runtime、Electron、XWayland；
- 状态：普通、最大化、全屏、overview、工作区切换、窗口动画；
- 几何：`frameRect === bufferRect` 与包含客户端阴影的 `frameRect !== bufferRect`；
- 实现：无效果、空 offscreen effect、扩展圆角、Mutter 原生圆角。

渲染比较应单独评估正文清晰度、圆角覆盖和阴影，不只保存主观截图。

## Mutter 原生路线

先编译补丁栈，再使用构建目录中的 libmutter 启动无头嵌套 Shell：

    ./scripts/test-mutter-patches.sh
    ./tests/run-mutter-nested.sh

嵌套测试通过环境变量启用 experimental feature，不更改当前桌面设置；它会
确认 Shell 实际映射了构建目录中的 libmutter，在 250% 缩放下启动带客户端
阴影的 GTK Wayland 窗口，并验证 frame 外、buffer 内的像素已经显示为背景。
