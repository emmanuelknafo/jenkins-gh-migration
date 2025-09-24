# Pull the official Jenkins LTS Docker image
docker pull jenkins/jenkins:lts

# Create a Docker volume for Jenkins data persistence
docker volume create jenkins_home

# Run Jenkins in Docker, mapping ports and mounting the volume
docker run -d `
  --name jenkins `
  -p 8080:8080 `
  -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  jenkins/jenkins:lts

# grab the initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# echo the URL to access Jenkins
Write-Host "Jenkins is running at http://localhost:8080"

# open browser
Start-Process http://localhost:8080