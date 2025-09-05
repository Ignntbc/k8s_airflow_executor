#!/bin/bash

# Скрипт для проверки состояния мониторинга Airflow

echo "=== Проверка состояния мониторинга Airflow ==="
echo ""

# Проверка namespace
echo "1. Проверка namespace..."
if kubectl get namespace airflow &> /dev/null; then
    echo "✅ Namespace 'airflow' существует"
else
    echo "❌ Namespace 'airflow' не найден"
    exit 1
fi

echo ""

# Проверка подов
echo "2. Состояние подов..."
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                    ПОДЫ AIRFLOW                         │"
echo "└─────────────────────────────────────────────────────────┘"
kubectl get pods -n airflow -o wide

echo ""

# Проверка сервисов
echo "3. Состояние сервисов..."
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                   СЕРВИСЫ AIRFLOW                       │"
echo "└─────────────────────────────────────────────────────────┘"
kubectl get svc -n airflow

echo ""

# Проверка готовности основных компонентов
echo "4. Проверка готовности компонентов..."

components=("airflow-webserver" "airflow-scheduler" "postgres" "prometheus" "grafana")
for component in "${components[@]}"; do
    if kubectl get deployment $component -n airflow &> /dev/null; then
        ready=$(kubectl get deployment $component -n airflow -o jsonpath='{.status.readyReplicas}')
        desired=$(kubectl get deployment $component -n airflow -o jsonpath='{.spec.replicas}')
        if [ "$ready" = "$desired" ] && [ "$ready" != "" ]; then
            echo "✅ $component: готов ($ready/$desired)"
        else
            echo "❌ $component: не готов ($ready/$desired)"
        fi
    else
        echo "❓ $component: не найден"
    fi
done

echo ""

# Проверка DaemonSet (Node Exporter)
echo "5. Проверка Node Exporter..."
if kubectl get daemonset node-exporter -n airflow &> /dev/null; then
    desired=$(kubectl get daemonset node-exporter -n airflow -o jsonpath='{.status.desiredNumberScheduled}')
    ready=$(kubectl get daemonset node-exporter -n airflow -o jsonpath='{.status.numberReady}')
    echo "✅ Node Exporter: $ready/$desired узлов готовы"
else
    echo "❌ Node Exporter: не найден"
fi

echo ""

# Проверка доступности сервисов
echo "6. Проверка доступности эндпоинтов..."

# Проверка Airflow
if kubectl get svc airflow-webserver -n airflow &> /dev/null; then
    airflow_port=$(kubectl get svc airflow-webserver -n airflow -o jsonpath='{.spec.ports[0].port}')
    echo "🌐 Airflow UI: kubectl port-forward svc/airflow-webserver $airflow_port:$airflow_port -n airflow"
    echo "   Затем откройте: http://localhost:$airflow_port (admin/admin)"
fi

# Проверка Grafana
if kubectl get svc grafana -n airflow &> /dev/null; then
    grafana_port=$(kubectl get svc grafana -n airflow -o jsonpath='{.spec.ports[0].port}')
    echo "📊 Grafana: kubectl port-forward svc/grafana $grafana_port:$grafana_port -n airflow"
    echo "   Затем откройте: http://localhost:$grafana_port (admin/admin)"
fi

# Проверка Prometheus
if kubectl get svc prometheus -n airflow &> /dev/null; then
    prometheus_port=$(kubectl get svc prometheus -n airflow -o jsonpath='{.spec.ports[0].port}')
    echo "🔍 Prometheus: kubectl port-forward svc/prometheus $prometheus_port:$prometheus_port -n airflow"
    echo "   Затем откройте: http://localhost:$prometheus_port"
fi

echo ""

# Проверка метрик
echo "7. Проверка доступности метрик..."

# Проверяем, что Prometheus может получать метрики
if kubectl get pod -l app=prometheus -n airflow &> /dev/null; then
    prometheus_pod=$(kubectl get pod -l app=prometheus -n airflow -o jsonpath='{.items[0].metadata.name}')
    if [ "$prometheus_pod" != "" ]; then
        echo "🔄 Проверяем доступность метрик в Prometheus..."
        # Простая проверка метрик
        metrics_check=$(kubectl exec $prometheus_pod -n airflow -- wget -qO- http://localhost:9090/api/v1/label/__name__/values 2>/dev/null | grep -o '"up"' | wc -l)
        if [ "$metrics_check" -gt 0 ]; then
            echo "✅ Метрики доступны в Prometheus"
        else
            echo "⚠️  Метрики могут быть недоступны"
        fi
    fi
fi

echo ""

# Полезные команды
echo "8. Полезные команды для отладки..."
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                  ОТЛАДКА И ЛОГИ                         │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "Логи основных компонентов:"
echo "• Airflow Webserver:  kubectl logs -f deployment/airflow-webserver -n airflow"
echo "• Airflow Scheduler:  kubectl logs -f deployment/airflow-scheduler -n airflow"
echo "• PostgreSQL:         kubectl logs -f deployment/postgres -n airflow"
echo "• Prometheus:         kubectl logs -f deployment/prometheus -n airflow"
echo "• Grafana:            kubectl logs -f deployment/grafana -n airflow"
echo ""
echo "Проверка конфигурации:"
echo "• ConfigMaps:         kubectl get configmaps -n airflow"
echo "• Secrets:            kubectl get secrets -n airflow"
echo "• PVCs:               kubectl get pvc -n airflow"
echo ""
echo "Мониторинг ресурсов:"
echo "• Top подов:          kubectl top pods -n airflow"
echo "• Top узлов:          kubectl top nodes"
echo "• События:            kubectl get events -n airflow --sort-by='.lastTimestamp'"

echo ""
echo "=== Проверка завершена ==="

# Проверка общего состояния
failed_components=0
for component in "${components[@]}"; do
    if kubectl get deployment $component -n airflow &> /dev/null; then
        ready=$(kubectl get deployment $component -n airflow -o jsonpath='{.status.readyReplicas}')
        desired=$(kubectl get deployment $component -n airflow -o jsonpath='{.spec.replicas}')
        if [ "$ready" != "$desired" ] || [ "$ready" = "" ]; then
            ((failed_components++))
        fi
    else
        ((failed_components++))
    fi
done

if [ $failed_components -eq 0 ]; then
    echo "🎉 Все компоненты работают корректно!"
    echo ""
    echo "Для начала работы выполните:"
    echo "kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow &"
    echo "kubectl port-forward svc/grafana 3000:3000 -n airflow &"
    echo ""
    echo "Затем откройте:"
    echo "• Airflow: http://localhost:8080"
    echo "• Grafana: http://localhost:3000"
else
    echo "⚠️  Обнаружены проблемы с $failed_components компонентами"
    echo "Проверьте логи и состояние подов"
fi
