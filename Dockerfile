FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /app

COPY pom.xml .
# download dependencies as a separate layer and skip test dependencies (test containers are heavy)
RUN mvn dependency:resolve -Dscope=compile -q
RUN mvn dependency:resolve -Dscope=runtime -q
COPY src ./src
RUN mvn package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN addgroup -S spring && adduser -S spring -G spring # run as a user (not root)
USER spring
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8082

#the flag makes java respect cgroup limits for HEAP
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-jar", "app.jar"]
