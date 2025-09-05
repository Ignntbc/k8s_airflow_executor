# Руководство по мониторингу Airflow в Kubernetes

## Обзор добавленного мониторинга

В проект был добавлен полноценный стек мониторинга, который позволяет отслеживать:

### 📊 Основные метрики:
- **CPU**: Загрузка процессора узлов и подов Airflow
- **Memory**: Использование оперативной памяти узлов и подов Airflow
- **Network**: Сетевая активность (входящий/исходящий трафик)
- **Disk I/O**: Активность чтения/записи на диск
- **Pod Status**: Количество активных подов и их статус

## 🚀 Быстрый старт

### 1. Развертывание
```bash
cd k8s
./deploy.sh
```

### 2. Доступ к интерфейсам
```bash
# Airflow UI
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n airflow

# Prometheus (опционально)
kubectl port-forward svc/prometheus 9090:9090 -n airflow
```

### 3. Открыть в браузере
- **Airflow**: http://localhost:8080 (admin/admin)
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## 📈 Дашборды Grafana

### 1. "Airflow Kubernetes Metrics" (базовый)
- Общая загрузка CPU и памяти
- Количество активных подов
- Базовая сетевая активность

### 2. "Airflow Advanced Kubernetes Metrics" (детализированный)
- Детальные метрики по каждому поду
- Сравнение узлов и подов
- Дисковая активность
- Расширенная сетевая аналитика

## 🔧 Архитектура мониторинга

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Node Exporter │───►│   Prometheus    │───►│     Grafana     │
│  (метрики узлов)│    │ (сбор метрик)   │    │ (визуализация)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              ▲
                              │
┌─────────────────┐           │
│ Kubernetes API  │───────────┘
│ (метрики подов) │
└─────────────────┘
```

## 📋 Компоненты мониторинга

| Компонент | Порт | Назначение |
|-----------|------|------------|
| Prometheus | 9090 | Сбор и хранение метрик |
| Grafana | 3000 | Визуализация дашбордов |
| Node Exporter | 9100 | Метрики узлов |

## 🔍 Полезные запросы Prometheus

### CPU метрики
```promql
# Загрузка CPU подов Airflow
rate(container_cpu_usage_seconds_total{namespace="airflow", pod=~"airflow-.*"}[5m]) * 100

# Загрузка CPU узлов
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory метрики  
```promql
# Использование памяти подов Airflow
container_memory_usage_bytes{namespace="airflow", pod=~"airflow-.*"}

# Использование памяти узлов
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes
```

## 🚨 Настройка алертов (расширение)

Для настройки уведомлений можно добавить Alertmanager:

```yaml
# Пример правила для высокой загрузки CPU
groups:
- name: airflow.rules
  rules:
  - alert: AirflowHighCPUUsage
    expr: rate(container_cpu_usage_seconds_total{namespace="airflow"}[5m]) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage in Airflow pod"
```

## 📊 Мониторинг производительности

### Ключевые показатели для отслеживания:

1. **CPU Usage** - должно быть < 80% в норме
2. **Memory Usage** - отслеживать утечки памяти
3. **Pod Restarts** - количество перезапусков подов
4. **Network I/O** - пропускная способность
5. **Disk I/O** - активность базы данных

### Рекомендации по оптимизации:

- Если CPU > 80% длительное время - увеличить resources.limits
- Если Memory растет постоянно - проверить на утечки памяти
- Высокий Disk I/O - оптимизировать запросы к БД
- Много Network I/O - проверить размер передаваемых данных

## 🛠 Troubleshooting

### Prometheus не собирает метрики подов
```bash
# Проверить аннотации подов
kubectl get pods -n airflow -o yaml | grep -A 5 annotations

# Проверить ServiceAccount права
kubectl auth can-i get pods --as=system:serviceaccount:airflow:airflow -n airflow
```

### Grafana не показывает данные
```bash
# Проверить подключение к Prometheus
kubectl exec -it deployment/grafana -n airflow -- wget -qO- http://prometheus:9090/api/v1/label/__name__/values
```

### Node Exporter не запускается
```bash
# Проверить DaemonSet
kubectl get daemonset node-exporter -n airflow
kubectl describe daemonset node-exporter -n airflow
```

## 📚 Дополнительные ресурсы

- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Kubernetes Monitoring Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-monitoring/)
