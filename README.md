# Jenkins (Docker) + Example Pipelines

This repository contains a small helper script to run Jenkins in Docker on Windows and two example pipelines you can import and run in Jenkins:

- `run-jenkins.ps1` — PowerShell script that pulls the Jenkins LTS image, creates a persistent Docker volume, starts (or reuses) a container named `jenkins`, waits for startup, attempts to auto-extract the initial admin password (from the secrets file or from logs), and opens the browser to the UI.
- `Jenkinsfile` — simple Declarative pipeline example.
- `scripted-pipeline.groovy` — simple Scripted Groovy pipeline example.

This README documents step-by-step how to run Jenkins using the included script, how to find/unlock the initial admin password, and how to import and run both pipeline types.

## Prerequisites

- Windows with PowerShell (pwsh recommended) — these instructions use `pwsh`/PowerShell Core but Windows PowerShell 5 can work with minor differences.
- Docker Desktop installed and running. The `docker` CLI must be available in PATH.
- Enough disk space to pull the Jenkins image and to create a Docker volume.

Open a PowerShell terminal (pwsh) in this repository folder:

```powershell
cd C:\src\GitHub\emmanuelknafo\jenkins-gh-migration
```

## 1) Run Jenkins using the helper script

The script is `run-jenkins.ps1`. It will:

- Pull `jenkins/jenkins:lts`.
- Ensure a Docker volume `jenkins_home` exists for persistence.
- Start (or reuse) a container named `jenkins` publishing ports 8080 and 50000.
- Poll the Jenkins HTTP endpoint and container logs until Jenkins prints the initial admin password or becomes fully ready.
- When the password is found, the script prints it and opens the default browser to `http://localhost:8080/`.

Run the script like this from PowerShell:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run-jenkins.ps1
```

Notes:
- The script prints progress and will show the initial admin password when it appears. Example printed line:

  Initial Jenkins admin password (from logs): 7be53a6b23394b6794216373a27c1357

- The script defaults to a 300s (5 minute) readiness timeout. If your machine is slow, increase `$timeout` inside the script or modify the `Get-InitialPassword` timeout.

Important: force reinstall reminder
- If you want to **cleanly reinstall** Jenkins (remove the existing container and Jenkins data) you can run the script with the `-Force` switch. This will remove the `jenkins` container and attempt to remove the `jenkins_home` Docker volume before starting a fresh instance:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run-jenkins.ps1 -Force
```

Warning: `-Force` is destructive — removing the `jenkins_home` volume permanently deletes all Jenkins configuration, jobs and build history stored there. Use `-Force` only when you explicitly want a clean reinstall or you have backups.

## 2) Unlocking Jenkins (first-time setup)

When you first visit `http://localhost:8080/` you will be shown an "Unlock Jenkins" page asking for the Administrator password. Use one of the following to obtain it:

- The script prints it on the terminal when found (see the `Initial Jenkins admin password` message).
- Read it directly from the running container:

```powershell
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

- Or inspect the container logs and look for the block containing "Please use the following password":

```powershell
docker logs jenkins --tail 500
```

If you prefer a quick extraction from logs, this command prints the first 32-hex match from the logs:

```powershell
docker logs jenkins --tail 2000 | Select-String -Pattern '[0-9a-fA-F]{32}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -First 1
```

Paste the password into the Unlock page and continue the Jenkins Setup Wizard (installation of suggested plugins and admin user creation).

Important: if you remove and recreate the container the initial password will change — use the password from the currently-running container.

## 3) Importing and running the pipeline examples

There are two example pipelines in this repo.

- `Jenkinsfile` (Declarative) — place this at the root of a repository and configure a Multibranch Pipeline or Pipeline job in Jenkins that points to this repo/branch. Jenkins will detect and run the `Jenkinsfile` automatically.
- `scripted-pipeline.groovy` (Scripted) — copy this into the Pipeline script area of a Jenkins Pipeline job, or store it in SCM and point Jenkins at the script.

### Option A — Run the Declarative `Jenkinsfile` (recommended for most users)

1. In Jenkins, create a new item → choose **Multibranch Pipeline** (or **Pipeline** if you want a single-branch job).
2. For a Multibranch Pipeline, add your Git repository (this repository) as the Source and scan branch sources. For a single Pipeline job, choose **Pipeline script from SCM** and set the repository/branch.
3. Save and run a build. Jenkins will read `Jenkinsfile` from the repository root and execute the stages.

Notes about the sample `Jenkinsfile`:
- It uses `agent any` (so Jenkins will schedule the job on any available agent/worker). For a fresh single-node Jenkins, the master (controller) can run the job if allowed.
- The stages are simple echo steps for demonstration.

### Option B — Run the Scripted Groovy pipeline

1. In Jenkins, create a new item → choose **Pipeline** and give it a name.
2. In the job configuration, under **Pipeline** → **Definition**, choose **Pipeline script**.
3. Open the file `scripted-pipeline.groovy` from this repository and paste the content into the pipeline script textarea (or point to it in SCM).
4. Save and click **Build Now**.

The scripted example uses `node { … }` and `sleep` to show typical scripted flow.

## 4) Useful Docker / Jenkins management commands

- Show Jenkins container status and published ports:

```powershell
docker ps --filter name=jenkins
```

- Show recent logs (helpful if you missed the password):

```powershell
docker logs jenkins --tail 500
```

- Follow logs live:

```powershell
docker logs jenkins -f
```

- Remove the container (will delete runtime state but not the Docker volume):

```powershell
docker rm -f jenkins
```

- Remove the persistent volume (this deletes Jenkins data permanently):

```powershell
docker volume rm jenkins_home
```

## 5) Troubleshooting

- If the script can't find the Docker CLI, ensure Docker Desktop is running and `docker` is on PATH.
- If the script times out waiting for Jenkins, increase `$timeout` at the top of `run-jenkins.ps1` and/or increase `Get-InitialPassword` timeout.
- If you see a permission error reading the secrets file inside the container, check the container logs and permissions; reading via `docker exec` should work as the container root.
- If the browser doesn't open automatically, copy `http://localhost:8080/` into your browser manually and use the password extracted earlier.

