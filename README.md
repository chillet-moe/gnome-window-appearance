# GNOME Window Appearance

为 GNOME Wayland 会话提供统一的窗口圆角与阴影，同时避免在非整数缩放下损失窗口内容清晰度。

本仓库并行维护两条实现路线：

- `extension/`：无需修改系统的 GNOME Shell 扩展，优先用于验证窗口几何、规则与视觉效果。
- `mutter-patches/`：集成到 Mutter 合成路径中的原生实现，目标是获得正确的 surface tree 裁切、稳定动画和无额外整窗重采样的高质量结果。

Fedora RPM 的构建和更新维护放在 `packaging/fedora/`，跨实现的验证放在 `tests/`。

## 当前状态

项目已完成针对 Fedora 44 / Mutter 50.4 的原生裁切、圆角 alpha 与 compositor
阴影补丁，并通过 250% 嵌套 Shell、真实 `wl_subsurface`、窗口状态和 Overview
clone 回归测试。实现只在现有 surface texture pipeline 中乘入圆角 coverage，
不会引入整窗离屏渲染和二次缩放；当前工作重点是 Fedora RPM 打包与回滚。

当前优先级：

1. 以 Fedora SRPM patch 的方式构建带可追溯 release 标识的 Mutter RPM。
2. 验证 RPM 安装、重新登录、降级和 `dnf5 distro-sync` 回滚。
3. 扩大客户端、缩放倍率、工作区和真实应用测试矩阵。

## 仓库结构

```text
extension/          GNOME Shell 扩展实现
mutter-patches/     Mutter 原生补丁栈
packaging/fedora/   RPM spec 与自动重建脚本
tests/              测试场景、基准与回归测试
docs/               需求、研究、架构与路线图
```

从 [文档索引](docs/README.md) 开始了解项目。
