def sse_event(data: str, event: str = None) -> bytes:
    lines = []
    if event:
        lines.append(f"event: {event}")
    lines.append(f"data: {data}")
    return ("\n".join(lines) + "\n\n").encode("utf-8")

