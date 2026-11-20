import subprocess, json

cmd = [
    "gcloud", "logging", "read",
    'resource.labels.service_name="yadvi-day1-test" AND timestamp>="2026-11-14T03:54:10Z" AND timestamp<="2026-11-14T03:54:20Z"',
    "--project=yadvi-seed-app-5f306",
    "--format=json"
]
out = subprocess.check_output(cmd, text=True, shell=True)
entries = json.loads(out)
for e in entries:
    txt = e.get("textPayload") or e.get("jsonPayload")
    if txt:
        print(f"[{e.get('timestamp')}] {txt}")

