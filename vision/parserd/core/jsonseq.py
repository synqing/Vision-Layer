import json


RS = b"\x1e"


def encode_record(obj: dict) -> bytes:
    return RS + json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8") + b"\n"

