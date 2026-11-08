#!/usr/bin/env python3
"""Local synthetic RTMPS fixture. No host trust changes and no automatic deletion."""
import argparse
import pathlib
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=pathlib.Path)
parser.add_argument('--receiver', type=pathlib.Path, required=True)
args = parser.parse_args()
root = args.directory.resolve()
root.mkdir(mode=0o700, parents=True, exist_ok=True)
if list(root.glob('*.key')) or (root / 'receiver.yml').exists():
    parser.error('choose a fresh private directory; existing originals are retained')
receiver = args.receiver.resolve()
version = subprocess.check_output([str(receiver), '--version'], text=True).strip()
if version != 'v1.21.3':
    parser.error('expected official MediaMTX v1.21.3')

def openssl(*values):
    subprocess.run(['openssl', *values], cwd=root, check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)

openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
        '-subj', '/CN=Stream14 Disposable Fixture CA', '-keyout', 'ca.key', '-out', 'ca.crt',
        '-addext', 'basicConstraints=critical,CA:TRUE', '-addext', 'keyUsage=critical,keyCertSign,cRLSign')
openssl('req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost',
        '-keyout', 'server.key', '-out', 'server.csr')
(root / 'server.ext').write_text('subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n')
openssl('x509', '-req', '-in', 'server.csr', '-CA', 'ca.crt', '-CAkey', 'ca.key',
        '-CAcreateserial', '-days', '1', '-extfile', 'server.ext', '-out', 'server.crt')
for key in root.glob('*.key'):
    key.chmod(0o600)
(root / 'receiver.yml').write_text('''logLevel: warn
rtsp: false
hls: false
webrtc: false
srt: false
moq: false
api: false
metrics: false
pprof: false
playback: false
rtmp: true
rtmpEncryption: strict
rtmpsAddress: 127.0.0.1:19360
rtmpServerKey: server.key
rtmpServerCert: server.crt
pathDefaults:
  record: true
  recordPath: ./received/%path/%Y-%m-%d_%H-%M-%S-%f_%z
  recordFormat: fmp4
  recordPartDuration: 200ms
  recordSegmentDuration: 1h
  recordDeleteAfter: 0s
paths:
  fixture/synthetic:
''')
with (root / 'receiver.log').open('x') as log:
    process = subprocess.Popen([str(receiver), str(root / 'receiver.yml')], cwd=root,
                               stdout=log, stderr=log, start_new_session=True)
time.sleep(0.3)
if process.poll() is not None:
    parser.error('receiver rejected setup; inspect private receiver.log')
(root / 'receiver.pid').write_text(str(process.pid))
print('Local receiver started; private directory retains CA and originals. Trust ca.crt only in a disposable simulator.')
