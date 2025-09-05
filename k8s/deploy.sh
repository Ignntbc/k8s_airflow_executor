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

# 8. Развертывание системы мониторинга
echo "10. Развертывание Node Exporter..."
kubectl apply -f 12-node-exporter.yaml

echo "11. Развертывание Prometheus..."
kubectl apply -f 10-prometheus.yaml

echo "12. Развертывание Grafana..."
kubectl apply -f 11-grafana.yaml
kubectl apply -f 13-grafana-advanced-dashboard.yaml

# Ожидание готовности Prometheus и Grafana
echo "13. Ожидание готовности мониторинга..."
kubectl wait --for=condition=ready pod -l app=prometheus -n airflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n airflow --timeout=300s

# 8. Копирование DAGs в PVC
echo "14. Копирование DAGs в PVC..."

# Создание временного пода для копирования DAGs
echo "14.1. Создание временного пода для копирования..."
kubectl apply -f 08-dags-pvc.yaml

# Ожидание готовности инициализирующего пода
echo "14.2. Ожидание готовности инициализирующего пода..."
if kubectl wait --for=condition=ready pod/dags-initializer -n airflow --timeout=60s; then
    # Копирование DAGs
    echo "14.3. Копирование DAGs из локальной папки..."
    if [ -d "../airflow/dags" ]; then
        echo "Найдена папка ../airflow/dags"
        kubectl cp ../airflow/dags/. airflow/dags-initializer:/opt/airflow/dags/ -c dags-copier
        echo "DAGs скопированы успешно!"
    elif [ -d "../airflow" ]; then
        echo "Найдена папка ../airflow, но нет подпапки dags"
        echo "Создаю пустую структуру..."
        kubectl exec dags-initializer -n airflow -c dags-copier -- mkdir -p /opt/airflow/dags
        echo "Скопируйте DAGs вручную или создайте их в папке ../airflow/dags"
    else
        echo "Папка ../airflow не найдена."
        echo "Создаю пустую структуру для DAGs..."
        kubectl exec dags-initializer -n airflow -c dags-copier -- mkdir -p /opt/airflow/dags
        echo "Скопируйте DAGs вручную командой:"
        echo "kubectl cp /path/to/your/dags/. airflow/dags-initializer:/opt/airflow/dags/ -c dags-copier"
    fi
    
    # Проверка содержимого
    echo "14.4. Проверка содержимого DAGs..."
    kubectl exec dags-initializer -n airflow -c dags-copier -- ls -la /opt/airflow/dags/
    
    # Удаление инициализирующего пода
    echo "14.5. Удаление инициализирующего пода..."
    kubectl delete pod dags-initializer -n airflow
    
    # Перезапуск подов для подхвата новых DAGs
    echo "14.6. Перезапуск подов для подхвата новых DAGs..."
    kubectl rollout restart deployment/airflow-webserver -n airflow
    kubectl rollout restart deployment/airflow-scheduler -n airflow
else
    echo "Не удалось создать под для копирования DAGs. Пропускаю этот шаг."
fi

echo "=== Развертывание завершено ==="
echo ""
echo "Проверка статуса подов:"
kubectl get pods -n airflow

echo ""
echo "Получение внешнего IP для доступа к Airflow:"
kubectl get svc airflow-webserver -n airflow

echo ""
echo "Получение внешнего IP для доступа к Grafana:"
kubectl get svc grafana -n airflow

echo ""
echo "Для доступа к Airflow UI используйте:"
echo "kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow"
echo ""
echo "Для доступа к Grafana используйте:"
echo "kubectl port-forward svc/grafana 3000:3000 -n airflow"
echo ""
echo "Данные для входа в Airflow:"
echo "Логин: admin"
echo "Пароль: admin"
echo ""
echo "Данные для входа в Grafana:"
echo "Логин: admin"
echo "Пароль: admin"
echo ""
echo "Для просмотра логов:"
echo "kubectl logs -f deployment/airflow-webserver -n airflow"
echo "kubectl logs -f deployment/airflow-scheduler -n airflow"
