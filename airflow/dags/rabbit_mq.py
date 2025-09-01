from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
import time
default_args = {
    'owner': 'test',
    'start_date': days_ago(1),
}

def sleep_task():
    time.sleep(10)
    print("Task completed after sleep")
with DAG(
    'rabbitmq_timeout_test',
    default_args=default_args,
    schedule_interval='*/2 * * * *',  # Каждую минуту
    catchup=False,
) as dag:

    for i in range(2):  # создаём 2 задачи с задержкой 10 сек
        PythonOperator(
            task_id=f'python_sleep_{i}',
            python_callable=sleep_task,
        )