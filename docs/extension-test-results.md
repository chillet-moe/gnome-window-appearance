# 扩展测试记录

## 2026-08-22：GNOME Shell 50.4 / Mutter 50.4

测试在独立的无头 Wayland GNOME Shell 中运行，不替换当前桌面 compositor，也不需要登出。虚拟显示器为 `3200×1800`，通过 `gdctl` 明确设置 logical monitor scale `2.5`。

已验证：

- Wayland GTK 3 测试窗口被扩展识别并应用效果；
- monitor scale 为 2.5 时，Clutter resource scale 和最终窗口 surface scale 均为 3；
- 主内容使用 `Meta.ShapedTexture` mask，不存在作用于整窗的 `Shell.GLSLEffect`；
- 四个圆角的截图像素检查通过；
- 1px 黑白、红蓝条纹与文字在最终 `3200×1800` 截图中保持清晰，没有扩展额外离屏缩放的迹象；
- 独立阴影可见并跟随圆角边界；
- 扩展停用后恢复 clip、内容 opacity，并移除阴影，没有 JavaScript 错误。

测试产物写入 `tests/artifacts/`，包括 GNOME Shell 日志、显示配置和 250% 截图；该目录不提交到 Git。

## 已确认的实现限制

- GNOME 50 的 `Meta.ShapedTexture` mask 不覆盖 opaque-region 快速路径。扩展把主内容 opacity 从 255 调为 254，以强制进入 blended path；代价是最多一个 alpha 等级的透明度。
- 圆角 mask 只作用于主 `Meta.ShapedTexture`。位于圆角区域内的独立 subsurface 尚未完成专门测试；整个 surface tree 当前只有矩形 `frameRect` clip。
- XWayland 暂不处理，因为扩展 API 无法安全读取并合并 Mutter 已有的 X11 shape mask。
- overview、workspace 动画、窗口缩放、最大化/全屏切换和 JetBrains Runtime shadow subsurface 仍需加入自动化测试。
- 当前代码针对 GNOME Shell 50 的内部 API；升级 GNOME 大版本时必须重新验证。

这些限制是判断是否下沉到 Mutter 原生实现的输入，不应被兼容层隐藏。
