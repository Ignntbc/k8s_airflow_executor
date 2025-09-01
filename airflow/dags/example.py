from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'Man',
    'start_date': days_ago(0),
    'depends_on_past': False,
}

with DAG(
    'mydag',
    default_args=default_args,
    schedule_interval='@once',
    catchup=False
) as dag:

    t1 = BashOperator(
        task_id='echo_hi',
        bash_command='echo "Hello"',
        executor_config={
            "KubernetesExecutor": {
                "image": "igntbc/airflow-custom:2.10.2"
            }
        }
    )
    t2 = BashOperator(
        task_id='print_date',
        bash_command='date',
        executor_config={
            "KubernetesExecutor": {
                "image": "igntbc/airflow-custom:2.10.2"
            }
        }
    )

    t1 >> t2