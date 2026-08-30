# Mutter 补丁测试记录

## 2026-08-30：Chrome stale surface allocation 防护

安装并确认真实会话运行 `mutter-50.4-1.gwa3.fc44` 后，Chrome 再次出现只剩
compositor 阴影、正文透明并持续播放动画末帧的现象。三个 profile 共用同一组
browser/GPU 进程，出问题的 profile 窗口关闭后无法再检查现场 actor；journal
没有 GPU/DRM reset，且窗口外观原型扩展未安装，排除了旧包、重复外观实现和明显
GPU reset。

代码复查发现第五个补丁只处理了 `clutter_actor_has_allocation() == false`，但
allocation 已标记存在时仍会无条件换算 child-local 圆角边界。如果 configure、
fractional scale 或窗口动画过渡中保留了无效或与 frame 完全不相交的旧 actor
box，圆角 shader 会把主 surface 的全部 fragment alpha 清零；独立绘制的阴影
不受影响，因此与现场现象一致。

第六个补丁在应用外观前验证主 surface allocation 的有限性、正尺寸和 frame
相交关系。失败时移除整窗矩形裁切、圆角与阴影，下一次有效同步自动恢复；异常
期间只写入一次包含窗口、allocation、frame、buffer 和 geometry scale 的 warning。
其他 subsurface 几何异常只关闭其 shader，避免局部瞬时状态拖累整个窗口。

验证结果：六个补丁从干净 `mutter-50.4-1.fc44.src.rpm` 顺序应用，目标
`libmutter-18.so.0.0.0` 编译无警告；250% 无头嵌套 Shell 的普通、最大化、
恢复、全屏、Overview clone 和工作区切换回归通过，正常状态过渡没有触发 stale
allocation 诊断；9 项仓库单元测试通过。由于真实问题发生后窗口已关闭，本次根因
仍以代码路径和现象吻合为依据；安装后若保护路径命中，可由 journal 中
`invalid or stale main surface allocation` 直接确认。

## 2026-08-25：透明正文与动画末帧持续重绘修复

真实会话偶发出现只剩 compositor 阴影、客户端正文完全透明，并持续呈现类似
最大化动画末帧的重绘。代码检查发现外观同步同时运行在 compositor
`before_paint`、actor `paint` 和 `get_paint_volume` 路径中；其中 clip 更新还会在
当前帧准备期间再次 `queue_redraw()`。窗口 configure 过渡期间若 frame/buffer
geometry 或 surface allocation 尚未同步，这条路径既可能生成裁掉完整正文的
边界，也会为下一帧继续排队。

第五个补丁将同步限制到 `before_paint` 和既有 geometry 生命周期，移除绘制与
paint-volume 查询中的状态修改及递归 redraw。对于 frame 不在 buffer 内、尺寸
无效或 surface 尚未 allocation 的瞬时状态，单帧降级为不应用原生外观，待下一次
有效同步恢复，优先保证客户端正文可见。

验证结果：五个补丁从干净 `mutter-50.4-1.fc44.src.rpm` 依次应用并完整编译
694 个目标；250% 无头嵌套 Shell 的普通、最大化、恢复、全屏、Overview clone
和工作区切换回归全部通过，窗口中心正文、四角、subsurface、阴影与 input clip
像素/状态检查均通过；9 项仓库单元测试通过。

## 2026-08-23：Wayland resize picking 修复

确认原 surface-container `clutter_actor_set_clip()` 会同时进入 Clutter paint 与
pick 路径，导致 `frameRect` 外的 CSD 透明 resize 热区无法收到 pointer 事件；
边缘拖动失效而 `Alt+F8` 仍正常，进一步排除了窗口 resize capability 和约束路径。

第四个补丁把矩形裁切改为 `MetaSurfaceContainerActorWayland::paint` 调用期间的
framebuffer clip，不再设置持久 actor clip。修复后：

- 四个补丁从干净 `mutter-50.4-1.fc44.src.rpm` 依次应用并完整编译
  `libmutter-18.so.0.0.0`；
- 250% 无头嵌套 GNOME Shell 回归通过；
- 运行时确认 surface container 的 `has_clip` 在普通、最大化、恢复、全屏、
  Overview clone 和工作区切换路径中始终为 false；
- frame 外、buffer 内的像素仍为固定背景，证明 paint-only clip 继续清除客户端
  阴影；圆角、subsurface 和 compositor 阴影像素检查均通过。

