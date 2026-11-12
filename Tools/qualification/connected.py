#!/usr/bin/env python3
"""Prepare and run the bounded Stream14 qualification tests with Xcode."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[2]
BUNDLE_ID = "com.smith3v.stream14"
PHONE_MODEL = "iPhone14,4"
SMOKE_SUITE = "Stream14Tests/ShortPhoneSmokeTests"
SMOKE_CASE = "ShortPhoneSmokeTests/twoProfilesRetainComposedOriginals()"
HOSTED_SUITES = (
    "AppConfigurationTests", "BroadcastSessionTests", "LocalRecorderTests",
    "MediaExperimentTests", "OverlayConfigurationTests", "OverlayHealthTests",
    "QualificationDiagnosticsTests", "RecordingDeletionTests", "RecordingFileSizeTests",
    "RecordingFinalizationTests", "RecordingRecoveryTests", "RTMPSPublisherTests",
    "RTMPSUploadAffinityTests", "SessionInterruptionTests", "SessionProfileTests",
    "SessionWorkspaceTests", "SharedMediaEncoderTests", "SharedMediaIntegrationTests",
    "WebOverlayCompositionTests", "YouTubeAuthorizationTests", "YouTubeBindingTests",
    "YouTubeClientTests", "YouTubeDataRetentionTests",
)
PROJECT_INPUTS = (
    "Config", "Stream14", "Stream14Tests", "Stream14UITests",
    "Stream14.xcodeproj", "Tools/TestRunnerIcon", "Tools/brand-test-runner.sh",
)


class Blocked(Exception):
    """The selected test did not produce sufficient execution evidence."""


def environment(**overrides):
    return {
        **{name: value for name, value in os.environ.items()
           if not name.startswith(("STREAM14_", "TEST_RUNNER_"))},
        **overrides,
    }


def command(args, log, timeout, *, output=None, env=None):
    """Bound the host process group and retain its output in the private run directory."""
    with log.open("xb") as diagnostics:
        if output is None:
            return run_process(args, diagnostics, diagnostics, timeout, env)
        with output.open("xb") as stdout:
            return run_process(args, stdout, diagnostics, timeout, env)


def run_process(args, stdout, stderr, timeout, env):
    process = subprocess.Popen(args, cwd=ROOT, env=env or environment(),
                               stdout=stdout, stderr=stderr, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as exc:
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=3)
        except ProcessLookupError:
            pass
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        reason = "Timed out" if isinstance(exc, subprocess.TimeoutExpired) else "Interrupted"
        raise Blocked(f"{reason} while running {args[0]}. Inspect the private log.") from exc


def checked(args, directory, name, timeout=30, *, output=None, env=None):
    log = directory / f"{name}.log"
    if command(args, log, timeout, output=output, env=env):
        raise Blocked(f"{name} did not succeed. Inspect {log.name}.")


def project_command(directory, packages, destination):
    return [
        "xcodebuild", "-project", "Stream14.xcodeproj", "-scheme", "Stream14",
        "-configuration", "Debug", "-destination", destination,
        "-derivedDataPath", str(directory),
        "-clonedSourcePackagesDirPath", str(packages),
        "-disableAutomaticPackageResolution", "-skipPackageUpdates",
        "-parallel-testing-enabled", "NO",
    ]


def checkout_identity():
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip()
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *PROJECT_INPUTS],
        cwd=ROOT,
    ).decode().split("\0")
    paths = sorted(set(filter(None, paths)) | {"Config/Local.xcconfig"})
    digest = hashlib.sha256()
    for path in paths:
        candidate = ROOT / path
        digest.update(path.encode() + b"\0")
        digest.update(hashlib.sha256(candidate.read_bytes()).digest() if candidate.is_file() else b"missing")
    return {"commit": head, "buildInputs": digest.hexdigest()}


def toolchain():
    return subprocess.check_output(["xcodebuild", "-version"], env=environment(),
                                   stderr=subprocess.DEVNULL, timeout=15).decode().strip()


def development_team():
    config = ROOT / "Config" / "Local.xcconfig"
    if not config.is_file():
        raise Blocked("Configure normal development signing in ignored Config/Local.xcconfig first.")
    matches = re.findall(r"^\s*DEVELOPMENT_TEAM\s*=\s*([A-Z0-9]{10})\s*(?://[^\n]*)?$",
                         config.read_text(), re.MULTILINE)
    if len(matches) != 1:
        raise Blocked("Set one DEVELOPMENT_TEAM assignment in ignored Config/Local.xcconfig.")
    return matches[0]


def simulator_id(value):
    try:
        return str(uuid.UUID(value)).upper()
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Supply an iOS Simulator UUID.") from exc


def phone_id(value):
    if not re.fullmatch(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40}", value):
        raise argparse.ArgumentTypeError("Supply the physical phone's hardware UDID.")
    return value.upper()


def create_directory(path):
    try:
        path.mkdir(mode=0o700)
    except FileExistsError as exc:
        raise Blocked("Choose a new work directory for this command.") from exc


def require_private(path):
    if not path.is_dir() or path.stat().st_mode & 0o077:
        raise Blocked("Use a private work directory created by prepare.")


def write_json(path, data):
    with path.open("x") as file:
        json.dump(data, file, indent=2)
        file.write("\n")


def build_products(directory):
    products = directory / "Build" / "Products"
    configurations = list(products.glob("*_iphoneos*-arm64.xctestrun"))
    app = products / "Debug-iphoneos" / "Stream14.app"
    if len(configurations) != 1 or not (app / "PlugIns/Stream14Tests.xctest").is_dir():
        raise Blocked("The prepared build is missing its unique iOS configuration or hosted tests.")
    return app, configurations[0]


def validate_products(app, xctestrun, directory, timeout=20):
    configuration = plistlib.loads(xctestrun.read_bytes())
    target = configuration.get("Stream14Tests", {})
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if (target.get("TestHostPath") != "__TESTROOT__/Debug-iphoneos/Stream14.app"
            or target.get("TestBundlePath") != "__TESTHOST__/PlugIns/Stream14Tests.xctest"
            or target.get("TestHostBundleIdentifier") != BUNDLE_ID
            or target.get("IsAppHostedTestBundle") is not True
            or info.get("CFBundleIdentifier") != BUNDLE_ID
            or info.get("DTPlatformName") != "iphoneos"):
        raise Blocked("The prepared products do not describe the expected Debug iOS hosted test.")
    checked(["codesign", "--verify", "--deep", "--strict", str(app)], directory, "signature", timeout)
    signatures = {}
    for label, product in (("app", app), ("test", app / "PlugIns/Stream14Tests.xctest")):
        name = f"{label}-signing-identity"
        checked(["codesign", "-d", "--verbose=4", str(product)], directory, name, timeout)
        hashes = re.findall(r"^CDHash=([0-9a-f]+)$", (directory / f"{name}.log").read_text(), re.MULTILINE)
        if len(hashes) != 1:
            raise Blocked("The signed host app or test bundle has no unique code directory hash.")
        signatures[label] = hashes[0]
    profile_path = directory / "profile.plist"
    embedded_profile = app / "embedded.mobileprovision"
    checked(["security", "cms", "-D", "-i", str(embedded_profile)],
            directory, "provisioning", timeout, output=profile_path)
    profile = plistlib.loads(profile_path.read_bytes())
    entitlements_path = directory / "entitlements.txt"
    checked(["codesign", "-d", "--entitlements", "-", str(app)],
            directory, "entitlements", timeout, output=entitlements_path)
    team = development_team()
    application = f"{team}.{BUNDLE_ID}"
    profile_entitlements = profile.get("Entitlements", {})
    # Recent codesign prints the native DER entitlements as an abstract
    # representation. Check the typed entries without asking for an XML conversion.
    entitlements = entitlements_path.read_text()
    signed_identifier = re.search(
        r"^\s*\[Key\] application-identifier\n\s*\[Value\]\n\s*\[String\] (\S+)\s*$",
        entitlements, re.MULTILINE,
    )
    signed_debug = re.search(
        r"^\s*\[Key\] get-task-allow\n\s*\[Value\]\n\s*\[Bool\] true\s*$",
        entitlements, re.MULTILINE,
    )
    if (not profile.get("ProvisionedDevices") or profile["ExpirationDate"] <= datetime.now(timezone.utc).replace(tzinfo=None)
            or team not in profile.get("TeamIdentifier", [])
            or profile_entitlements.get("application-identifier") != application
            or profile_entitlements.get("get-task-allow") is not True
            or not signed_identifier or signed_identifier.group(1) != application
            or not signed_debug):
        raise Blocked("The build requires a current matching Apple Development provisioning profile.")
    signatures["profile"] = hashlib.sha256(embedded_profile.read_bytes()).hexdigest()
    return info, {udid.upper() for udid in profile["ProvisionedDevices"]}, signatures


def version(info):
    return {"version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"]}


def prepare(args, directory, report):
    if not args.packages.is_dir():
        raise Blocked("Supply the existing Swift package checkout directory.")
    initial = checkout_identity()
    xcode = toolchain()
    report["commit"] = initial["commit"]
    phone_build = directory / "phone-build"
    generic = project_command(phone_build, args.packages, "generic/platform=iOS")
    checked([*generic, "-allowProvisioningUpdates", f"DEVELOPMENT_TEAM={development_team()}",
             f"-only-testing:{SMOKE_SUITE}", "build-for-testing"], directory, "build-phone", 900)
    app, xctestrun = build_products(phone_build)
    info, _, signatures = validate_products(app, xctestrun, directory)

    simulator = project_command(directory / "enumeration-build", args.packages,
                                f"platform=iOS Simulator,id={args.simulator}")
    enumeration_path = directory / "enumeration.json"
    checked([*simulator, f"-only-testing:{SMOKE_SUITE}", "-enumerate-tests",
             "-test-enumeration-style", "flat", "-test-enumeration-format", "json",
             "-test-enumeration-output-path", str(enumeration_path), "test"],
            directory, "enumerate", 900, env=environment(TEST_RUNNER_STREAM14_INTERFACE_FIXTURE="idle"))
    enumeration = json.loads(enumeration_path.read_bytes())
    identifiers = [test["identifier"] for plan in enumeration["values"] for test in plan["enabledTests"]]
    if enumeration.get("errors") != [] or identifiers != [f"Stream14Tests/{SMOKE_CASE}"]:
        raise Blocked("Enumeration did not select exactly the expected short smoke method.")
    if checkout_identity() != initial:
        raise Blocked("Build inputs changed during preparation. Prepare again in a new directory.")
    metadata = {
        **initial, **version(info), "toolchain": xcode,
        "root": str(ROOT), "suite": SMOKE_SUITE, "productSignatures": signatures,
        "xctestrunSHA256": hashlib.sha256(xctestrun.read_bytes()).hexdigest(),
    }
    write_json(directory / "prepared.json", metadata)
    report.update(version(info), status="pass", selectedTests=identifiers,
                  message="Signed products are prepared. No phone test ran.")


def remaining(deadline, maximum=300):
    budget = min(maximum, deadline - time.monotonic() - 4)
    if budget < 1:
        raise Blocked("The five-minute phone visit budget expired.")
    return budget


def core_device(args, directory, name, deadline):
    result = directory / f"{name}.json"
    checked(["xcrun", "devicectl", *args, "--timeout", "10", "--json-output", str(result)],
            directory, name, remaining(deadline, 12))
    return json.loads(result.read_bytes())["result"]


def selected_phone(udid, directory, deadline):
    result = core_device(["list", "devices"], directory, "devices", deadline)
    devices = [device for device in result["devices"]
               if device.get("hardwareProperties", {}).get("udid", "").upper() == udid]
    if len(devices) != 1:
        raise Blocked("Connect the selected iPhone by USB and verify its hardware UDID.")
    device = devices[0]
    hardware = device["hardwareProperties"]
    connection = device.get("connectionProperties", {})
    software = device.get("deviceProperties", {})
    if (hardware.get("productType") != PHONE_MODEL or hardware.get("reality") != "physical"
            or hardware.get("platform") != "iOS"):
        raise Blocked("This short smoke supports the physical iPhone 13 mini.")
    if (connection.get("transportType") != "wired" or connection.get("pairingState") != "paired"
            or connection.get("tunnelState") != "connected"):
        raise Blocked("Connect the paired iPhone by USB and unlock it.")
    if software.get("developerModeStatus") != "enabled":
        raise Blocked("Developer Mode is required for Xcode tests on this iPhone.")
    lock = core_device(["device", "info", "lockState", "--device", udid], directory, "lock-state", deadline)
    if lock.get("passcodeRequired") is not False or lock.get("unlockedSinceBoot") is not True:
        raise Blocked("Unlock the selected iPhone before running the smoke.")
    return software["osVersionNumber"]


def os_version(value):
    parts = tuple(int(part) for part in value.split("."))
    return (*parts, *([0] * (3 - len(parts))))


def test_nodes(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            yield node
        else:
            yield from test_nodes(node.get("children", []))


def native_results(directory, report, deadline):
    bundle = directory / "tests.xcresult"
    results = {}
    if not bundle.is_dir():
        raise Blocked("Xcode produced no test result bundle. Inspect test.log.")
    for name in ("summary", "tests"):
        output = directory / f"native-{name}.json"
        checked(["xcrun", "xcresulttool", "get", "test-results", name, "--path", str(bundle), "--compact"],
                directory, f"result-{name}", remaining(deadline, 12), output=output)
        results[name] = json.loads(output.read_bytes())
    summary = results["summary"]
    for field in ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures"):
        value = summary.get(field)
        if type(value) is not int or value < 0:
            raise Blocked("Xcode reported incomplete test counts.")
        report[field] = value
    return summary, list(test_nodes(results["tests"]["testNodes"]))


def classify(summary, status, report):
    if report["failedTests"]:
        report.update(status="fail", message="Xcode recorded a failed test. Inspect the private result bundle.")
    elif (status or summary.get("result") != "Passed" or not report["passedTests"] or report["skippedTests"]
          or report["expectedFailures"] or report["totalTestCount"] != report["passedTests"]):
        raise Blocked("Xcode did not record a clean, nonempty execution. Inspect the private result bundle.")
    else:
        report.update(status="pass", message="The selected tests ran and passed.")


def run(args, directory, report):
    deadline = time.monotonic() + 300
    prepared = json.loads((args.work_dir / "prepared.json").read_bytes())
    if (prepared["root"] != str(ROOT) or prepared["suite"] != SMOKE_SUITE
            or prepared["toolchain"] != toolchain()
            or any(prepared[key] != value for key, value in checkout_identity().items())):
        raise Blocked("The prepared checkout, build inputs, or Xcode changed. Prepare again.")
    report["commit"] = prepared["commit"]
    app, xctestrun = build_products(args.work_dir / "phone-build")
    if hashlib.sha256(xctestrun.read_bytes()).hexdigest() != prepared["xctestrunSHA256"]:
        raise Blocked("The prepared Xcode test configuration changed. Prepare again.")
    info, devices, signatures = validate_products(app, xctestrun, directory, remaining(deadline, 15))
    if signatures != prepared["productSignatures"] or version(info) != {key: prepared[key] for key in ("version", "build")}:
        raise Blocked("The prepared signed app or tests changed. Prepare again.")
    report.update(version(info))
    ios = selected_phone(args.device, directory, deadline)
    if args.device not in devices or os_version(ios) < os_version(info["MinimumOSVersion"]):
        raise Blocked("The prepared app profile or minimum iOS does not match this iPhone.")
    report.update(device="iPhone 13 mini", os=ios)
    command_args = [
        "xcodebuild", "-xctestrun", str(xctestrun),
        "-destination", f"platform=iOS,id={args.device}", "-destination-timeout", "10",
        "-parallel-testing-enabled", "NO", "-test-iterations", "1",
        "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", "90",
        f"-only-testing:{SMOKE_SUITE}", "-resultBundlePath", str(directory / "tests.xcresult"),
        "test-without-building",
    ]
    # Preserve time for result inspection and process-group cleanup.
    status = command(command_args, directory / "test.log", remaining(deadline - 25),
                     env=environment(TEST_RUNNER_STREAM14_INTERFACE_FIXTURE="idle",
                                     TEST_RUNNER_STREAM14_SHORT_DEVICE_SMOKE="1"))
    summary, cases = native_results(directory, report, deadline)
    configurations = summary.get("devicesAndConfigurations", [])
    phone = configurations[0].get("device", {}) if len(configurations) == 1 else {}
    if phone.get("platform") != "iOS" or phone.get("deviceId", "").upper() != args.device:
        raise Blocked("The result does not identify the selected physical phone.")
    if len(cases) != 1 or cases[0].get("nodeIdentifier") != SMOKE_CASE or report["totalTestCount"] != 1:
        raise Blocked("The expected physical smoke did not produce exactly one test result.")
    report["test"] = SMOKE_CASE
    if cases[0].get("result") != "Passed" and not report["failedTests"]:
        raise Blocked("The expected physical smoke was not recorded as passed.")
    classify(summary, status, report)


def hosted(args, directory, report):
    if not args.packages.is_dir():
        raise Blocked("Supply the existing Swift package checkout directory.")
    report["commit"] = checkout_identity()["commit"]
    simulator = project_command(directory / "simulator-build", args.packages,
                                f"platform=iOS Simulator,id={args.simulator}")
    status = command([
        *simulator, *(f"-only-testing:Stream14Tests/{suite}" for suite in HOSTED_SUITES),
        "-resultBundlePath", str(directory / "tests.xcresult"), "test",
    ], directory / "test.log", 900, env=environment(TEST_RUNNER_STREAM14_INTERFACE_FIXTURE="idle"))
    summary, cases = native_results(directory, report, time.monotonic() + 30)
    configurations = summary.get("devicesAndConfigurations", [])
    target = configurations[0].get("device", {}) if len(configurations) == 1 else {}
    if target.get("platform") != "iOS Simulator" or target.get("deviceId", "").upper() != args.simulator:
        raise Blocked("The result does not identify the selected Simulator.")
    executed = {case["nodeIdentifier"].split("/", 1)[0] for case in cases}
    report["suites"] = sorted(executed)
    if executed != set(HOSTED_SUITES):
        raise Blocked("Xcode did not record the complete hosted suite selection.")
    classify(summary, status, report)


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    for action, help_text in (
        ("prepare", "Build and verify signed Debug tests before connecting the phone."),
        ("run", "Run the one short local smoke on a wired iPhone 13 mini."),
        ("hosted", "Run the selected deterministic suites on an iOS Simulator."),
    ):
        sub = commands.add_parser(action, help=help_text, description=help_text)
        sub.add_argument("--work-dir", type=Path, required=True, help="Private build and evidence directory.")
        if action == "run":
            sub.add_argument("--device", type=phone_id, required=True, help="Physical iPhone hardware UDID.")
            sub.add_argument("--allow-camera-mic", action="store_true", required=True,
                             help="Authorize two short local camera and microphone captures of a non-private scene.")
            sub.add_argument("--allow-in-place-install", action="store_true", required=True,
                             help="Allow Xcode to replace the installed Stream14 build in place, including TestFlight.")
        else:
            sub.add_argument("--packages", type=Path, required=True, help="Existing Swift package checkout directory.")
            sub.add_argument("--simulator", type=simulator_id, required=True, help="iOS Simulator UUID.")
    return parser.parse_args()


def main():
    os.umask(0o077)
    args = arguments()
    args.work_dir = args.work_dir.expanduser().resolve()
    if hasattr(args, "packages"):
        args.packages = args.packages.expanduser().resolve()
    directory = None
    started = time.monotonic()
    report = {"schema": 1, "action": args.action, "status": "blocked"}
    try:
        if args.action == "run":
            require_private(args.work_dir)
            directory = Path(tempfile.mkdtemp(prefix="device-", dir=args.work_dir))
        else:
            create_directory(args.work_dir)
            directory = args.work_dir
        {"prepare": prepare, "run": run, "hosted": hosted}[args.action](args, directory, report)
    except Blocked as exc:
        report["message"] = str(exc)
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as exc:
        # Raw tool output and paths can contain identifiers or configuration.
        report["message"] = f"Could not complete {args.action} ({type(exc).__name__}). Inspect private evidence."
    if directory:
        evidence = directory / "evidence.json"
        report["elapsedSeconds"] = round(time.monotonic() - started, 3)
        write_json(evidence, report)
        print(f"Evidence {evidence}")
    print(f"{report['status'].upper()} — {report['message']}")
    return {"pass": 0, "fail": 1, "blocked": 2}[report["status"]]


if __name__ == "__main__":
    sys.exit(main())
