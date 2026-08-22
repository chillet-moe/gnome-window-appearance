# Fedora Packaging

这里将放置 Mutter RPM spec 调整、补丁注入和自动重建脚本。

部署原则：

- 基于 Fedora 对应版本的 dist-git 或 SRPM 构建；
- 通过 spec `Patch` 项应用 `mutter-patches/`；
- 使用 RPM 安装、升级、验证、降级和移除；
- 不用 `meson install` 或手工复制文件覆盖 `/usr`；
- Mutter 与 GNOME Shell 作为同一个兼容性测试集合；
- 系统更新后先重建和测试，再更新本机 compositor 包。

初期可使用 DNF5 versionlock 防止官方包意外覆盖本地构建，但锁定只是短期保护，不能替代跟进安全更新和 bugfix。
