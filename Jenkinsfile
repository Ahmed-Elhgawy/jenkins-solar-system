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
                        withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                            dependencyCheck additionalArguments: "--scan \'./\'  --out \'./\' --format \'ALL\' --prettyPrint --nvdApiKey $NVD_API_KEY --disableCvssV4", odcInstallation: 'OWASP-DepCheck'
                        }

                        dependencyCheckPublisher failedTotalCritical: 1, pattern: 'dependency-check-report.xml'

                        publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'Dependency Check HTML Report', reportTitles: '', useWrapperFileDirectly: true])

                        junit allowEmptyResults: true, keepProperties: true, testResults: 'dependency-check-junit.xml'
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