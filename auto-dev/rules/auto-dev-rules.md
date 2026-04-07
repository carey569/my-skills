# auto-dev 规则参考

> 本文件仅作为文档参考。v0.3.0 起不再注入到 CLAUDE.md，所有规则已内嵌到各命令文件中。

## 环境探测规则

所有 auto-dev 相关 skill（`/auto-dev`、`/fix-bug`、`/add-feature`）在开始前必须执行环境探测：

1. 检查项目根目录是否存在 `.auto-dev.yaml`
   - 存在 → 读取 `project.language`、`commands.test`、`commands.build` 等配置
   - 不存在 → 自动探测：

| 特征文件 | 语言 | 默认 test_cmd | 默认 build_cmd |
|----------|------|--------------|----------------|
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `package.json` | TypeScript/JS | `npm test` | `npm run build` |
| `pyproject.toml` / `requirements.txt` | Python | `pytest` | `python -m build` |
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |
| `pom.xml` | Java (Maven) | `mvn test` | `mvn package` |
| `build.gradle` / `build.gradle.kts` | Java (Gradle) | `gradle test` | `gradle build` |

2. 检查是否存在 `scripts/verify.sh`，记录备用
3. 检查是否存在 `test-specs/` 目录

## 任务复杂度分级

| 级别 | 标准 | 流程 |
|------|------|------|
| **S** | 单文件改动，逻辑简单 | 直接实现 → 跑已有测试 |
| **M** | 2-3 文件，逻辑清晰 | 先写测试 → 再写实现 → 验证 |
| **L** | 4+ 文件或跨模块 | 生成 test-spec → 人审批 → Agent T 写测试 → Agent C 实现 → 验证 |
| **XL** | 架构变更或新子系统 | 同 L，增加设计评审和分阶段交付 |

## 核心规则

1. **先理解再动手**：修改任何代码前，必须先读取相关文件理解上下文
2. **测试与实现分离**：L/XL 任务使用独立 Agent 分别负责测试和实现
3. **冻结边界**：用户审批过的文件通过 SHA-256 校验和强制保障完整性
4. **自愈循环上限**：单元测试最多 5 轮，集成测试最多 3 轮
5. **错误脱敏**：面向用户的错误信息不得暴露内部路径、堆栈或敏感配置
6. **进度可恢复**：所有阶段性进展记录到 `.progress/status.md`

## 可用技能

- `/auto-dev` — 自动开发全流程（路由到子命令）
- `/auto-dev-init` — 项目环境探测
- `/auto-dev-spec` — 测试规格生成
- `/auto-dev-run` — 自动编码验证循环
- `/auto-dev-report` — 验收报告
- `/auto-dev-resume` — 恢复中断的流程
- `/fix-bug` — 定位并修复 bug
- `/add-feature` — 添加新功能
