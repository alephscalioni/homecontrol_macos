"""Local-only Home Assistant protocol fixture; no real devices or external dependencies."""
import asyncio
import base64
import hashlib
import json
import struct
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18765


async def send(writer, value):
    payload = json.dumps(value, ensure_ascii=False).encode()
    size = len(payload)
    header = bytes([0x81, size]) if size < 126 else bytes([0x81, 126]) + struct.pack("!H", size)
    writer.write(header + payload)
    await writer.drain()


async def frame(reader, writer):
    first, second = await reader.readexactly(2)
    length = second & 127
    if length == 126:
        length = struct.unpack("!H", await reader.readexactly(2))[0]
    elif length == 127:
        length = struct.unpack("!Q", await reader.readexactly(8))[0]
    if length > 1024 * 1024:
        raise ValueError("Frame too large")
    mask = await reader.readexactly(4) if second & 128 else b""
    payload = await reader.readexactly(length)
    if mask:
        payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    opcode = first & 15
    if opcode == 8:
        return None
    if opcode == 9:
        writer.write(bytes([0x8A, len(payload)]) + payload)
        await writer.drain()
        return {}
    return json.loads(payload)


def entity(temperature=21, second=20):
    return {"entity_id": "climate.test", "state": "cool", "last_updated": f"2026-10-15T12:00:{second:02}.000000Z",
            "attributes": {"friendly_name": "Ar de teste", "temperature": temperature, "current_temperature": 23,
                           "min_temp": 16, "max_temp": 32, "temperature_unit": "°C", "target_temp_step": 1,
                           "supported_features": 385, "hvac_modes": ["off", "cool", "heat"]}}


async def event(writer, subscription, state, second):
    await send(writer, {"id": subscription, "type": "event", "event": {"event_type": "state_changed",
               "time_fired": f"2026-10-15T12:00:{second:02}.000000Z",
               "data": {"entity_id": "climate.test", "new_state": state}}})


async def handle(reader, writer):
    try:
        request = (await reader.readuntil(b"\r\n\r\n")).decode()
        headers = {line.split(":", 1)[0].lower(): line.split(":", 1)[1].strip()
                   for line in request.split("\r\n")[1:] if ":" in line}
        if "sec-websocket-key" not in headers:
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK")
            await writer.drain()
            return
        accept = base64.b64encode(hashlib.sha1((headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        writer.write(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
        await writer.drain()
        await send(writer, {"type": "auth_required", "ha_version": "2026.10.0"})
        token, subscribed, subscription = "", False, 0
        subscriptions = {}
        last_command_id = 0
        while True:
            message = await frame(reader, writer)
            if message is None:
                break
            kind, command_id = message.get("type"), message.get("id")
            if command_id is not None:
                if command_id <= last_command_id:
                    await send(writer, {"id": command_id, "type": "result", "success": False, "error": {"message": "Message ID must increase"}})
                    continue
                last_command_id = command_id
            if kind == "auth":
                token = message.get("access_token")
                if token == "test-invalid":
                    await send(writer, {"type": "auth_invalid", "message": "Invalid access token"})
                    return
                await send(writer, {"type": "auth_ok", "ha_version": "2026.10.0"})
            elif kind == "subscribe_events":
                if token == "test-subscribe-error":
                    await send(writer, {"id": command_id, "type": "result", "success": False, "error": {"message": "Subscription denied"}})
                    continue
                subscriptions[message.get("event_type")] = command_id
                if message.get("event_type") == "state_changed":
                    subscribed, subscription = True, command_id
                await send(writer, {"id": command_id, "type": "result", "success": True, "result": None})
                if token == "test-stale" and message.get("event_type") == "state_changed":
                    await event(writer, subscription, entity(18, 10), 10)
                if token == "test-registry" and message.get("event_type") == "entity_registry_updated":
                    for event_type in ["area_registry_updated", "device_registry_updated", "entity_registry_updated"]:
                        await send(writer, {"id": subscriptions[event_type], "type": "event", "event": {"event_type": event_type, "data": {"action": "update"}}})
            elif kind == "get_states":
                await send(writer, {"id": command_id, "type": "result", "success": subscribed, "result": [entity()]})
                if token == "test-stale":
                    await asyncio.sleep(0.03)
                    await event(writer, subscription, entity(23, 30), 30)
                    await event(writer, subscription, None, 40)
                    await event(writer, subscription, entity(22, 35), 35)
            elif kind == "call_service":
                if token == "test-timeout":
                    continue
                if token == "test-disconnect":
                    return
                if token == "test-service-error":
                    await send(writer, {"id": command_id, "type": "result", "success": False, "error": {"message": "Ação não permitida"}})
                    continue
                target = message.get("target", {}).get("entity_id")
                valid = target == "climate.test" and message.get("domain") == "climate"
                await send(writer, {"id": command_id, "type": "result", "success": valid, "result": {"context": {"id": "test"}}, "error": {"message": "Incorrect service target"}})
            elif kind == "ping":
                await send(writer, {"id": command_id, "type": "pong"})
            elif kind and kind.startswith("config/"):
                result = []
                if token == "test-registry":
                    result = {
                        "config/area_registry/list": [{"area_id": "office", "name": "Escritório"}],
                        "config/device_registry/list": [{"id": "test_device", "name": "Ar", "area_id": "office"}],
                        "config/entity_registry/list": [{"entity_id": "climate.test", "device_id": "test_device", "area_id": None}]
                    }.get(kind, [])
                await send(writer, {"id": command_id, "type": "result", "success": True, "result": result})
    except (asyncio.IncompleteReadError, ConnectionError, ValueError):
        pass
    finally:
        writer.close()
        await writer.wait_closed()


async def main():
    server = await asyncio.start_server(handle, "127.0.0.1", PORT)
    print(f"Local fixture ready on 127.0.0.1:{PORT}", flush=True)
    async with server:
        await server.serve_forever()


asyncio.run(main())
