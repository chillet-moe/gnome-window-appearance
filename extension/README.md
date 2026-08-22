# GNOME Shell Extension

这里将放置无需替换系统包的 GNOME Shell 扩展。

首个原型的目标是验证：按 `frameRect` 裁掉 `bufferRect` 中的客户端阴影，只对主内容应用圆角 alpha，并由独立 actor 绘制统一阴影。默认实现不得对整个窗口 actor 使用会创建离屏 FBO 的 `Shell.GLSLEffect`。

实现开始前请先阅读 [架构](../docs/architecture.md) 和 [小数缩放模糊调查](../docs/research/fractional-scaling-blur.md)。
