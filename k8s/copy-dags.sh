#!/bin/bash

# Скрипт для копирования DAG файлов в Kubernetes PVC

echo "=== Копирование DAG файлов в Airflow ==="

# Проверка, что мы находимся в правильной директории
if [ ! -d "./airflow/dags" ]; then
    echo "❌ Папка ./airflow/dags не найдена!"
    echo "Убедитесь, что вы находитесь в корневой папке проекта k8s_airflow_executor"
    exit 1
fi

# Проверка наличия DAG файлов
dag_count=$(find ./airflow/dags -name "*.py" | wc -l)
if [ $dag_count -eq 0 ]; then
    echo "❌ Не найдено Python файлов в папке ./airflow/dags"
    exit 1
fi

echo "📁 Найдено $dag_count DAG файлов:"
find ./airflow/dags -name "*.py" -exec basename {} \;

# Создание временного пода для копирования (если не существует)
echo "🔄 Проверка пода dags-initializer..."
if ! kubectl get pod dags-initializer -n airflow &> /dev/null; then
    echo "📦 Создание пода dags-initializer..."
    kubectl apply -f k8s/08-dags-pvc.yaml
    
    echo "⏳ Ожидание готовности пода..."
    kubectl wait --for=condition=ready pod/dags-initializer -n airflow --timeout=60s
fi

# Копирование DAG файлов
echo "📋 Копирование DAG файлов..."
kubectl cp ./airflow/dags/. airflow/dags-initializer:/opt/airflow/dags/ -c dags-copier

# Проверка результата копирования
echo "✅ Проверка содержимого PVC:"
kubectl exec dags-initializer -n airflow -c dags-copier -- ls -la /opt/airflow/dags/

# Установка правильных прав доступа
echo "🔐 Установка прав доступа..."
kubectl exec dags-initializer -n airflow -c dags-copier -- chmod -R 755 /opt/airflow/dags/

# Перезапуск компонентов Airflow для подхвата новых DAGs
echo "🔄 Перезапуск Airflow компонентов..."
kubectl rollout restart deployment/airflow-webserver -n airflow
kubectl rollout restart deployment/airflow-scheduler -n airflow

echo "⏳ Ожидание готовности компонентов..."
kubectl rollout status deployment/airflow-webserver -n airflow --timeout=120s
kubectl rollout status deployment/airflow-scheduler -n airflow --timeout=120s

# Очистка временного пода
echo "🧹 Удаление временного пода..."
kubectl delete pod dags-initializer -n airflow --ignore-not-found=true

echo ""
echo "🎉 DAG файлы успешно загружены!"
echo ""
echo "📋 Для проверки:"
echo "1. Откройте Airflow UI: kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow"
echo "2. Перейдите по адресу: http://localhost:8080"
echo "3. Войдите с данными: admin/admin"
echo ""
echo "⏰ DAG файлы должны появиться в интерфейсе через 1-2 минуты"
