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
2. `0002-compositor-round-wayland-surface-trees.patch`
   - 在每个 Wayland surface 的 `MetaShapedTexture` pipeline 中乘入圆角 alpha，
     不创建整窗 offscreen framebuffer，也不额外采样窗口纹理。
   - 使用变换前的 destination texture 坐标和 fragment derivative 抗锯齿，
     覆盖分数缩放、actor transform、clone 与 subsurface。
   - 圆角启用时禁用 opaque-region bypass 与 direct scanout 判定，避免不透明
   客户端绕过 alpha；当前默认半径为 16 logical px。
3. `0003-compositor-shadow-wayland-surface-trees.patch`
   - 复用 Mutter 的缓存九宫格阴影实现，在 Wayland window actor 中先绘制一份
     compositor 阴影，再绘制完整 surface tree；不创建或重采样整窗纹理。
   - 阴影与圆角正文使用同一 frame geometry，并从阴影 clip 中减去圆角正文，
     防止透明角下方漏出阴影。
   - 分别缓存 focused/unfocused 阴影，把阴影边界并入 paint volume；阴影随
     window actor 的动画和 clone 一起变换。
   - 将实际与 X11 无关的 shadow factory/window shape 源文件改为始终构建，
     已验证 `-Dxwayland=false` 配置。
4. `0004-compositor-preserve-wayland-surface-input.patch`
   - 将 surface tree 的矩形裁切从持久的 Clutter actor clip 改为仅在 paint
     调用期间生效的 framebuffer clip，避免裁切同时限制 actor picking。
   - 保留客户端在 `frameRect` 外声明的输入区域，使 CSD 透明边框仍能发起
     `xdg_toplevel.resize`，同时继续裁掉相同区域中的客户端阴影。
5. `0005-compositor-stabilize-wayland-appearance-sync.patch`
   - 外观状态只在 compositor `before_paint` 和既有 geometry 生命周期同步，
     不再从 actor `paint` / `get_paint_volume` 中修改 pipeline 或排队下一帧。
   - 对 configure 期间短暂不一致的 frame/buffer geometry 和尚未 allocation 的
     surface 采用无裁切降级，避免窗口正文被完整裁成透明并持续重绘动画末帧。

开发测试可用环境变量启用，不修改用户设置：

```bash
MUTTER_DEBUG_EXPERIMENTAL_FEATURES=window-appearance gnome-shell ...
```

RPM 安装后则可写入设置并重新登录：

```bash
gsettings set org.gnome.mutter experimental-features "['window-appearance']"
```