## 6) Security notes

- The initial admin password is printed in container logs and stored in the container's secrets file. Treat it as sensitive and do not share it publicly.
- Avoid passing the admin password in URLs or logs. The script only prints the password to your local terminal for convenience.

## 7) Next steps / optional improvements

- Add a `-Timeout` parameter to the script and expose configuration through command-line params.
- Add a `-PrintLogSnippet` or `-Verbose` flag that prints the few log lines used to extract the password, for easier debugging.
- Add a minimal Job DSL or seed job to auto-create pipeline jobs in Jenkins.

If you'd like, I can implement any of the optional improvements above — tell me which one and I'll add it.

---
Files in this repo:

- `run-jenkins.ps1` — PowerShell helper to run Jenkins in Docker and surface the password.
- `Jenkinsfile` — Declarative example pipeline.
- `scripted-pipeline.groovy` — Scripted Groovy pipeline example.

## Using Docker Compose (controller + agent)

This repository now includes a `docker-compose.yml` which starts a Jenkins controller and a simple inbound agent. The Compose stack maps the same persistent volume `jenkins_home` used by the script.

Start the Compose stack with:

```powershell
# start controller + agent using docker compose directly
docker compose up -d
```

Or use the helper script to start the compose stack (new `-Compose` switch):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run-jenkins.ps1 -Compose
```

Force a clean reinstall of the compose stack and volume:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run-jenkins.ps1 -Compose -Force
```

Notes:
- The `-Compose` option prefers the built-in `docker compose` command (Docker CLI plugin). If `docker` with compose is not available it will fall back to `docker-compose` if installed.
- `-Force` will try to bring down existing compose services and remove the `jenkins_home` volume. This is destructive and will delete Jenkins data.

Using agents with Docker Compose
--------------------------------

The `docker-compose.yml` in this repo includes an `agent` service that uses the official `jenkins/inbound-agent` image and connects to the controller using the JNLP (inbound) protocol. To run the agent you must create a permanent agent (or copy the JNLP secret) in the Jenkins controller and provide the agent secret to the Compose service.

Steps to create an agent and get the secret:

1. Open Jenkins UI → Manage Jenkins → Manage Nodes and Clouds → New Node.
2. Create a new permanent agent node (give it a name, e.g. `agent-1`) and choose "Permanent Agent".
3. After creating the node, go to the agent's page and click "Launch agent by connecting it to the controller". You will see the agent's secret/token and the JNLP command. Copy the secret (a long string).

Using a `.env` file for docker compose
-------------------------------------

Create a `.env` file next to `docker-compose.yml` with the following content:

```ini
JENKINS_AGENT_NAME=agent-1
JENKINS_SECRET=your-jnlp-secret-here
```

Then start the stack:

```powershell
docker compose up -d
```

Or using the helper script:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run-jenkins.ps1 -Compose
```

If you need the agent to run Docker commands (build inside the agent), consider mounting the host Docker socket into the agent container (see commented `volumes` in `docker-compose.yml`). This has security implications — only do it if you understand and accept the risk.

# jenkins-gh-migration

https://dev.to/msrabon/step-by-step-guide-to-setting-up-jenkins-on-docker-with-docker-agent-based-builds-43j5
