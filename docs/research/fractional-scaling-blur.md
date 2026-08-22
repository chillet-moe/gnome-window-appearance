# 小数缩放模糊调查

## 结论

现有圆角扩展在 250% 等非整数缩放下出现整窗模糊，高概率由作用于整个窗口 actor 的 `Shell.GLSLEffect` 引起。

`Shell.GLSLEffect` 基于 `ClutterOffscreenEffect`。它先把 actor 绘制到离屏纹理，再把离屏结果绘制到输出。当真实 resource scale 为 `2.5` 时，Clutter 会按向上取整后的 `3` 分配资源纹理，并在线性过滤下映射回 `2.5` 倍输出。这给窗口正文增加了一次无法保持像素对应关系的重采样：

```text
客户端 buffer / 窗口纹理
          │
          ▼
按 ceil(2.5) = 3 分配的离屏 FBO
          │  linear sampling
          ▼
2.5 倍屏幕输出
```

文字、细线和高对比度边缘因此软化。整数缩放时离屏资源与输出的比例一致，现象通常不明显。

## 为什么圆角 shader 不是主要原因

被调查的圆角 shader 主要修改已有输出颜色的 alpha，并没有自行再次调用 `texture()` 对窗口内容采样。圆角距离场或 `pixelStep` 计算错误可能破坏边缘形状，但不足以解释整个窗口正文都变软。

因此应分别处理两个问题：

- 内容清晰度：避免整窗 offscreen effect 和额外重采样。
- 圆角质量：在最终合成采样处修改 alpha，或使用不会先栅格化整窗的裁切机制。

## 窗口几何

GNOME Shell 扩展可读取：

```js
const frameRect = window.get_frame_rect();
const bufferRect = window.get_buffer_rect();
```

- `frameRect` 是用户感知的窗口边界；Wayland 下通常对应客户端声明的 `xdg_surface.window_geometry`。
- `bufferRect` 是参与合成的 buffer/surface tree 外接边界，可能包括透明装饰或客户端阴影。
- 两者之差可用于计算正文相对 buffer 的 inset。

对正确声明 window geometry 的 JetBrains Runtime 窗口，扩展通常并非“无法知道正确边界”；真正的限制是 GNOME Shell 扩展缺少一个稳定接口，能够对整个 Wayland surface tree 按该边界做圆角裁切，同时避免整窗离屏渲染。

## 扩展路线的待验证方案

扩展原型应拆分职责：

1. 在 `Meta.WindowActor` 层按 `frameRect` 应用普通矩形 clip，裁掉正文外的客户端阴影。
2. 只在主 `Meta.ShapedTexture` 或等价内容节点上应用圆角 alpha mask。
3. 使用独立 actor 绘制 compositor 风格的统一阴影。
4. 不在整个窗口 actor 上挂 `Shell.GLSLEffect`。

矩形 clip 有机会使用 scissor 或 stencil，主纹理 alpha mask 也有机会避免整窗中间 FBO。不过 `Meta.ShapedTexture` 和 actor 层级并不是稳定的 Shell Extension API，仍需实际验证：

- Wayland subsurface 是否随预期被矩形裁掉；
- overview clone、工作区切换和窗口动画中的 clip/mask 生命周期；
- XWayland shape mask 与自定义圆角是否冲突；
- 跨 GNOME 版本的内部 actor 结构变化。

## 原生路线

若扩展 API 无法在所有路径中无损裁切，应把实现下沉到 Mutter 的窗口内容绘制和阴影阶段。原生实现的目标不是修补 `ClutterOffscreenEffect` 的所有用途，而是让窗口圆角与阴影不需要经过通用整窗 offscreen effect。

预期优势：

- 可访问完整的 surface tree、window geometry 和 compositor 状态；
- 能在最终纹理采样或合成 pipeline 中应用 alpha 裁切；
- 可统一处理普通窗口、动画、overview clone 和 subsurface；
- 能由 compositor 直接拥有阴影。

代价是 Mutter 内部 API 和 ABI 会随 GNOME 大版本变化，因此补丁必须保持小而聚焦，并通过 Fedora 自动重建流程持续验证。

## 可证伪验证

以下实验用于确认根因，而不是直接作为产品实现：

1. 在测试窗口上挂一个不修改颜色的空 `Shell.GLSLEffect`。
2. 分别在 200%、250% 和 300% 下截取相同静态内容。
3. 对比无 effect、空 effect、当前圆角 effect 三组结果。
4. 若空 effect 在 250% 下产生同类模糊，即可把问题定位到 offscreen 路径，而非圆角 GLSL。
5. 临时切换过滤方式只能帮助理解采样链路，不能作为最终修复。

测试还应记录每一阶段的逻辑尺寸、resource scale、FBO 像素尺寸和最终输出尺寸，避免只凭肉眼判断。

## 相关资料

- [Mutter `clutter-offscreen-effect.c`](https://gitlab.gnome.org/GNOME/mutter/-/blob/gnome-50/clutter/clutter/clutter-offscreen-effect.c)
- [Clutter Actor `get_resource_scale()`](https://gnome.pages.gitlab.gnome.org/mutter/clutter/method.Actor.get_resource_scale.html)
- [Wayland `xdg_surface.set_window_geometry`](https://wayland.app/protocols/xdg-shell#xdg_surface:request:set_window_geometry)

这些结论来自对 Rounded Window Corners Reborn 绘制路径、Mutter 50 offscreen effect 实现以及本机 JetBrains Runtime Wayland 阴影实现的联合调查。进入实现阶段后，应把关键实验结果和对应 Mutter commit 固化到测试记录中。
