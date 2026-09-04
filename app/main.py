"""
API REST mínima para o Projeto 1 do portfólio DevOps.

Endpoints:
  GET  /health          -> health check para o CloudWatch / load balancer
  GET  /tasks           -> lista tarefas
  POST /tasks           -> cria tarefa
  GET  /tasks/{id}      -> busca uma tarefa
  DELETE /tasks/{id}    -> remove uma tarefa
"""
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="devops-01-ec2-cicd", version="1.0.0")

# Armazenamento em memória (propositalmente simples: o objetivo é a infra)
tasks_db: dict[str, dict] = {}


class TaskIn(BaseModel):
    title: str
    done: bool = False


class Task(TaskIn):
    id: str
    created_at: str


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.get("/tasks", response_model=list[Task])
def list_tasks() -> list[dict]:
    return list(tasks_db.values())


@app.post("/tasks", response_model=Task, status_code=201)
def create_task(task: TaskIn) -> dict:
    task_id = str(uuid4())
    record = {
        "id": task_id,
        "title": task.title,
        "done": task.done,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    tasks_db[task_id] = record
    return record


@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: str) -> dict:
    record = tasks_db.get(task_id)
    if record is None:
        raise HTTPException(status_code=404, detail="task not found")
    return record


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: str) -> None:
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="task not found")
    del tasks_db[task_id]