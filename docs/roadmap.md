# 路线图

## 阶段 0：研究基线

- [x] 定位现有扩展在小数缩放下的主要模糊链路。
- [x] 区分 `frameRect`、`bufferRect` 与 compositor 阴影边界。
- [x] 确定扩展原型与 Mutter 原生实现并行、递进的仓库结构。
- [ ] 保存空 `Shell.GLSLEffect` 的 200%/250%/300% 对照实验。
- [ ] 建立 JetBrains Runtime、GTK、Qt、Electron 和 XWayland 测试窗口清单。

退出条件：模糊根因有可重复实验，测试截图和环境信息可供后续实现对比。

## 阶段 1：扩展原型

- [x] 搭建最小 GNOME Shell 扩展。
- [ ] 记录窗口 actor tree、正文纹理节点和 subsurface 行为。
- [x] 实现 `frameRect` 相对 `bufferRect` 的矩形 clip。
- [x] 在主内容节点验证无整窗 FBO 的圆角 alpha mask。
- [x] 实现独立统一阴影。
- [ ] 覆盖移动、缩放、最大化、全屏、overview 和工作区切换。
- [ ] 输出按 Shell 版本分类的兼容性与已知限制。

退出条件：扩展方案在目标 GNOME 版本上可日常使用，或存在经过测试证明无法绕过的 API/渲染限制。

## 阶段 2：Mutter 设计与最小补丁

- [x] 选定窗口 surface tree 的原生裁切入口。
- [ ] 选定不引入额外整窗采样的圆角实现位置。
- [ ] 明确 compositor 阴影与现有 shape/阴影代码的所有权。
- [ ] 把实现拆成可独立审查的最小补丁。
- [x] 在 nested GNOME Shell 中完成首个矩形裁切补丁的 smoke test 和渲染对比。

退出条件：原生路径满足清晰度与几何成功标准，补丁没有依赖扩展中的 actor monkey patch。

## 阶段 3：Fedora 打包

- [ ] 建立 Fedora spec patch 注入方式。
- [ ] 实现针对当前 Fedora Mutter 包的自动重建脚本。
- [ ] 为产物添加可追溯的本地 release 标识。
- [ ] 验证安装、登出重登、降级和 `dnf5 distro-sync` 回退。
- [ ] 建立更新检测、自动重建和失败时停止升级的流程。

退出条件：不手工覆盖系统文件即可安装和回退；Fedora 小版本更新能够自动重建或明确失败。

## 阶段 4：长期维护与上游化

- [ ] 减少版本相关代码和补丁冲突面。
- [ ] 评估哪些通用能力适合提交到 Mutter 上游。
- [ ] 为 GNOME 大版本更新维护兼容矩阵。
- [ ] 视多机需求决定是否使用 COPR。

## 当前下一步

Mutter 50.4 的首个原生补丁已在 Wayland surface-container 层实现可选的
window geometry 矩形裁切，并通过 250% 无头嵌套测试。下一步在
`MetaShapedTexture` pipeline 中实现不创建整窗 FBO 的圆角 alpha，同时为
最大化/全屏状态切换增加自动化覆盖；随后再确定 compositor 阴影所有权。
