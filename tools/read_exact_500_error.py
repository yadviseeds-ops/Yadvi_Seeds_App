import subprocess, json

filter_str = 'resource.labels.service_name="yadvi-day1-test" AND timestamp>="2026-11-14T05:19:00Z" AND timestamp<="2026-11-14T05:22:00Z"'
cmd = ["gcloud", "logging", "read", filter_str, "--project=yadvi-seed-app-5f306", "--limit=50", "--format=json"]
out = subprocess.check_output(cmd, text=True, shell=True)
entries = json.loads(out)
for e in entries:
    txt = e.get("textPayload") or e.get("jsonPayload")
    if txt:
        print(f"[{e.get('timestamp')}] {txt}")
