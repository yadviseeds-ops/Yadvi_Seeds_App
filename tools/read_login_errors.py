import subprocess, json

# Search for login-firebase, verify-user, auth, or any 401/404/500 errors in the last 24 hours
filter_str = 'resource.labels.service_name="yadvi-day1-test" AND timestamp>="2026-11-13T18:00:00Z" AND (httpRequest.requestUrl=~"auth" OR textPayload=~"auth" OR textPayload=~"Firebase" OR textPayload=~"Shop")'
cmd = ["gcloud", "logging", "read", filter_str, "--project=yadvi-seed-app-5f306", "--limit=100", "--format=json"]
out = subprocess.check_output(cmd, text=True, shell=True)
entries = json.loads(out)
print(f"Total matching entries: {len(entries)}")
for e in entries:
    hr = e.get("httpRequest")
    txt = e.get("textPayload") or e.get("jsonPayload")
    ts = e.get("timestamp")
    if hr:
        print(f"[{ts}] {hr.get('status')} {hr.get('requestMethod')} {hr.get('requestUrl')}")
    elif txt:
        print(f"[{ts}] {txt}")

