import asyncio
import json
import logging
import re
import time

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from config import settings
from services.session_manager import session_manager

router = APIRouter()
logger = logging.getLogger("sentio.websocket")

WAIT_POLL_INTERVAL  = 0.02
ACTIVE_POLL_INTERVAL = 0.01
HEARTBEAT_INTERVAL  = 5.0   # seconds between keepalive pings when no EEG data


def _is_allowed_origin(origin: str | None) -> bool:
    if origin is None:
        return True

    if origin in settings.cors_allowed_origins:
        return True

    return re.fullmatch(settings.cors_allowed_origin_regex, origin) is not None


def _get_client_identity(websocket: WebSocket) -> tuple[str, int | str]:
    client_host = websocket.client.host if websocket.client else "unknown"
    client_port = websocket.client.port if websocket.client else "unknown"
    return client_host, client_port


def _log_connection_requested(client_host: str, client_port: int | str, origin: str | None):
    logger.info(
        "WebSocket connection requested for %s from %s:%s origin=%s",
        settings.ws_endpoint,
        client_host,
        client_port,
        origin,
    )


def _log_connection_accepted(client_host: str, client_port: int | str):
    logger.info(
        "WebSocket accepted for %s from %s:%s active=%s streaming=%s",
        settings.ws_endpoint,
        client_host,
        client_port,
        session_manager.is_active(),
        session_manager.is_streaming(),
    )


def _log_waiting_for_data(client_host: str, client_port: int | str, last_wait_log: float) -> float:
    now = time.monotonic()
    if now - last_wait_log >= 5.0:
        logger.info(
            "WebSocket waiting for EEG data for %s:%s active=%s streaming=%s",
            client_host,
            client_port,
            session_manager.is_active(),
            session_manager.is_streaming(),
        )
        return now

    return last_wait_log


async def _send_new_message(
    websocket: WebSocket,
    message: dict,
    last_timestamp,
    messages_sent: int,
    client_host: str,
    client_port: int | str,
) -> tuple[object, int]:
    timestamp = message.get("timestamp")
    if timestamp == last_timestamp:
        return last_timestamp, messages_sent

    await websocket.send_json(message)
    messages_sent += 1

    if messages_sent == 1 or messages_sent % 25 == 0:
        logger.info(
            "Sent EEG frame %s to %s:%s timestamp=%s emotion=%s",
            messages_sent,
            client_host,
            client_port,
            timestamp,
            message.get("emotion"),
        )

    return timestamp, messages_sent


async def _wait_for_next_frame(last_timestamp: object | None) -> dict | None:
    message = session_manager.get_latest_stream_message()
    if message is None:
        return None

    if message.get("timestamp") == last_timestamp:
        return None

    return message


# =============================================================================
#  SEND LOOP — pushes EEG frames + heartbeat keepalives to the client
# =============================================================================

async def _run_send_loop(
    websocket: WebSocket,
    client_host: str,
    client_port: int | str,
) -> None:
    last_timestamp = None
    messages_sent  = 0
    last_wait_log  = 0.0
    last_heartbeat = time.monotonic()

    while True:
        message = await _wait_for_next_frame(last_timestamp)

        if message is None:
            last_wait_log = _log_waiting_for_data(client_host, client_port, last_wait_log)
            now = time.monotonic()
            if now - last_heartbeat >= HEARTBEAT_INTERVAL:
                await websocket.send_json({"type": "heartbeat", "status": "waiting"})
                last_heartbeat = now
            await asyncio.sleep(
                WAIT_POLL_INTERVAL
                if session_manager.get_latest_stream_message() is None
                else ACTIVE_POLL_INTERVAL
            )
            continue

        last_timestamp, messages_sent = await _send_new_message(
            websocket, message, last_timestamp, messages_sent,
            client_host, client_port,
        )
        last_heartbeat = time.monotonic()
        await asyncio.sleep(ACTIVE_POLL_INTERVAL)


# =============================================================================
#  RECEIVE LOOP — handles status messages sent BY the Arduino (bidirectional)
# =============================================================================

async def _run_receive_loop(
    websocket: WebSocket,
    client_host: str,
    client_port: int | str,
) -> None:
    """
    Listens for JSON frames sent by the Arduino (or any connected client).

    Arduino status frame format:
      {
        "type":     "arduino_status",
        "emotion":  "calm",
        "pattern":  "fluid",
        "ai_active": true,
        "ts":       12345
      }

    The latest status is stored in session_manager so the REST API and
    frontend can query what the Arduino is currently rendering.
    """
    while True:
        try:
            raw = await websocket.receive_text()
        except WebSocketDisconnect:
            raise
        except Exception as exc:
            logger.warning(
                "WebSocket receive error from %s:%s — %s", client_host, client_port, exc
            )
            raise

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            logger.debug(
                "WebSocket non-JSON from %s:%s — ignored", client_host, client_port
            )
            continue

        msg_type = data.get("type", "")

        if msg_type == "arduino_status":
            session_manager.set_arduino_status(data)
            logger.debug(
                "Arduino status from %s:%s — emotion=%s pattern=%s ai_active=%s",
                client_host,
                client_port,
                data.get("emotion"),
                data.get("pattern"),
                data.get("ai_active"),
            )
        else:
            logger.debug(
                "WebSocket unknown type=%r from %s:%s — ignored",
                msg_type, client_host, client_port,
            )


# =============================================================================
#  WEBSOCKET ENDPOINT
# =============================================================================

@router.websocket(settings.ws_endpoint)
async def brain_stream(websocket: WebSocket):
    """
    Bidirectional WebSocket stream.

    Backend → Client (Arduino / Frontend):
        EEG frames with emotion, pattern, ai_pattern, colours, etc.
        Heartbeat keepalives while waiting for EEG data.

    Client (Arduino) → Backend:
        arduino_status frames: current emotion + pattern the Arduino is rendering.
    """
    origin      = websocket.headers.get("origin")
    client_host, client_port = _get_client_identity(websocket)
    _log_connection_requested(client_host, client_port, origin)

    if not _is_allowed_origin(origin):
        logger.warning("Rejected websocket connection from origin %s", origin)
        await websocket.close(code=1008)
        return

    await websocket.accept()
    _log_connection_accepted(client_host, client_port)

    send_task    = asyncio.create_task(_run_send_loop(websocket, client_host, client_port))
    receive_task = asyncio.create_task(_run_receive_loop(websocket, client_host, client_port))

    done, pending = await asyncio.wait(
        {send_task, receive_task},
        return_when=asyncio.FIRST_COMPLETED,
    )

    for task in pending:
        task.cancel()
        try:
            await task
        except (asyncio.CancelledError, WebSocketDisconnect):
            pass

    for task in done:
        try:
            task.result()
        except (WebSocketDisconnect, asyncio.CancelledError):
            logger.info(
                "WebSocket disconnected for %s:%s",
                client_host,
                client_port,
            )
        except Exception:
            logger.exception(
                "WebSocket error for %s:%s",
                client_host,
                client_port,
            )
