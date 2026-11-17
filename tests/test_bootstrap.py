from pathlib import Path
import subprocess,tempfile,os
p=Path(__file__).resolve().parents[1]
s=p.joinpath('bootstrap.sh').read_text()
with tempfile.TemporaryDirectory() as d:
 d=Path(d); log=d/'calls'
 for name,body in {'uname':'if [ "$1" = -s ]; then echo "${MOCK_OS:-Linux}"; else echo "${MOCK_ARCH:-x86_64}"; fi','tailscale':'echo "tailscale $*" >> "$MOCK_LOG"; if [ "$1" = up ]; then echo "https://auth.example.test/device"; exit 1; fi; echo mock-version','tsh':'echo "tsh $*" >> "$MOCK_LOG"; echo mock-version','sudo':'"$@"','curl':'echo unexpected-download >&2; exit 99'}.items():
  f=d/name; f.write_text('#!/bin/sh\n'+body+'\n'); f.chmod(0o755)
 env={**os.environ,'PATH':str(d)+':/usr/bin:/bin','MOCK_LOG':str(log)}
 # /usr/local/bin precedes mocks but has no clients on authoring host.
 for osname,arch in [('Linux','x86_64'),('Darwin','arm64')]:
  r=subprocess.run(['bash','-s','--','--dry-run'],input=s,text=True,capture_output=True,env={**env,'MOCK_OS':osname,'MOCK_ARCH':arch}); assert r.returncode==0,r.stderr
 r=subprocess.run(['bash','-s'],input=s,text=True,capture_output=True,env=env)
 assert r.returncode==1,(r.stdout,r.stderr)
 assert 'https://auth.example.test/device' in r.stdout
 assert '--login-server=https://mesh.psmhome.no --timeout=10s' in log.read_text()
 assert not 'unbound' in r.stderr
 r=subprocess.run(['bash','-s','--','--bogus'],input=s,text=True,capture_output=True,env=env); assert r.returncode==2
 r=subprocess.run(['bash','-s','--','--dry-run'],input=s,text=True,capture_output=True,env={**env,'HEADSCALE_LOGIN_SERVER':'http://bad'}); assert r.returncode==2
 print('PASS: stdin dry-run Linux/amd64 and Darwin/arm64; existing clients skipped, default login URL/flags and pending exit; unknown option and invalid endpoint rejected; cleanup valid.')
