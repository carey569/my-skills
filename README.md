# My Claude Code Skills

Personal skill collection for [Claude Code](https://claude.ai/claude-code).

## Skills

| Skill | Description |
|-------|-------------|
| [auto-dev](auto-dev/) | AI-driven development & verification workflow — spec-driven test separation, self-healing verification loops |

## 安装

```bash
git clone git@github.com:carey569/my-skills.git ~/.claude/skills
cd ~/.claude/skills
bash install.sh
```

安装完成后，在任意项目中打开 Claude Code 即可使用所有 skill 命令。

安装脚本做两件事：
1. 将 `commands/*.md` 符号链接到 `~/.claude/commands/`（Claude Code 的自定义命令目录）
2. 将核心规则注入 `~/.claude/CLAUDE.md`（通过 BEGIN/END markers 包裹，支持幂等更新）

## 使用方法

安装后，在 Claude Code 中直接输入斜杠命令即可调用。以下是每个命令的详细用法。

### `/auto-dev` — 完整开发流程

最常用的入口命令。输入命令后描述你的需求，auto-dev 会自动评估复杂度并选择对应流程。

```
> /auto-dev 给用户模块添加邮箱验证功能

# auto-dev 会：
# 1. 探测项目环境（语言、测试框架、基础设施）
# 2. 评估复杂度 → 假设判定为 L 级别
# 3. 生成 test-spec（测试规格）→ 等你审批
# 4. 你回复 "approved" 后，自动执行：
#    - Agent T 根据 test-spec 生成测试代码
#    - Agent C 编写实现代码
#    - 运行测试 → 失败则自动修复（最多 5 轮）
# 5. 全部通过后输出验收报告
```

**子命令**：也可以直接调用特定阶段

```
> /auto-dev init       # 仅探测环境，生成 .auto-dev.yaml
> /auto-dev spec       # 仅生成 test-spec
> /auto-dev run        # 仅执行自动编码验证循环
> /auto-dev report     # 仅生成验收报告
> /auto-dev resume     # 恢复上次中断的流程
```

**复杂度自动分级**：

| 级别 | 判定标准 | auto-dev 的处理方式 |
|------|---------|-------------------|
| **S** | 改 1-2 个文件 | 直接改代码 → 跑已有测试 |
| **M** | 改 3+ 个文件 | 先写测试 → 再改代码 → 自愈验证 |
| **L** | 新模块/跨模块 | 生成 test-spec → 人审批 → Agent T/C 分离执行 |
| **XL** | 架构变更 | 同 L + 设计评审 + 分阶段交付 |

### `/fix-bug` — Bug 修复

专为 bug 修复设计的 Test-First 流程：先写复现测试证明 bug 存在，再修代码让测试通过。

```
> /fix-bug 用户注册时如果邮箱包含大写字母会返回 500 错误

# fix-bug 会：
# 1. 分析 bug，定位相关代码，向你确认理解是否正确
# 2. 用独立 Agent 编写复现测试（不读实现代码，避免测试被实现污染）
# 3. 运行测试 → 确认 FAIL（证明 bug 存在）→ 请你确认
# 4. 修改实现代码（不改测试）→ 自愈循环最多 5 轮
# 5. 跑全量回归测试，确认没有引入新问题
# 6. 输出修复报告（根因分析 + 改动说明 + 风险评估）
```

**每一步都需要你确认**，不会在理解不清的情况下盲目操作。

### `/add-feature` — 新功能开发

Design-Test-Implement 三阶段流程，确保每个功能有清晰的设计和完备的测试覆盖。

```
> /add-feature 添加 CSV 导出功能，支持按时间范围筛选

# add-feature 会：
# 1. 分析需求，列出要修改/新增的文件，判断复杂度
# 2. 输出设计方案（接口定义、数据结构、核心流程）→ 请你审查
# 3. 提取验收用例，生成 test-spec → 请你审批并冻结
# 4. Agent T 生成测试 → Agent C 实现功能 → 自愈验证
# 5. 跑全量回归测试 + 集成验证
# 6. 输出验收报告
```

**M 级别简化流程**：如果功能较小（3-5 个文件），会跳过正式文档，直接在对话中确认方案后写测试和实现。

### `/auto-dev-resume` — 恢复中断的流程

如果上次 auto-dev 执行到一半退出了会话，下次进来可以恢复：

```
> /auto-dev-resume

# 读取 .progress/status.md，显示：
# - 上次的任务描述
# - 中断在哪个阶段（Phase A/B/C/D）
# - 测试通过进度
# 你可以选择：继续 / 重新开始 / 查看详情
```

也可以直接输入 `/auto-dev`，如果检测到未完成的任务会自动提示你是否恢复。

## 使用示例

### 示例 1：Go Web 服务添加用户接口

```
> /auto-dev 实现用户 CRUD 接口，包括创建、查询、更新、删除

# auto-dev 探测到 go.mod + docker-compose.yaml
# 生成 .auto-dev.yaml:
#   language: go, test: "go test ./...", databases: [mysql], caches: [redis]
#
# 判定复杂度: L（涉及 handler/service/repo 多层 + 数据库迁移）
#
# 生成 test-specs/user-crud.yaml，包含 8 个测试用例:
#   TC-001: 创建用户成功
#   TC-002: 创建用户邮箱重复
#   TC-003: 查询用户成功
#   TC-004: 查询不存在的用户
#   ...
#
# 你审批后，Agent T 生成 table-driven 测试，Agent C 实现代码
# 自愈 2 轮后全部通过，输出验收报告
```

### 示例 2：Python CLI 修复 bug

```
> /fix-bug 执行 mytool export --format csv 时，中文字符变成乱码

# fix-bug 分析后输出理解：
#   现象：CSV 导出中文乱码
#   疑似根因：export 函数没有指定 UTF-8 编码
#   影响范围：export 命令
#
# 你确认后，生成复现测试 test_export_chinese_characters()
# 运行测试 → FAIL ✓（bug 确认存在）
# 修复：在 open() 中添加 encoding='utf-8'
# 复现测试 PASS，回归测试 PASS
# 输出修复报告
```

### 示例 3：TypeScript React 添加功能

```
> /add-feature 在用户列表页添加搜索框，支持按姓名和邮箱模糊搜索

# 判定复杂度: M（改 3 个文件：SearchBar 组件 + UserList 页面 + API 层）
# 走简化流程：
#   方案确认 → 直接写测试 → 实现 → 验证
# 不生成正式 test-spec，直接写 React Testing Library 测试
```

## 配置

首次在项目中使用 `/auto-dev` 时，会自动探测环境并生成 `.auto-dev.yaml`。你也可以手动执行：

```
> /auto-dev init
```

### 配置文件说明

```yaml
version: "0.2.0"

project:
  name: "my-app"              # 项目名称
  language: "go"              # 语言：go / python / typescript / rust / java
  root: "."                   # 项目根路径

commands:
  test: "go test ./..."       # 测试命令
  build: "go build ./..."     # 构建命令
  lint: "golangci-lint run"   # lint 命令（可选）

infra:
  container: docker-compose   # 容器编排工具（null 表示无容器）
  compose_file: "docker-compose.yaml"
  databases: [mysql]          # 数据库依赖
  caches: [redis]             # 缓存依赖

policy:
  unit_max_retries: 5         # 单元测试自愈循环上限
  integration_max_retries: 3  # 集成测试自愈循环上限
  complexity_threshold: 3     # 改几个文件以上算 L 级别
  require_approval: true      # 是否要求人审批（建议 L/XL 保持 true）

frozen_files: []              # 审批后冻结的文件列表（自动维护）
frozen_checksums: {}          # 冻结文件的 SHA-256 校验和（自动维护）
```

### 支持的语言

| 语言 | 探测依据 | 默认测试命令 |
|------|---------|-------------|
| Go | `go.mod` | `go test ./...` |
| Python | `pyproject.toml` / `requirements.txt` | `pytest` |
| TypeScript | `package.json` + `.ts` 文件 | `npm test` |
| Rust | `Cargo.toml` | `cargo test` |
| Java | `pom.xml` / `build.gradle` | `mvn test` / `gradle test` |

## 核心机制

### 测试与实现分离

L/XL 级别任务中，测试和实现由两个独立 Agent 完成：

- **Agent T**（测试）：只读 test-spec 和接口定义，**不读实现代码**
- **Agent C**（实现）：读测试代码和需求，编写实现，**不可修改测试**

这避免了"自己写测试自己通过"的确认偏差问题。

### 冻结边界

人工审批后的文件（test-spec、测试代码、verify.sh）被冻结，实现阶段不可修改。v0.2.0 起通过 SHA-256 校验和强制保障，不再仅靠 AI 自律。

### 自愈循环

测试失败时，Agent C 自动分析原因并修复实现代码（不改测试），最多 5 轮。如果没有进展或出现回归，立即暂停并向你报告，附带诊断分析和建议。

## 升级

```bash
cd ~/.claude/skills
git pull
bash install.sh
```

`install.sh` 通过 BEGIN/END markers 管理注入的规则，升级时自动替换旧内容，无需手动清理。

## 卸载

```bash
cd ~/.claude/skills
bash install.sh --uninstall
```

会移除所有符号链接和 `CLAUDE.md` 中注入的规则。

## 更多文档

- [auto-dev 详细文档](auto-dev/README.md) — 完整配置、工作流程图、FAQ
- [方法论详解](auto-dev/docs/methodology.md) — 四阶段方法论和设计原理
- 语言示例：[Go](auto-dev/docs/examples/go-web-service.md) · [Python](auto-dev/docs/examples/python-cli.md) · [TypeScript](auto-dev/docs/examples/typescript-react.md) · [Rust](auto-dev/docs/examples/rust-cli.md) · [Java](auto-dev/docs/examples/java-spring.md)

## License

MIT
