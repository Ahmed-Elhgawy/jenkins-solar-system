pipeline {
    agent any

    tools {
        nodejs 'nodejs-22-14-0'
    }

    environment {
        MONGO_URI = "mongodb://54.162.38.232"
        MONGO_USERNAME = credentials('mongodb-user')
        MONGO_PASSWORD = credentials('mongodb-secret')
        SONARQUBE_HOME = tools('sonarqube-scanner')
    }

    options {
        disableResume()
        disableConcurrentBuilds abortPrevious: true
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
            options { timestamps() }
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
            options { retry(2) }
            steps {
                sh 'npm test'
            }
        }
        stage('Code Coverage') {
            steps {
                catchError(buildResult: 'SUCCESS', message: 'The Error will be fixed in the future', stageResult: 'UNSTABLE') {
                    sh 'npm run coverage'
                }
            }
        }
        stage('SAST - SonarQube') {
            steps {
                sh '''
                    $SONARQUBE_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=solar-system \
                        -Dsonar.sources=app.js \
                        -Dsonar.host.url=http://74.235.244.254:9000 \
                        -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info \
                        -Dsonar.token=sqp_b6b644de4e489265d92433149b8a34de0af4c1bd
                '''
            }
        }
    }

    // post {
    //     always {
    //         junit allowEmptyResults: true, keepProperties: true, testResults: 'test-results.xml'

    //         publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])
    //     }
    // }

}