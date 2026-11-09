#!/usr/bin/env python3
"""Compile the production codec/writer without the unrelated HaishinKit actor.
Only platform-independent profile declarations are extracted; codec and writer
bodies are copied unchanged from the current checkout. No camera/device access.
"""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
media = root / 'Stream14/Media'
profile = (media / 'SessionProfile.swift').read_text().replace('import HaishinKit\n', '')
start = profile.index('    func audioSettings(muted: Bool)')
end = profile.index('    var videoSettings:', start)
profile = profile[:start] + profile[end:]
(out / 'SessionProfile.swift').write_text(profile)
# Reuse the dependency's existing CoreMedia Sendable declaration, rather than
# inventing a new app annotation. This matches the production import's semantics.
dependency = Path(sys.argv[2]).resolve()
sendability = (dependency / 'HaishinKit/Sources/Extension/CMSampleBuffer+Extension.swift').read_text()
sendability = 'import AVFoundation\n' + sendability[sendability.index('#if hasAttribute(retroactive)'):]
(out / 'HaishinKit.swift').write_text(sendability)
subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-emit-module', '-module-name', 'HaishinKit',
    '-module-cache-path', str(out / 'cache'), str(out / 'HaishinKit.swift'),
    '-emit-module-path', str(out / 'HaishinKit.swiftmodule')], check=True)
codec = (media / 'SharedMediaEncoder.swift').read_text().split('nonisolated final class SharedMediaCodec {', 1)[1]
(out / 'Codec.swift').write_text('''import AVFoundation
import Synchronization
import VideoToolbox
import HaishinKit
nonisolated enum SharedMediaEncoder {
    enum Failure: Error { case configuration, codec, timeline, audioFormat }
}
nonisolated final class SharedMediaCodec {''' + codec)
(out / 'LocalRecorder.swift').write_text((media / 'LocalRecorder.swift').read_text())
(out / 'RecordingRecovery.swift').write_text((media / 'RecordingRecovery.swift').read_text())
subprocess.run(['xcrun', 'swiftc', '-O', '-swift-version', '6', '-D', 'APP_WRITER',
    '-module-cache-path', str(out / 'cache'), '-I', str(out), '-parse-as-library',
    str(out / 'SessionProfile.swift'), str(out / 'Codec.swift'), str(out / 'LocalRecorder.swift'), str(out / 'RecordingRecovery.swift'),
    str(root / 'Tools/fragment-recovery/Probe.swift'), str(root / 'Tools/fragment-recovery/AppWriter.swift'),
    '-o', str(out / 'probe')], check=True)
print(out / 'probe')
