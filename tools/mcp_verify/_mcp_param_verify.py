#!/usr/bin/env python3
"""Verify param bar + material UX via Godot AI MCP at http://127.0.0.1:8000/mcp"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "http://127.0.0.1:8000/mcp"
SESSION = None
OUT = Path(r"C:\Users\PA602\Code\synie-planner\_mcp_param_verify.json")


def log(msg: str):
    sys.stdout.buffer.write((msg + "\n").encode("utf-8", errors="replace"))
    sys.stdout.buffer.flush()


def post(payload: dict):
    global SESSION
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if SESSION:
        headers["Mcp-Session-Id"] = SESSION
    req = urllib.request.Request(BASE, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            sid = resp.headers.get("Mcp-Session-Id")
            if sid:
                SESSION = sid
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return e.code, body


def parse_sse_or_json(body: str):
    if body.lstrip().startswith("{"):
        return json.loads(body)
    result = None
    for line in body.splitlines():
        if line.startswith("data:"):
            chunk = line[5:].strip()
            if not chunk or chunk == "[DONE]":
                continue
            try:
                result = json.loads(chunk)
            except json.JSONDecodeError:
                pass
    return result


def rpc(method: str, params=None, id_=1):
    payload = {"jsonrpc": "2.0", "id": id_, "method": method}
    if params is not None:
        payload["params"] = params
    status, body = post(payload)
    parsed = parse_sse_or_json(body)
    log(f"=== {method} status={status} session={SESSION}")
    return status, parsed


def tool_call(name: str, arguments: dict, id_: int):
    return rpc("tools/call", {"name": name, "arguments": arguments}, id_=id_)


def dig(obj):
    if obj is None:
        return None
    if isinstance(obj, dict):
        if "result" in obj:
            res = obj["result"]
            if isinstance(res, dict) and "content" in res:
                texts = []
                for c in res.get("content", []):
                    if isinstance(c, dict) and c.get("type") == "text":
                        texts.append(c.get("text", ""))
                if texts:
                    try:
                        return json.loads(texts[0])
                    except Exception:
                        return {"_text": texts[0][:4000]}
            return res
        if "error" in obj:
            return obj
    return obj


def main():
    results = {}
    _, init = rpc(
        "initialize",
        {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "param-verify", "version": "1.0"},
        },
        id_=1,
    )
    results["initialize"] = dig(init)
    post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    # stop any running game first
    for args in (
        {"op": "stop", "params": {}},
        {"action": "stop"},
    ):
        try:
            _, stop0 = tool_call("project_manage", args, 2)
            results["stop_before"] = dig(stop0)
            log(f"stop_before tried {args}")
            break
        except Exception as e:
            log(f"stop_before fail {args}: {e}")

    time.sleep(0.5)

    # filesystem scan — try both param shapes
    scan = None
    for args in (
        {"op": "scan", "params": {}},
        {"action": "scan"},
    ):
        _, scan = tool_call("filesystem_manage", args, 3)
        d = dig(scan)
        results["scan"] = d
        log(f"scan tried {args} -> keys {list(d.keys()) if isinstance(d, dict) else type(d)}")
        if isinstance(d, dict) and ("error" not in d or "ok" in d or "success" in d):
            # accept first non-fatal
            break

    time.sleep(1.0)

    # logs_clear
    for args in (
        {"action": "logs_clear"},
        {"op": "logs_clear", "params": {}},
    ):
        _, lc = tool_call("editor_manage", args, 4)
        results["logs_clear"] = dig(lc)
        log(f"logs_clear tried {args}")
        break

    # project_run main
    run = None
    for args in (
        {"mode": "main"},
        {"action": "run", "mode": "main"},
        {"op": "run", "params": {"mode": "main"}},
    ):
        _, run = tool_call("project_run", args, 5)
        d = dig(run)
        results["project_run"] = d
        log(f"project_run tried {args}")
        if isinstance(d, dict):
            log("project_run keys: " + str(list(d.keys())))
            for k in ["helper_live", "current_run_errors", "recent_errors", "ok", "success", "error", "message", "game_status"]:
                if k in d:
                    log(f"  {k}={d[k]!r}"[:800])
        # if looks like wrong schema, try next
        text = json.dumps(d, ensure_ascii=False) if d is not None else ""
        if "Unknown tool" in text or ("required" in text.lower() and "error" in text.lower()):
            continue
        break

    time.sleep(2.5)

    # read logs / editor state
    for name, args in (
        ("logs_read_editor", {"source": "editor", "include_details": True}),
        ("logs_read_game", {"source": "game", "include_details": True}),
    ):
        try:
            _, lg = tool_call("logs_read", args, 6 if "editor" in name else 7)
            results[name] = dig(lg)
        except Exception as e:
            results[name] = {"err": str(e)}

    try:
        _, es = tool_call("editor_state", {}, 8)
        results["editor_state"] = dig(es)
        if isinstance(results["editor_state"], dict):
            for k in ["helper_live", "current_run_errors", "running"]:
                if k in results["editor_state"]:
                    log(f"editor_state.{k}={results['editor_state'][k]!r}"[:800])
    except Exception as e:
        results["editor_state"] = {"err": str(e)}

    # stop
    for args in (
        {"op": "stop", "params": {}},
        {"action": "stop"},
    ):
        _, stop = tool_call("project_manage", args, 9)
        results["stop"] = dig(stop)
        log(f"stop tried {args}")
        break

    OUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"wrote {OUT}")
    log("DONE")


if __name__ == "__main__":
    main()
