#!/bin/bash

# Скрипт для удаления Airflow из Kubernetes

echo "=== Удаление Airflow из Kubernetes ==="

echo "1. Удаление Scheduler..."
kubectl delete -f 07-scheduler.yaml

echo "2. Удаление Webserver..."
kubectl delete -f 06-webserver.yaml

echo "3. Удаление RBAC..."
kubectl delete -f 05-rbac.yaml

echo "4. Удаление PostgreSQL..."
kubectl delete -f 04-postgres.yaml

echo "5. Удаление Secrets..."
kubectl delete -f 03-secrets.yaml

echo "6. Удаление ConfigMap..."
kubectl delete -f 02-configmap.yaml

echo "7. Удаление namespace (опционально, раскомментируйте если нужно)..."
# kubectl delete -f 01-namespace.yaml

echo "=== Удаление завершено ==="

echo ""
echo "Проверка оставшихся ресурсов в namespace airflow:"
kubectl get all -n airflow
