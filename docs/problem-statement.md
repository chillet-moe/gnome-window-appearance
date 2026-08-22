# 目标与边界

## 背景

GNOME 桌面中的窗口可能由 GTK、Qt、JetBrains Runtime、Electron 或 XWayland 客户端绘制。不同客户端对圆角、透明边缘和客户端阴影的处理并不一致，因此同一桌面中会出现：

- 圆角半径不同或完全没有圆角；
- 阴影大小、颜色与模糊半径不一致；
- 客户端阴影属于 surface tree，使 buffer 的可见尺寸大于窗口正文；
- 扩展为统一外观而处理整窗纹理时，在 125%、150%、175%、225% 或 250% 等小数缩放下使文字和细线变模糊。

JetBrains Runtime 是重要测试对象：其 Wayland 窗口可通过 subsurface 提交客户端阴影，同时使用 `xdg_surface.set_window_geometry` 声明不含阴影的正文边界。因此 compositor 通常知道正确窗口几何，但必须选择正确的 surface tree 裁切与阴影策略。

## 产品目标

项目应在 GNOME Wayland 会话中提供：

1. 可配置且视觉一致的窗口圆角。
2. 由 compositor 一侧统一绘制的窗口阴影。
3. 对已正确声明 window geometry 的客户端，移除正文边界之外的客户端阴影。
4. 在小数缩放下不降低窗口正文、文字或细线的清晰度。
5. 正确处理移动、缩放、最大化、全屏、overview、工作区切换和窗口动画。
6. 对不应处理的窗口提供可靠的自动判断和显式规则。

## 成功标准

- 在整数和非整数缩放下，启用效果前后的窗口正文截图应保持相同采样清晰度；差异应集中在圆角 alpha 边缘和阴影区域。
- 使用 `frameRect` 与 `bufferRect` 不同的 Wayland 客户端时，客户端阴影不会残留在统一阴影内部。
- GTK、Qt、JetBrains Runtime、Electron 和 XWayland 的代表窗口均有明确测试结果。
- 最大化和全屏窗口不会错误保留普通窗口圆角或阴影。
- Mutter 补丁能够作为 RPM 安装、升级、降级和移除，不直接覆盖 `/usr` 中由 RPM 管理的文件。

## 非目标

- 不修改应用自身的主题或 widget 样式。
- 不承诺在扩展路线中使用稳定的 GNOME Shell 公共 API 完成所有功能；扩展原型允许依赖版本相关接口，但必须隔离兼容层。
- 不通过长期锁定旧版 Mutter 来逃避补丁维护和安全更新。
- 不把强制 nearest-neighbor 过滤当作最终的清晰度修复。

## 约束

- 默认平台是 Fedora 上的 GNOME Wayland。
- 扩展方案不得要求替换系统包。
- 原生方案必须以小型、可重放的补丁栈维护，不长期维护完整 Mutter fork。
- 在确认扩展边界之前，不扩大 Mutter 修改范围；原生实现应复用扩展阶段验证过的几何、规则和视觉参数。
