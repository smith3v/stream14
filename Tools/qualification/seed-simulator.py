#!/usr/bin/env python3
"""Add one expendable numeric checkpoint to an existing disposable Simulator.
Does not install, reset, uninstall, delete or alter existing recordings.
"""
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid
simulator, source, output = sys.argv[1:]
container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', simulator,
    'com.smith3v.stream14', 'data'], text=True).strip())
assert f'/CoreSimulator/Devices/{simulator}/data/Containers/Data/Application/' in str(container)
assert Path(source).stat().st_size <= 128 * 1024
data = Path(source).read_bytes()
json.loads(data)
directory = container / 'Library/Application Support/MediaExperiments'
directory.mkdir(parents=True, exist_ok=True)
identifier = str(uuid.uuid4()).upper()
(directory / (identifier + '.json')).write_text(json.dumps({
    'id': identifier, 'version': 2, 'created': time.time() - 978307200,
    'status': 'interrupted', 'profile': '1080p30'}))
(directory / (identifier + '.qualification.json')).write_bytes(data)
Path(output).write_text(json.dumps({'STREAM14_QUALIFICATION_FIXTURE_ID': identifier}) + '\n')
print('qualificationFixtureSeeded')
