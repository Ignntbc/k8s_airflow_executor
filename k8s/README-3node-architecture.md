# Airflow Kubernetes 3-Node Architecture

Этот документ описывает новую архитектуру Airflow кластера, распределенного на 3 узлах для повышения отказоустойчивости и производительности.

## Обзор архитектуры

### Старая архитектура (1 нода)
Все компоненты размещались на одном узле с использованием `podAffinity`.

### Новая архитектура (3 ноды)

```
┌─────────────────────────────────────────────────────────────────┐
│                        AIRFLOW CLUSTER                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   НОДА 1        │   НОДА 2        │         НОДА 3              │
│  (Management)   │ (Scheduler-1)   │      (Scheduler-2)          │
├─────────────────┼─────────────────┼─────────────────────────────┤
│ • Webserver     │ • Scheduler #1  │ • Scheduler #2              │
│ • PostgreSQL    │ • Worker Pods   │ • Worker Pods               │
│ • Grafana       │ • Node Exporter │ • Node Exporter             │
│ • Prometheus    │                 │                             │
│ • NFS Server    │                 │                             │
│ • Node Exporter │                 │                             │
└─────────────────┴─────────────────┴─────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │ NFS Storage │
                    │ (DAGs/Logs) │
                    └─────────────┘
```

## Преимущества новой архитектуры

### ✅ Высокая доступность (HA)
- Выход из строя одной ноды не нарушает работу кластера
- Два независимых scheduler'а для планирования задач
- Автоматическое переключение при отказе узлов

### ✅ Масштабируемость
- Легко добавлять новые scheduler узлы
- Распределение нагрузки между узлами
- Возможность горизонтального масштабирования worker'ов

### ✅ Производительность
- Разделение вычислительной нагрузки
- Изоляция критических компонентов
- Оптимизированное размещение подов

### ✅ Управляемость
- Четкое разделение ответственности
- Упрощенное обслуживание и отладка
- Изолированное обновление компонентов

## Детальное описание компонентов

### Нода 1: Management (Управляющая)
**Роль**: Централизованное управление и мониторинг

**Компоненты**:
- **Airflow Webserver**: Веб-интерфейс для управления DAG'ами
- **PostgreSQL**: База данных метаданных Airflow
- **Grafana**: Система визуализации метрик
- **Prometheus**: Сбор и хранение метрик
- **NFS Server**: Общее хранилище для DAG'ов и логов

**Характеристики**:
- Маркировка: `node-role.kubernetes.io/airflow=management`
- Доступ извне через LoadBalancer/NodePort
- Центральная точка администрирования

### Нода 2: Scheduler-1 (Первый планировщик)
**Роль**: Основной планировщик задач

**Компоненты**:
- **Airflow Scheduler #1**: Первичный планировщик DAG'ов
- **Worker Pods**: Динамически создаваемые поды для выполнения задач
- **Node Exporter**: Сбор метрик узла

**Характеристики**:
- Маркировка: `node-role.kubernetes.io/airflow=scheduler-1`
- Приоритетное размещение worker'ов
- Anti-affinity с другими scheduler'ами

### Нода 3: Scheduler-2 (Второй планировщик)
**Роль**: Резервный/дополнительный планировщик

**Компоненты**:
- **Airflow Scheduler #2**: Вторичный планировщик для HA
- **Worker Pods**: Динамически создаваемые поды для выполнения задач
- **Node Exporter**: Сбор метрик узла

**Характеристики**:
- Маркировка: `node-role.kubernetes.io/airflow=scheduler-2`
- Балансировка нагрузки с scheduler-1
- Автоматическое переключение при отказах

## Хранилище данных

### NFS Storage (ReadWriteMany)
**Назначение**: Общий доступ к DAG'ам и логам

**Компоненты**:
- **NFS Server**: Развернут на management ноде
- **NFS Client Provisioner**: Автоматическое создание PV
- **StorageClass**: `nfs-client` для ReadWriteMany

**PVC**:
```yaml
# DAGs
airflow-dags-pvc: 5Gi (ReadWriteMany)

# Logs  
airflow-logs-pvc: 10Gi (ReadWriteMany)
```

### PostgreSQL Storage (ReadWriteOnce)
**Назначение**: База данных метаданных

**Характеристики**:
- Размещение только на management ноде
- Локальное хранилище для производительности
- Подключение через Kubernetes Service

## Сетевая архитектура

