#!/bin/bash
set -e  # exit on any error

# ── Network ──────────────────────────────────────────────────────────────────
docker network create gym-network 2>/dev/null || echo "Network already exists, skipping"
#
# ── Builds ───────────────────────────────────────────────────────────────────
docker build -t main-service .
docker build -t report-service https://github.com/abay-kulamkadyr/trainer-workload-service.git#main
docker build -t eureka-server https://github.com/abay-kulamkadyr/eureka-server.git#main

# ── Health checker ───────────────────────────────────────────────────────────────────
wait_healthy() {
    local name=$1
    local timeout=${2:-60}
    echo "Waiting for $name to be healthy..."
    for i in $(seq 1 $timeout); do
        status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null)
        [ "$status" = "healthy" ] && echo "$name is healthy" && return 0
        sleep 1
    done
    echo "Timeout waiting for $name" && exit 1
}

# ── Infrastructure ───────────────────────────────────────────────────────────
docker run -dit -p 8761:8761 \
    --name=eureka \
    --network=gym-network \
    --health-cmd="nc -z 127.0.0.1 8761" \
    --health-interval=10s \
    --health-retries=5 \
    eureka-server

docker run -dit -p 5432:5432 \
    -e POSTGRES_USER=myuser \
    -e POSTGRES_PASSWORD=password \
    -e POSTGRES_DB=gym-crm \
    --name postgres \
    --network=gym-network \
    --health-cmd="pg_isready -U myuser -d gym-crm" \
    --health-interval=5s \
    --health-retries=10 \
    postgres:16

docker run -dit -p 27017:27017 \
    -e MONGO_INITDB_DATABASE=trainer_db \
    -e MONGO_INITDB_ROOT_PASSWORD=secret \
    -e MONGO_INITDB_ROOT_USERNAME=root \
    --name mongodb \
    --network=gym-network \
    --health-cmd="mongosh --eval 'db.runCommand({ping:1})' --quiet" \
    --health-interval=5s \
    --health-retries=10 \
    mongo:8.2.5

docker run -dit \
    -p 9092:9092 \
    -p 29092:29092 \
    -p 9999:9999 \
    -p 9099:9099 \
    -e CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS="1@kafka:9099" \
    -e KAFKA_LISTENERS=INTERNAL://0.0.0.0:19092,EXTERNAL://0.0.0.0:9092,DOCKER://0.0.0.0:29092,CONTROLLER://0.0.0.0:9099 \
    -e KAFKA_ADVERTISED_LISTENERS=INTERNAL://kafka:19092,EXTERNAL://${DOCKER_HOST_IP:-127.0.0.1}:9092,DOCKER://host.docker.internal:29092 \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,DOCKER:PLAINTEXT,CONTROLLER:PLAINTEXT \
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
    -e KAFKA_INTER_BROKER_LISTENER_NAME=INTERNAL \
    -e KAFKA_LOG4J_LOGGERS="kafka.controller=INFO,kafka.producer.async.DefaultEventHandler=INFO,state.change.logger=INFO" \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
    -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
    -e KAFKA_AUTHORIZER_CLASS_NAME=org.apache.kafka.metadata.authorizer.StandardAuthorizer \
    -e KAFKA_ALLOW_EVERYONE_IF_NO_ACL_FOUND="true" \
    --name kafka \
    --network=gym-network \
    --health-cmd="nc -z 127.0.0.1 9092" \
    --health-interval=5s \
    --health-retries=10 \
    confluentinc/cp-kafka:8.0.0

# ── Application services ─────────────────────────────────────────────────────
wait_healthy postgres
wait_healthy kafka
wait_healthy eureka
docker run -dit -p 8082:8082 \
    -e spring_profiles_active=local \
    -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/gym-crm \
    -e SPRING_DATASOURCE_USERNAME=myuser \
    -e SPRING_DATASOURCE_PASSWORD=password \
    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:19092 \
    -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka:8761/eureka/ \
    --network=gym-network \
    --name main \
    main-service

wait_healthy mongodb
docker run -dit -p 8081:8081 \
    -e SPRING_DATA_MONGODB_URI=mongodb://root:secret@mongodb:27017/trainer_db?authSource=admin \
    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:19092 \
    -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka:8761/eureka/ \
    --network=gym-network \
    --name report \
    report-service

