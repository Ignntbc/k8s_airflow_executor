#!/bin/bash

# Скрecho "4. Удаление echo "7. Удаление ConfigMap..."
kubectl delete -f 02-configmap.yaml

echo "8. Удаление namespace (опционально, раскомментируйте если нужно)..."..."
kubectl delete -f 05-rbac.yaml

echo "5. Удаление PostgreSQL..."
kubectl delete -f 04-postgres.yaml

echo "6. Удаление Secrets..."
kubectl delete -f 03-secrets.yaml

echo "7. Удаление ConfigMap..."аления Airflow из Kubernetes

echo "=== Удаление Airflow из Kubernetes ==="

echo "1. Удаление Scheduler..."
kubectl delete -f 07-scheduler.yaml

echo "2. Удаление Webserver..."
kubectl delete -f 06-webserver.yaml

echo "3. Удаление системы мониторинга..."
kubectl delete -f 13-grafana-advanced-dashboard.yaml
kubectl delete -f 11-grafana.yaml
kubectl delete -f 10-prometheus.yaml
kubectl delete -f 12-node-exporter.yaml

echo "4. Удаление RBAC..."
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
