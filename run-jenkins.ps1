<#
Simple PowerShell helper to run Jenkins in Docker on Windows and try to
automatically surface the initial admin password. It will:
 - pull the Jenkins LTS image
 - ensure a Docker volume exists
 - start (or reuse) a container named 'jenkins'
 - wait for Jenkins to become available
 - attempt to read /var/jenkins_home/secrets/initialAdminPassword inside the container
   and, if not present yet, scan container logs for a 32-char hex password.
 - open the default browser to http://localhost:8080

Usage: run with PowerShell (pwsh) so Start-Process opens the default browser on Windows.
#>

$Image = 'jenkins/jenkins:lts'
$Volume = 'jenkins_home'
$Container = 'jenkins'
$HttpPort = 8080
$AgentPort = 50000

Write-Host "Pulling $Image..."
docker pull $Image | Out-Null

# ensure volume
docker volume inspect $Volume > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Docker volume: $Volume"
    docker volume create $Volume | Out-Null
} else {
    Write-Host "Docker volume '$Volume' already exists."
}

# handle existing container
$exists = docker ps -a --filter "name=$Container" --format "{{.Names}}" 2>$null
$isRunning = $null
if ($exists -eq $Container) {
    $isRunning = docker inspect -f '{{.State.Running}}' $Container 2>$null
    if ($isRunning -eq 'true') {
        Write-Host "Container '$Container' is already running."
    } else {
        Write-Host "Found existing container '$Container' but not running. Removing it."
        docker rm -f $Container | Out-Null
    }
}

if (($exists -ne $Container) -or ($isRunning -ne 'true')) {
    Write-Host "Starting Jenkins container '$Container' (image: $Image)"
    # Build argument array so PowerShell passes each option as a separate argv to the docker executable
    $dockerArgs = @(
        'run', '-d', '--name', $Container,
        '-p', "$($HttpPort):8080",
        '-p', "$($AgentPort):50000",
        '-v', "$($Volume):/var/jenkins_home",
        '--restart', 'unless-stopped', $Image
    )
    & docker @dockerArgs | Out-Null
}

$url = "http://localhost:$HttpPort/"
Write-Host "Waiting for Jenkins to become available at $url"

$timeout = 300
$start = Get-Date
$ready = $false
while ((Get-Date) -lt $start.AddSeconds($timeout)) {
    try {
        $resp = Invoke-WebRequest -Uri $url -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) {
            $ready = $true
            break
        }
    } catch {
        # ignore
    }

    try {
        $logs = docker logs $Container --tail 200 2>$null
        if ($logs -and $logs -match 'Jenkins is fully up and running') {
            $ready = $true
            break
        }
    } catch {
        # ignore
    }

    Write-Host -NoNewline '.'
    Start-Sleep -Seconds 3
}

if (-not $ready) {
    Write-Warning "Timed out waiting for Jenkins to become ready after $timeout seconds."
} else {
    Write-Host "`nJenkins appears ready."
}

function Get-InitialPassword {
    param(
        [string]$ContainerName,
        [string]$FilePath = '/var/jenkins_home/secrets/initialAdminPassword',
        [int]$TimeoutSeconds = 120
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        # 1) try reading the secrets file inside container
        try {
            $pw = docker exec $ContainerName cat $FilePath 2>$null
            if ($pw) { return $pw.Trim() }
        } catch {
            # ignore
        }

        # 2) fallback: scan logs for a 32-char hex password or the "Please use the following password" block
        try {
            $logs = docker logs $ContainerName --tail 500 2>$null
            if ($logs) {
                $m = [regex]::Match($logs, '[0-9a-fA-F]{32}')
                if ($m.Success) { return $m.Value }

                $lines = $logs -split "\r?\n"
                for ($i = 0; $i -lt $lines.Length; $i++) {
                    if ($lines[$i] -match 'Please use the following password') {
                        for ($j = $i+1; $j -lt $lines.Length; $j++) {
                            $candidate = $lines[$j].Trim()
                            if ($candidate -ne '') { return $candidate }
                        }
                    }
                }
            }
        } catch {
            # ignore
        }

        Start-Sleep -Seconds 3
    }

    return $null
}

$initial = Get-InitialPassword -ContainerName $Container -TimeoutSeconds 120
if ($initial) {
    Write-Host "`nInitial Jenkins admin password: $initial"
} else {
    Write-Warning "Could not retrieve initial admin password automatically. Check inside the container at /var/jenkins_home/secrets/initialAdminPassword or run: docker logs $Container -f"
}

Write-Host "Opening browser to $url"
Start-Process $url

Write-Host "Done."