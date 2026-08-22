# Mutter Patches

这里将保存按应用顺序编号的 Mutter 原生补丁。

补丁目标是直接在合成路径中实现窗口正文裁切、圆角 alpha 和 compositor 阴影，不增加整窗离屏重采样。每个补丁应保持单一职责，并在提交说明中记录适用的 Mutter 分支、依赖关系和对应测试。

Fedora spec 或构建环境修改属于 `packaging/fedora/`，不应混入功能补丁。
