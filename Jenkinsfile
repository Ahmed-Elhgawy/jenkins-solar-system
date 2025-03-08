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
                stage('NPM Dependency Check') {
                    steps {
                        sh 'npm audit --audit-level=critical'
                    }
                }
                stage('OWASP Dependency Check') {
                    steps {
                        echo "There is an issue with the OWASP Dependency Check plugin. It is not working as expected. Please use the below code to run the OWASP Dependency Check manually."
                        // withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                            // sh 'mvn org.owasp:dependency-check-maven:9.0.0:purge'
                            // dependencyCheck additionalArguments: "--scan \'./\'  --out \'./\' --format \'ALL\' --prettyPrint", odcInstallation: 'OWASP-DepCheck'
                        // }

                        // dependencyCheckPublisher failedTotalCritical: 1, pattern: 'dependency-check-report.xml'

                        // publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'Dependency Check HTML Report', reportTitles: '', useWrapperFileDirectly: true])

                        // junit allowEmptyResults: true, keepProperties: true, testResults: 'dependency-check-junit.xml'
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
                junit allowEmptyResults: true, keepProperties: true, testResults: 'test-results.xml'
            }
        }
    }
}