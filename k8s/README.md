# Развертывание Airflow в Kubernetes с KubernetesExecutor

Этот проект содержит Kubernetes манифесты для развертывания Apache Airflow с использованием KubernetesExecutor.

## Архитектура

- **PostgreSQL**: 1 под с базой данных
- **Airflow Webserver**: 1 под с веб-интерфейсом  
- **Airflow Scheduler**: 1 под с планировщиком
- **Workers**: Создаются динамически через KubernetesExecutor

## Компоненты

1. **01-namespace.yaml** - Создание namespace `airflow`
2. **02-configmap.yaml** - Конфигурация Airflow
3. **03-secrets.yaml** - Пароли и секретные ключи
4. **04-postgres.yaml** - PostgreSQL база данных
5. **05-rbac.yaml** - RBAC для KubernetesExecutor
6. **06-webserver.yaml** - Airflow Webserver
7. **07-scheduler.yaml** - Airflow Scheduler

## Быстрое развертывание

```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

## Ручное развертывание

```bash
# 1. Применить манифесты по порядку
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml  
kubectl apply -f 03-secrets.yaml
kubectl apply -f 04-postgres.yaml
kubectl apply -f 05-rbac.yaml

# 2. Дождаться готовности PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n airflow --timeout=300s

# 3. Развернуть Airflow компоненты
kubectl apply -f 06-webserver.yaml
kubectl apply -f 07-scheduler.yaml
```

## Доступ к Airflow UI

1. **Port-forward:**
   ```bash
   kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
   ```
   Затем открыть http://localhost:8080

2. **LoadBalancer (если поддерживается кластером):**
   ```bash
   kubectl get svc airflow-webserver -n airflow
   ```

## Данные для входа

- **Логин:** admin
- **Пароль:** admin

## Проверка статуса

```bash
# Статус подов
kubectl get pods -n airflow

# Логи webserver
kubectl logs -f deployment/airflow-webserver -n airflow

# Логи scheduler  
kubectl logs -f deployment/airflow-scheduler -n airflow

# Логи PostgreSQL
kubectl logs -f deployment/postgres -n airflow
```

## Настройки KubernetesExecutor

Конфигурация в `02-configmap.yaml`:

- `AIRFLOW__KUBERNETES_EXECUTOR__NAMESPACE: "airflow"` - namespace для worker подов
- `AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_REPOSITORY: "apache/airflow"` - образ для worker
- `AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_TAG: "2.10.2-python3.9"` - тег образа
- `AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS: "True"` - удалять поды после выполнения
- `AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS_ON_SUCCESS: "True"` - удалять при успехе
- `AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS_ON_FAILURE: "False"` - сохранять при ошибке для отладки

## Хранилище

- **DAGs**: PVC `airflow-dags-pvc` (5Gi, ReadWriteMany)
- **Logs**: PVC `airflow-logs-pvc` (10Gi, ReadWriteMany)  
- **PostgreSQL**: PVC `postgres-pvc` (10Gi, ReadWriteOnce)

## Кастомизация

### Изменение версии Airflow

В `02-configmap.yaml` и `06-webserver.yaml`, `07-scheduler.yaml`:
```yaml
AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_TAG: "2.10.2-python3.9"
# и в образах контейнеров:
image: apache/airflow:2.10.2-python3.9
```

### Изменение ресурсов

В файлах deployment добавить/изменить:
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi" 
    cpu: "1000m"
```

### Добавление переменных окружения

В `02-configmap.yaml` добавить нужные переменные.

## Удаление

```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Troubleshooting

1. **Поды не запускаются:**
   ```bash
   kubectl describe pod <pod-name> -n airflow
   ```

2. **Проблемы с базой данных:**
   ```bash
   kubectl logs deployment/postgres -n airflow
   ```

3. **Проблемы с правами KubernetesExecutor:**
   ```bash
   kubectl auth can-i create pods --as=system:serviceaccount:airflow:airflow -n airflow
   ```

4. **Worker поды не создаются:**
   - Проверить RBAC права
   - Проверить наличие образа в registry
   - Проверить логи scheduler
