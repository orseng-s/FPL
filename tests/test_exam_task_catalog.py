import json
from pathlib import Path

CATALOG_PATH = Path(__file__).resolve().parents[1] / "web" / "data" / "tasks.json"
REQUIRED_FIELDS = {
    "id",
    "year",
    "season",
    "course",
    "part",
    "theme",
    "subthemes",
    "difficulty",
    "points",
    "durationMinutes",
    "sourcePdf",
    "pageRange",
    "taskNumber",
    "title",
    "summary",
    "status",
}


def load_catalog():
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def test_exam_task_catalog_has_unique_ids_and_required_metadata():
    tasks = load_catalog()
    ids = [task["id"] for task in tasks]

    assert tasks
    assert len(ids) == len(set(ids))
    for task in tasks:
        assert REQUIRED_FIELDS.issubset(task)
        assert task["subthemes"]
        assert task["points"] > 0
        assert task["durationMinutes"] > 0


def test_exam_task_catalog_supports_geometry_filtering_across_courses():
    tasks = load_catalog()
    geometry_tasks = [task for task in tasks if task["theme"] == "Geometry"]
    courses = {task["course"] for task in geometry_tasks}

    assert len(geometry_tasks) >= 2
    assert len(courses) >= 2
