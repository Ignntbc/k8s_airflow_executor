#!/bin/bash

# Скрипт для развертывания Airflow в Kubernetes с KubernetesExecutor
# Новая архитектура: 3 ноды с распределением ролей

echo "=== Развертывание Airflow в Kubernetes (3-нодная архитектура) ==="

# Проверка маркировки узлов
echo "0. Проверка маркировки узлов..."
MANAGEMENT_NODES=$(kubectl get nodes -l node-role.kubernetes.io/airflow=management --no-headers | wc -l)
SCHEDULER1_NODES=$(kubectl get nodes -l node-role.kubernetes.io/airflow=scheduler-1 --no-headers | wc -l)
SCHEDULER2_NODES=$(kubectl get nodes -l node-role.kubernetes.io/airflow=scheduler-2 --no-headers | wc -l)

echo "Найдено узлов:"
echo "- Management: $MANAGEMENT_NODES"
echo "- Scheduler-1: $SCHEDULER1_NODES"
echo "- Scheduler-2: $SCHEDULER2_NODES"

if [ "$MANAGEMENT_NODES" -eq 0 ] || [ "$SCHEDULER1_NODES" -eq 0 ] || [ "$SCHEDULER2_NODES" -eq 0 ]; then
    echo "ВНИМАНИЕ: Не все узлы помечены. Применяю автоматическую маркировку..."
    kubectl apply -f 14-node-labels.yaml
    echo "Ожидание завершения маркировки узлов..."
    sleep 10
else
    echo "Все узлы корректно помечены."
fi

# 1. Создание namespace
echo "1. Создание namespace..."
kubectl apply -f 01-namespace.yaml

# 2. Создание ConfigMap с конфигурацией
echo "2. Создание ConfigMap..."
kubectl apply -f 02-configmap.yaml

# 3. Создание Secrets
echo "3. Создание Secrets..."
kubectl apply -f 03-secrets.yaml

# 4. Настройка NFS Storage
echo "4. Настройка NFS Storage для shared volumes..."
kubectl apply -f 15-nfs-storage.yaml

# Ожидание готовности NFS
echo "4.1. Ожидание готовности NFS сервера..."
kubectl wait --for=condition=ready pod -l app=nfs-server -n airflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=nfs-client-provisioner -n airflow --timeout=300s

# 5. Настройка RBAC для KubernetesExecutor
echo "5. Настройка RBAC..."
kubectl apply -f 05-rbac.yaml

# 6. Развертывание PostgreSQL на management ноде
echo "6. Развертывание PostgreSQL на management ноде..."
kubectl apply -f 04-postgres.yaml

# Ожидание готовности PostgreSQL
echo "6.1. Ожидание готовности PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n airflow --timeout=300s

# 7. Развертывание Airflow Webserver на management ноде
echo "7. Развертывание Airflow Webserver на management ноде..."
kubectl apply -f 06-webserver.yaml

# Ожидание готовности Webserver
echo "7.1. Ожидание готовности Webserver..."
kubectl wait --for=condition=ready pod -l app=airflow-webserver -n airflow --timeout=300s

# 8. Развертывание Airflow Scheduler'ов на отдельных нодах
echo "8. Развертывание Airflow Scheduler'ов..."
echo "8.1. Развертывание Scheduler-1..."
kubectl apply -f 07-scheduler-1.yaml

echo "8.2. Ожидание готовности Scheduler-1..."
kubectl wait --for=condition=ready pod -l app=airflow-scheduler,scheduler-instance=1 -n airflow --timeout=300s

echo "8.3. Развертывание Scheduler-2..."
kubectl apply -f 07-scheduler-2.yaml

echo "8.4. Ожидание готовности Scheduler-2..."
kubectl wait --for=condition=ready pod -l app=airflow-scheduler,scheduler-instance=2 -n airflow --timeout=300s

# 9. Обновление Worker Pod Template
echo "9. Обновление Worker Pod Template..."
kubectl apply -f 09-worker-pod-template.yaml

# 10. Развертывание системы мониторинга на management ноде
echo "10. Развертывание Node Exporter на всех нодах..."
kubectl apply -f 12-node-exporter.yaml

echo "11. Развертывание Prometheus на management ноде..."
kubectl apply -f 10-prometheus.yaml

echo "12. Развертывание Grafana на management ноде..."
kubectl apply -f 11-grafana.yaml
kubectl apply -f 13-grafana-advanced-dashboard.yaml

