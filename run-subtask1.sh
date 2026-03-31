#!/bin/bash
set -e  # exit on any error

docker build -t main-service .
docker build -t report-service https://github.com/abay-kulamkadyr/trainer-workload-service.git#main

docker run -dit -p 8082:8082 --name main  -e spring_profiles_active=no-integrations main-service
docker run -dit -p 8081:8081 --name report -e spring_profiles_active=no-integrations report-service

