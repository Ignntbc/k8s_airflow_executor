#!/bin/bash

echo "=== Удаление Airflow из Kubernetes (3-нодная архитектура) ==="

echo "1. Удаление Scheduler'ов..."
kubectl delete -f 07-scheduler-1.yaml --ignore-not-found=true
kubectl delete -f 07-scheduler-2.yaml --ignore-not-found=true
kubectl delete -f 07-scheduler.yaml --ignore-not-found=true  # старый файл

echo "2. Удаление Webserver..."
kubectl delete -f 06-webserver.yaml --ignore-not-found=true

echo "3. Удаление Worker Pod Template..."
kubectl delete -f 09-worker-pod-template.yaml --ignore-not-found=true

echo "4. Удаление системы мониторинга..."
kubectl delete -f 13-grafana-advanced-dashboard.yaml --ignore-not-found=true
kubectl delete -f 11-grafana.yaml --ignore-not-found=true
kubectl delete -f 10-prometheus.yaml --ignore-not-found=true
kubectl delete -f 12-node-exporter.yaml --ignore-not-found=true

echo "5. Удаление PostgreSQL..."
kubectl delete -f 04-postgres.yaml --ignore-not-found=true

echo "6. Удаление NFS Storage..."
kubectl delete -f 15-nfs-storage.yaml --ignore-not-found=true

echo "7. Очистка тестовых ресурсов..."
kubectl delete pod test-nfs-pod -n airflow --ignore-not-found=true
kubectl delete pvc test-nfs-claim -n airflow --ignore-not-found=true
kubectl delete pod dags-initializer -n airflow --ignore-not-found=true

echo "8. Удаление RBAC..."
kubectl delete -f 05-rbac.yaml --ignore-not-found=true

# Дополнительная очистка RBAC для node labeling
kubectl delete clusterrole node-labeler --ignore-not-found=true
kubectl delete clusterrolebinding node-labeler-binding --ignore-not-found=true

echo "9. Удаление PVC (Persistent Volume Claims)..."
kubectl delete pvc airflow-dags-pvc -n airflow --ignore-not-found=true
kubectl delete pvc airflow-logs-pvc -n airflow --ignore-not-found=true  
kubectl delete pvc postgres-pvc -n airflow --ignore-not-found=true

echo "10. Удаление Secrets..."
kubectl delete -f 03-secrets.yaml --ignore-not-found=true

echo "11. Удаление ConfigMap..."
kubectl delete -f 02-configmap.yaml --ignore-not-found=true

# Удаление дополнительных ConfigMaps
kubectl delete configmap node-labeling-script -n airflow --ignore-not-found=true
kubectl delete configmap nfs-storage-instructions -n airflow --ignore-not-found=true

echo "12. Очистка Jobs..."
kubectl delete job node-labeling-helper -n airflow --ignore-not-found=true

echo "13. Удаление маркировки узлов..."
echo "Удаляем маркировку airflow с узлов..."

# Получаем список всех узлов с маркировкой airflow
LABELED_NODES=$(kubectl get nodes -l "node-role.kubernetes.io/airflow" --no-headers -o custom-columns=":metadata.name" 2>/dev/null)

if [ ! -z "$LABELED_NODES" ]; then
    echo "Найдены узлы с маркировкой airflow:"
    echo "$LABELED_NODES"
    
    for node in $LABELED_NODES; do
        echo "Удаляем маркировку с узла: $node"
        kubectl label nodes $node node-role.kubernetes.io/airflow- --ignore-not-found=true
    done
else
    echo "Узлы с маркировкой airflow не найдены"
fi

echo "14. Удаление namespace (опционально, раскомментируйте если нужно)..."
read -p "Удалить namespace 'airflow'? Это удалит ВСЕ ресурсы в namespace. (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Удаляем namespace airflow..."
    kubectl delete namespace airflow --ignore-not-found=true
    echo "Namespace airflow удален"
else
    echo "Namespace airflow сохранен"
fi

echo ""
echo "=== Удаление завершено ==="

echo ""
echo "=== ПРОВЕРКА ОСТАВШИХСЯ РЕСУРСОВ ==="

echo "Ресурсы в namespace airflow:"
kubectl get all -n airflow 2>/dev/null || echo "Namespace airflow не существует или пуст"

echo ""
echo "PVC в namespace airflow:"
kubectl get pvc -n airflow 2>/dev/null || echo "PVC не найдены"

echo ""
echo "Узлы с маркировкой airflow:"
kubectl get nodes -l "node-role.kubernetes.io/airflow" --no-headers 2>/dev/null || echo "Узлы с маркировкой airflow не найдены"

echo ""
echo "ClusterRoles связанные с airflow:"
kubectl get clusterroles | grep -i airflow || echo "ClusterRoles связанные с airflow не найдены"

echo ""
echo "ClusterRoleBindings связанные с airflow:"
kubectl get clusterrolebindings | grep -i airflow || echo "ClusterRoleBindings связанные с airflow не найдены"

echo ""
echo "StorageClasses связанные с NFS:"
kubectl get storageclass | grep -E "(nfs|airflow)" || echo "NFS StorageClasses не найдены"

echo ""
echo "=== ДОПОЛНИТЕЛЬНАЯ ОЧИСТКА ==="
echo "Если остались 'висящие' ресурсы, используйте следующие команды:"
echo ""
echo "# Принудительное удаление всех подов в namespace:"
echo "kubectl delete pods --all -n airflow --force --grace-period=0"
echo ""
echo "# Удаление всех PVC принудительно:"  
echo "kubectl patch pvc <pvc-name> -n airflow -p '{\"metadata\":{\"finalizers\":null}}'"
echo ""
echo "# Очистка всех ресурсов в namespace:"
echo "kubectl delete all --all -n airflow"
echo ""
echo "# Полное удаление namespace:"
echo "kubectl delete namespace airflow --force --grace-period=0"

echo ""
echo "=== ГОТОВО К ПОВТОРНОМУ РАЗВЕРТЫВАНИЮ ==="
echo "Теперь можно заново развернуть кластер командой:"
echo "./deploy.sh"
