pipeline {
    agent any

    tools {
        nodejs 'nodejs-22-14-0'
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
            parallel {
                stage('Dependency Check') {
                    steps {
                        sh 'npm audit --audit-level=critical'
                    }
                }
                stage('OWASP Dependency Check') {
                    steps {
                        dependencyCheck additionalArguments: '''
                            --scan \'./\' 
                            --out \'./\'
                            --format \'ALL\'
                            --prettyPrint''', odcInstallation: 'OWASP-DepCheck'
                    }
                }
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