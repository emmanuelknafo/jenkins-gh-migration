// Simple Declarative Jenkins pipeline (Jenkinsfile)
// - Can be imported as a Pipeline job (Multibranch or single-repo pipeline)
// - Prints a few stages and echoes the initial message

pipeline {
    agent any

    stages {
        stage('Prepare') {
            steps {
                echo "Preparing workspace on ${env.NODE_NAME}"
            }
        }

        stage('Build') {
            steps {
                echo 'Hello from Declarative Jenkinsfile!'
            }
        }

        stage('Test') {
            steps {
                echo 'Running quick smoke test (noop)'
            }
        }

        stage('Publish') {
            steps {
                echo 'Publish step (no-op in example)'
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
    }
}
