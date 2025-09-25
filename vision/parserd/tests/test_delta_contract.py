import jsonpatch
from datetime import datetime


def make_brief(ts, pane, old_facts, new_facts, confidence=0.99):
    patch = jsonpatch.make_patch(old_facts, new_facts)
    return {
        "ts": ts,
        "pane": pane,
        "delta": patch.patch,   # RFC 6902 ops
        "confidence": confidence,
    }


def test_ci_flip_to_green_patch():
    old = {"ci": {"status": "failing", "checks_failed": 2, "checks_total": 7, "names": ["lint", "unit"]}}
    new = {"ci": {"status": "passing", "checks_total": 7}}
    brief = make_brief(datetime.utcnow().isoformat() + "Z", "CI_SUMMARY", old, new)

    # Expect: replace status->passing, remove checks_failed, remove names
    ops = brief["delta"]
    assert {"op": "replace", "path": "/ci/status", "value": "passing"} in ops
    assert any(op["op"] == "remove" and op["path"] == "/ci/checks_failed" for op in ops)
    assert any(op["op"] == "remove" and op["path"] == "/ci/names" for op in ops)


def test_pr_blocked_requires_reviews():
    old = {"pr": {"mergeable": "clean"}}
    new = {"pr": {"mergeable": "blocked", "required_reviews": 1}}
    ops = jsonpatch.make_patch(old, new).patch
    assert {"op": "replace", "path": "/pr/mergeable", "value": "blocked"} in ops
    assert {"op": "add", "path": "/pr/required_reviews", "value": 1} in ops