### Service Discovery
Все компоненты используют стандартные Kubernetes Services:

```yaml
postgres:5432          # PostgreSQL
airflow-webserver:8080 # Web UI
prometheus:9090        # Metrics
grafana:3000          # Monitoring
nfs-server:2049       # NFS
```

### Маршрутизация трафика
- **Внешний доступ**: LoadBalancer для webserver и grafana
- **Внутренний трафик**: ClusterIP для всех остальных сервисов
- **Мониторинг**: Prometheus scraping через аннотации

## Развертывание

### Предварительные требования
1. Kubernetes кластер с 3+ узлами
2. kubectl настроенный для доступа к кластеру
3. Достаточные ресурсы на каждом узле

### Минимальные ресурсы

**Нода 1 (Management)**:
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB

**Нода 2-3 (Schedulers)**:
- CPU: 1 core
- RAM: 2GB
- Storage: 10GB

### Пошаговое развертывание

1. **Клонирование репозитория**:
```bash
git clone <repository-url>
cd k8s_airflow_executor/k8s
```

2. **Автоматическое развертывание**:
```bash
chmod +x deploy.sh
./deploy.sh
```

3. **Ручное развертывание** (по порядку):
```bash
# Маркировка узлов
kubectl apply -f 14-node-labels.yaml

# Базовая конфигурация
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secrets.yaml

# NFS Storage
kubectl apply -f 15-nfs-storage.yaml

# RBAC
kubectl apply -f 05-rbac.yaml

# PostgreSQL
kubectl apply -f 04-postgres.yaml

# Webserver
kubectl apply -f 06-webserver.yaml

# Schedulers
kubectl apply -f 07-scheduler-1.yaml
kubectl apply -f 07-scheduler-2.yaml

# Worker template
kubectl apply -f 09-worker-pod-template.yaml

# Мониторинг
kubectl apply -f 12-node-exporter.yaml
kubectl apply -f 10-prometheus.yaml
kubectl apply -f 11-grafana.yaml
kubectl apply -f 13-grafana-advanced-dashboard.yaml
```

### Проверка развертывания

```bash
# Статус всех подов
kubectl get pods -n airflow -o wide

# Размещение по узлам
kubectl get pods -n airflow -o wide | grep -E "(management|scheduler)"

# Состояние сервисов
kubectl get svc -n airflow

# Проверка NFS
kubectl logs test-nfs-pod -n airflow
```

## Мониторинг

### Grafana Dashboards
Доступны два дашборда:
1. **Airflow Kubernetes Metrics**: Базовые метрики
2. **Airflow Advanced Kubernetes Metrics**: Детализированные метрики

### Ключевые метрики
- CPU/Memory по узлам и подам
- Состояние scheduler'ов
- Количество активных worker'ов
- Производительность DAG'ов
- Состояние базы данных

### Доступ к мониторингу
```bash
# Grafana
kubectl port-forward svc/grafana 3000:3000 -n airflow
# Открыть: http://localhost:3000
# Логин: admin / Пароль: admin

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n airflow
# Открыть: http://localhost:9090
```

## Управление

### Доступ к Airflow UI
```bash
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Открыть: http://localhost:8080
# Логин: admin / Пароль: admin
```

### Управление DAG'ами
```bash
# Копирование новых DAG'ов
kubectl cp /path/to/dags/. <webserver-pod>:/opt/airflow/dags/ -n airflow

# Обновление через NFS (автоматически синхронизируется)
# DAG'и доступны на всех узлах через NFS mount
```

### Масштабирование scheduler'ов
```bash
# Увеличение replicas (осторожно с базой данных!)
kubectl scale deployment airflow-scheduler-1 --replicas=2 -n airflow

# Добавление нового scheduler узла
# 1. Пометить новый узел
kubectl label nodes <new-node> node-role.kubernetes.io/airflow=scheduler-3

# 2. Создать новый deployment (скопировать 07-scheduler-2.yaml)
```

## Troubleshooting

### Общие проблемы

#### 1. Поды не запускаются
```bash
# Проверка событий
kubectl get events -n airflow --sort-by='.lastTimestamp'

# Описание пода
kubectl describe pod <pod-name> -n airflow

# Проверка маркировки узлов
kubectl get nodes --show-labels | grep airflow
```

