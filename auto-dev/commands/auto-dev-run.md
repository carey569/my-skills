# /auto-dev-run — 自动编码验证循环 (Phase C)

全自动执行测试生成、代码实现和自愈循环。

---

## 执行逻辑

### 1. 前置检查

- 加载 `.auto-dev.yaml`，获取 `commands.test`、`commands.build`、`infra`、`policy` 等配置
- 加载 `designs/` 下已审批的设计文档（作为实现参考）
- 加载 `test-specs/` 下所有 `.yaml` 文件
- **校验冻结文件完整性**：对 `frozen_files` 中的每个文件（包括设计文档、test-specs、verify.sh）计算 SHA-256，与 `frozen_checksums` 比对。不一致则暂停并报告
- 初始化 `.progress/status.md`

### 2. Agent T — 生成测试代码

- 读取 test-specs，**不读取任何实现代码**（硬性规则，确保测试独立于实现）
- 根据语言生成对应格式的测试文件：
  - Go → `*_test.go`
  - Python → `test_*.py`
  - TypeScript → `*.test.ts` 或 `*.spec.ts`
  - Rust → `#[cfg(test)] mod tests`（或独立的 `tests/` 目录）
  - Java → `*Test.java`
- 测试代码应覆盖 test-specs 中所有 P0 和 P1 用例
- 每个测试函数对应一个 test-spec case，在注释中标注 spec_id 和 case_id

### 3. Agent C — 编写实现代码

- 读取设计文档、测试代码和 test-specs，理解需要实现的功能和设计约束
- **先理解再动手**：修改任何代码前，必须先读取相关文件理解上下文
- 编写实现代码，使所有测试通过
- 遵守冻结边界规则，只修改允许修改的文件
- **错误脱敏**：实现代码中面向用户的错误信息不得暴露内部路径、堆栈或敏感配置

### 4. 单元测试自愈循环

```
retry_count = 0
while retry_count < unit_max_retries:
    运行 commands.test
    if 全部通过:
        break
    else:
        分析失败原因
        修改实现代码（不修改测试代码，测试代码已冻结）
        更新 .progress/status.md
        retry_count += 1

if retry_count >= unit_max_retries:
    暂停，输出诊断报告（见"终止与升级条件"）
```

### 5. 集成测试自愈循环

如果 `infra.container` 不为 null：

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
        更新 .progress/status.md
        retry_count += 1

docker compose down

if retry_count >= integration_max_retries:
    暂停，输出诊断报告
```

### 6. 完成

- **再次校验冻结文件完整性**：确保实现阶段没有意外修改冻结文件
- 自动调用 `/auto-dev-report` 生成验收报告
- 更新 `.progress/status.md` 状态为「已通过」

---

## 进度跟踪

在 `.progress/status.md` 中持续记录：

```markdown
# 开发进度

## 任务描述
<用户的原始需求描述>

## 当前状态: <进行中|已通过|已暂停>
## 当前阶段: <Phase A|Phase B|Phase C|Phase D>
## 最后更新: <时间戳>

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

## 终止与升级条件

### 自动继续的条件

- 每轮自愈修复后，失败的测试数量减少或有新的测试通过
- 即：**有可观测的进展**

### 暂停并升级的条件

出现以下任一情况时，**立即暂停**，不再继续自愈循环：

1. **同一测试连续 N 轮失败**：同一个测试用例连续修复 N 次（N = unit_max_retries / 2，向上取整）仍然失败
2. **回归**：修复一个测试导致之前已通过的测试重新失败
3. **验证方案疑似有误**：AI 判断 test-spec 或测试代码本身可能存在错误
4. **达到最大重试次数**
5. **冻结文件被篡改**：校验和不匹配

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
