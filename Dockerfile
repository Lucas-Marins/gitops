FROM registry.access.redhat.com/ubi9/openjdk-17:latest AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
