# Changelog

## 0.3.0 (2026-04-07)

### Breaking Changes
- `install.sh` no longer injects rules into `~/.claude/CLAUDE.md` — all rules are now self-contained in command files
- Running `install.sh` will auto-clean legacy CLAUDE.md injections from v0.1.0/v0.2.0

### New Features
- **One-liner install**: `curl -fsSL https://raw.githubusercontent.com/carey569/my-skills/master/install.sh | bash`
- install.sh auto-detects local vs remote mode: clones if needed, pulls if already installed
- Remote uninstall via `curl ... | bash -s -- --uninstall`

### Improvements
- Command files are fully self-contained — no external rule injection needed
- "先理解再动手" and "错误脱敏" rules merged into each command's 执行原则/重要原则
- `auto-dev/rules/auto-dev-rules.md` retained as documentation reference only
- Simpler install: only symlinks, no file injection, no markers to maintain

## 0.2.0 (2026-04-07)

### Breaking Changes
- `.auto-dev.yaml` schema 重构：`project.test_cmd` → `commands.test`，`project.build_cmd` → `commands.build`
- test-spec 模板统一使用 `cases` 作为列表键（原 `specs`）

### New Features
- **子命令拆分**：`/auto-dev` 拆分为 `/auto-dev-init`、`/auto-dev-spec`、`/auto-dev-run`、`/auto-dev-report`、`/auto-dev-resume`
- **进度恢复**：新增 `/auto-dev-resume` 命令，支持中断后恢复流程
- **冻结文件校验**：SHA-256 checksum 强制保障冻结文件完整性
- **Monorepo 支持**：`.auto-dev.yaml` 新增 `modules` 字段，init 流程自动检测多模块结构
- **install.sh 升级**：支持 `--uninstall`，规则注入使用 BEGIN/END markers 支持版本升级
- **.gitignore 指引**：init 流程提示用户配置 .gitignore

### Improvements
- 环境探测逻辑去重，三个命令共享 rules 中的探测规则
- test-spec 模板增加 `spec_id`、`priority`、`source` 等字段
- verify.sh 模板增加 Phase 0 冻结文件校验步骤
- 进度文件增加任务描述、当前阶段、最后更新时间

## 0.1.0 (2026-04-03)

- Initial release
- Core skills: `/auto-dev`, `/fix-bug`, `/add-feature`
- Language support: Go, Python, TypeScript, Rust, Java
- Auto-inject rules into CLAUDE.md
- Project environment auto-detection
- Spec-driven test separation (Agent T / Agent C)
- Self-healing verification loop
- Test injection mechanism for E2E without real external APIs
