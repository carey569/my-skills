# Rust CLI 工具示例

## 项目类型

使用 clap 解析参数、serde 序列化的 CLI 工具（如格式转换器）。

## 自动探测结果

auto-dev 检测到 `Cargo.toml` 及 clap/serde 依赖后生成：

```yaml
# .auto-dev.yaml
project:
  name: "mytool"
  language: "rust"
  root: "."
commands:
  test: "cargo test"
  build: "cargo build"
  lint: "cargo clippy -- -D warnings"
infra:
  container: null
  databases: []
  caches: []
```

## test-spec 示例

```yaml
# test-specs/convert-command.yaml
spec_id: FEAT-001
title: "convert 命令"
module: "src/commands/convert"
approved: false
cases:
  - name: "test_convert_json_to_toml"
    desc: "将 JSON 文件转换为 TOML 格式输出"
    input:
      args: ["convert", "--from", "json", "--to", "toml", "input.json"]
      file_content: '{"name":"test","deps":["a","b"]}'
    expect:
      - "退出码为 0"
      - "stdout 是合法 TOML，name = 'test'"
  - name: "test_convert_invalid_input"
    desc: "输入格式错误时返回有意义的错误信息"
    input:
      args: ["convert", "--from", "json", "--to", "toml", "bad.json"]
      file_content: "{invalid"
    expect: ["退出码为 1", "stderr 包含 'invalid JSON'"]
  - name: "test_convert_output_file"
    desc: "使用 --output 参数写入文件"
    input:
      args: ["convert", "--from", "json", "--to", "toml", "-o", "out.toml", "input.json"]
    expect: ["退出码为 0", "out.toml 存在且内容合法"]
```

## Agent T 生成的测试代码

### 单元测试（`#[cfg(test)]` 模块）

```rust
// src/commands/convert.rs
#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_convert_json_to_toml() {
        let input = r#"{"name":"test","deps":["a","b"]}"#;
        let mut output = Vec::new();
        let result = convert(Cursor::new(input), &mut output, Format::Json, Format::Toml);
        assert!(result.is_ok());
        let s = String::from_utf8(output).unwrap();
        let parsed: toml::Value = toml::from_str(&s).unwrap();
        assert_eq!(parsed["name"].as_str().unwrap(), "test");
        assert_eq!(parsed["deps"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn test_convert_invalid_json_returns_error() {
        let mut output = Vec::new();
        let result = convert(Cursor::new("{invalid"), &mut output, Format::Json, Format::Toml);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("invalid JSON"));
    }
}
```

### 集成测试（assert_cmd + predicates）

```rust
// tests/integration_test.rs
use assert_cmd::Command;
use predicates::prelude::*;
use tempfile::TempDir;
use std::fs;

#[test]
fn test_cli_convert_json_to_toml() {
    let dir = TempDir::new().unwrap();
    fs::write(dir.path().join("in.json"), r#"{"name":"test"}"#).unwrap();
    Command::cargo_bin("mytool").unwrap()
        .args(["convert", "--from", "json", "--to", "toml"]).arg(dir.path().join("in.json"))
        .assert().success().stdout(predicate::str::contains("name = \"test\""));
}

#[test]
fn test_cli_convert_invalid_input() {
    let dir = TempDir::new().unwrap();
    fs::write(dir.path().join("bad.json"), "{invalid").unwrap();
    Command::cargo_bin("mytool").unwrap()
        .args(["convert", "--from", "json", "--to", "toml"]).arg(dir.path().join("bad.json"))
        .assert().failure().stderr(predicate::str::contains("invalid JSON"));
}
```

## verify.sh 示例

```bash
#!/bin/bash
set -euo pipefail
cargo build --release
BIN="./target/release/mytool"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cat > "$TMPDIR/input.json" << 'JSON'
{"name":"verify","features":["a","b","c"]}
JSON

$BIN convert --from json --to toml "$TMPDIR/input.json" > "$TMPDIR/out.toml"
grep -q 'name = "verify"' "$TMPDIR/out.toml"

$BIN convert --from toml --to json "$TMPDIR/out.toml" > "$TMPDIR/rt.json"
python3 -c "import json; d=json.load(open('$TMPDIR/rt.json')); assert d['name']=='verify'"

if $BIN convert --from json --to toml /nonexistent 2>/dev/null; then exit 1; fi

echo "All verifications passed"
```

## Rust 特有注意事项

- **`#[cfg(test)]` 模块**：单元测试放在源文件末尾，Rust 社区惯例
- **assert_cmd + predicates**：CLI 集成测试推荐组合，auto-dev 自动添加为 dev-dependencies
- **tempfile**：文件 I/O 测试用 `TempDir` 确保隔离
- **anyhow/thiserror**：根据项目错误处理库匹配断言方式
- **cargo clippy**：verify.sh 默认包含 `cargo clippy -- -D warnings`
- **feature flags**：如 Cargo.toml 定义了 features，会为各组合生成测试
