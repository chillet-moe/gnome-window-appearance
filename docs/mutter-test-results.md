# Mutter 补丁测试记录

## 2026-08-22：Fedora 44 / Mutter 50.4

测试基线来自当前系统精确匹配的 `mutter-50.4-1.fc44.src.rpm`。补丁通过
`scripts/prepare-mutter-source.sh` 从干净源码重新应用，随后以 Meson debug
配置完整编译 `libmutter-18.so.0.0.0` 及其 Cogl、Clutter、MTK 依赖。

前两个补丁验证结果：

- `git apply` 可严格解析补丁栈，Mutter 编译无警告或错误；
- 无头 GNOME Shell 的 `/proc/<pid>/maps` 确认加载构建目录中的 patched
  `libmutter-18`，而不是系统 core library；
- experimental feature 通过 `MUTTER_DEBUG_EXPERIMENTAL_FEATURES` 仅在测试
  会话启用，没有修改当前桌面的 GSettings；
- logical monitor 成功进入 250% 缩放；
- 自定义 Wayland probe 的 frame 为 `760×457`，buffer 为 `812×509`，能够
  覆盖带客户端阴影的 `frameRect != bufferRect` 路径；
- 测试扩展在几何同步后直接确认 Wayland surface container 的 native clip
  已设置；
- frame 外、buffer 内的截图采样恢复为固定 `#204060` 背景，表明客户端阴影
  被 surface-tree 矩形裁切清除；
- probe 提交一个覆盖左上角的独立红色 `wl_subsurface`：红色在圆角内部保持
  可见，而四个角落均恢复为背景，证明圆角应用于完整 surface tree；
- 窗口中心仍为客户端内容，防止 shader 将整窗错误变透明却误报通过；
- 250% 缩放下圆角使用最终 fragment coverage，不经过整窗 FBO；
- Shell 日志没有 JavaScript error、断言失败或崩溃。

测试命令：

    ./scripts/test-mutter-patches.sh
    ./tests/run-mutter-nested.sh

当前结果覆盖矩形裁切、原生圆角 alpha 和合成的 `wl_subsurface` 回归客户端。
compositor 阴影、状态切换、overview、workspace、clone 和真实 JetBrains
Runtime subsurface 仍待后续补丁与测试覆盖。
