#!/usr/bin/env python3
"""Read-only native analyzer regression against a retained synthetic movie.
Never print fixture paths, payloads, command arguments, or raw subprocess errors.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
binary, fixture, output = map(Path, sys.argv[1:])
def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            value.update(chunk)
    return value.digest()
before = digest(fixture)
result = subprocess.run([str(binary), str(fixture)], capture_output=True)
if result.returncode != 0:
    raise SystemExit('nativeAnalysisFailed')
report = json.loads(result.stdout)
for key in ['compressedVideo', 'compressedAudio', 'decodedVideo', 'decodedAudio']:
    track = report[key]
    if not track['finishedReading'] or track['invalidTimestampBuffers'] or track['mediaSamples'] <= 0:
        raise SystemExit('nativeTrackFailed')
if report['compressedVideo']['mediaSamples'] != report['decodedVideo']['mediaSamples']:
    raise SystemExit('videoCountMismatch')
# Secret-shaped input must not appear in normal failure stdout/stderr.
secret = '/private/tester-secret/overlay?token=fixture-secret&stream-key=fixture'
failed = subprocess.run([str(binary), secret], capture_output=True)
if failed.returncode == 0 or b'fixture-secret' in failed.stdout + failed.stderr or secret.encode() in failed.stdout + failed.stderr:
    raise SystemExit('failurePrivacyFailed')
if digest(fixture) != before:
    raise SystemExit('originalChanged')
output.write_bytes(result.stdout)
print('nativeFullReadTimingFailurePrivacyOriginalPreservationPassed')
