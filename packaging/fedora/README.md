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

## 开发构建

`scripts/prepare-mutter-source.sh` 默认读取当前已安装 `mutter` 包的
`SOURCERPM`，下载完全匹配的源码包并按编号应用 `mutter-patches/`。也可以把
本地 SRPM 路径作为第一个参数传入。`scripts/build-mutter.sh` 在隔离的
`_build/mutter/` 下构建，不会向 `/usr` 安装文件。

运行：

    ./scripts/test-mutter-patches.sh

若缺少构建依赖，可按匹配的 SRPM 安装：

    sudo dnf5 builddep ./mutter-50.4-1.fc44.src.rpm

## 可安装 RPM

以下流程会重新解包精确匹配的 Fedora SRPM，把编号补丁声明为 spec 的
`Patch9001...` 并交给 `%autosetup -S git` 严格应用。Release 使用
`1.gwa2.fc44` 形式，高于同一 Fedora release，但新的 Fedora release 仍能被
更新检测发现。所有工作目录和产物都位于 `_build/fedora/`。

    ./packaging/fedora/build-rpms.sh
    ./packaging/fedora/verify-rpms.sh
    ./packaging/fedora/test-rpms.sh
    ./packaging/fedora/test-scale-matrix.sh

构建会生成主包、当前已安装的子包、测试/调试子包、SRPM，以及包含上游 SRPM、
GNOME Shell 精确 baseline、仓库 commit 和补丁/RPM SHA-256 的
`_build/fedora/build-metadata.txt`。主 Mutter 包精确依赖该 GNOME Shell EVR，
防止系统更新留下新 Shell + 旧 patched Mutter。
`test-rpms.sh` 会直接从最终主 RPM 解包 release/LTO 优化后的 core libmutter，
并用它运行与开发构建相同的 250% 嵌套渲染回归，不安装系统包。
`test-scale-matrix.sh` 进一步对同一优化库依次运行 200%、250% 和 300% 回归，
每个倍率的截图与日志保存在独立 artifact 目录。

安装脚本只升级当前已经安装的 Mutter 子包。它会先把这些包的官方 RPM 下载到
`_build/fedora/rollback/`，保存精确版本清单与安装前的完整 experimental feature
列表，再从禁用仓库的本地事务安装，最后在不覆盖其他 feature 的前提下启用
`window-appearance`：

    ./packaging/fedora/install-rpms.sh

也可以在安装前单独准备并审计离线回滚集合：

    ./packaging/fedora/cache-rollback.sh

安装后需登出并重新登录。恢复官方包及原有 feature 列表：

    ./packaging/fedora/verify-live-session.sh

    ./packaging/fedora/rollback-rpms.sh

回滚只使用安装前缓存的精确 RPM，并原样恢复 feature 列表，不依赖当时的网络
或仓库状态。也可在官方包仍可用时执行 `sudo dnf5 distro-sync 'mutter*'`，但缓存
回滚更可预测。

离线回滚仅适用于 GNOME Shell 仍等于安装前 baseline 的情况。Shell 已更新或图形
登录异常时，使用当前 Fedora 仓库同步整个已安装栈：

    ./packaging/fedora/recover-official.sh

完整的系统更新顺序与 TTY 恢复步骤见
[`docs/system-update-runbook.md`](../../docs/system-update-runbook.md)。

## 更新门禁

`rebuild-update.sh` 查询当前架构最新的 Fedora Mutter，并比较构建时与当前 GNOME
Shell baseline。两者均未变化时直接退出；任一变化时，依次执行严格补丁重放、
核心库编译、nested Shell 回归、Fedora RPM 构建、摘要/精确依赖验证和优化 RPM
三倍率矩阵。任何一步失败都会停止，且不会自动安装：

    ./packaging/fedora/rebuild-update.sh

不建议只 versionlock Mutter：这会增加新 GNOME Shell 与旧 compositor 混用的
风险。系统更新前应先恢复官方栈；不要用 versionlock 代替安全更新跟进。