#### 2. NFS проблемы
```bash
# Статус NFS сервера
kubectl logs -l app=nfs-server -n airflow

# Статус provisioner
kubectl logs -l app=nfs-client-provisioner -n airflow

# Проверка PVC
kubectl get pvc -n airflow

# Тест NFS mount
kubectl apply -f 15-nfs-storage.yaml  # содержит тестовый под
kubectl logs test-nfs-pod -n airflow
```

#### 3. Scheduler'ы не работают
```bash
# Логи scheduler'ов
kubectl logs -l app=airflow-scheduler -n airflow

# Проверка подключения к БД
kubectl exec -it <scheduler-pod> -n airflow -- airflow db check

# Состояние jobs в БД
kubectl exec -it <webserver-pod> -n airflow -- airflow jobs check
```

#### 4. Worker'ы не создаются
```bash
# Проверка RBAC
kubectl auth can-i create pods --as=system:serviceaccount:airflow:airflow -n airflow

# Pod template конфигурация
kubectl get configmap worker-pod-template -n airflow -o yaml

# События создания подов
kubectl get events -n airflow | grep "worker"
```

### Проблемы производительности

#### 1. Медленная работа scheduler'ов
- Проверить ресурсы CPU/Memory
- Увеличить `AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL`
- Оптимизировать DAG'и (уменьшить количество задач)

#### 2. Проблемы с базой данных
```bash
# Подключения к PostgreSQL
kubectl exec -it <postgres-pod> -n airflow -- psql -U airflow -d airflow -c "SELECT * FROM pg_stat_activity;"

# Размер базы данных
kubectl exec -it <postgres-pod> -n airflow -- psql -U airflow -d airflow -c "SELECT pg_size_pretty(pg_database_size('airflow'));"
```

#### 3. Проблемы с NFS
- Проверить latency сети между узлами
- Увеличить timeout'ы в NFS настройках
- Рассмотреть использование более производительного storage

### Логи и отладка

```bash
# Все логи namespace
kubectl logs --tail=100 -l app=airflow-webserver -n airflow
kubectl logs --tail=100 -l app=airflow-scheduler -n airflow

# Интерактивный доступ
kubectl exec -it <pod-name> -n airflow -- /bin/bash

# Проверка конфигурации Airflow
kubectl exec -it <pod-name> -n airflow -- airflow config list
```

## Обновление и обслуживание

### Обновление версии Airflow
1. Обновить версию в образах в манифестах
2. Применить rolling update:
```bash
kubectl set image deployment/airflow-webserver airflow-webserver=apache/airflow:2.11.0-python3.9 -n airflow
kubectl set image deployment/airflow-scheduler-1 airflow-scheduler=apache/airflow:2.11.0-python3.9 -n airflow
kubectl set image deployment/airflow-scheduler-2 airflow-scheduler=apache/airflow:2.11.0-python3.9 -n airflow
```

### Резервное копирование
```bash
# Backup PostgreSQL
kubectl exec <postgres-pod> -n airflow -- pg_dump -U airflow airflow > airflow-backup.sql

# Backup DAGs (если не в Git)
kubectl cp <webserver-pod>:/opt/airflow/dags ./dags-backup -n airflow
```

### Очистка
```bash
# Полная очистка
chmod +x cleanup.sh
./cleanup.sh

# Частичная очистка (только поды)
kubectl delete deployment --all -n airflow
```

## Миграция со старой архитектуры

### Шаги миграции
1. **Резервное копирование данных**
2. **Остановка старого кластера**
3. **Развертывание новой архитектуры**
4. **Восстановление данных**
5. **Тестирование функциональности**

### Команды миграции
```bash
# 1. Backup
kubectl exec <old-postgres-pod> -- pg_dump -U airflow airflow > migration-backup.sql
kubectl cp <old-webserver-pod>:/opt/airflow/dags ./dags-migration

# 2. Новое развертывание
./deploy.sh

# 3. Restore
kubectl cp migration-backup.sql <new-postgres-pod>:/tmp/
kubectl exec <new-postgres-pod> -- psql -U airflow airflow < /tmp/migration-backup.sql
kubectl cp ./dags-migration <new-webserver-pod>:/opt/airflow/dags/
```

## Заключение

Новая 3-нодная архитектура обеспечивает:
- **Высокую доступность** системы
- **Масштабируемость** под нагрузку
- **Упрощенное управление** компонентами
- **Улучшенную производительность**

Для получения дополнительной помощи обращайтесь к документации Airflow и Kubernetes.
