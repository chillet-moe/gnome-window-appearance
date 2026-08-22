# GNOME / Mutter 系统更新与恢复

本地 patched Mutter 的 EVR 高于同一 Fedora 构建的官方包。普通 `dnf upgrade`
不会主动把更高 EVR 的本地包降级为官方包，而 GNOME Shell 在 ABI 未变化时也未必
要求精确的 Mutter EVR。因此如果没有额外约束，确实可能出现“GNOME Shell 已更新，
Mutter 仍是旧 patched build”的未测试组合。

## 一致性 guard

从 `gwa2` 起，本地主 `mutter` RPM 精确依赖构建/测试时的 GNOME Shell EVR，例如：

    gnome-shell(x86-64) = 50.4-1.fc44

检查当前包：

    rpm -q --requires mutter | rg '^gnome-shell'

系统更新若想单独升级 GNOME Shell，DNF 必须同时用兼容的 Mutter 替换本地包；普通
`upgrade` 不会把更高 EVR 的本地包隐式降级，所以事务会保留旧 Shell 或报告依赖
冲突，而不会静默生成新 Shell + 旧 patched Mutter。不要用 `--skip-broken`、删除
依赖或强制 `rpm --nodeps` 绕过该门禁。

这个 guard 会有意阻止 GNOME Shell 安全更新，直到恢复官方栈或生成匹配的新构建；
它不是 versionlock，也不能代替及时更新。

## 推荐的系统更新流程

更新前先回到安装 patch 之前缓存的同版本官方 Mutter：

    cd ~/Projects/gnome-window-appearance
    ./packaging/fedora/rollback-rpms.sh
    sudo dnf5 upgrade --refresh
    sudo systemctl reboot

重启后先在完整官方栈上确认桌面可用，再为当前已安装的 GNOME Shell/Mutter 重建：

    ./packaging/fedora/rebuild-update.sh

该命令同时比较 Mutter SRPM 和 GNOME Shell 精确 NEVRA。即使 Mutter 源码包没有
变化，只要 Shell 更新过，也会重新注入补丁、编译并运行 nested 与优化 RPM 的
200%/250%/300% 回归。成功后才重新安装：

    ./packaging/fedora/install-rpms.sh

安装后登出并重新登录，再由用户确认真实桌面的视觉效果。

## 回到原版

如果 GNOME Shell 自安装 patch 后没有更新，优先使用完全离线、可重复的精确回滚：

    ./packaging/fedora/rollback-rpms.sh

脚本会原样恢复安装前的 Mutter 子包和 experimental feature 列表。它会比较当前
GNOME Shell 与缓存 baseline；若 Shell 已变化，会拒绝把旧 Mutter 塞回新桌面。

如果系统已经更新过 GNOME Shell/Mutter，或离线回滚拒绝执行，使用当前 Fedora
仓库同步所有已经安装的 GNOME Shell/Mutter 包：

    ./packaging/fedora/recover-official.sh
    sudo systemctl reboot

`recover-official.sh` 不使用旧缓存，也不安装新的可选包；它只对当前已经安装且名称
匹配 `gnome-shell*` / `mutter*` 的包执行 `distro-sync`，并移除
`window-appearance` feature。联网恢复后再按上面的重建流程生成新 patch。

## 已经出现新 GNOME + 旧 patched Mutter

如果桌面仍可用，不要先登出；在终端运行 `recover-official.sh`，完成后重启。

如果图形登录失败：

1. 按 `Ctrl+Alt+F3` 进入 TTY 并登录；
2. 进入本仓库；
3. 运行 `./packaging/fedora/recover-official.sh`；
4. 运行 `sudo systemctl reboot`。

不要在 GNOME 已更新后强制运行旧 `rollback-rpms.sh`，也不要只手工替换
`libmutter`。若网络不可用，应等待网络恢复或使用与当前 Fedora 仓库一致的完整
RPM 集合；旧离线缓存只保证安装 patch 当时的桌面 baseline。
