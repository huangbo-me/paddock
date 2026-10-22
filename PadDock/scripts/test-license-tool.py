#!/usr/bin/env python3
import pathlib, subprocess, tempfile, hashlib, json, stat
root = pathlib.Path(__file__).resolve().parents[1]
tool = root / '.build/tools/paddock-license'
def run(*args, ok=True):
    p = subprocess.run([str(tool), *map(str,args)], capture_output=True, text=True)
    assert (p.returncode == 0) == ok, (args[0], p.returncode, p.stderr)
    return p
with tempfile.TemporaryDirectory(prefix='paddock-issuer-') as folder:
    d=pathlib.Path(folder); key=d/'signing.key'; config=d/'Commerce.json'; batch=d/'batch.txt'
    run('keygen', key, config)
    assert stat.S_IMODE(key.stat().st_mode) == 0o600
    original=hashlib.sha256(key.read_bytes()).digest()
    run('keygen', key, config, ok=False)
    assert hashlib.sha256(key.read_bytes()).digest() == original
    run('issue',key,100,batch)
    codes=batch.read_text().splitlines()
    assert len(codes)==100 and len(set(codes))==100
    assert stat.S_IMODE(batch.stat().st_mode)==0o600
    run('verify',config,batch)
    issued=hashlib.sha256(batch.read_bytes()).digest()
    run('issue',key,1,batch,ok=False)
    assert hashlib.sha256(batch.read_bytes()).digest()==issued
    malformed=d/'malformed.txt'; malformed.write_text(codes[0].replace('PD1.','PD2.',1))
    run('verify',config,malformed,ok=False)
    run('set-purchase-url',config,'https://afdian.com.evil.test/a/shop',ok=False)
    run('set-purchase-url',config,'https://afdian.com/a/example')
    assert json.loads(config.read_text())['purchaseURL']=='https://afdian.com/a/example'
    key.chmod(0o644); run('issue',key,1,d/'bad.txt',ok=False)
print('Issuer integration passed: generation, permissions, 100 unique codes, verification, tampering, overwrite protection and purchase URL validation.')
