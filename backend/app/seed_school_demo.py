from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict


BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data"
DB_FILE = DATA_DIR / "store.json"


def _timestamp(value: str) -> Dict[str, str]:
    return {"__timestamp__": value}


def _load_db() -> Dict[str, Any]:
    if not DB_FILE.exists():
        return {"collections": {}, "auth": {"users": {}, "email_index": {}}}
    with DB_FILE.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _save_db(db: Dict[str, Any]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with DB_FILE.open("w", encoding="utf-8") as fh:
        json.dump(db, fh, ensure_ascii=True, indent=2)


def _upsert_collection(db: Dict[str, Any], name: str, docs: Dict[str, Dict[str, Any]]) -> None:
    db.setdefault("collections", {}).setdefault(name, {}).update(docs)


def _upsert_auth(db: Dict[str, Any], uid: str, email: str, password: str) -> None:
    auth = db.setdefault("auth", {})
    users = auth.setdefault("users", {})
    email_index = auth.setdefault("email_index", {})
    users[uid] = {
        "uid": uid,
        "email": email,
        "password": password,
        "created_at": "2026-03-13T00:00:00+00:00",
    }
    email_index[email] = uid


def seed_demo_school() -> None:
    db = _load_db()

    admin_uid = "demo_admin_uid"
    teacher_uid = "demo_teacher_uid"
    parent_uid = "demo_parent_uid"
    student_uid = "demo_student_uid"

    class_room_id = "class_room_10_a"
    math_subject_id = "subject_math_10"
    science_subject_id = "subject_science_10"
    task_id = "task_math_week1"

    _upsert_auth(db, admin_uid, "admin@schoolmate.test", "Demo@123")
    _upsert_auth(db, teacher_uid, "teacher@schoolmate.test", "Demo@123")
    _upsert_auth(db, parent_uid, "parent@schoolmate.test", "Demo@123")
    _upsert_auth(db, student_uid, "student@schoolmate.test", "Demo@123")

    _upsert_collection(
        db,
        "admins",
        {
            admin_uid: {
                "uid": admin_uid,
                "email": "admin@schoolmate.test",
                "first_name": "Ava",
                "last_name": "Admin",
                "urlAvatar": "",
            }
        },
    )
    _upsert_collection(
        db,
        "teacher",
        {
            teacher_uid: {
                "uid": teacher_uid,
                "email": "teacher@schoolmate.test",
                "first_name": "Tariq",
                "last_name": "Teacher",
                "phone": "9999999993",
                "subjects": [math_subject_id, science_subject_id],
                "urlAvatar": "",
                "token": "demo-teacher-token",
            }
        },
    )
    _upsert_collection(
        db,
        "parents",
        {
            parent_uid: {
                "uid": parent_uid,
                "email": "parent@schoolmate.test",
                "first_name": "Pia",
                "last_name": "Parent",
                "urlAvatar": "",
            }
        },
    )
    _upsert_collection(
        db,
        "students",
        {
            student_uid: {
                "uid": student_uid,
                "email": "student@schoolmate.test",
                "first_name": "Sam",
                "last_name": "Student",
                "fees": "1250",
                "class_id": class_room_id,
                "phone": "9999999991",
                "parent_phone": "9999999992",
                "parent_email": "parent@schoolmate.test",
                "class_name": "10-A",
                "urlAvatar": "",
                "grade_average": 88,
                "grade": "10",
                "lastMessageTime": _timestamp("2026-03-13T07:03:49.209915Z"),
            }
        },
    )

    _upsert_collection(
        db,
        "class-room",
        {
            class_room_id: {
                "uid": class_room_id,
                "acadimic_year": "10",
                "section": "A",
                "number_of_students": 1,
            }
        },
    )
    _upsert_collection(
        db,
        "acadimic_year",
        {
            "10": {
                "id": "10",
                "grade": 10,
                "subject": [math_subject_id, science_subject_id],
            }
        },
    )
    _upsert_collection(
        db,
        "subject",
        {
            math_subject_id: {
                "id": math_subject_id,
                "name": "Mathematics",
                "subject_grade": "10",
            },
            science_subject_id: {
                "id": science_subject_id,
                "name": "Science",
                "subject_grade": "10",
            },
        },
    )
    _upsert_collection(
        db,
        "relation",
        {
            "relation_math_10a": {
                "uid": "relation_math_10a",
                "teacher": teacher_uid,
                "teacher_name": "Tariq Teacher",
                "grade": "10",
                "subject": math_subject_id,
                "subject_name": "Mathematics",
                "classrooms": [class_room_id],
            },
            "relation_science_10a": {
                "uid": "relation_science_10a",
                "teacher": teacher_uid,
                "teacher_name": "Tariq Teacher",
                "grade": "10",
                "subject": science_subject_id,
                "subject_name": "Science",
                "classrooms": [class_room_id],
            },
        },
    )

    _upsert_collection(
        db,
        "classProgram",
        {
            "program_class_assembly": {
                "id": "program_class_assembly",
                "type": "Assembly",
                "url": "https://schoolmate.local/programs/class-assembly",
                "date": _timestamp("2026-03-20T08:00:00Z"),
                "class-room": class_room_id,
            },
            "program_class_lab": {
                "id": "program_class_lab",
                "type": "Science Lab",
                "url": "https://schoolmate.local/programs/science-lab",
                "date": _timestamp("2026-03-22T10:30:00Z"),
                "class-room": class_room_id,
            },
        },
    )
    _upsert_collection(
        db,
        "teacherProgram",
        {
            "program_teacher_meeting": {
                "id": "program_teacher_meeting",
                "type": "Staff Meeting",
                "url": "https://schoolmate.local/programs/staff-meeting",
                "date": _timestamp("2026-03-18T13:00:00Z"),
                "teacher": teacher_uid,
            }
        },
    )

    _upsert_collection(
        db,
        "announcement",
        {
            "ann_student_exam": {
                "id": "ann_student_exam",
                "title": "Midterm Schedule",
                "content": "Mathematics midterm starts next Monday at 9:00 AM.",
                "date": _timestamp("2026-03-13T09:00:00Z"),
                "class-room": class_room_id,
                "type": "Students",
            },
            "ann_teacher_meeting": {
                "id": "ann_teacher_meeting",
                "title": "Teacher Briefing",
                "content": "All teachers should submit week plans before Friday noon.",
                "date": _timestamp("2026-03-13T11:00:00Z"),
                "type": "Teachers",
            },
            "ann_all_holiday": {
                "id": "ann_all_holiday",
                "title": "School Holiday",
                "content": "School will be closed on March 25 for maintenance.",
                "date": _timestamp("2026-03-13T12:00:00Z"),
                "type": "All",
            },
        },
    )

    _upsert_collection(
        db,
        "reference",
        {
            "ref_math_book": {
                "id": "ref_math_book",
                "uid": "ref_math_book",
                "grade": 10,
                "name": "Algebra Revision Sheet",
                "subject_id": math_subject_id,
                "subjectName": "Mathematics",
                "type": "book",
                "url": "https://schoolmate.local/reference/algebra-sheet.pdf",
            },
            "ref_science_video": {
                "id": "ref_science_video",
                "uid": "ref_science_video",
                "grade": 10,
                "name": "Cells Introduction",
                "subject_id": science_subject_id,
                "subjectName": "Science",
                "type": "video",
                "url": "https://schoolmate.local/reference/cells-video",
                "teacher_id": teacher_uid,
                "teacher_name": "Tariq Teacher",
            },
        },
    )

    _upsert_collection(
        db,
        "lessons",
        {
            "lesson_math_linear": {
                "id": "lesson_math_linear",
                "subject": math_subject_id,
                "name": "Linear Equations",
            },
            "lesson_math_geometry": {
                "id": "lesson_math_geometry",
                "subject": math_subject_id,
                "name": "Geometry Basics",
            },
            "lesson_science_cells": {
                "id": "lesson_science_cells",
                "subject": science_subject_id,
                "name": "Cells and Tissues",
            },
        },
    )

    _upsert_collection(
        db,
        "Task",
        {
            task_id: {
                "id": task_id,
                "name": "Algebra Worksheet 1",
                "classroom": class_room_id,
                "deadline": _timestamp("2026-03-21T14:00:00Z"),
                "subjectName": "Mathematics",
                "subject_id": math_subject_id,
                "teacher_id": teacher_uid,
                "uploadDate": _timestamp("2026-03-13T08:00:00Z"),
                "url": "https://schoolmate.local/tasks/algebra-worksheet-1.pdf",
            }
        },
    )
    _upsert_collection(
        db,
        "Task-result",
        {
            "task_result_math_1": {
                "checked": True,
                "classroom_id": class_room_id,
                "class_id": class_room_id,
                "mark": 17,
                "student_id": student_uid,
                "task_id": task_id,
                "task_result_id": "task_result_math_1",
                "uploadDate": _timestamp("2026-03-13T12:30:00Z"),
                "url": "https://schoolmate.local/submissions/algebra-worksheet-1.pdf",
            }
        },
    )

    _upsert_collection(
        db,
        "tests",
        {
            "test_math_1": {
                "id": "test_math_1",
                "subject_id": math_subject_id,
                "grade": "10",
                "student_id": student_uid,
                "result": 85,
                "taskid": task_id,
                "StudenUploadDate": "2026/03/13",
            }
        },
    )
    _upsert_collection(
        db,
        "homeworks",
        {
            "homework_math_1": {
                "id": "homework_math_1",
                "subject_id": math_subject_id,
                "grade": "10",
                "student_id": student_uid,
                "result": 90,
            }
        },
    )
    _upsert_collection(
        db,
        "exam1",
        {
            "exam1_math_1": {
                "id": "exam1_math_1",
                "subject_id": math_subject_id,
                "grade": "10",
                "student_id": student_uid,
                "result": 87,
            }
        },
    )
    _upsert_collection(
        db,
        "exam2",
        {
            "exam2_math_1": {
                "id": "exam2_math_1",
                "subject_id": math_subject_id,
                "grade": "10",
                "student_id": student_uid,
                "result": 89,
            }
        },
    )

    _upsert_collection(
        db,
        "quiz",
        {
            "quiz_math_intro": {
                "uid": "quiz_math_intro",
                "name": "Algebra Quick Quiz",
                "subject_name": "Mathematics",
                "diffculty": "Easy",
                "question": "Solve 2x + 4 = 10",
            }
        },
    )

    _upsert_collection(
        db,
        f"chats/{student_uid}/messages",
        {
            "chat_msg_1": {
                "idUser": teacher_uid,
                "urlAvatar": "",
                "username": "Tariq",
                "message": "Please complete the algebra worksheet before Saturday.",
                "createdAt": _timestamp("2026-03-13T07:03:42.820049Z"),
                "uid": student_uid,
            },
            "chat_msg_2": {
                "idUser": teacher_uid,
                "urlAvatar": "",
                "username": "Tariq",
                "message": "I uploaded a new science reference video for your class.",
                "createdAt": _timestamp("2026-03-13T07:03:49.203011Z"),
                "uid": student_uid,
            },
        },
    )

    _save_db(db)


if __name__ == "__main__":
    seed_demo_school()
    print(f"Seeded demo school data into {DB_FILE}")