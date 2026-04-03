# /auto-dev — AI 开发验证流程

> 规格驱动测试分离 + 自愈验证循环

核心理念：**人审方案，机器执行**。人类负责审批设计文档和测试规格，AI 负责生成测试、编写实现、自动修复，直到所有验证通过。

---

## 子命令分发

根据用户输入的子命令执行对应流程：

| 输入 | 动作 |
|------|------|
| `/auto-dev init` | 探测项目环境，生成 `.auto-dev.yaml` |
| `/auto-dev spec` | 从设计文档生成 test-specs |
| `/auto-dev run` | 执行 Phase C 自动编码验证循环 |
| `/auto-dev report` | 输出验收报告 |
| `/auto-dev`（无子命令） | 根据任务复杂度自动选择流程（见下方分级规则） |

当用户输入 `/auto-dev` 后面跟了具体的任务描述但没有子命令时，先评估任务复杂度，再自动选择对应流程。

---

## 任务复杂度分级

在无子命令时，先分析用户描述的任务，判定复杂度等级，然后执行对应流程：

### S — 简单（改 1-2 个文件）

流程：直接修改 → 跑已有测试 → 完成

步骤：
1. 定位需要修改的文件
2. 直接修改代码
3. 运行项目已有的测试命令
4. 测试通过 → 完成；失败 → 修复 → 重跑（最多 3 轮）

### M — 中等（改 3+ 文件或涉及接口变更）

流程：先写测试 → 再改代码 → 跑测试 → 完成

步骤：
1. 分析影响范围
2. 为变更点编写/更新测试用例
3. 修改实现代码
4. 运行测试 → 失败 → 修实现（不改测试） → 重跑（最多 5 轮）

### L — 复杂（新模块/新功能）

流程：Phase A → B → C

步骤：
1. **Phase A**：分析设计文档和需求，生成 test-specs（等同 `/auto-dev spec`）
2. **Phase B**：请用户审查 test-specs，审批后冻结
3. **Phase C**：执行自动编码验证循环（等同 `/auto-dev run`）

### XL — 系统级（新项目/系统重构）

流程：Phase A → B → C → D

步骤：
1. **Phase A**：探测环境 + 生成配置（等同 `/auto-dev init` + `/auto-dev spec`）
2. **Phase B**：请用户审查全部规格和方案，审批后冻结
3. **Phase C**：分模块执行自动编码验证循环
4. **Phase D**：集成测试 + 验收报告（等同 `/auto-dev report`）

---

## `/auto-dev init` — 项目环境探测

### 执行逻辑

1. **扫描项目根目录**，依据特征文件探测语言和工具链：

| 特征文件 | 语言/平台 | test_cmd | build_cmd |
|----------|-----------|----------|-----------|
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `package.json` | TypeScript / Node | `npm test` | `npm run build` |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | `pytest` | `python -m build` |
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |
| `pom.xml` | Java (Maven) | `mvn test` | `mvn package` |
| `build.gradle` / `build.gradle.kts` | Java (Gradle) | `gradle test` | `gradle build` |

2. **探测容器化配置**：
   - `docker-compose.yaml` 或 `docker-compose.yml` → `container: docker-compose`
   - `Dockerfile` → 记录但不自动启用容器流程

3. **探测基础设施依赖**：
   - 扫描配置文件（`.env`、`application.yaml`、`config/` 等）中的数据库、缓存、消息队列连接信息
   - 识别常见依赖：PostgreSQL、MySQL、Redis、MongoDB、Kafka、RabbitMQ 等

4. **探测已有测试结构**：
   - 查找已有测试文件的位置和命名模式
   - 检查是否有 CI 配置（`.github/workflows/`、`.gitlab-ci.yml` 等）

5. **生成 `.auto-dev.yaml`**，写入项目根目录。

### `.auto-dev.yaml` 模板

```yaml
# auto-dev 配置 — 由 /auto-dev init 自动生成
project:
  name: <项目名>
  language: <Go|TypeScript|Python|Rust|Java>
  root: <项目根路径>

commands:
  test: <test_cmd>
  build: <build_cmd>
  lint: <lint_cmd，如果检测到>

container:
  enabled: <true|false>
  tool: <docker-compose|none>
  file: <docker-compose.yaml 路径>

infrastructure:
  databases: []       # 检测到的数据库列表
  caches: []          # 检测到的缓存列表
  message_queues: []  # 检测到的消息队列列表

retries:
  unit_max_retries: 5
  integration_max_retries: 3

frozen_files: []
  # 冻结的文件列表，AI 不可修改

test_specs_dir: test-specs
progress_dir: .progress
```

