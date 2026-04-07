# /auto-dev-spec — 测试规格生成

从需求/设计文档生成 test-specs，经人审批后冻结。

---

## 执行逻辑

### 1. 读取设计文档

- 搜索 `docs/` 目录下的 `.md` 和 `.html` 文件
- 如果没有 `docs/` 目录，询问用户指定文档路径
- 如果用户直接提供了需求描述，以该描述为输入

### 2. 提取验收用例

从设计文档中识别功能需求、接口规格、业务规则，将每个可验证的需求点转化为一个测试用例。

### 3. 生成 `test-specs/*.yaml`

使用语言无关格式，字段定义如下：

```yaml
# test-specs/feature-xxx.yaml
spec_id: FEAT-001
title: <功能名称>
module: <模块路径>
source: <来源文档路径>
approved: false

cases:
  - id: TC-001
    name: <测试函数名，英文 snake_case>
    description: <用例描述>
    preconditions:
      - <前置条件，用自然语言描述>
    input:
      key: "value"
    expect:
      - <期望结果，用自然语言描述>
    priority: P0
    edge_cases:
      - name: <边界情况名>
        input: {}
        expect: []

  - id: TC-002
    name: ...
    description: ...
    priority: P1
```

### 4. 生成 `scripts/verify.sh`

根据项目技术栈定制集成验证脚本，参照 `templates/verify.sh.tmpl` 的框架：
- 包含环境准备、服务启动、测试执行、结果收集、环境清理
- 脚本应有清晰的注释和错误处理
- **加入冻结文件校验步骤**（详见下方）

### 5. 请用户审查

输出生成的 test-specs 摘要，列出所有用例的 ID、描述和优先级。

明确询问用户：「请审查以上测试规格。确认无误后请回复"approved"，我将冻结这些文件并进入编码阶段。如需修改请直接说明。」

**必须等待用户明确审批后才能继续。**

### 6. 审批后冻结

1. 将 `test-specs/` 下所有 `.yaml` 文件和 `scripts/verify.sh` 加入 `.auto-dev.yaml` 的 `frozen_files` 列表
2. 计算每个冻结文件的 SHA-256 校验和，写入 `frozen_checksums`
3. 后续 AI 不可修改这些文件

冻结后的 `.auto-dev.yaml` 示例：

```yaml
frozen_files:
  - test-specs/user-service.yaml
  - scripts/verify.sh

frozen_checksums:
  "test-specs/user-service.yaml": "a1b2c3d4..."
  "scripts/verify.sh": "e5f6g7h8..."
```
