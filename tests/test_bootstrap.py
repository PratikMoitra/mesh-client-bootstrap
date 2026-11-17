import os, subprocess, tempfile, pathlib, zipfile
p=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
 d=pathlib.Path(d)
 env=dict(os.environ)
 env['PATH']=str(d)+':'+env['PATH']
 for cmd, body in {'tailscale':'printf "tailscale:%s\\n" "$*"','tsh':'printf "tsh:%s\\n" "$*"','sudo':'exec "$@"'}.items():
  f=d/cmd; f.write_text('#!/bin/sh\n'+body+'\n'); f.chmod(0o755)
 conf=d/'config.env'; conf.write_text('HEADSCALE_LOGIN_SERVER=https://mesh.test\nTELEPORT_PROXY=teleport.test:443\n')
 def run(*args): return subprocess.run(['bash',str(p/'bootstrap.sh'),*args],env=env,text=True,capture_output=True)
 r=run('--apply','--config',str(p/'config.example.env')); assert r.returncode!=0 and 'verified HTTPS' in r.stderr
 r=run('--apply','--config',str(conf)); assert r.returncode==0,r.stderr
 assert 'tailscale:version' in r.stdout and 'tsh:version' in r.stdout and 'tailscale:up' not in r.stdout
 r=run('--apply','--connect','--config',str(conf)); assert r.returncode==0,r.stderr
 assert 'tailscale:up --login-server=https://mesh.test --timeout=5s' in r.stdout
 conf.write_text('BAD_KEY=anything\n'); assert run('--apply','--config',str(conf)).returncode!=0
 r=run('--bogus'); assert r.returncode==2
print('PASS: placeholder refusal, install-free existing-client path, mock login flags, unknown config/option refusal (5 checks).')
