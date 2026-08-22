# GNOME Shell Extension

这是无需替换系统包的 GNOME Shell 50 原型。

当前实现：

- 使用 `Meta.WindowActor.set_clip()` 按 `frameRect` 裁掉 `bufferRect` 外的客户端内容；
- 使用 `Meta.ShapedTexture.set_mask_texture()` 直接给主窗口纹理提供圆角 alpha mask；
- 使用独立 `St` actor 绘制统一阴影；
- 不对窗口 actor 添加 `Shell.GLSLEffect`，因此不会为圆角创建整窗离屏 FBO。

GNOME 50 的 `Meta.ShapedTexture` 只在 blended paint path 应用 mask。为避免客户端 opaque region 绕过圆角，原型把主内容 actor 的 opacity 从 255 调为 254；这不会增加整窗采样，但代价是最多一个 alpha 等级的透明度。扩展停用、窗口最大化或全屏时会恢复原值。原生 Mutter 路线不需要这一折衷。

第一版只处理 Wayland 的普通窗口、对话框和模态对话框。XWayland 暂不处理，因为公开 API 无法取得并合并 Mutter 已有的 X11 shape mask。

## 本地构建

```bash
./scripts/build-extension.sh
```

产物位于 `_build/extension/gnome-window-appearance@chillet.moe/`。集成测试使用嵌套 GNOME Shell，不会替换当前桌面 compositor，也不需要登出：

```bash
./tests/run-nested.sh
```

集成测试创建 `3200×1800` 的无头虚拟显示器，明确设置 250% 缩放，并断言最终 resource/surface scale 为 3、四角均被裁切且扩展可干净停用。需要 `mutter-devkit`、`mutter-devel`、GTK 3 开发文件和 ImageMagick。

实现开始前请先阅读 [架构](../docs/architecture.md) 和 [小数缩放模糊调查](../docs/research/fractional-scaling-blur.md)。
