# Mutter Patches

这里将保存按应用顺序编号的 Mutter 原生补丁。

补丁目标是直接在合成路径中实现窗口正文裁切、圆角 alpha 和 compositor 阴影，不增加整窗离屏重采样。每个补丁应保持单一职责，并在提交说明中记录适用的 Mutter 分支、依赖关系和对应测试。

Fedora spec 或构建环境修改属于 `packaging/fedora/`，不应混入功能补丁。

## 当前补丁栈

1. `0001-compositor-clip-wayland-surface-trees.patch`
   - 基线：Fedora 44 的 Mutter 50.4。
   - 增加 `window-appearance` experimental feature。
   - 在 Wayland window actor 的 surface-container 层按 `frameRect` 相对
     `bufferRect` 的几何裁切完整 surface tree，因此也覆盖 subsurface 阴影。
   - 只处理 normal、dialog 和 modal-dialog；最大化与全屏时恢复原始路径。
   - 该补丁只做矩形裁切，不包含圆角 alpha 或 compositor 阴影。

开发测试可用环境变量启用，不修改用户设置：

```bash
MUTTER_DEBUG_EXPERIMENTAL_FEATURES=window-appearance gnome-shell ...
```

RPM 安装后则可写入设置并重新登录：

```bash
gsettings set org.gnome.mutter experimental-features "['window-appearance']"
```
