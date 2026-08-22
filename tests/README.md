# Tests

这里将保存扩展与 Mutter 实现共享的测试场景、渲染基准和 Fedora 包验证。

首批测试矩阵至少覆盖：

- 缩放：200%、250%、300%，并逐步补齐其他非整数倍率；
- 客户端：GTK、Qt、JetBrains Runtime、Electron、XWayland；
- 状态：普通、最大化、全屏、overview、工作区切换、窗口动画；
- 几何：`frameRect === bufferRect` 与包含客户端阴影的 `frameRect !== bufferRect`；
- 实现：无效果、空 offscreen effect、扩展圆角、Mutter 原生圆角。

渲染比较应单独评估正文清晰度、圆角覆盖和阴影，不只保存主观截图。
