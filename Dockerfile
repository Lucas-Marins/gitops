# ============================================================
# BUILD STAGE — precisa do JDK + Maven (imagem SEM -runtime)
# ============================================================

## Imagem que sem problemas
FROM registry.access.redhat.com/ubi9/openjdk-17:1.24 AS builder

## Imagem com problema
##FROM registry.access.redhat.com/ubi9/openjdk-17:latest AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests




# ============================================================
# RUNTIME STAGE — só precisa do JRE (imagem COM -runtime)
# ============================================================

FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
