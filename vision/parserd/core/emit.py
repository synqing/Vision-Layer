import asyncio
import aiohttp
from aiohttp import web
import logging
from .jsonseq import encode_record


async def emit_webhook(url: str, brief: dict):
    async with aiohttp.ClientSession() as session:
        async with session.post(url, json=brief) as resp:
            if resp.status >= 300:
                logging.warning("webhook failed: %s", resp.status)


async def stream_sse(request, queue):
    response = web.StreamResponse(status=200, reason='OK', headers={
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
    })
    await response.prepare(request)
    try:
        while True:
            item = await queue.get()
            line = f"data: {item}\n\n".encode("utf-8")
            await response.write(line)
            await response.drain()
    except asyncio.CancelledError:
        pass
    finally:
        await response.write_eof()
    return response


async def stream_jsonseq(request, queue):
    response = web.StreamResponse(status=200, reason='OK', headers={
        'Content-Type': 'application/json-seq',
    })
    await response.prepare(request)
    try:
        while True:
            item = await queue.get()
            await response.write(encode_record(item))
            await response.drain()
    except asyncio.CancelledError:
        pass
    finally:
        await response.write_eof()
    return response