这组自动测试覆盖导致回归的 actor-clip 条件和原有视觉结果；真实桌面的边、角
拖动仍应在安装新 RPM 后进行最终确认。

## 2026-08-22：Fedora 44 / Mutter 50.4

测试基线来自当前系统精确匹配的 `mutter-50.4-1.fc44.src.rpm`。补丁通过
`scripts/prepare-mutter-source.sh` 从干净源码重新应用，随后以 Meson debug
配置完整编译 `libmutter-18.so.0.0.0` 及其 Cogl、Clutter、MTK 依赖。

前三个补丁验证结果：

- `git apply` 可严格解析补丁栈，Mutter 编译无警告或错误；
- 无头 GNOME Shell 的 `/proc/<pid>/maps` 确认加载构建目录中的 patched
  `libmutter-18`，而不是系统 core library；
- experimental feature 通过 `MUTTER_DEBUG_EXPERIMENTAL_FEATURES` 仅在测试
  会话启用，没有修改当前桌面的 GSettings；
- logical monitor 成功进入 200%、250% 和 300% 缩放；
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
- 同一 probe 依次执行普通、最大化、恢复、全屏、再次恢复：最大化与全屏时
  native clip 均关闭且红色方角可见，两次恢复后 native clip 与四个圆角均恢复；
- compositor 在圆角 frame 外绘制一份独立阴影，像素采样确认阴影可见，且
  透明角下没有正文或客户端阴影泄漏；最大化和全屏时该阴影随外观路径关闭；
- Overview 中 `MetaWindowActor` 存在 mapped clone，截图保持圆角与阴影；退出
  Overview 后 clone 被清理且原窗口外观保持；
- 切换到临时工作区后原窗口 actor 正确变为 unmapped，返回原工作区后 actor
  重新 mapped，native clip、圆角和阴影状态保持；测试结束时临时工作区被移除；
- 默认 Xwayland 配置从干净源码完整编译 694 个目标；另以
  `-Dxwayland=false -Dtests=disabled` 完整编译 664 个目标，验证 Wayland 阴影
  不会隐式依赖 Xwayland 构建条件；
- Shell 日志没有 JavaScript error、断言失败或崩溃。

测试命令：

    ./scripts/test-mutter-patches.sh
    ./tests/run-mutter-nested.sh
    ./packaging/fedora/test-scale-matrix.sh

当前结果覆盖矩形裁切、原生圆角 alpha、compositor 阴影、最大化/全屏状态
切换、Overview clone、工作区切换和合成的 `wl_subsurface` 回归客户端，并已在
最终优化 RPM 上通过 200%、250% 和 300% 缩放矩阵。真实 JetBrains Runtime
subsurface 仍待扩大覆盖。

Fedora spec 以 `Patch9001` 至 `Patch9003` 通过 `%autosetup -S git` 严格应用，
使用 Fedora release flags、LTO 与完整安装目标成功生成
`mutter-50.4-1.gwa1.fc44` 的主包、已安装子包、测试/调试包和 SRPM。所有 RPM
摘要通过，DNF `--assumeno` 确认为四个已安装子包的纯升级事务。最终主 RPM 中
解包出的优化版 libmutter 再次通过上述三倍率嵌套渲染回归。四个原始
`50.4-1.fc44` 官方 RPM 已按精确 NEVRA 缓存并通过 Fedora 签名/摘要验证，供
离线回滚使用。真实系统安装、登出重登和离线回滚往返均已通过；新 Shell 进程的
`/proc/<pid>/maps` 显示加载当前落盘 patched libmutter inode，用户确认真实桌面
圆角与阴影视觉效果。回滚测试发现并修复了 feature 列表恢复不精确的问题，现改为
安装前完整快照与原样恢复。宿主视觉效果由用户确认，自动像素判断继续限定在隔离
nested 环境。

`gwa2` 产物增加 `gnome-shell(x86-64) = 50.4-1.fc44` 精确运行时依赖，并记录
GNOME Shell 完整 NEVRA baseline。重新完成 release/LTO RPM 构建和
200%/250%/300% nested 回归后，宿主从 `gwa1` 纯升级到 `gwa2`。联网
`dnf5 distro-sync --assumeno` 恢复预演正确规划将四个本地 Mutter 子包同步回
Fedora 官方 `50.4-1.fc44`，未修改系统。
