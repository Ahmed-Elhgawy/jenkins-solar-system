pipeline {
    agent any

    tools {
        nodejs 'nodejs-22-14-0'
    }

    environment {
        MONGO_URI = "mongodb://54.162.38.232"
        MONGO_USERNAME = credentials('mongodb-user')
        MONGO_PASSWORD = credentials('mongodb-secret')
        SONARQUBE_HOME = tool 'sonarqube-scanner' ;
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
                timeout(time: 60, unit: 'SECONDS') {
                    withSonarQubeEnv('sonarqube-server') {
                        sh '''
                            $SONARQUBE_HOME/bin/sonar-scanner \
                                -Dsonar.projectKey=solar-system \
                                -Dsonar.sources=app.js \
                                -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info \
                        '''
                    }
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('Docker Image Build') {
            steps {
                sh 'printenv'
                sh "docker build -t elhgawy/solar-system-app:$GIT_COMMIT ."
            }
        }
        stage('Trivy vulnerability scan') {
            steps {
                sh '''
                    trivy image elhgawy/solar-system-app:$GIT_COMMIT \
                        --severity LOW,MEDIUM,HIGH \
                        --exit-code 0 \
                        --quiet \
                        --format json -o trivy-image-HIGH-report.json

                    trivy image elhgawy/solar-system-app:$GIT_COMMIT \
                        --severity CRITICAL \
                        --exit-code 1 \
                        --quiet \
                        --format json -o trivy-image-CRITICAL-report.json
                '''
            }
            post {
                always {
                    sh '''
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-image-HIGH-report.html trivy-image-HIGH-report.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-image-CRITICAL-report.html trivy-image-CRITICAL-report.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/junit.tpl" \
                            --output trivy-image-HIGH-report.xml trivy-image-HIGH-report.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/junit.tpl" \
                            --output trivy-image-CRITICAL-report.xml trivy-image-CRITICAL-report.json
                    '''
                }
            }
        }
        stage('Docker Image PUSH') {
            steps {
                withDockerRegistry(credentialsId: 'dockerhub',, url: "") {
                    sh "docker push elhgawy/solar-system-app:$GIT_COMMIT "
                }
            }
        }
        stage('Deploy - AWS EC2') {
            when {
               branch 'feature/*'
            }
            steps {
                script {
                   sshagent(['ahmed-keyPair']) {
                        withAWS(credentials: 'aws-jenkins-creds',region: 'us-east-1') {
                            sh '''
                                URL=$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | select(.Tags[].Value == "Docker server") | .PublicDnsName')
                                ssh -o StrictHostKeyChecking=no ec2-user@$URL "
                                    if sudo docker ps | grep -q "solar-system"; then
                                        echo "Container is running"
                                        sudo docker stop solar-system && sudo docker rm solar-system
                                        echo "Container is stopped"
                                    fi
                                    sudo docker run --name solar-system -d \
                                        -e MONGO_URI=$MONGO_URI \
                                        -e MONGO_USERNAME=$MONGO_USERNAME \
                                        -e MONGO_PASSWORD=$MONGO_PASSWORD \
                                        -p 5000:5000 elhgawy/solar-system-app:$GIT_COMMIT
                                "
                            '''
                        }
                    } 
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, keepProperties: true, testResults: 'test-results.xml'

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-HIGH-report.html', reportName: 'Trivy Scan HIGH Report', reportTitles: '', useWrapperFileDirectly: true])
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-CRITICAL-report.html', reportName: 'Trivy Scan CRITICAL Report', reportTitles: '', useWrapperFileDirectly: true])
            junit allowEmptyResults: true, keepProperties: true, testResults: 'trivy-image-HIGH-report.xml'
            junit allowEmptyResults: true, keepProperties: true, testResults: 'trivy-image-CRITICAL-report.xml'
        }
    }

}   