6. **输出探测结果摘要**，请用户确认或调整。

---

## `/auto-dev spec` — 测试规格生成

### 执行逻辑

1. **读取设计文档**：
   - 搜索 `docs/` 目录下的 `.md` 和 `.html` 文件
   - 如果没有 `docs/` 目录，询问用户指定文档路径
   - 如果用户直接提供了需求描述，以该描述为输入

2. **提取验收用例**：
   - 从设计文档中识别功能需求、接口规格、业务规则
   - 将每个可验证的需求点转化为一个测试用例

3. **生成 `test-specs/*.yaml`**（语言无关格式）：

```yaml
# test-specs/feature-xxx.yaml
spec_id: FEAT-001
title: <功能名称>
source: <来源文档路径>

cases:
  - id: TC-001
    description: <用例描述>
    preconditions:
      - <前置条件，用自然语言描述>
    input:
      - <输入描述>
    expect:
      - <期望结果，用自然语言描述>
    priority: <P0|P1|P2>

  - id: TC-002
    description: ...
    preconditions: [...]
    input: [...]
    expect: [...]
    priority: P1
```

4. **生成 `scripts/verify.sh`**（根据项目技术栈定制）：
   - 该脚本用于集成测试阶段
   - 包含环境准备、服务启动、测试执行、结果收集、环境清理的完整流程
   - 脚本应有清晰的注释和错误处理

5. **请用户审查**：
   - 输出生成的 test-specs 摘要，列出所有用例的 ID、描述和优先级
   - 明确询问用户：「请审查以上测试规格。确认无误后请回复"approved"，我将冻结这些文件并进入编码阶段。如需修改请直接说明。」
   - **必须等待用户明确审批后才能继续**

6. **审批后冻结**：
   - 将 `test-specs/` 下所有文件和 `scripts/verify.sh` 加入 `.auto-dev.yaml` 的 `frozen_files` 列表
   - 后续 AI 不可修改这些文件

---

## `/auto-dev run` — 自动编码验证循环 (Phase C)

### 执行逻辑

1. **读取配置**：
   - 加载 `.auto-dev.yaml`，获取 `test_cmd`、`build_cmd`、`container`、`retries` 等配置
   - 加载 `test-specs/` 下所有 `.yaml` 文件

2. **Agent T — 生成测试代码**：
   - 读取 test-specs，**不读取任何实现代码**（这是硬性规则，确保测试独立于实现）
   - 根据语言生成对应格式的测试文件：
     - Go → `*_test.go`
     - Python → `test_*.py`
     - TypeScript → `*.test.ts` 或 `*.spec.ts`
     - Rust → `#[cfg(test)] mod tests`（或独立的 `tests/` 目录）
     - Java → `*Test.java`
   - 测试代码应覆盖 test-specs 中所有 P0 和 P1 用例
   - 每个测试函数对应一个 test-spec case，在注释中标注 spec_id 和 case_id

3. **Agent C — 编写实现代码**：
   - 读取测试代码和 test-specs，理解需要实现的功能
   - 编写实现代码，使所有测试通过
   - 遵守冻结边界规则，只修改允许修改的文件

4. **单元测试自愈循环**：

```
retry_count = 0
while retry_count < unit_max_retries:
    运行 test_cmd
    if 全部通过:
        break
    else:
        分析失败原因
        修改实现代码（不修改测试代码，测试代码已冻结）
        retry_count += 1

if retry_count >= unit_max_retries:
    暂停，输出诊断报告（见"终止与升级条件"）
```

5. **集成测试自愈循环**（如果 `container.enabled == true`）：

```
docker compose up -d
等待服务就绪

retry_count = 0
while retry_count < integration_max_retries:
    运行 scripts/verify.sh
    if 全部通过:
        break
    else:
        分析失败原因
        修改实现代码或配置（不修改 verify.sh，已冻结）
        retry_count += 1

docker compose down

if retry_count >= integration_max_retries:
    暂停，输出诊断报告
```

6. **全部通过后**：
   - 自动调用 `/auto-dev report` 生成验收报告
   - 更新 `.progress/status.md`

### 进度跟踪

在 `.progress/status.md` 中持续记录：

```markdown
# 开发进度

## 当前状态: <进行中|已通过|已暂停>

## 单元测试
- 总用例数: N
- 通过: X
- 失败: Y
- 自愈轮次: Z / unit_max_retries

## 集成测试
- 状态: <未开始|进行中|已通过|已暂停>
- 自愈轮次: Z / integration_max_retries

## 修改记录
- [轮次 1] 修改了 file_a.go: 原因描述
- [轮次 2] 修改了 file_b.go: 原因描述
```

