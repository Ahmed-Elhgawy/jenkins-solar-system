pipeline {
    agent any

    tools {
        nodejs 'nodejs-20-14-0'
    }

    environment {
        MONGO_URI = "mongodb://54.162.38.232"
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
                withCredentials([usernamePassword(credentialsId: 'mongo-credentials', passwordVariable: 'MONGO_PASSWORD', usernameVariable: 'MONGO_USERNAME')]) {
                    echo "MONGO_USERNAME: ${MONGO_USERNAME}"
                    echo "MONGO_PASSWORD: ${MONGO_PASSWORD}"
                    sh 'npm test'
                }
            }
        }
    }
}