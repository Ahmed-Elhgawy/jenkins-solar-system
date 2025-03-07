pipeline {
    agent any

    tools {
        nodejs 'nodejs-20-14-0'
    }

    stages {
        stage('Version') {
            steps {
                sh '''
                    node -v
                    npm -v
                '''
            }
        }
        stage('Install Dependencies') {
            steps {
                sh 'npm install --no-audit'
            }
        }
        stage('Dependency Check') {
            steps {
                sh 'npm audit --audit-level=critical'
            }
        }
        stage('Unit Test') {
            steps {
                sh 'npm test'
            }
        }
    }
}