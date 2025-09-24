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

param(
    [switch]$Force,               # when set, remove container AND volume and do a fresh install
    [int]$Timeout = 300,          # overall readiness timeout in seconds
    [switch]$Compose               # when set, use docker compose to start controller + agent
)

$Image = 'jenkins/jenkins:lts'
$Volume = 'jenkins_home'
$Container = 'jenkins'
$HttpPort = 8080
$AgentPort = 50000

# URL used to open the browser
$url = "http://localhost:$HttpPort/"

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
        if (-not $Force) {
            Write-Host "Container '$Container' is already running. Opening browser to $url and exiting."
            Start-Process $url
            exit 0
        } else {
            Write-Host "Force requested: removing running container '$Container' and volume '$Volume' for fresh install."
            docker rm -f $Container | Out-Null
            # attempt to remove volume as part of a full reinstall; ignore errors
            docker volume rm $Volume > $null 2>&1
            # mark as absent so we proceed to start a fresh container
            $exists = $null
            $isRunning = $null
        }
    } else {
        # existing but not running: remove the stopped container so we can start fresh
        Write-Host "Found existing container '$Container' but not running. Removing it."
        docker rm -f $Container | Out-Null
        $exists = $null
        $isRunning = $null
    }
}

if (($exists -ne $Container) -or ($isRunning -ne 'true')) {
    if ($Compose) {
        Write-Host "Starting Jenkins controller + agent using docker compose (docker-compose.yml)"

        # If Force is requested, bring down any existing compose stack and remove the volume
        if ($Force) {
            Write-Host "Force requested: removing existing compose stack and attempting to remove volume '$Volume'"
            # attempt to stop and remove compose stack
            if (Get-Command docker -ErrorAction SilentlyContinue) {
                docker compose down --volumes --remove-orphans 2>$null | Out-Null
            } else {
                docker-compose down --volumes --remove-orphans 2>$null | Out-Null
            }
            docker volume rm $Volume > $null 2>&1
        }

        # start via docker compose (prefer `docker compose` if available)
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            docker compose up -d
        } else {
            docker-compose up -d
        }
    } else {
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
}
$WriteHostMsg = "Waiting for Jenkins to become available at $url"
Write-Host $WriteHostMsg

$start = Get-Date
$ready = $false
$initial = $null
while ((Get-Date) -lt $start.AddSeconds($Timeout)) {
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

    # Try to surface the initial admin password as soon as it appears (file or logs)
    if (-not $initial) {
        try {
            $pw = docker exec $Container cat /var/jenkins_home/secrets/initialAdminPassword 2>$null
            if ($pw) {
                $initial = $pw.Trim()
                Write-Host "`nInitial Jenkins admin password (from secrets file): $initial"
                # Stop waiting and proceed to open the browser immediately
                $ready = $true
                break
            }
        } catch {
            # ignore
        }

        if (-not $initial) {
            try {
                $recent = docker logs $Container --tail 500 2>$null
                if ($recent) {
                    $m = [regex]::Match($recent -replace '\[LF\]>\s*', '', '[0-9a-fA-F]{32}')
                    if ($m.Success) {
                        $initial = $m.Value
                        Write-Host "`nInitial Jenkins admin password (from logs): $initial"
                        # Stop waiting and proceed to open the browser immediately
                        $ready = $true
                        break
                    } else {
                        # look for the explanatory block and pick the next non-empty-looking line
                        $lines = ($recent -replace '\[LF\]>\s*', '') -split "\r?\n"
                        for ($li = 0; $li -lt $lines.Length; $li++) {
                            if ($lines[$li] -match 'Please use the following password' -or $lines[$li] -match 'An admin user has been created') {
                                for ($lj = $li+1; $lj -lt [Math]::Min($lines.Length, $li+10); $lj++) {
                                    $cand = ($lines[$lj] -replace '[^0-9a-fA-F]', '').Trim()
                                    if ($cand -match '^[0-9a-fA-F]{32}$') {
                                        $initial = $cand
                                        Write-Host "`nInitial Jenkins admin password (from logs): $initial"
                                        # Stop waiting and proceed to open the browser immediately
                                        $ready = $true
                                        break
                                    }
                                }
                                if ($initial) { break }
                            }
                        }
                    }
                }
            } catch {
                # ignore
            }
        }
    }

    Write-Host -NoNewline '.'
    Start-Sleep -Seconds 3
}

if (-not $ready) {
    Write-Warning "Timed out waiting for Jenkins to become ready after $Timeout seconds."
    exit 1
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
        # 1) try reading the secrets file inside container (fastest, preferred)
        try {
            $pw = docker exec $ContainerName cat $FilePath 2>$null
            if ($pw) { return $pw.Trim() }
        } catch {
            # ignore
        }

        # 2) fallback: scan a larger portion of the container logs and look for a 32-char hex password
        try {
            # fetch a larger tail in case the log block was earlier in the start sequence
            $logs = docker logs $ContainerName --tail 2000 2>$null
            if ($logs) {
                # remove some noisy prompts like [LF]> that can appear in logs
                $clean = $logs -replace '\[LF\]>\s*', ''

                # search for any 32-char hex (typical Jenkins initial password)
                $m = [regex]::Match($clean, '[0-9a-fA-F]{32}')
                if ($m.Success) { return $m.Value }

                # sometimes the password is printed on its own line after an explanatory line
                $lines = $clean -split "\r?\n"
                for ($i = 0; $i -lt $lines.Length; $i++) {
                    if ($lines[$i] -match 'Please use the following password' -or $lines[$i] -match 'An admin user has been created') {
                        # look a few lines ahead for the first non-empty-looking token that looks like a password
                        for ($j = $i+1; $j -lt [Math]::Min($lines.Length, $i+10); $j++) {
                            $candidate = ($lines[$j] -replace '[^0-9a-fA-F]', '').Trim()
                            if ($candidate -match '^[0-9a-fA-F]{32}$') { return $candidate }
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

try {
    $initial = Get-InitialPassword -ContainerName $Container -TimeoutSeconds 120
} catch {
    $initial = $null
}
if ($initial) {
    Write-Host "`nInitial Jenkins admin password: $initial"
} else {
    Write-Warning "Could not retrieve initial admin password automatically. Check inside the container at /var/jenkins_home/secrets/initialAdminPassword or run: docker logs $Container -f"
}

Write-Host "Opening browser to $url"
Start-Process $url

Write-Host "Done."
exit 0