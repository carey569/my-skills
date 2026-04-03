# auto-dev

AI 开发验证流程 Skill，核心理念：**人审方案，机器执行**。

auto-dev 将开发流程拆分为四个阶段：人类负责审批测试规格和验证方案，AI 负责生成测试、编写实现和自动验证。测试与实现由独立 Agent 分别完成，避免"球员兼裁判"。

## 安装

```bash
git clone git@github.com:carey569/my-skills.git ~/.claude/skills
cd ~/.claude/skills
bash install.sh
```

安装脚本会将 skill 命令链接到 `~/.claude/commands/`，并将核心规则注入 `~/.claude/CLAUDE.md`。

## 可用 Skill

| 命令 | 用途 | 适用场景 |
|------|------|---------|
| `/auto-dev` | 完整开发验证流程 | 新模块开发、功能实现 |
| `/fix-bug` | Bug 修复流程 | 先复现再修复，test-first |
| `/add-feature` | 新功能添加 | 在已有模块上扩展功能 |

## 快速开始

```
# 1. 在 Claude Code 中输入
/auto-dev

# 2. auto-dev 自动探测项目环境，生成 .auto-dev.yaml
#    检查语言、测试命令、基础设施配置

# 3. 描述你的需求，auto-dev 会：
#    - 生成 test-spec → 请你审批
#    - Agent T 写测试 → Agent C 写实现
#    - 自愈循环验证 → 输出验收报告
```

## 配置文件

项目根目录的 `.auto-dev.yaml` 控制 auto-dev 行为：

```yaml
version: "0.1.0"

project:
  language: "go"                # go / python / typescript / rust / java
  test_cmd: "go test ./..."     # 测试命令
  build_cmd: "go build ./..."   # 构建命令
  lint_cmd: "golangci-lint run" # lint 命令 (可选)

infra:
  container: docker-compose     # docker-compose / dockerfile / null
  compose_file: "docker-compose.yaml"
  database: mysql               # mysql / postgres / sqlite / null
  cache: redis                  # redis / null

policy:
  unit_max_retries: 5           # 单元测试自愈上限
  integration_max_retries: 3    # 集成测试自愈上限
  complexity_threshold: 3       # 几个文件以上算 L 级别
  require_approval: true        # 是否要求人审批验证方案

frozen_files: []                # Phase B 审批后自动追加
```

如果项目中没有该文件，auto-dev 会自动探测并生成。

## 支持的语言

| 语言 | 探测依据 | 默认测试命令 |
|------|---------|-------------|
| Go | `go.mod` | `go test ./...` |
| Python | `pyproject.toml` / `requirements.txt` | `pytest` |
| TypeScript | `package.json` + `.ts` 文件 | `npm test` |
| Rust | `Cargo.toml` | `cargo test` |
| Java | `pom.xml` / `build.gradle` | `mvn test` / `gradle test` |

## 工作流程

```
Phase A: 需求分析 & 环境探测
  +--------------------------+
  | 读取需求 → 探测项目环境  |
  | 评估复杂度 (S/M/L/XL)   |
  | 生成 test-spec           |
  +--------------------------+
            |
            v
Phase B: 人工审批                    <-- 人类审批
  +--------------------------+
  | 审批 test-spec           |
  | 审批 verify.sh           |
  | 冻结测试规格             |
  +--------------------------+
            |
            v
Phase C: 全自动实现 & 验证           <-- 机器执行
  +--------------------------+
  | Agent T: 生成测试代码    |
  | Agent C: 编写实现代码    |
  | 自愈循环 (最多 5 轮)     |
  | 运行 verify.sh           |
  +--------------------------+
            |
            v
Phase D: 验收报告
  +--------------------------+
  | 测试结果汇总             |
  | 回归风险评估             |
  | 人工最终确认             |
  +--------------------------+
```

## 任务复杂度分级

| 级别 | 标准 | 流程 |
|------|------|------|
| **S** | 单文件改动，逻辑简单 | 直接实现 -> 跑已有测试 |
| **M** | 2-3 文件，逻辑清晰 | 先写测试 -> 再写实现 -> 验证 |
| **L** | 4+ 文件或跨模块 | test-spec -> 人审批 -> Agent T -> Agent C -> 验证 |
| **XL** | 架构变更或新子系统 | 同 L，增加设计评审和分阶段交付 |

## 常见问题

**Q: auto-dev 和直接让 AI 写代码有什么区别？**
A: 直接让 AI 写代码是"球员兼裁判"——自己写自己测。auto-dev 用独立的 Agent T 写测试、Agent C 写实现，测试规格经人审批后冻结，实现阶段不可篡改。

**Q: 如果自愈循环 5 轮后仍然失败怎么办？**
A: auto-dev 会停止执行，输出每轮的尝试和失败原因，请你介入。你可以调整 test-spec、放宽断言条件，或手动提示修复方向。

**Q: frozen_files 是什么？为什么不能改？**
A: 这是 Phase B 人工审批后冻结的文件列表，包括 test-spec、测试代码和 verify.sh。冻结保证"验收标准不被实现者篡改"，这是整个方法论的核心约束。

**Q: 小改动也需要走完整流程吗？**
A: 不需要。S 级任务（单文件、逻辑简单）直接实现并跑已有测试即可。完整流程只在 L/XL 级别任务中启用。

**Q: 能不能跳过人工审批？**
A: 可以在 `.auto-dev.yaml` 中设置 `require_approval: false`。但不推荐在 L/XL 任务中这样做，因为没有人审批的测试规格容易遗漏边界情况。

**Q: 项目没有现成的测试怎么办？**
A: auto-dev 会从零开始生成测试。它先生成 test-spec（测试规格），你审批后 Agent T 生成具体测试代码。不依赖项目已有测试。

## 更多文档

- [方法论详解](docs/methodology.md) -- 完整的四阶段方法论和设计原理
- [Go Web 服务示例](docs/examples/go-web-service.md)
- [Python CLI 工具示例](docs/examples/python-cli.md)
- [TypeScript React 示例](docs/examples/typescript-react.md)
- [Rust CLI 工具示例](docs/examples/rust-cli.md)
- [Java Spring Boot 示例](docs/examples/java-spring.md)

## 版本

当前版本：0.1.0

## License

MIT
