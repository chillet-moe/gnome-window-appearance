# 文档索引

- [目标与边界](problem-statement.md)：项目要解决的问题、成功标准和非目标。
- [小数缩放模糊调查](research/fractional-scaling-blur.md)：已确认的渲染链路、证据、待验证假设。
- [架构](architecture.md)：扩展、Mutter 补丁、Fedora 打包和测试之间的职责边界。
- [路线图](roadmap.md)：从实验基线到可日常使用 RPM 的阶段计划。
- [扩展测试记录](extension-test-results.md)：GNOME 50、250% 缩放下的当前结果与限制。
- [Mutter 补丁测试记录](mutter-test-results.md)：原生补丁的构建、加载与渲染验证。

文档中的“窗口边界”默认指用户感知的正文边界，而不是客户端提交的全部 buffer 或 surface tree 外接矩形；需要区分时会明确使用 `frameRect` 和 `bufferRect`。
