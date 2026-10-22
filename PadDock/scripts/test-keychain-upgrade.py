#!/usr/bin/env python3
"""Exercise differing ad-hoc code identities, using only a disposable test item."""
import pathlib, subprocess, tempfile, uuid, time
root = pathlib.Path(__file__).resolve().parents[1]
def run(*args, **kwargs):
    return subprocess.run(list(map(str,args)), check=True, capture_output=True, text=True, **kwargs)
with tempfile.TemporaryDirectory(prefix='paddock-keychain-upgrade-') as directory:
    folder=pathlib.Path(directory)
    obj=folder/'support.o'
    run('xcrun','clang','-Wall','-Wextra','-Werror','-I',root/'Sources/KeychainSupport/include','-c',root/'Sources/KeychainSupport/PadDockKeychainSupport.c','-o',obj)
    creator=folder/'creator'; reader=folder/'reader'
    run('xcrun','swiftc','-swift-version','5','-warnings-as-errors','-module-cache-path',root/'.build/modules','-import-objc-header',root/'Sources/KeychainSupport/include/PadDockKeychainSupport.h',root/'Sources/Core/Commerce.swift',root/'Sources/Core/CommerceEngine.swift',root/'Sources/Storage/KeychainCommerceStorage.swift',root/'Tests/KeychainUpgrade/main.swift',obj,'-framework','Security','-framework','LocalAuthentication','-o',creator)
    reader.write_bytes(creator.read_bytes()); reader.chmod(0o700)
    run('codesign','--force','--sign','-','--identifier','app.paddock.tests.creator',creator)
    run('codesign','--force','--sign','-','--identifier','app.paddock.tests.reader',reader)
    service='app.paddock.tests.upgrade.'+str(uuid.uuid4())
    run(creator,service,'create',timeout=5)
    try:
        started=time.monotonic()
        result=run(reader,service,'read',timeout=5)
        print(result.stdout.strip())
        print(f'Cross-identity Keychain regression passed in {time.monotonic()-started:.2f}s.')
    finally:
        run(creator,service,'delete',timeout=5)
