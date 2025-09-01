#!/bin/bash

# Скрипт для развертывания Airflow в Kubernetes с KubernetesExecutor

echo "=== Развертывание Airflow в Kubernetes ==="

# 1. Создание namespace
echo "1. Создание namespace..."
kubectl apply -f 01-namespace.yaml

# 2. Создание ConfigMap с конфигурацией
echo "2. Создание ConfigMap..."
kubectl apply -f 02-configmap.yaml

# 3. Создание Secrets
echo "3. Создание Secrets..."
kubectl apply -f 03-secrets.yaml

# 4. Развертывание PostgreSQL
echo "4. Развертывание PostgreSQL..."
kubectl apply -f 04-postgres.yaml

# 5. Настройка RBAC для KubernetesExecutor
echo "5. Настройка RBAC..."
kubectl apply -f 05-rbac.yaml

# Ожидание готовности PostgreSQL
echo "6. Ожидание готовности PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n airflow --timeout=300s

# 6. Развертывание Airflow Webserver
echo "7. Развертывание Airflow Webserver..."
kubectl apply -f 06-webserver.yaml

# Ожидание готовности Webserver
echo "8. Ожидание готовности Webserver..."
kubectl wait --for=condition=ready pod -l app=airflow-webserver -n airflow --timeout=300s

# 7. Развертывание Airflow Scheduler
echo "9. Развертывание Airflow Scheduler..."
kubectl apply -f 07-scheduler.yaml

echo "=== Развертывание завершено ==="
echo ""
echo "Проверка статуса подов:"
kubectl get pods -n airflow

echo ""
echo "Получение внешнего IP для доступа к Airflow:"
kubectl get svc airflow-webserver -n airflow

echo ""
echo "Для доступа к Airflow UI используйте:"
echo "kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow"
echo ""
echo "Логин: admin"
echo "Пароль: admin"
echo ""
echo "Для просмотра логов:"
echo "kubectl logs -f deployment/airflow-webserver -n airflow"
echo "kubectl logs -f deployment/airflow-scheduler -n airflow"
