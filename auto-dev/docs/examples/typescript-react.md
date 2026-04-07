# TypeScript React + Node.js 后端示例

## 项目类型

前后端一体 TypeScript 项目：React 前端（Vite）+ Express 后端，Vitest/Jest 测试。

## 自动探测结果

auto-dev 检测到 `package.json` + `.ts`/`.tsx` 后生成：

```yaml
# .auto-dev.yaml
project:
  name: "my-fullstack-app"
  language: "typescript"
  root: "."
commands:
  test: "npm test"
  build: "npm run build"
  lint: "npm run lint"
infra:
  container: docker-compose
  compose_file: "docker-compose.yaml"
  databases: [postgres]
  caches: [redis]
```

## test-spec 示例

```yaml
# test-specs/user-service.yaml
spec_id: FEAT-001
title: "用户服务"
module: "packages/backend/src/services"
approved: false
cases:
  - name: "test_create_user_returns_user_with_id"
    desc: "创建用户成功，返回带 ID 的用户对象"
    input: { body: { name: "Alice", email: "new@test.com" } }
    expect:
      - "返回对象包含 id（正整数）"
      - "name === 'Alice'"
  - name: "test_create_user_duplicate_email_returns_409"
    desc: "邮箱已存在时返回 409"
    preconditions: ["数据库中已存在 email='dup@test.com'"]
    input: { body: { name: "Bob", email: "dup@test.com" } }
    expect: ["抛出 ConflictError"]
  - name: "test_user_form_submits_and_shows_success"
    desc: "前端表单提交成功后显示提示"
    input: { form: { name: "Alice", email: "new@test.com" } }
    expect: ["页面显示 'User created successfully'", "表单被清空"]
```

## Agent T 生成的测试代码

### 后端测试

```typescript
// packages/backend/src/services/__tests__/userService.test.ts
import { describe, it, expect, beforeEach, vi } from "vitest";
import { UserService } from "../userService";
import type { UserRepository } from "../../repos/userRepository";
import { ConflictError } from "../../errors";

describe("UserService", () => {
  let service: UserService;
  let mockRepo: UserRepository;

  beforeEach(() => {
    mockRepo = {
      findByEmail: vi.fn(),
      create: vi.fn(),
      findById: vi.fn(),
    } as unknown as UserRepository;
    service = new UserService(mockRepo);
  });

  it("should create user and return user with id", async () => {
    vi.mocked(mockRepo.findByEmail).mockResolvedValue(null);
    vi.mocked(mockRepo.create).mockResolvedValue({
      id: 1, name: "Alice", email: "new@test.com", createdAt: new Date(),
    });
    const user = await service.createUser({ name: "Alice", email: "new@test.com" });
    expect(user.id).toBeGreaterThan(0);
    expect(user.name).toBe("Alice");
  });

  it("should throw ConflictError for duplicate email", async () => {
    vi.mocked(mockRepo.findByEmail).mockResolvedValue({ id: 1 } as any);
    await expect(
      service.createUser({ name: "Bob", email: "dup@test.com" })
    ).rejects.toThrow(ConflictError);
  });
});
```

### 前端测试

```typescript
// packages/frontend/src/components/__tests__/UserForm.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UserForm } from "../UserForm";

describe("UserForm", () => {
  it("should submit and show success message", async () => {
    render(<UserForm onSubmit={vi.fn().mockResolvedValue({ id: 1 })} />);
    const user = userEvent.setup();
    await user.type(screen.getByLabelText(/name/i), "Alice");
    await user.type(screen.getByLabelText(/email/i), "new@test.com");
    await user.click(screen.getByRole("button", { name: /submit/i }));
    await waitFor(() =>
      expect(screen.getByText(/user created successfully/i)).toBeInTheDocument()
    );
  });
});
```

## verify.sh 示例

```bash
#!/bin/bash
set -euo pipefail
cd packages/frontend && npm run build && cd ../..
docker-compose up -d --wait
trap "docker-compose down" EXIT

curl -sf http://localhost:3000/api/health | grep -q "ok"

RESP=$(curl -sf -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"E2E Test","email":"e2e@test.com"}')
USER_ID=$(echo "$RESP" | jq -r '.id')
[ "$USER_ID" -gt 0 ]

RESP=$(curl -sf "http://localhost:3000/api/users/$USER_ID")
echo "$RESP" | jq -e '.name == "E2E Test"' > /dev/null

COUNT=$(docker-compose exec -T postgres psql -U app -t -c \
  "SELECT COUNT(*) FROM users WHERE email='e2e@test.com'")
[ "$(echo $COUNT | tr -d ' ')" -eq 1 ]

echo "All verifications passed"
```

## TypeScript 特有注意事项

- **测试框架**：根据 package.json 自动判断 Vitest 还是 Jest
- **React Testing Library**：组件测试遵循"测试用户行为而非实现细节"
- **Monorepo**：识别 pnpm workspace / Turborepo / Nx 工作区结构
- **类型检查**：verify.sh 中建议加入 `npx tsc --noEmit`
- **ESM vs CJS**：检测 `"type": "module"` 确保测试配置兼容
- **环境变量**：使用 `.env.test` 文件隔离测试环境配置