# Ожидание готовности мониторинга
echo "12.1. Ожидание готовности мониторинга..."
kubectl wait --for=condition=ready pod -l app=prometheus -n airflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n airflow --timeout=300s

# 13. Копирование DAGs в NFS PVC
echo "13. Копирование DAGs в NFS PVC..."

# Создание временного пода для копирования DAGs
echo "13.1. Создание временного пода для копирования..."
kubectl apply -f 08-dags-pvc.yaml

# Ожидание готовности инициализирующего пода
echo "13.2. Ожидание готовности инициализирующего пода..."
if kubectl wait --for=condition=ready pod/dags-initializer -n airflow --timeout=60s; then
    # Копирование DAGs
    echo "13.3. Копирование DAGs из локальной папки..."
    if [ -d "../airflow/dags" ]; then
        echo "Найдена папка ../airflow/dags"
        kubectl cp ../airflow/dags/. airflow/dags-initializer:/opt/airflow/dags/ -c dags-copier
        echo "DAGs скопированы успешно в NFS storage!"
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
    echo "13.4. Проверка содержимого DAGs в NFS..."
    kubectl exec dags-initializer -n airflow -c dags-copier -- ls -la /opt/airflow/dags/
    
    # Удаление инициализирующего пода
    echo "13.5. Удаление инициализирующего пода..."
    kubectl delete pod dags-initializer -n airflow
    
    # Перезапуск подов для подхвата новых DAGs
    echo "13.6. Перезапуск подов для подхвата новых DAGs..."
    kubectl rollout restart deployment/airflow-webserver -n airflow
    kubectl rollout restart deployment/airflow-scheduler-1 -n airflow
    kubectl rollout restart deployment/airflow-scheduler-2 -n airflow
else
    echo "Не удалось создать под для копирования DAGs. Пропускаю этот шаг."
fi

echo "=== Развертывание завершено ==="
echo ""
echo "=== АРХИТЕКТУРА КЛАСТЕРА ==="
echo "Нода 1 (Management):"
echo "- Airflow Webserver"
echo "- PostgreSQL"
echo "- Grafana"
echo "- Prometheus"
echo "- NFS Server"
echo ""
echo "Нода 2 (Scheduler-1):"
echo "- Airflow Scheduler #1"
echo "- Worker Pods (динамически)"
echo ""
echo "Нода 3 (Scheduler-2):"
echo "- Airflow Scheduler #2"
echo "- Worker Pods (динамически)"
echo ""
echo "Все ноды:"
echo "- Node Exporter для мониторинга"
echo ""
echo "Проверка статуса подов:"
kubectl get pods -n airflow -o wide

echo ""
echo "Проверка размещения по нодам:"
echo "Management нода:"
kubectl get pods -n airflow -l app=airflow-webserver -o wide
kubectl get pods -n airflow -l app=postgres -o wide
kubectl get pods -n airflow -l app=grafana -o wide
kubectl get pods -n airflow -l app=prometheus -o wide

echo ""
echo "Scheduler ноды:"
kubectl get pods -n airflow -l app=airflow-scheduler -o wide

echo ""
echo "Получение внешнего IP для доступа к Airflow:"
kubectl get svc airflow-webserver -n airflow

echo ""
echo "Получение внешнего IP для доступа к Grafana:"
kubectl get svc grafana -n airflow

echo ""
echo "=== ДОСТУП К СЕРВИСАМ ==="
echo "Для доступа к Airflow UI используйте:"
echo "kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow"
echo "Затем откройте: http://localhost:8080"
echo ""
echo "Для доступа к Grafana используйте:"
echo "kubectl port-forward svc/grafana 3000:3000 -n airflow"
echo "Затем откройте: http://localhost:3000"
echo ""
echo "=== УЧЕТНЫЕ ДАННЫЕ ==="
echo "Airflow:"
echo "Логин: admin"
echo "Пароль: admin"
echo ""
echo "Grafana:"
echo "Логин: admin"
echo "Пароль: admin"
echo ""
echo "=== ПОЛЕЗНЫЕ КОМАНДЫ ==="
echo "Просмотр логов:"
echo "kubectl logs -f deployment/airflow-webserver -n airflow"
echo "kubectl logs -f deployment/airflow-scheduler-1 -n airflow"
echo "kubectl logs -f deployment/airflow-scheduler-2 -n airflow"
echo ""
echo "Тестирование NFS:"
echo "kubectl logs test-nfs-pod -n airflow"
echo ""
echo "Мониторинг worker'ов:"
echo "kubectl get pods -n airflow | grep airflow-worker"
