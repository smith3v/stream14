#!/usr/bin/env python3
"""Native synthetic-media regression. Retains private artifacts; prints safe totals.

Usage: verify-markers.py MARKERS_BINARY FIXTURE_BINARY NEW_PRIVATE_DIRECTORY
No camera, microphone, network, app, device or user media is used.
"""
from pathlib import Path
import hashlib
import json
import math
import os
import stat
import subprocess
import sys


def require(condition, code):
    if not condition:
        raise SystemExit(code)


require(len(sys.argv) == 4, 'testArguments')
binary, fixture_binary, root = map(Path, sys.argv[1:])
root.mkdir(mode=0o700)
checks = 0


def check(condition, code):
    global checks
    require(condition, code)
    checks += 1


def run(args, success=True):
    try:
        result = subprocess.run(list(map(str, args)), capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        raise SystemExit('nativeProcessUnavailable')
    require((result.returncode == 0) == success, 'unexpectedNativeOutcome')
    if not success:
        require(result.stdout == b'' and result.stderr.startswith(b'markerUnavailable:'), 'unsafeFailureOutput')
        require(b'fixture-secret' not in result.stderr and len(result.stderr) < 100, 'unsafeFailureDetails')
    return result


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1_048_576), b''):
            value.update(chunk)
    return value.hexdigest()


def measure(manifest, selection, name):
    path = root / (name + '-selection.json')
    path.write_text(json.dumps(selection))
    return json.loads(run([binary, 'measure', manifest, path]).stdout)


cases = [
    ('positive', .08, 44100, 2, 0, 'fixed', 'markers'),
    ('negative', -.08, 48000, 1, 2, 'variable', 'markers'),
    ('missing', 0, 48000, 2, 0, 'fixed', 'missing'),
]
for name, shift, rate, channels, origin, cadence, marker_mode in cases:
    source = root / (name + '.mp4')
    run([fixture_binary, source, shift, rate, channels, origin, cadence, marker_mode])
    before = digest(source)
    output = root / (name + '-inspection')
    window_args = [origin + 1, origin + 2, origin + 4, origin + 5]
    run([binary, 'inspect', source, output, *window_args])
    manifest_path = output / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    check(manifest['inputSHA256'] == before == digest(source), 'originalChanged')
    check(stat.S_IMODE(output.stat().st_mode) == 0o700, 'outputDirectoryNotPrivate')
    check(all(stat.S_IMODE(p.stat().st_mode) == 0o600 for p in output.iterdir()), 'outputFileNotPrivate')
    selection = {'schema': 1, 'markers': []}
    for number, inspection in enumerate(manifest['inspections']):
        frames = inspection['frames']
        times = [f['pts'] for f in frames]
        check(all(a < b for a, b in zip(times, times[1:])), 'videoPTSOrder')
        check(abs(times[0] - window_args[number * 2]) < 1e-8, 'actualNonzeroVideoPTS')
        check(all(abs(t * 30 - round(t * 30)) < 1e-7 for t in times), 'actualVideoTimestampGrid')
        if cadence == 'variable':
            check(max(b - a for a, b in zip(times, times[1:])) > .06, 'variableCadenceLost')
        audio = inspection['audio']
        check(audio['sampleRate'] == rate and audio['channels'] == channels, 'audioFormatChanged')
        for channel_bins in audio['bins']:
            check(all(0 <= b['lastPTS'] - b['firstPTS'] < .001001 and
                      abs((b['samples'] - 1) / rate - (b['lastPTS'] - b['firstPTS'])) < 1e-8 and
                      b['firstPTS'] <= b['peakPTS'] <= b['lastPTS'] and
                      b['minimum'] <= b['maximum'] for b in channel_bins), 'waveformTimingNotSampleDerived')
        if marker_mode == 'missing':
            check(max(abs(b['peak']) for b in audio['bins'][-1]) < .01, 'silentFixtureNotSilent')
            selection['markers'].append({'name': inspection['window']['name']})
            continue
        contact = origin + (1.5 if number == 0 else 4.5)
        first_contact = min(frames, key=lambda f: abs(f['pts'] - contact))
        previous = frames[frames.index(first_contact) - 1]
        check(abs(first_contact['pts'] - contact) < 1e-8, 'contactFrameTimestamp')
        low = float(run([fixture_binary, 'jpeg', output / previous['image']]).stdout)
        high = float(run([fixture_binary, 'jpeg', output / first_contact['image']]).stdout)
        check(low < .3 and high > .7, 'extractedJPEGDoesNotMatchPTS')
        onset = next(b for b in audio['bins'][-1] if b['maximum'] > .25)
        check(onset['firstPTS'] <= contact + shift <= onset['lastPTS'], 'decodedAACOnsetOutsideExpectedBin')
        selection['markers'].append({'name': inspection['window']['name'], 'channel': channels - 1,
            'video': {'lower': previous['pts'], 'upper': first_contact['pts']},
            'audio': {'lower': onset['firstPTS'], 'upper': onset['lastPTS']}})
    result = measure(manifest_path, selection, name)
    check(result['qualification'] == 'notDetermined' and
          result['markerRecognition'] == 'humanSelectionNotVerifiedByTool', 'syntheticFixtureClaimedPhysicalPass')
    if marker_mode == 'missing':
        check(all(m['status'] == 'pendingMissingOrAmbiguousMarker' for m in result['markers']), 'missingMarkerNotPending')
    else:
        for marker, selected in zip(result['markers'], selection['markers']):
            lower = selected['audio']['lower'] - selected['video']['upper']
            upper = selected['audio']['upper'] - selected['video']['lower']
            check(abs(marker['offsetLowerSeconds'] - lower) < 1e-10 and
                  abs(marker['offsetUpperSeconds'] - upper) < 1e-10 and lower <= shift <= upper,
                  'signedConservativeIntervalWrong')
            check(math.isclose(marker['halfRangeSeconds'], (upper - lower) / 2, abs_tol=1e-10),
                  'intervalUncertaintyWrong')
    # An existing destination is never reused, emptied or overwritten.
    sentinel = output / 'sentinel.txt'
    sentinel.write_text('retain')
    run([binary, 'inspect', source, output, *window_args], success=False)
    check(sentinel.read_text() == 'retain' and digest(source) == before, 'existingOutputChanged')

