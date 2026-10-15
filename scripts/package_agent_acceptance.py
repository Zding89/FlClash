import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess


def run(*arguments):
    subprocess.run(arguments, check=True)


def main():
    project = pathlib.Path(__file__).resolve().parent.parent
    source = pathlib.Path('/Applications/FlClash Usage.app')
    target = pathlib.Path('/private/tmp/FlClash Agent Acceptance.app')
    bundle = 'com.zding.flclash.usage.acceptance'
    if target.is_symlink():
        raise RuntimeError('Acceptance bundle must not be a symbolic link')
    if target.exists():
        with (target / 'Contents/Info.plist').open('rb') as stream:
            if plistlib.load(stream)['CFBundleIdentifier'] != bundle:
                raise RuntimeError('Existing bundle is not owned by this acceptance task')
    else:
        run('/usr/bin/ditto', str(source), str(target))
    info_path = target / 'Contents/Info.plist'
    with info_path.open('rb') as stream:
        info = plistlib.load(stream)
    info.update({
        'CFBundleIdentifier': bundle,
        'CFBundleName': 'FlClash Agent Acceptance',
        'CFBundleDisplayName': 'FlClash 验收',
    })
    with info_path.open('wb') as stream:
        plistlib.dump(info, stream)
    frameworks = target / 'Contents/Frameworks'
    generated = project / 'build/agent-acceptance-frameworks'
    for framework in [*generated.glob('*.framework'), *generated.glob('native_assets/*.framework')]:
        destination = frameworks / framework.name
        if destination.is_symlink():
            raise RuntimeError('Unexpected framework symbolic link')
        if destination.exists():
            shutil.rmtree(destination)
        run('/usr/bin/ditto', str(framework), str(destination))
    shutil.copy2(project / 'libclash/macos/FlClashCore', target / 'Contents/MacOS/FlClashCore')
    resources = target / 'Contents/Resources/ai'
    shutil.copy2(project / 'packages/ai_agent_host/dist/host.mjs', resources / 'host.mjs')
    manifest_path = resources / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['hostSha256'] = hashlib.sha256((resources / 'host.mjs').read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest))
    run('/usr/bin/codesign', '--force', '--deep', '--sign', '-', '--entitlements',
        str(project / 'macos/Runner/DebugProfile.entitlements'), str(target))
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(target))
    print(target)


if __name__ == '__main__':
    main()
