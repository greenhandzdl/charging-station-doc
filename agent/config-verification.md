# Configuration Verification Report

**Project:** Charging Station Backend
**Date:** 2026-06-05
**Scope:** application.yml, config/, SwaggerConfig, SecurityConfig, .env.example, compile

---

## Check 1: `application.yml` → `config/` Import

**Result: PASS**

- `/mnt/data/charging-station-doc/code/charging-station-backend/src/main/resources/application.yml` line 12 contains `spring.config.import: optional:config/`
- The `config/` directory at project root exists and contains both `application-dev.yml` and `application-prod.yml`
- Default profile is `dev` (`spring.profiles.active: dev`), so dev config is loaded by default

---

## Check 2: Swagger is Dev-Only

**Result: PASS**

- `/mnt/data/charging-station-doc/code/charging-station-backend/src/main/java/com/charging/infrastructure/config/SwaggerConfig.java` line 28 has `@Profile("dev")` -- Swagger beans only instantiate when `dev` profile is active
- `application.yml` has `springdoc.api-docs.enabled: true` and `springdoc.swagger-ui.enabled: true` at lines 33-36 (these are top-level, not under `spring:` -- correct for springdoc 2.x)
- Dependency `springdoc-openapi-starter-webmvc-ui:2.6.0` is declared in `pom.xml`

---

## Check 3: SecurityConfig Allows Swagger Paths

**Result: PASS**

- `/mnt/data/charging-station-doc/code/charging-station-backend/src/main/java/com/charging/infrastructure/security/SecurityConfig.java` line 41:
  `.requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()`
- Swagger UI and OpenAPI JSON endpoints are publicly accessible

---

## Check 4: `.env.example` Completeness

**Result: PASS**

`.env.example` documents all 11 environment variables referenced by `config/application-dev.yml` and `config/application-prod.yml`:

| Variable | Documented? |
|---|---|
| `DB_HOST` | Yes |
| `DB_PORT` | Yes |
| `DB_NAME` | Yes |
| `DB_USERNAME` | Yes |
| `DB_PASSWORD` | Yes |
| `REDIS_HOST` | Yes |
| `REDIS_PORT` | Yes |
| `REDIS_PASSWORD` | Yes (empty default) |
| `JWT_SECRET` | Yes |
| `PAYMENT_HMAC_SECRET` | Yes |
| `WECHAT_API_KEY` | Yes |
| `ALIPAY_API_KEY` | Yes |

---

## Check 5: Compile Check

**Result: SKIPPED**

- `mvn` is not installed in this environment (Java 25 LTS is available but no Maven/Gradle wrapper exists)
- No syntax errors could be verified by compilation
- **Recommendation**: Run `mvn compile` in a local environment with Maven 3.8+ and JDK 17+ to confirm

---

## Additional Findings

### Potential Bug: SecurityConfig Auth Paths Use Incorrect Context-Path Prefix

The `SecurityConfig` permits auth endpoints with an `/api` prefix:
```java
.requestMatchers("/api/v1/auth/register").permitAll()
.requestMatchers("/api/v1/auth/login").permitAll()
.requestMatchers("/api/v1/auth/password-reset").permitAll()
.requestMatchers("/api/v1/auth/password-reset/confirm").permitAll()
.requestMatchers("/api/v1/captcha/**").permitAll()
.requestMatchers("/api/v1/payments/callback").permitAll()
.requestMatchers("/actuator/health").permitAll()
```

With `server.servlet.context-path=/api` (application.yml line 4), Spring Security's `requestMatchers(String)` matches **against the URI path minus the context path**. This means:

- A request to `http://localhost:8080/api/v1/auth/login` is matched against `v1/auth/login` (context path `/api` is stripped)
- The pattern `/api/v1/auth/login` will **never match** -- it should be `/v1/auth/login`
- Swagger patterns (`/swagger-ui/**`, `/v3/api-docs/**`) are correctly written without the `/api` prefix

`SwaggerConfig.java` confirms the correct approach: its `pathsToMatch` uses `/v1/auth/register` (no `/api` prefix).

**Severity:** HIGH -- auth endpoints would return 401/403 instead of being publicly accessible. Login and registration would fail.

### Note: Springdoc Config at Root Level

`springdoc` properties are at root level (not under `spring:`) in `application.yml`. This is correct for Spring Boot 3.x with springdoc-openapi 2.x.

---

## Summary

| # | Check | Status |
|---|---|---|
| 1 | `application.yml` → `config/` import | **PASS** |
| 2 | Swagger dev-only (`@Profile("dev")`) | **PASS** |
| 3 | SecurityConfig allows Swagger paths | **PASS** |
| 4 | `.env.example` completeness | **PASS** |
| 5 | Maven compilation | **SKIPPED** (no build tool) |

**Overall:** 4/5 checks passed, 1 skipped. One **high-severity bug** found in SecurityConfig -- auth endpoint patterns are incorrectly prefixed with `/api`, which will cause login/registration to fail at runtime due to Spring Security context-path matching behavior.