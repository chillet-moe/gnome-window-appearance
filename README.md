# GNOME Window Appearance

为 GNOME Wayland 会话提供统一的窗口圆角与阴影，同时避免在非整数缩放下损失窗口内容清晰度。

本仓库并行维护两条实现路线：

- `extension/`：无需修改系统的 GNOME Shell 扩展，优先用于验证窗口几何、规则与视觉效果。
- `mutter-patches/`：集成到 Mutter 合成路径中的原生实现，目标是获得正确的 surface tree 裁切、稳定动画和无额外整窗重采样的高质量结果。

Fedora RPM 的构建和更新维护放在 `packaging/fedora/`，跨实现的验证放在 `tests/`。

## 当前状态

项目处于设计与原型准备阶段。已有调查表明，现有圆角扩展在小数缩放下的模糊主要来自 `Shell.GLSLEffect`/`ClutterOffscreenEffect` 引入的整窗离屏渲染和二次缩放，而不是圆角距离场计算本身。

当前优先级：

1. 建立可复现的清晰度与窗口几何测试基线。
2. 验证扩展路线能否使用矩形 clip、主纹理 alpha mask 和独立阴影避开整窗 offscreen effect。
3. 明确扩展 API 的不可绕过限制后，再将验证过的模型下沉到 Mutter。
4. 以 Fedora SRPM patch 的方式打包原生实现，并自动跟随 Fedora Mutter 更新重建。

## 仓库结构

```text
extension/          GNOME Shell 扩展实现
mutter-patches/     Mutter 原生补丁栈
packaging/fedora/   RPM spec 与自动重建脚本
tests/              测试场景、基准与回归测试
docs/               需求、研究、架构与路线图
```

从 [文档索引](docs/README.md) 开始了解项目。
