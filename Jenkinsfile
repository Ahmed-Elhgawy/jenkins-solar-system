pipeline {
    agent any

    tools {
        nodejs 'nodejs-22-14-0'
    }

    environment {
        MONGO_URI = "mongodb://change depend on the EC2 instance public IP"
        MONGO_USERNAME = credentials('mongodb-user')
        MONGO_PASSWORD = credentials('mongodb-secret')
        GITEA_TOKEN = credentials('gitea-api-token')
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
        stage('NPM Dependency Check') {
            steps {
                sh 'npm audit --audit-level=critical'
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
        stage('Integration Testing') {
            when {
               branch 'feature/*'
            }
            steps {
                withAWS(credentials: 'aws-jenkins-creds',region: 'us-east-1') {
                    sh "bash integration-testing-ec2.sh"
                }
            }
        }
        stage('K8S - Update Image Tag') {
            when {
               branch 'PR*'
            }
            steps {
                script {
                    if(fileExists('solar-system-gitops-argocd')) {
                        sh "rm -rf 'solar-system-gitops-argocd'"
                    }
                }
                sh "git clone http://4.227.216.46:3000/my-organization/solar-system-gitops-argocd.git"
                dir('solar-system-gitops-argocd/kubernetes') {
                    sh '''
                        git branch -m feature/$BUILD_NUMBER
                        git checkout feature/$BUILD_NUMBER
                        sed -i "s|elhgawy/solar-system-app:.*|elhgawy/solar-system-app:$GIT_COMMIT|g" deployment.yml

                        git config --global user.email "jenkins@my-organiztion"
                        git remote set-url origin http://$GITEA_TOKEN@4.227.216.46:3000/my-organization/solar-system-gitops-argocd.git
                        git add .
                        git commit -m "Update image tag"
                        git push -u origin feature/$BUILD_NUMBER
                    '''
                }
            }
        }
        stage('K8S - Raise PR') {
            when {
               branch 'PR*'
            }
            steps {
                sh """
                    curl -X 'POST' \
                    'http://4.227.216.46:3000/api/v1/repos/my-organization/solar-system-gitops-argocd/pulls' \
                    -H 'accept: application/json' \
                    -H 'Authorization: token $GITEA_TOKEN' \
                    -H 'Content-Type: application/json' \
                    -d '{
                    "assignee": "git-admin",
                    "assignees": [
                        "git-admin"
                    ],
                    "base": "main",
                    "body": "update Image in deployment manifest",
                    "head": "feature/$BUILD_NUMBER",
                    "title": "Update Docker image"
                    }'
                """
            }
        }
        stage('APP is Synced..!') {
            when {
               branch 'PR*'
            }
            steps {
                timeout(time: 1, unit: 'DAYS') {
                    input message: 'Is The Application is Synced', ok: 'YES! App is Synced'
                }
            }
        }
        stage('DASP - OWASP ZAP') {
            when {
               branch 'PR*'
            }
            steps {
                sh '''
                    chmod 777 $(pwd)
                    docker run --rm -v $(pwd):/zap/wrk/:rw ghcr.io/zaproxy/zaproxy zap-api-scan.py \
                        -t http://172.203.129.56:30000/api-docs/ \
                        -f openapi \
                        -r zap-report.html \
                        -w zap-report.md \
                        -x zap-report.xml \
                        -J zap-report.json \
                        -c zap-ignore-rules
                '''
            }
        }
        stage('Upload - AWS S3') {
            when {
               branch 'PR*'
            }
            steps {
                sh '''
                    mkdir reports-$BUILD_NUMBER
                    cp -rf coverage/ reports-$BUILD_NUMBER/
                    cp test-results.xml trivy-image-*.* zap-report.* reports-$BUILD_NUMBER/
                '''
                withAWS(credentials: 'aws-jenkins-creds',region: 'us-east-1') {
                    s3Upload(file:"reports-$BUILD_NUMBER", bucket:'solar-system-bucket', path:"jenkins-$BUILD_NUMBER/")
                }
            }
        }
        stage('Applyed to Production..!') {
            when {
               branch 'main'
            }
            steps {
                timeout(time: 1, unit: 'DAYS') {
                    input message: 'Applyed to Production', ok: 'YES! Let us go to Production', submitter: 'admin'
                }
            }
        }
        stage('lambda - S3 Upload and Deploy') {
            when {
               branch 'main'
            }
            steps {
                withAWS(credentials: 'aws-jenkins-creds',region: 'us-east-1') {
                    sh '''
                        tail -5 app.js
                        echo '**********************'
                        sed -i "/^app\\.listen(5000/ s/^/\\/\\//" app.js
                        sed -i "s/^module.exports = app;/\\/\\/module.exports = app;/g" app.js
                        sed -i "s|^//module.exports.handler|module.exports.handler|" app.js
                        echo '**********************'
                        tail -5 app.js
                    '''
                    sh '''
                        zip -qr solar-system-lambda-$BUILD_NUMBER.zip app* package* index.html node*
                        ls -lta solar-system-lambda-$BUILD_NUMBER.zip
                    '''
                    s3Upload(file:"solar-system-lambda-${BUILD_NUMBER}.zip", bucket:'elhgawy-solar-system-lambda-bucket')
                    sh """
                        aws lambda update-function-configuration \
                        --function-name solar-system-function \
                        --environment '{"Variables":{ "MONGO_URI": "${MONGO_URI}","MONGO_USERNAME": "${MONGO_USERNAME}","MONGO_PASSWORD": "${MONGO_PASSWORD}"}}'
                    """
                    sh '''
                        aws lambda update-function-code \
                        --function-name solar-system-function \
                        --s3-bucket elhgawy-solar-system-lambda-bucket \
                        --s3-key solar-system-lambda-$BUILD_NUMBER.zip
                    '''
                }
            }
        }
        stage('lambda - Invoke Function') {
            when {
                branch 'main'
            }
            steps {
                withAWS(credentials: 'aws-jenkins-creds',region: 'us-east-1') {
                    sh '''
                        sleep 30s
                        function_arn=$(aws lambda get-function-url-config --function-name solar-system-function)
                        function_url=$(echo $function_arn | jq -r '.FunctionUrl | sub("/$";"")')

                        curl -Is $function_url | grep -i "200 OK"
                    '''
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

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'zap-report.html', reportName: 'DAST - ZAP Report', reportTitles: '', useWrapperFileDirectly: true])
            junit allowEmptyResults: true, keepProperties: true, testResults: 'zap-report.xml'
        }
    }

}