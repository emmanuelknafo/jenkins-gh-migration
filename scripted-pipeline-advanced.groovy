// Scripted pipeline advanced example (dummy)
// Demonstrates parameters, node usage, parallel stages, stash/unstash, try/catch, and post cleanup

def buildDir = 'build'
pipeline {
    agent none
    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch')
        booleanParam(name: 'RUN_INTEGRATION', defaultValue: false)
    }
    stages {
        stage('Prepare') {
            agent { label 'docker-agent' }
            steps {
                echo "Running prepare on ${env.NODE_NAME}"
                // Use double-quoted Groovy strings so ${buildDir} is expanded before the shell runs
                sh "mkdir -p ${buildDir} && echo build-prep > ${buildDir}/prep.txt"
                stash includes: "${buildDir}/**", name: 'prepared'
            }
        }

        stage('Parallel Work') {
            parallel {
                stage('Worker A') {
                    agent { label 'docker-agent' }
                    steps {
                        unstash 'prepared'
                        echo "Worker A running on ${env.NODE_NAME}"
                        sh "echo A > ${buildDir}/a.txt"
                    }
                }
                stage('Worker B') {
                    agent { label 'docker-agent' }
                    steps {
                        unstash 'prepared'
                        echo "Worker B running on ${env.NODE_NAME}"
                        sh "echo B > ${buildDir}/b.txt"
                    }
                }
            }
        }

        stage('Integration') {
            when {
                expression { return params.RUN_INTEGRATION }
            }
            agent { label 'docker-agent' }
            steps {
                echo 'Running integration tests (dummy)'
                sh "echo integration > ${buildDir}/integration.txt"
            }
        }

        stage('Package') {
            agent { label 'docker-agent' }
            steps {
                echo 'Packaging'
                sh "tar -czf ${buildDir}/artifact-${BUILD_NUMBER}.tgz -C ${buildDir} ."
                archiveArtifacts artifacts: "${buildDir}/**/*"
            }
        }
    }
    post {
        always {
            echo 'Cleaning up workspace'
            // cleanWs() requires a node context; this pipeline uses `agent none` at the top
            // so run cleanWs inside a node block to ensure it has workspace access.
            script {
                node('docker-agent') {
                    cleanWs()
                }
            }
        }
    }
}
