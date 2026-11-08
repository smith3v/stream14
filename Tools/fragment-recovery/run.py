#!/usr/bin/env python3
"""Run only private synthetic children; never operates on app/user recordings."""
import hashlib
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

binary = Path(sys.argv[1]).resolve(strict=True)
out = Path(sys.argv[2]).resolve()
app_writer = "--app-writer" in sys.argv[3:]
validate_only = "--validate-only" in sys.argv[3:]
if not validate_only:
    out.mkdir(parents=True, exist_ok=False)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def operation(*args):
    result = subprocess.run([str(binary), *map(str, args)], capture_output=True, text=True, timeout=30)
    return {"exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}


if validate_only:
    results = json.loads((out / "results.json").read_text())
else:
    results = []
    for mode in ["normal", "before", "after", "finalize"]:
        movie = out / (mode + ".original.mp4")
        child = subprocess.Popen([str(binary), "write", str(movie), mode], stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        events = []
        selector = selectors.DefaultSelector()
        selector.register(child.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + 60
        kill_signal = "finish-started" if mode == "finalize" else "kill-ready"
        killed = False
        try:
            while time.monotonic() < deadline:
                ready = selector.select(timeout=1)
                if ready:
                    line = child.stdout.readline()
                    if not line:
                        break
                    event = json.loads(line)
                    events.append(event)
                    if mode != "normal" and event.get("checkpoint") == kill_signal:
                        # PID belongs to our un-reaped Popen child, never an app or name match.
                        os.kill(child.pid, signal.SIGKILL)
                        killed = True
                        break
                if child.poll() is not None:
                    # Drain any remaining event lines, including finish-completed race evidence.
                    break
            if child.poll() is None and not killed:
                child.wait(timeout=max(0.1, deadline - time.monotonic()))
            remaining, stderr = child.communicate(timeout=10)
            events.extend(json.loads(line) for line in remaining.splitlines())
        finally:
            selector.close()
            if child.poll() is None:
                child.kill()
                child.wait()
        row = {"mode": mode, "events": events, "writerExit": child.returncode, "writerStderr": stderr.decode(),
               "originalBytes": movie.stat().st_size if movie.exists() else 0}
        if movie.exists():
            original_hash = digest(movie)
            row["originalSHA256"] = original_hash
            row["inspectOriginal"] = operation("inspect", movie)
            recovered = out / (mode + ".recovered.mp4")
            row["export"] = operation("export", movie, recovered)
            if recovered.exists():
                row["recoveredBytes"] = recovered.stat().st_size
                row["inspectRecovered"] = operation("inspect", recovered)
            row["originalUnchanged"] = original_hash == digest(movie)
        results.append(row)
        (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        print(json.dumps(row), flush=True)

# Explicit checks distinguish usable recovery from mere file existence/export success.
assert {row["mode"] for row in results} == {"normal", "before", "after", "finalize"}
for row in results:
    assert row.get("originalUnchanged"), row["mode"]
    assert digest(out / (row["mode"] + ".original.mp4")) == row["originalSHA256"]
    if row["mode"] == "before":
        assert row["writerExit"] == -signal.SIGKILL
        assert row["inspectOriginal"]["exit"] != 0 and row["export"]["exit"] != 0
        continue
    original = json.loads(row["inspectOriginal"]["stdout"])
    recovered = json.loads(row["inspectRecovered"]["stdout"])
    assert row["inspectOriginal"]["exit"] == row["inspectRecovered"]["exit"] == row["export"]["exit"] == 0
    assert {t["type"] for t in original["tracks"]} == {"vide", "soun"}
    for track in original["tracks"]:
        other = next(t for t in recovered["tracks"] if t["type"] == track["type"])
        assert track["readerStatus"] == other["readerStatus"] == 2
        assert track["compressedReaderStatus"] == other["compressedReaderStatus"] == 2
        assert track["compressedSHA256"] == other["compressedSHA256"]
        assert track["compressedBytes"] == other["compressedBytes"] > 0
        assert track["decodedSampleUnits"] > 0 and other["decodedSampleUnits"] > 0
        if app_writer and row["mode"] != "normal" and track["type"] == "soun":
            # Measured native remux rounds the incomplete AAC tail's trim metadata.
            # Encoded payload hashes/bytes above must still be exactly identical.
            trimmed = track["decodedSampleUnits"] - other["decodedSampleUnits"]
            assert 0 <= trimmed <= 1024, trimmed
            assert 0 <= track["endEstimate"] - other["endEstimate"] <= 1024 / 44_100
            print(f"{row['mode']}: native remux trimmed {trimmed} decoded AAC PCM frames; encoded bytes unchanged")
        else:
            assert track["decodedSampleUnits"] == other["decodedSampleUnits"]
    video = next(t for t in original["tracks"] if t["type"] == "vide")
    if row["mode"] == "normal":
        assert row["writerExit"] == 0 and video["decodedSampleUnits"] == 750
    else:
        assert row["writerExit"] == -signal.SIGKILL
        assert 300 <= video["decodedSampleUnits"] <= 750
print("PASS: native reads, original preservation, exact compressed payload identity, video count and explicit AAC trim checks")
