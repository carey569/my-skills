# Java Spring Boot 服务示例

## 项目类型

Spring Boot Web 服务，Maven 构建，MySQL + Redis，Docker Compose 编排。

## 自动探测结果

auto-dev 检测到 `pom.xml` + Spring Boot 依赖后生成：

```yaml
# .auto-dev.yaml
project:
  language: "java"
  test_cmd: "mvn test"
  build_cmd: "mvn package -DskipTests"
  lint_cmd: "mvn checkstyle:check"
infra:
  container: docker-compose
  compose_file: "docker-compose.yaml"
  database: mysql
  cache: redis
```

## test-spec 示例

```yaml
# test-specs/user-service.yaml
module: "src/main/java/com/example/myapp/service"
approved: false
specs:
  - name: "test_create_user_success"
    desc: "正常创建用户，返回带 ID 的对象"
    input: { request: { name: "Alice", email: "new@test.com" } }
    expect: ["返回 User，id > 0", "getName() == 'Alice'", "getCreatedAt() != null"]
  - name: "test_create_user_duplicate_email"
    desc: "邮箱已存在时抛出异常"
    preconditions: ["数据库中已存在 email='dup@test.com'"]
    input: { request: { name: "Bob", email: "dup@test.com" } }
    expect: ["抛出 DuplicateEmailException"]
  - name: "test_get_user_not_found"
    desc: "查询不存在用户时抛出异常"
    input: { user_id: 99999 }
    expect: ["抛出 UserNotFoundException", "消息包含 '99999'"]
```

## Agent T 生成的测试代码

### Service 单元测试（JUnit 5 + Mockito）

```java
// src/test/java/com/example/myapp/service/UserServiceTest.java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock private UserRepository userRepository;
    @InjectMocks private UserService userService;

    @Test
    void createUser_success() {
        var request = new CreateUserRequest("Alice", "new@test.com");
        when(userRepository.findByEmail("new@test.com")).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(1L);
            return u;
        });

        User result = userService.createUser(request);

        assertThat(result.getId()).isGreaterThan(0);
        assertThat(result.getName()).isEqualTo("Alice");
        assertThat(result.getCreatedAt()).isNotNull();
    }

    @Test
    void createUser_duplicateEmail_throwsException() {
        var request = new CreateUserRequest("Bob", "dup@test.com");
        when(userRepository.findByEmail("dup@test.com")).thenReturn(Optional.of(new User()));

        assertThatThrownBy(() -> userService.createUser(request))
            .isInstanceOf(DuplicateEmailException.class);
        verify(userRepository, never()).save(any());
    }

    @Test
    void getUser_notFound_throwsException() {
        when(userRepository.findById(99999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.getUser(99999L))
            .isInstanceOf(UserNotFoundException.class)
            .hasMessageContaining("99999");
    }
}
```

### Controller 切片测试（`@WebMvcTest`）

```java
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockBean private UserService userService;

    @Test
    void createUser_returns201() throws Exception {
        when(userService.createUser(any())).thenReturn(new User(1L, "Alice", "new@test.com"));
        mockMvc.perform(post("/api/users").contentType(APPLICATION_JSON)
                .content("{\"name\":\"Alice\",\"email\":\"new@test.com\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }
}
```

## verify.sh 示例

```bash
#!/bin/bash
set -euo pipefail
mvn package -DskipTests -q
docker-compose up -d --wait
trap "docker-compose down" EXIT

java -jar target/myapp-*.jar --spring.profiles.active=test &
trap "kill $! 2>/dev/null; docker-compose down" EXIT
for i in $(seq 1 30); do curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1 && break; sleep 1; done

RESP=$(curl -sf -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"E2E","email":"e2e@test.com"}')
USER_ID=$(echo "$RESP" | jq -r '.id')
[ "$USER_ID" -gt 0 ]

RESP=$(curl -sf "http://localhost:8080/api/users/$USER_ID")
echo "$RESP" | jq -e '.name == "E2E"' > /dev/null

COUNT=$(docker-compose exec -T mysql mysql -uroot -ptest app_db -N -e \
  "SELECT COUNT(*) FROM users WHERE email='e2e@test.com'")
[ "$(echo $COUNT | tr -d ' ')" -eq 1 ]

echo "All verifications passed"
```

## Java 特有注意事项

- **JUnit 5 + Mockito**：默认使用 `@ExtendWith(MockitoExtension.class)` + `@Mock`/`@InjectMocks`
- **AssertJ**：优先使用流式断言 `assertThat(...).isEqualTo(...)` 而非 JUnit 原生断言
- **@WebMvcTest**：Controller 用切片测试，Service 层用 `@MockBean` 替代
- **Testcontainers**：如已引入，优先用它替代 docker-compose 管理测试依赖
- **application-test.yaml**：集成测试用独立 profile，`@ActiveProfiles("test")` 激活
- **Maven vs Gradle**：根据 `pom.xml` / `build.gradle` 自动切换构建命令
