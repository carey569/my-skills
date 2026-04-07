# /auto-dev-init — 项目环境探测

探测项目环境，生成 `.auto-dev.yaml` 配置文件。

---

## 执行逻辑

### 1. 扫描项目根目录

依据特征文件探测语言和工具链：

| 特征文件 | 语言/平台 | test_cmd | build_cmd |
|----------|-----------|----------|-----------|
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `package.json` | TypeScript / Node | `npm test` | `npm run build` |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | `pytest` | `python -m build` |
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |
| `pom.xml` | Java (Maven) | `mvn test` | `mvn package` |
| `build.gradle` / `build.gradle.kts` | Java (Gradle) | `gradle test` | `gradle build` |

### 2. Monorepo 检测

如果项目根目录同时存在多种语言的特征文件，或存在 `packages/`、`services/`、`apps/` 等目录结构：
- 扫描各子目录，为每个子模块独立探测语言和命令
- 在 `.auto-dev.yaml` 中生成 `modules` 列表
- 顶层 `project` 字段记录主语言或标记为 `monorepo`

### 3. 探测容器化配置

- `docker-compose.yaml` 或 `docker-compose.yml` → `container: docker-compose`
- `Dockerfile` → 记录但不自动启用容器流程

### 4. 探测基础设施依赖

扫描配置文件（`.env`、`application.yaml`、`config/` 等）中的连接信息：
- 数据库：PostgreSQL、MySQL、SQLite、MongoDB
- 缓存：Redis、Memcached
- 消息队列：Kafka、RabbitMQ

### 5. 探测已有测试结构

- 查找已有测试文件的位置和命名模式
- 检查是否有 CI 配置（`.github/workflows/`、`.gitlab-ci.yml` 等）

### 6. 生成 `.auto-dev.yaml`

写入项目根目录，格式参照 `templates/auto-dev.yaml.tmpl`。

### 7. 生成 .gitignore 建议

如果项目的 `.gitignore` 中没有 auto-dev 相关条目，提示用户考虑添加：

```
# auto-dev 生成的临时文件
.progress/
```

以下文件通常建议纳入版本管理（不加入 .gitignore）：
- `.auto-dev.yaml` — 项目配置，团队共享
- `test-specs/` — 测试规格，团队共享
- `scripts/verify.sh` — 集成验证脚本

### 8. 输出探测结果摘要

请用户确认或调整。
