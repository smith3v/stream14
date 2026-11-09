#!/usr/bin/env python3
"""Copy only supplied expendable synthetic files into a disposable Simulator.
Never installs/uninstalls/resets the app and never removes existing artifacts.
"""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import time
import uuid

simulator, readable, unreadable, output = sys.argv[1:]
container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', simulator,
    'com.smith3v.stream14', 'data'], text=True).strip())
assert f'/CoreSimulator/Devices/{simulator}/data/Containers/Data/Application/' in str(container)
directory = container / 'Library/Application Support/MediaExperiments'
directory.mkdir(parents=True, exist_ok=True)
values = {}
for index, (key, source) in enumerate([
    ('STREAM14_RECOVERY_FIXTURE_ID', readable), ('STREAM14_RECOVERY_UNREADABLE_ID', unreadable)]):
    identifier = str(uuid.uuid4()).upper()
    shutil.copyfile(source, directory / (identifier + '.mp4'))
    (directory / (identifier + '.json')).write_text(json.dumps({
        'id': identifier, 'version': 2, 'created': time.time() - 978307200 - index * 60,
        'status': 'interrupted', 'profile': '1080p30'}))
    values[key] = identifier
Path(output).write_text(json.dumps(values, indent=2) + '\n')
print(json.dumps(values))