---

## `/auto-dev report` — 验收报告

### 执行逻辑

1. 读取以下数据源：
   - 最近一次 `test_cmd` 的输出
   - `scripts/verify.sh` 的输出（如有）
   - `.progress/status.md`

2. 输出标准化验收报告：

```
╔══════════════════════════════════════════╗
║           auto-dev 验收报告              ║
╠══════════════════════════════════════════╣
║ 项目: <project.name>                    ║
║ 语言: <project.language>                ║
║ 日期: <当前日期>                         ║
╠══════════════════════════════════════════╣
║ 单元测试                                 ║
║   总用例: N    通过: X    失败: Y        ║
║   自愈轮次: Z                            ║
╠══════════════════════════════════════════╣
║ 集成测试                                 ║
║   状态: <通过/失败/未执行>                ║
║   自愈轮次: Z                            ║
╠══════════════════════════════════════════╣
║ 结论: <全部通过 / 部分通过 / 未通过>      ║
╚══════════════════════════════════════════╝

## 详细结果

### 通过的测试
- [TC-001] <描述> — PASS
- [TC-002] <描述> — PASS

### 失败的测试（如有）
- [TC-003] <描述> — FAIL
  原因: <失败原因分析>

### 自愈记录
- 轮次 1: <修改内容和原因>
- 轮次 2: <修改内容和原因>

### 遗留问题（如有）
- <问题描述>
```

---

## 冻结边界规则

冻结机制用于防止 AI 在自愈循环中篡改验证标准，确保测试的独立性和可信度。

### AI 可以修改的文件

- 实现代码（`src/`、`internal/`、`pkg/`、`lib/` 等目录下的源文件）
- 项目配置文件（`docker-compose.yaml` 中的环境变量、端口等）
- `.progress/status.md`

### AI 不能修改的文件（frozen_files）

以下文件一旦经用户审批即冻结，AI 在自愈循环中**绝对不可修改**：

- `test-specs/*.yaml` — 测试规格
- `scripts/verify.sh` — 集成验证脚本
- Agent T 生成的测试代码（经确认后冻结）
- 用户在 `.auto-dev.yaml` 的 `frozen_files` 中额外指定的文件

### 冻结违规处理

如果 AI 在自愈循环中判断某个冻结文件存在问题（例如测试规格有错误、验证脚本有缺陷）：

1. **立即暂停**，不尝试绕过
2. 向用户输出诊断报告，说明：
   - 哪个冻结文件可能有问题
   - 问题的具体表现
   - 建议的修改方案
3. 等待用户决定：修改冻结文件并重新冻结，或调整实现方案

---

## 终止与升级条件

### 自动继续的条件

- 每轮自愈修复后，失败的测试数量减少或有新的测试通过
- 即：**有可观测的进展**

### 暂停并升级的条件

出现以下任一情况时，**立即暂停**，不再继续自愈循环：

1. **同一测试连续 N 轮失败**：同一个测试用例连续修复 N 次（N = unit_max_retries / 2，向上取整）仍然失败
2. **回归**：修复一个测试导致之前已通过的测试重新失败
3. **验证方案疑似有误**：AI 判断 test-spec 或测试代码本身可能存在错误
4. **达到最大重试次数**：总重试次数达到 `unit_max_retries` 或 `integration_max_retries`

### 暂停时的诊断报告格式

```
## 自愈循环已暂停

### 暂停原因
<原因类别>: <具体描述>

### 当前状态
- 通过的测试: X / N
- 失败的测试: Y
- 已执行轮次: Z

### 失败分析
#### <失败的测试 ID>
- 错误信息: <最近一次的错误输出>
- 已尝试的修复:
  - 轮次 M: <修改内容> → <结果>
  - 轮次 M+1: <修改内容> → <结果>
- 根因分析: <AI 对根本原因的判断>

### 建议
- 选项 A: <建议的修复方案>
- 选项 B: <备选方案>
- 选项 C: 修改 test-spec <spec_id>（需要解冻）

### 需要人工决策
请选择处理方式，或提供其他指示。
```

---

## 执行原则

1. **测试先于实现**：永远先有测试规格和测试代码，再写实现
2. **测试独立性**：Agent T 生成测试时不读实现代码，确保测试反映规格而非实现
3. **冻结不可违**：冻结文件是人机信任的边界，AI 不可单方面修改
4. **进展可观测**：每轮自愈都要记录变更和结果，用户可随时查看进度
5. **及时止损**：没有进展时立即暂停，不做无意义的重试
6. **最小变更**：每轮修复只改必要的代码，避免大范围重写导致回归
