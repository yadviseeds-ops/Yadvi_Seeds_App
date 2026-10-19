# Yadvi Seeds — Phase B Isolated Live MySQL 8.0 Integration Test
$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$containerName = "yadvi-mysql-disposable-$timestamp"
$disposableDb = "yadvi_seeds_disposable_$timestamp"
$disposableSource = "backend/backups/disposable_test_source_$timestamp.db"
$disposableCheckpoint = "backend/backups/disposable_test_checkpoint_$timestamp.json"

Write-Host "=== YADVI SEEDS PHASE B: LIVE MYSQL 8.0 INTEGRATION TESTING ==="
Write-Host "Execution Timestamp: $timestamp"
Write-Host "Ephemeral Container: $containerName"
Write-Host "Disposable Target DB: $disposableDb"
Write-Host "Host Port Binding: 127.0.0.1:3307"

# In-memory secret generation
$env:MYSQL_ROOT_PASSWORD = python -c "import secrets; print(secrets.token_urlsafe(24))"
$env:TARGET_DATABASE_URL = "mysql+mysqlconnector://root:$($env:MYSQL_ROOT_PASSWORD)@127.0.0.1:3307/$disposableDb"

$containerStarted = $false
$sourceCopied = $false

try {
    Write-Host "`n1. Launching ephemeral MySQL 8.0 container on 127.0.0.1:3307..."
    docker run -d `
      --name $containerName `
      -p 127.0.0.1:3307:3306 `
      --env MYSQL_ROOT_PASSWORD `
      -e MYSQL_DATABASE=$disposableDb `
      mysql:8.0

    $containerStarted = $true
    Write-Host "Container started. ID: $(docker inspect --format '{{.Id}}' $containerName)"

    Write-Host "`n2. Preparing disposable source database copy..."
    Copy-Item backend/backups/yadvi_seeds_backup_20261013_223421.db $disposableSource
    $sourceCopied = $true
    Write-Host "Disposable source created at: $disposableSource"

    Write-Host "`n3. Executing live MySQL integration tests..."
    python backend/test_mysql_live_integration.py `
      --source $disposableSource `
      --confirm-target $disposableDb `
      --checkpoint-file $disposableCheckpoint `
      --timestamp $timestamp

    Write-Host "`n=== INTEGRATION TESTS COMPLETED SUCCESSFULLY ==="
}
catch {
    Write-Host "`n!!! EXECUTION FAILED: $_"
    throw
}
finally {
    Write-Host "`n=== INITIATING GUARANTEED CLEANUP TEARDOWN ==="

    if ($containerStarted) {
        Write-Host "Removing ephemeral container: $containerName..."
        docker rm -f $containerName | Out-Null
        Write-Host "[CLEANUP OK] Container $containerName removed."
    }

    if (Test-Path $disposableSource) {
        Remove-Item $disposableSource -Force
        Write-Host "[CLEANUP OK] Disposable source copy removed."
    }

    if (Test-Path $disposableCheckpoint) {
        Remove-Item $disposableCheckpoint -Force
        Write-Host "[CLEANUP OK] Disposable checkpoint file removed."
    }

    $env:TARGET_DATABASE_URL = $null
    $env:MYSQL_ROOT_PASSWORD = $null
    Write-Host "[CLEANUP OK] In-memory environment credentials wiped."

    Write-Host "`n=== POST-CLEANUP INTEGRITY VERIFICATION ==="
    # Verify documind-db container untouched
    $documind = docker ps -a --filter "name=documind-db" --format "{{.Names}}: {{.Status}}"
    Write-Host "Unrelated container check: $documind"

    # Verify Windows MySQL80 untouched
    $winMysql = Get-Service MySQL80 | Select-Object -ExpandProperty Status
    Write-Host "Windows MySQL80 service status: $winMysql"

    # Verify master backup integrity
    $backupItem = Get-Item backend/backups/yadvi_seeds_backup_20261013_223421.db
    Write-Host "Master backup size: $($backupItem.Length) bytes (Last modified: $($backupItem.LastWriteTime))"

    Write-Host "Teardown complete."
}
