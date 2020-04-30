#!/usr/bin/env groovy

/*
  https://www.powerupcloud.com/automate-blue-green-deployment-on-kubernetes-in-a-single-pipeline-part-10/

  This pipeline was taken from the above and is converted to declarative. The intent here is to test blue / green
  deployments to EKS. This template can be used to iterate and test different types of deployments and possible different
  LB types.. ( or anything needed.... )
*/
pipeline {
  agent any
  parameters{
      string(defaultValue: "master", description: 'Which Git Branch to clone?', name: 'GIT_BRANCH')
      string(description: 'AWS Account Number?', name: 'ACCOUNT')
      string(defaultValue: "taxicab-prod-svc", description: 'Blue Service Name to patch in Prod Environment', name: 'PROD_BLUE_SERVICE')
      string(defaultValue: "taxi", description: 'AWS ECR Repository where built docker images will be pushed.', name: 'ECR_REPO_NAME')
      string(defaultValue: "us-east-1", description: 'AWS Region.', name: 'AWS_REGION')
  }
  environment {
    registry = "docker_hub_account/repository_name"
    registryCredential = 'dockerhub'
  }
  options {
       disableConcurrentBuilds()
       buildDiscarder(logRotator(numToKeepStr: '10'))
       timeout(time:120, unit:'MINUTES')
       withAWS(credentials:'as-aws-key')
   }
   stages {
     stage('Clone Repo') {
         steps {
             script {
                 try {
                     echo "******** ${env.STAGE_NAME} ********"
                     git(
                          url: 'https://github.com/granite-cloud/TaxiCabApplication.git',
                          credentialsId: 'as-github',
                          branch: params.GIT_BRANCH
                      )
                 }
                 catch (Exception e) {
                     currentBuild.result = 'FAILED'
                     echo "The stage: ${env.STAGE_NAME} failed"
                     throw e
                 }
             }//script
         } //steps
      } //stage

      stage('Maven Build') {
        steps {
          script {
              try {
                  echo "******** ${env.STAGE_NAME} ********"
                  withMaven(maven: 'apache-maven3.6'){
                   sh "mvn clean package"
                  }
              }
              catch (Exception e) {
                  currentBuild.result = 'FAILED'
                  echo "The stage: ${env.STAGE_NAME} failed"
                  throw e
              }
          }//script
        } //steps
      } //stage

      stage('Build Docker Image') {
           steps {
             script {
                 try {
                      echo "******** ${env.STAGE_NAME} ********"
                      CALLER_ID = sh (
                       script: "aws sts get-caller-identity --query 'Account' --output text --region ${params.AWS_REGION}",
                       returnStdout: true
                     ).trim()

                     GIT_COMMIT_ID = sh (
                       script: 'git log -1 --pretty=%H',
                       returnStdout: true
                     ).trim()

                     TIMESTAMP = sh (
                       script: 'date +%Y%m%d%H%M%S',
                       returnStdout: true
                     ).trim()

                     echo "Git commit id: ${GIT_COMMIT_ID}"
                     IMAGETAG="${GIT_COMMIT_ID}-${TIMESTAMP}"
                     sh "docker build -t ${ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${IMAGETAG} ."
                     sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${CALLER_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}"
                     sh "docker push ${ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${IMAGETAG}"
                 }
                 catch (Exception e) {
                     currentBuild.result = 'FAILED'
                     echo "The stage: ${env.STAGE_NAME} failed"
                     throw e
                 }
             }//script
           } //steps
        } //stage

        stage('User Input') {
          steps {
            script {
                try {
                    echo "******** ${env.STAGE_NAME} ********"
                    // Expose a user input to allow conditional logic in prod deployment stages
                    def userInput = input message: 'Proceed to Production?',
                                    parameters:[booleanParam(defaultValue: false, description: 'Ticking this box will do a deployment on Prod', name: 'DEPLOY_TO_PROD'),
                                                booleanParam(defaultValue: false, description: 'First Deployment on Prod?', name: 'PROD_BLUE_DEPLOYMENT')
                                               ]
                }
                catch (Exception e) {
                    def user = e.getCauses()[0].getUser()
                    echo "Aborted by:\n ${user}"
                    currentBuild.result = "SUCCESS"
                }
            }//script
          } //steps
        } //stage

        stage('Deploy Prod') {
          steps {
            script {
                try {
                    echo "******** ${env.STAGE_NAME} ********"
                    if ( userInput['DEPLOY_TO_PROD'] == true) {
                      echo "Deploying to Production..."
                        withEnv(["KUBECONFIG=${JENKINS_HOME}/.kube/config","IMAGE=${ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${IMAGETAG}"]){
                          sh "sed -i 's|IMAGE|${IMAGE}|g' k8s/deployment.yaml"
                          sh "sed -i 's|ACCOUNT|${ACCOUNT}|g' k8s/service.yaml"
                          sh "sed -i 's|dev|prod|g' k8s/*.yaml"
                          sh "${JENKINS_HOME}/tools/bin/kubectl apply -f k8s"
                          DEPLOYMENT = sh (
                              script: 'cat k8s/deployment.yaml | yq  r -  metadata.name',
                              returnStdout: true
                          ).trim()
                          echo "Creating k8s resources..."
                          sleep 180
                          DESIRED= sh (
                              script: "${JENKINS_HOME}/tools/bin/kubectl get deployment/$DEPLOYMENT | awk '{print \$2}' | grep -v DESIRED",
                              returnStdout: true
                          ).trim()
                          CURRENT= sh (
                              script: "${JENKINS_HOME}/tools/bin/kubectl get deployment/$DEPLOYMENT | awk '{print \$3}' | grep -v CURRENT",
                              returnStdout: true
                          ).trim()
                          if (DESIRED.equals(CURRENT)) {
                              currentBuild.result = "SUCCESS"
                          } else {
                              error("Deployment Unsuccessful.")
                              currentBuild.result = "FAILURE"
                              return
                          }
                        }
                    }
                else {
                        echo "Aborted Production Deployment..!!"
                        currentBuild.result = "SUCCESS"
                        return
                    }
                }
                catch (Exception e) {
                    currentBuild.result = 'FAILED'
                    echo "The stage: ${env.STAGE_NAME} failed"
                    throw e
                }
            }//script
          } //steps
        } //stage

        stage('Validate Green Deployment') {
          steps {
            script {
                try {
                    echo "******** ${env.STAGE_NAME} ********"
                    if (userInput['PROD_BLUE_DEPLOYMENT'] == false) {
                      withEnv(["KUBECONFIG=${JENKINS_HOME}/.kube/config"]){
                         GREEN_SVC_NAME = sh (
                             script: "yq .metadata.name k8s/service.yaml | tr -d '\"'",
                             returnStdout: true
                         ).trim()
                         GREEN_LB = sh (
                             script: "${JENKINS_HOME}/tools/bin/kubectl get svc ${GREEN_SVC_NAME} -o jsonpath=\"{.status.loadBalancer.ingress[*].hostname}\"",
                             returnStdout: true
                         ).trim()
                         echo "Green ENV LB: ${GREEN_LB}"
                         RESPONSE = sh (
                             script: "curl -s -o /dev/null -w \"%{http_code}\" http://admin:password@${GREEN_LB}/swagger-ui.html -I",
                             returnStdout: true
                         ).trim()
                         if (RESPONSE == "200") {
                             echo "Application is working fine. Proceeding to patch the service to point to the latest deployment..."
                         }
                         else {
                             echo "Application didnot pass the test case. Not Working"
                             currentBuild.result = "FAILURE"
                         }
                     }
                  }
                }
                catch (Exception e) {
                    currentBuild.result = 'FAILED'
                    echo "The stage: ${env.STAGE_NAME} failed"
                    throw e
                }
            }//script
          } //steps
        } //stage

        stage('Patch Prod Blue Service') {
          steps {
            script {
                try {
                    echo "******** ${env.STAGE_NAME} ********"
                    if (userInput['PROD_BLUE_DEPLOYMENT'] == false) {
                       	withEnv(["KUBECONFIG=${JENKINS_HOME}/.kube/config"]){
                         	BLUE_VERSION = sh (
                             	script: "kubectl get svc/${PROD_BLUE_SERVICE} -o yaml | yq .spec.selector.version",
                           	returnStdout: true
                         	).trim()
                         	CMD = "kubectl get deployment -l version=${BLUE_VERSION} | awk '{if(NR>1)print \$1}'"
                         	BLUE_DEPLOYMENT_NAME = sh (
                             	script: "${CMD}",
                           		returnStdout: true
                         	).trim()
                         	echo "${BLUE_DEPLOYMENT_NAME}"
                         	sh """kubectl patch svc  "${PROD_BLUE_SERVICE}" -p '{\"spec\":{\"selector\":{\"app\":\"taxicab\",\"version\":\"${BUILD_NUMBER}\"}}}'"""
                          // Needs to be testing here and on failure there should be a rollback that performs a patch back to the old BUILD_NUMBER for the env
                          // sh """kubectl patch svc  "${PROD_BLUE_SERVICE}" -p '{\"spec\":{\"selector\":{\"app\":\"taxicab\",\"version\":\"${BLUE_VERSION}\"}}}'"""
                         	echo "Deleting Blue Environment..."
                         	sh "kubectl delete svc ${GREEN_SVC_NAME}"
                         	sh "kubectl delete deployment ${BLUE_DEPLOYMENT_NAME}"
                    }
                   }
                }
                catch (Exception e) {
                    currentBuild.result = 'FAILED'
                    echo "The stage: ${env.STAGE_NAME} failed"
                    throw e
                }
            }//script
          } //steps
        } //stage

    }// stages
    // Post work after each run
    post {
        always {
            // clean up the workspace after each job
            step([$class: 'WsCleanup'])
            //println "pass final"  // use to test for now and look at Worspace artifcats post build as needed
        }
    }//post
}//pipeline
