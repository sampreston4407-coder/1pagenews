import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["ADMIN_TOKEN"] = "test-token"

from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402


def client() -> TestClient:
    main._store = None
    return TestClient(main.app)


def test_today_returns_seven_general_stories():
    with client() as c:
        r = c.get("/v1/edition/today")
        assert r.status_code == 200, r.text
        body = r.json()
        assert len(body["stories"]) == 7
        assert body["topic_stories"] == {}


def test_topics_add_without_subtracting():
    with client() as c:
        r = c.get("/v1/edition/today?topics=ai,finance")
        body = r.json()
        assert len(body["stories"]) == 7
        assert set(body["topic_stories"]) == {"ai", "finance"}


def test_unknown_topic_is_400():
    with client() as c:
        assert c.get("/v1/edition/today?topics=crypto").status_code == 400


def test_methodology_and_sources():
    with client() as c:
        assert c.get("/v1/methodology").json()["sections"]
        assert len(c.get("/v1/sources").json()) >= 3


def test_admin_requires_token():
    with client() as c:
        assert c.get("/v1/admin/lint-failures").status_code == 401
        assert c.get("/v1/admin/lint-failures", headers={"x-admin-token": "test-token"}).status_code == 200


def test_corrections_round_trip():
    with client() as c:
        payload = {
            "story_id": "2026-09-03-budget", "edition_date": "2026-09-03",
            "corrected_at": "2026-09-04T10:00:00Z",
            "what_we_said": "The gap was $40 billion.", "what_was_true": "The gap was $38 billion.",
            "how_we_found_out": "A reader sent the committee's own summary.",
        }
        assert c.post("/v1/admin/corrections", json=payload, headers={"x-admin-token": "test-token"}).status_code == 200
        assert c.get("/v1/corrections").json()[0]["what_was_true"] == "The gap was $38 billion."