source = root / 'positive.mp4'
manifest = root / 'positive-inspection' / 'manifest.json'
selection = json.loads((root / 'positive-selection.json').read_text())
for index, invalid in enumerate([
    [-1, 1, 4, 5], [1, 3.1, 4, 5], [1, 2, 1.5, 2.5], [1, 2, 6, 7],
    ['nan', 2, 4, 5], [1, 'inf', 4, 5], [1, 1, 4, 5],
]):
    output = root / ('invalid-window-' + str(index))
    run([binary, 'inspect', source, output, *invalid], success=False)
    check(not output.exists(), 'invalidWindowCreatedOutput')

for index, change in enumerate(['channel', 'offFrame', 'backwards', 'outOfPCM', 'partial', 'missingName', 'zeroAudio']):
    invalid = json.loads(json.dumps(selection))
    marker = invalid['markers'][0]
    if change == 'channel': marker['channel'] = 8
    if change == 'offFrame': marker['video']['lower'] += .001
    if change == 'backwards': marker['audio']['upper'] = marker['audio']['lower'] - 1
    if change == 'outOfPCM': marker['audio']['upper'] = 3
    if change == 'partial': del marker['audio']
    if change == 'missingName': marker['name'] = 'fixture-secret'
    if change == 'zeroAudio': marker['audio']['upper'] = marker['audio']['lower']
    path = root / ('invalid-selection-' + str(index) + '.json')
    path.write_text(json.dumps(invalid))
    run([binary, 'measure', manifest, path], success=False)
    checks += 1

secret = root / 'fixture-secret?token=fixture-secret.mp4'
run([binary, 'inspect', secret, root / 'unreadable-output', 1, 2, 4, 5], success=False)
check(not (root / 'unreadable-output').exists(), 'missingInputCreatedOutput')
truncated = root / 'truncated.mp4'
truncated.write_bytes(source.read_bytes()[:100])
run([binary, 'inspect', truncated, root / 'truncated-output', 1, 2, 4, 5], success=False)
check(not (root / 'truncated-output' / 'manifest.json').exists(), 'truncatedInputGotSuccessManifest')
symlink = root / 'symlink.mp4'
symlink.symlink_to(source)
run([binary, 'inspect', symlink, root / 'symlink-output', 1, 2, 4, 5], success=False)
check(not (root / 'symlink-output').exists(), 'symlinkInputAccepted')

print(json.dumps({'nativeSyntheticChecksPassed': checks, 'fixtures': len(cases),
                  'physicalSync': 'notMeasured', 'artifacts': 'retainedPrivately'}, sort_keys=True))
