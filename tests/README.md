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
确认 Shell 实际映射了构建目录中的 libmutter，默认在 250% 缩放下启动一个
`frameRect != bufferRect` 的 Wayland 客户端。该客户端用独立红色
`wl_subsurface` 覆盖左上角；测试同时验证客户端阴影被清除、四角圆角 alpha、
subsurface 在圆角内部仍可见、compositor 阴影在 frame 外可见，以及窗口正文
没有被错误地整体裁掉。测试还确认 surface container 没有持久 actor clip，避免
绘制裁切同时限制 Wayland picking 和 CSD resize 热区。随后测试最大化、恢复、
全屏、再次恢复，验证方角禁用
路径与圆角恢复路径；最后进入并退出 Overview，确认 clone 继承圆角和阴影且
退出后被正确清理。测试还会切换到临时工作区并返回，确认原窗口 actor 的映射
生命周期和原生外观状态正确恢复。

验证最终优化 RPM 的 200%、250% 和 300% 缩放矩阵：

    ./packaging/fedora/test-scale-matrix.sh

也可以用 `GWA_TEST_SCALE` 单独选择嵌套测试倍率，用
`GWA_TEST_ARTIFACT_DIR` 隔离截图和日志。
