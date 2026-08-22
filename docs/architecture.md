# 架构

## 总体策略

仓库采用“共享行为模型、两种渲染后端”的结构。扩展路线负责低风险验证和无需系统修改的可用实现；Mutter 路线负责扩展 API 无法可靠实现的合成能力。两者共享测试场景、窗口分类规则和视觉参数语义，但不强行共享与运行时绑定的代码。

```text
需求与测试场景
      │
      ├── extension/ ─────── 无系统修改的原型与兼容实现
      │       │
      │       └── 暴露 API/质量边界
      │
      └── mutter-patches/ ── 原生裁切与 compositor 阴影
              │
              └── packaging/fedora/ ── 可安装、可回退的 RPM
```

## 共享概念

### 三类边界

- 正文边界：用户认为窗口实际占据的矩形，通常对应 `frameRect`。
- buffer 边界：客户端 surface tree 的外接矩形，通常对应 `bufferRect`。
- 阴影边界：compositor 阴影的视觉范围，可超出正文边界，但不属于窗口命中测试或布局尺寸。

任何实现都不得只用一个矩形混合表达这三种含义。

### 外观策略

每个窗口经过规则判断后得到不可变的外观决策：

- 是否裁切；
- 各角半径；
- 是否绘制阴影及其参数；
- 最大化、全屏和特殊窗口状态下的覆盖规则；
- 必要时的应用级 geometry 修正。

窗口识别、策略计算与具体 actor/pipeline 操作应分离，便于让扩展和 Mutter 测试使用相同的行为用例。

## `extension/`

职责：

- 读取 `Meta.Window` 几何与状态；
- 维护窗口生命周期和 GNOME 版本兼容层；
- 验证矩形 clip、主内容 alpha mask 和独立阴影方案；
- 提供规则与视觉参数的快速迭代入口；
- 明确记录无法通过扩展可靠解决的场景。

约束：

- 禁止以作用于整个窗口 actor 的 `Shell.GLSLEffect` 作为默认圆角实现；
- GNOME 内部 API 的使用必须集中在兼容层，不散布到规则和状态管理代码中；
- overview 与 workspace 动画不是后续附加功能，而是首批测试路径。

## `mutter-patches/`

职责：

- 在拥有 surface tree 和 window geometry 的层级应用裁切；
- 在不创建额外整窗 FBO 的合成路径中实现圆角 alpha；
- 由 compositor 绘制并管理统一阴影；
- 处理动画、clone、subsurface、XWayland shape 和窗口状态变化；
- 保持补丁栈可逐个审查、重放和上游化。

补丁按依赖顺序编号。每个补丁都应说明目标、前置补丁、影响路径和对应测试，避免把 Fedora 打包修改混入功能补丁。

## `packaging/fedora/`

职责：

- 获取与当前 Fedora 匹配的 Mutter dist-git 或 SRPM；
- 将 `mutter-patches/` 以 spec `Patch` 项应用；
- 使用明确的本地 release 后缀构建 RPM；
- 生成构建元数据，记录 Fedora、Mutter、GNOME Shell、源码 commit 和补丁 commit；
- 支持安装前检查、嵌套会话 smoke test、升级和回退。

不允许使用 `meson install` 或手工复制共享库覆盖系统 Mutter。开发构建与系统部署必须分开。

## `tests/`

测试分为四层：

1. 几何与策略单元测试：inset、半径、状态和窗口规则。
2. 渲染基准：整数/非整数缩放下的像素差异和边缘质量。
3. GNOME 集成测试：生命周期、overview、工作区、最大化和全屏。
4. Fedora 包测试：构建、安装、版本升级、versionlock 与回退。

截图比较时必须区分正文区域、圆角过渡区和阴影区，不能用整图单一阈值掩盖正文模糊。

## 版本兼容

- GNOME 小版本更新：自动尝试重放和构建补丁，并运行 smoke test。
- GNOME 大版本更新：视为需要显式适配的事件，检查 actor/pipeline 内部结构与 libmutter ABI。
- 扩展 metadata 只声明实际验证过的 Shell 版本。
- Mutter 补丁和 RPM 产物必须能追溯到精确上游源码版本。
