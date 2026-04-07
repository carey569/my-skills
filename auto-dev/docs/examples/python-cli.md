# Python CLI 工具示例

## 项目类型

Click/Typer 命令行工具，SQLite 存储，pyproject.toml 管理依赖。

## 自动探测结果

auto-dev 检测到 `pyproject.toml` 和 Click/Typer 依赖后生成：

```yaml
# .auto-dev.yaml
project:
  name: "mytool"
  language: "python"
  root: "."
commands:
  test: "pytest"
  build: "pip install -e ."
  lint: "ruff check ."
infra:
  container: null
  databases: [sqlite]
  caches: []
```

## test-spec 示例

```yaml
# test-specs/cli-add-command.yaml
spec_id: FEAT-001
title: "CLI add 命令"
module: "src/mytool/commands/add"
approved: false
cases:
  - name: "test_add_item_success"
    desc: "添加记录成功，输出确认信息"
    input:
      args: ["add", "--name", "buy milk", "--priority", "high"]
    expect:
      - "退出码为 0"
      - "stdout 包含 'Added: buy milk'"
      - "数据库中存在对应记录"
  - name: "test_add_item_duplicate"
    desc: "重复添加时提示已存在"
    preconditions: ["数据库中已有 name='buy milk' 的记录"]
    input:
      args: ["add", "--name", "buy milk"]
    expect:
      - "退出码为 1"
      - "stderr 包含 'already exists'"
  - name: "test_add_item_missing_name"
    desc: "缺少 --name 参数，显示帮助"
    input: { args: ["add"] }
    expect: ["退出码为 2", "stderr 包含 'Missing option'"]
```

## Agent T 生成的测试代码

使用 pytest fixtures 隔离测试数据：

```python
# tests/test_cli_add.py
import pytest
from click.testing import CliRunner
from mytool.cli import app
from mytool.db import get_db, init_db


@pytest.fixture
def runner(tmp_path):
    db_path = tmp_path / "test.db"
    init_db(str(db_path))
    return CliRunner(env={"MYTOOL_DB": str(db_path)})


class TestAddCommand:
    def test_add_item_success(self, runner, tmp_path):
        db_path = tmp_path / "test.db"
        env = {"MYTOOL_DB": str(db_path)}
        result = runner.invoke(app, ["add", "--name", "buy milk", "--priority", "high"], env=env)
        assert result.exit_code == 0
        assert "Added: buy milk" in result.output

        db = get_db(str(db_path))
        row = db.execute("SELECT priority FROM items WHERE name=?", ("buy milk",)).fetchone()
        assert row["priority"] == "high"

    def test_add_item_duplicate(self, runner, tmp_path):
        db_path = tmp_path / "test.db"
        env = {"MYTOOL_DB": str(db_path)}
        runner.invoke(app, ["add", "--name", "buy milk"], env=env)
        result = runner.invoke(app, ["add", "--name", "buy milk"], env=env)
        assert result.exit_code == 1
        assert "already exists" in result.output

    def test_add_item_missing_name(self, runner):
        result = runner.invoke(app, ["add"])
        assert result.exit_code == 2
        assert "Missing option" in result.output
```

## verify.sh 示例

```bash
#!/bin/bash
set -euo pipefail
pip install -e . -q
export MYTOOL_DB=$(mktemp /tmp/mytool_test_XXXXXX.db)
trap "rm -f $MYTOOL_DB" EXIT

mytool init

OUTPUT=$(mytool add --name "test item" --priority high 2>&1)
echo "$OUTPUT" | grep -q "Added: test item"

OUTPUT=$(mytool list 2>&1)
echo "$OUTPUT" | grep -q "test item"

mytool export --format json --output /tmp/mytool_export.json
python3 -c "
import json; data = json.load(open('/tmp/mytool_export.json'))
assert len(data) == 1 and data[0]['name'] == 'test item'
"

if mytool add --name "test item" 2>/dev/null; then exit 1; fi

echo "All verifications passed"
```

## Python 特有注意事项

- **pytest fixtures**：优先用 fixture 注入依赖，`conftest.py` 共享公共 fixture
- **tmp_path**：SQLite 等文件型数据库使用 pytest 内置 `tmp_path` 隔离
- **CliRunner**：Click 用 `click.testing.CliRunner`，Typer 用 `typer.testing.CliRunner`
- **环境变量隔离**：通过 `MYTOOL_DB` 等环境变量指向临时数据库
- **虚拟环境**：verify.sh 应在项目虚拟环境中运行
- **类型检查**：建议在 verify.sh 中加入 `mypy src/`
