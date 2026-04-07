# Go Web 服务示例

## 项目类型

Gin HTTP + gRPC 微服务，依赖 MySQL 和 Redis，Docker Compose 编排。

## 自动探测结果

auto-dev 检测到 `go.mod` + `docker-compose.yaml` 后生成：

```yaml
# .auto-dev.yaml
project:
  name: "my-go-service"
  language: "go"
  root: "."
commands:
  test: "go test ./..."
  build: "go build ./cmd/server"
  lint: "golangci-lint run"
infra:
  container: docker-compose
  compose_file: "docker-compose.yaml"
  databases: [mysql]
  caches: [redis]
```

## test-spec 示例

```yaml
# test-specs/user-service.yaml
spec_id: FEAT-001
title: "用户服务"
module: "internal/service"
approved: false
cases:
  - name: "test_create_user_success"
    desc: "正常创建用户，返回用户 ID"
    input: { name: "alice", email: "alice@example.com" }
    expect:
      - "返回的 user.ID > 0"
      - "user.Name == 'alice'"
    edge_cases:
      - name: "test_create_user_duplicate_email"
        input: { name: "bob", email: "alice@example.com" }
        expect: ["返回 ErrDuplicateEmail 错误"]
  - name: "test_get_user_not_found"
    desc: "查询不存在的用户"
    input: { id: 99999 }
    expect: ["返回 ErrUserNotFound 错误"]
```

## Agent T 生成的测试代码

Table-driven 风格，只依赖接口定义，不读实现：

```go
// internal/service/user_test.go
package service

import (
    "context"
    "testing"
    "myapp/internal/repo/mocks"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

func TestCreateUser(t *testing.T) {
    tests := []struct {
        name    string
        input   CreateUserInput
        setup   func(*mocks.UserRepo)
        wantErr error
        check   func(*testing.T, *User)
    }{
        {
            name:  "success",
            input: CreateUserInput{Name: "alice", Email: "alice@example.com"},
            setup: func(m *mocks.UserRepo) {
                m.On("FindByEmail", mock.Anything, "alice@example.com").Return(nil, ErrUserNotFound)
                m.On("Create", mock.Anything, mock.AnythingOfType("*service.User")).Return(nil)
            },
            check: func(t *testing.T, u *User) {
                assert.NotZero(t, u.ID)
                assert.Equal(t, "alice", u.Name)
            },
        },
        {
            name:  "duplicate_email",
            input: CreateUserInput{Name: "bob", Email: "alice@example.com"},
            setup: func(m *mocks.UserRepo) {
                m.On("FindByEmail", mock.Anything, "alice@example.com").Return(&User{ID: 1}, nil)
            },
            wantErr: ErrDuplicateEmail,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := mocks.NewUserRepo(t)
            tt.setup(repo)
            svc := NewUserService(repo, nil)
            user, err := svc.CreateUser(context.Background(), tt.input)
            if tt.wantErr != nil {
                assert.ErrorIs(t, err, tt.wantErr)
                return
            }
            assert.NoError(t, err)
            tt.check(t, user)
        })
    }
}
```

## verify.sh 示例

```bash
#!/bin/bash
set -euo pipefail
docker-compose up -d --wait
trap "docker-compose down" EXIT

curl -sf http://localhost:8080/health | grep -q "ok"

RESP=$(curl -sf -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"e2e","email":"e2e@test.com"}')
USER_ID=$(echo "$RESP" | jq -r '.id')
[ "$USER_ID" -gt 0 ]

GRPC_RESP=$(grpcurl -plaintext -d "{\"id\":$USER_ID}" \
  localhost:9090 user.UserService/GetUser)
echo "$GRPC_RESP" | jq -e '.name == "e2e"' > /dev/null

COUNT=$(docker-compose exec -T db mysql -N -e \
  "SELECT COUNT(*) FROM app.users WHERE email='e2e@test.com'")
[ "$COUNT" -eq 1 ]

echo "All verifications passed"
```

## Go 特有注意事项

- **table-driven tests**：Go 社区标准模式，auto-dev 默认生成此风格
- **testify**：项目已引入则使用，否则用标准库断言
- **mockery/gomock**：根据 `go.sum` 自动判断使用哪个 mock 框架
- **build tags**：集成测试建议用 `//go:build integration` 标签
- **race detector**：verify.sh 中建议加 `go test -race ./...`
- **testcontainers-go**：如已引入，优先用它替代 docker-compose
