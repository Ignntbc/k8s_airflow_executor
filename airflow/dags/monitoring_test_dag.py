"""
Тестовый DAG для проверки мониторинга CPU и памяти
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import time
import psutil
import logging

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

dag = DAG(
    'monitoring_test_dag',
    default_args=default_args,
    description='DAG для тестирования мониторинга CPU и памяти',
    schedule_interval=timedelta(minutes=5),
    catchup=False,
    tags=['test', 'monitoring'],
)

def cpu_intensive_task():
    """Задача, нагружающая CPU"""
    logging.info("Начинаем CPU-интенсивную задачу")
    
    # Нагрузка на CPU в течение 30 секунд
    start_time = time.time()
    while time.time() - start_time < 30:
        # Вычисления для нагрузки CPU
        result = sum(i * i for i in range(10000))
    
    # Получаем текущие метрики
    cpu_percent = psutil.cpu_percent(interval=1)
    memory_info = psutil.virtual_memory()
    
    logging.info(f"CPU использование: {cpu_percent}%")
    logging.info(f"Память использована: {memory_info.percent}%")
    logging.info("CPU-интенсивная задача завершена")
    
    return {
        'cpu_percent': cpu_percent,
        'memory_percent': memory_info.percent,
        'result': result
    }

def memory_intensive_task():
    """Задача, потребляющая память"""
    logging.info("Начинаем задачу, потребляющую память")
    
    # Создаем большой список для потребления памяти
    big_list = []
    for i in range(1000000):
        big_list.append(f"item_{i}_{'x' * 100}")
    
    # Держим данные в памяти 20 секунд
    time.sleep(20)
    
    # Получаем метрики
    memory_info = psutil.virtual_memory()
    cpu_percent = psutil.cpu_percent(interval=1)
    
    logging.info(f"Память использована: {memory_info.percent}%")
    logging.info(f"CPU использование: {cpu_percent}%")
    logging.info(f"Размер списка: {len(big_list)} элементов")
    
    # Освобождаем память
    del big_list
    
    logging.info("Задача, потребляющая память, завершена")
    
    return {
        'memory_percent': memory_info.percent,
        'cpu_percent': cpu_percent,
        'list_size': 1000000
    }

def mixed_workload_task():
    """Задача, комбинирующая нагрузку на CPU и память"""
    logging.info("Начинаем смешанную нагрузку")
    
    # Создаем данные в памяти
    data = {}
    for i in range(100000):
        data[f"key_{i}"] = [j * j for j in range(100)]
    
    # CPU-интенсивные вычисления
    start_time = time.time()
    result = 0
    while time.time() - start_time < 25:
        for key in list(data.keys())[:1000]:  # Обрабатываем часть данных
            result += sum(data[key])
    
    # Получаем финальные метрики
    memory_info = psutil.virtual_memory()
    cpu_percent = psutil.cpu_percent(interval=1)
    
    logging.info(f"Финальные метрики:")
    logging.info(f"CPU: {cpu_percent}%, Память: {memory_info.percent}%")
    logging.info(f"Результат вычислений: {result}")
    
    return {
        'final_cpu': cpu_percent,
        'final_memory': memory_info.percent,
        'calculation_result': result,
        'data_size': len(data)
    }

def system_info_task():
    """Задача для получения информации о системе"""
    logging.info("Получаем информацию о системе")
    
    # Системная информация
    cpu_count = psutil.cpu_count()
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    logging.info(f"CPU ядер: {cpu_count}")
    logging.info(f"Общая память: {memory.total / (1024**3):.2f} GB")
    logging.info(f"Доступная память: {memory.available / (1024**3):.2f} GB")
    logging.info(f"Общее место на диске: {disk.total / (1024**3):.2f} GB")
    logging.info(f"Свободное место на диске: {disk.free / (1024**3):.2f} GB")
    
    return {
        'cpu_count': cpu_count,
        'total_memory_gb': memory.total / (1024**3),
        'available_memory_gb': memory.available / (1024**3),
        'total_disk_gb': disk.total / (1024**3),
        'free_disk_gb': disk.free / (1024**3)
    }

# Определяем задачи
cpu_task = PythonOperator(
    task_id='cpu_intensive_task',
    python_callable=cpu_intensive_task,
    dag=dag,
)

memory_task = PythonOperator(
    task_id='memory_intensive_task',  
    python_callable=memory_intensive_task,
    dag=dag,
)

mixed_task = PythonOperator(
    task_id='mixed_workload_task',
    python_callable=mixed_workload_task,
    dag=dag,
)

info_task = PythonOperator(
    task_id='system_info_task',
    python_callable=system_info_task,
    dag=dag,
)

# Определяем зависимости
info_task >> [cpu_task, memory_task] >> mixed_task
