# Pasty（macOS 剪贴板工具）

Pasty 是一个 **macOS 菜单栏剪贴板历史工具**：自动捕获剪贴板内容（当前以文本为主），提供快速搜索、预览、复制/粘贴回上一应用的工作流，并将所有数据可靠地落在本地一个目录中，便于迁移与备份。

> 这是一个“UI（Swift/SwiftUI） + Core（Go + SQLite）”的双层架构项目：
> - SwiftUI 负责体验与系统集成（菜单栏、面板、快捷键、权限等）
> - Go Core 负责数据模型、持久化、搜索、导入导出与维护操作

---

## 主要功能

- **剪贴板历史（本地）**
  - 捕获剪贴板内容并保存到本地数据库（SQLite）
  - 列表浏览、搜索、预览
  - 固定（Pin）与清理历史

- **面板交互（高效键盘流）**
  - 菜单栏常驻
  - 快捷键呼出面板（可配置）
  - 键盘上下选择，**Enter** 触发复制/粘贴动作（依赖系统权限，见下文）
  - **Esc** 关闭

- **隐私与存储可控**
  - 支持“隐私模式”（停止捕获新内容）
  - 所有持久化数据集中在一个目录，方便迁移/备份

- **维护与迁移**
  - 支持 optimize / vacuum / integrity_check 等数据库维护操作
  - 支持目录级 **导出/导入**（导入可保留备份）

---

## 项目结构（高层）

- `core/`：Go 核心库（导出 C ABI），负责存储/搜索/导入导出等
- `macos/`：macOS SwiftUI App
  - `macos/ClipboardToolApp/`：SwiftPM 工程（`swift build` 可直接编译）
  - `macos/Xcode/`：Xcode 工程（由 XcodeGen 生成，便于打包/分发）
- `scripts/`：构建与发布脚本

更详细的分层与依赖规则见：`docs/architecture/macos.md`。

---

## 开发环境要求（macOS）

- macOS 14+
- Xcode（以及 Command Line Tools）
- Homebrew
- Go（用于编译 core 动态库）
- XcodeGen（用于生成/维护 Xcode 工程）

---

## 快速开始（新机器）

前提：你已经 clone 了仓库，并且 OpenClaw 环境已经单独准备好（如果你要和“小爱”协作开发）。

在仓库根目录执行：

```bash
./scripts/bootstrap_dev_macos.sh
```

如果你只想跑 SwiftPM/Go 构建，不想执行最后的 Xcode build：

```bash
./scripts/bootstrap_dev_macos.sh --skip-xcodebuild
```

脚本会完成：
- 安装依赖（`go`、`xcodegen`）
- 生成 Xcode 工程（XcodeGen）
- 编译 Go core 动态库
- `swift build`（SwiftPM）
- 可选 `xcodebuild`（Xcode Debug build）

---

## 常用构建命令

### 生成 Xcode 工程（必须由 XcodeGen 维护）

```bash
./scripts/gen_xcodeproj.sh
```

### 构建 Go Core 动态库

```bash
./scripts/build_core.sh
```

### SwiftPM 构建（macOS App）

```bash
cd macos/ClipboardToolApp
swift build
```

---

## 自动粘贴权限说明（重要）

当通过全局快捷键呼出面板并使用 **Enter** 执行“粘贴回上一应用”的流程时，应用会尝试：
1) 将选中项写入系统剪贴板
2) 切回上一应用
3) 发送合成按键（Cmd+V）完成粘贴

这通常需要你在：
- 系统设置 → 隐私与安全 → **辅助功能（Accessibility）**
- （部分系统）**输入监控（Input Monitoring）**

授予权限。

如果缺少权限，复制到剪贴板仍然可用，但自动粘贴可能失败。

---

## 发布（GitHub Actions：DMG）

本仓库配置了基于 tag 的自动发布：

- 推送符合 `vX.Y.Z` 的 tag 会触发 GitHub Actions（macos-14）
- 工作流会构建 DMG 并自动创建 GitHub Release

示例：

```bash
git tag -a v0.2.1 -m "Pasty 0.2.1"
git push origin v0.2.1
```

工作流文件：`.github/workflows/release-dmg.yml`

---

## 相关文档

- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)：开发指南与构建流程
- [docs/spec/](docs/spec/)：产品与功能规格（V1）
- [docs/design/](docs/design/)：UI/UX 与功能设计规格
- [docs/architecture/](docs/architecture/)：技术架构文档
- [docs/planning/](docs/planning/)：任务清单与待办事项
- [CHANGELOG.md](CHANGELOG.md)：版本变更

---

## 许可证

（待补充）
