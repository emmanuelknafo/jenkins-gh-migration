// Simple Scripted Groovy pipeline example
// Save as a Pipeline script in Jenkins ("Pipeline script" option) or use as a reference

node {
    stage('Init') {
        echo "Running scripted pipeline on ${env.NODE_NAME}"
    }

    stage('Hello') {
        echo 'Hello world from scripted Groovy pipeline'
    }

    stage('Sleep') {
        echo 'Simulating work...'
        sleep time: 2, unit: 'SECONDS'
    }

    stage('Done') {
        echo 'Scripted pipeline complete.'
    }
}
