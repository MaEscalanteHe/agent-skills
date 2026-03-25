# Java Dockerfile Patterns

## Table of Contents

- [Production Dockerfile (Maven)](#production-dockerfile-maven)
- [Gradle Variant](#gradle-variant)
- [Custom JRE with jlink](#custom-jre-with-jlink)
- [Spring Boot Layered Jars](#spring-boot-layered-jars)
- [Why JRE-Only Runtime](#why-jre-only-runtime)

---

## Production Dockerfile (Maven)

Complete multi-stage Dockerfile for a Spring Boot application built with Maven:

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build

# Copy dependency descriptor first for cache efficiency
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn dependency:go-offline -B

COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn clean package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

RUN addgroup -g 1001 -S java && \
    adduser -S java -u 1001 -G java

COPY --from=builder /build/target/*.jar app.jar
RUN chown java:java app.jar

USER java
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Key decisions:

- **dependency:go-offline first**: downloads all dependencies in a cached layer. Source code changes don't invalidate this layer, saving significant rebuild time (Maven dependency resolution is slow)
- **sharing=locked**: Maven's local repository (`~/.m2/repository`) is not safe for concurrent writes. `sharing=locked` serializes access when multiple builds run in parallel
- **-B (batch mode)**: suppresses interactive download progress, producing cleaner build logs
- **JRE-only runtime**: the JDK includes compilers, profilers, and development tools (~300MB) not needed at runtime
- **start-period=30s**: Java apps with Spring Boot can take 10-30 seconds to start. Without this grace period, the healthcheck would report unhealthy before the app is ready
- **wget over curl**: Alpine's wget is built-in (busybox), so no additional package needed. For slim/debian images, use `curl -f` instead

## Gradle Variant

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build

COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY gradle ./gradle
COPY gradlew .
RUN chmod +x gradlew

# Download dependencies first
RUN --mount=type=cache,target=/home/gradle/.gradle,sharing=locked \
    ./gradlew dependencies --no-daemon

COPY src ./src
RUN --mount=type=cache,target=/home/gradle/.gradle,sharing=locked \
    ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
RUN addgroup -g 1001 -S java && \
    adduser -S java -u 1001 -G java

COPY --from=builder /build/build/libs/*.jar app.jar
RUN chown java:java app.jar

USER java
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Note `--no-daemon`: the Gradle daemon is designed for long-running developer machines. In Docker builds, it wastes memory and can cause issues with cache mounts.

## Custom JRE with jlink

For maximum size reduction, build a custom JRE containing only the modules your application actually uses:

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn dependency:go-offline -B

COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn clean package -DskipTests -B

# Identify required modules
RUN jdeps --ignore-missing-deps --multi-release 21 \
    --print-module-deps target/*.jar > modules.txt

# Build minimal JRE
RUN jlink \
    --add-modules $(cat modules.txt) \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=zip-6 \
    --output /opt/custom-jre

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /opt/custom-jre /opt/java
COPY --from=builder /build/target/*.jar app.jar

ENV PATH="/opt/java/bin:$PATH"

RUN addgroup -g 1001 -S java && \
    adduser -S java -u 1001 -G java && \
    chown java:java app.jar

USER java
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

A custom JRE can be 40-80MB instead of the full JRE's ~190MB. The tradeoff is added build complexity and the need to keep `jdeps` output accurate as dependencies change. Best for applications where image size is a hard constraint.

## Spring Boot Layered Jars

Spring Boot 2.3+ supports layered JARs that split the fat JAR into layers ordered by change frequency, enabling better Docker layer caching:

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn dependency:go-offline -B

COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn clean package -DskipTests -B

# Extract layers from the fat JAR
RUN java -Djarmode=layertools -jar target/*.jar extract --destination extracted

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
RUN addgroup -g 1001 -S java && \
    adduser -S java -u 1001 -G java

# Copy layers in order of change frequency (least → most)
COPY --from=builder /build/extracted/dependencies/ ./
COPY --from=builder /build/extracted/spring-boot-loader/ ./
COPY --from=builder /build/extracted/snapshot-dependencies/ ./
COPY --from=builder /build/extracted/application/ ./

USER java
EXPOSE 8080
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

The layer order matters:

1. **dependencies/** — third-party libraries (change rarely)
2. **spring-boot-loader/** — Spring Boot loader classes (change almost never)
3. **snapshot-dependencies/** — SNAPSHOT versions (change occasionally)
4. **application/** — your code (changes every build)

When only your code changes, Docker rebuilds only the `application` layer and reuses the cached dependency layers. This can save 100-200MB of layer transfers per deployment.

## Why JRE-Only Runtime

|                   | JDK                                                 | JRE                     |
| ----------------- | --------------------------------------------------- | ----------------------- |
| **Size**          | ~400MB                                              | ~190MB                  |
| **Includes**      | Compiler (javac), profiler (jvisualvm), debug tools | Only the runtime (java) |
| **Use in Docker** | Builder stage only                                  | Runtime stage           |

The JDK contains `javac`, `jlink`, `jdeps`, `jconsole`, and other development tools that are never needed at runtime. Using `eclipse-temurin:21-jre-alpine` instead of `eclipse-temurin:21-jdk-alpine` for the runtime stage saves ~200MB and removes tools that could be used to compile malicious code inside a compromised container.
