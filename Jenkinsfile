pipeline {
    agent any
    environment {
        TEST = 'yes'
        DEPLOY = 'yes'
    }
    
    stages {
        stage('Prepare') {
          steps {
           script {
      if (!env.ENVIRONMENT) {
        env.ENVIRONMENT = "production"
      }
    }}}
        stage('Test') {
            when { environment name: 'TEST', value: 'yes' }
            steps {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']],
     userRemoteConfigs: [[url: 'git@github.com:sdarwin/django-terraform.git']]])
     sshagent (credentials: ['b8c5efcc-d20a-4b4b-a6c4-090d619dee0e']) {
              sh '''
#The test phase has been moved to the django-website Jenkinsfile. 
#So, this can be a no-op.
true
'''
            }
            }
        }
        stage('Deploy') {
            when { environment name: 'DEPLOY', value: 'yes' }
            steps {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']],
     userRemoteConfigs: [[url: 'git@github.com:sdarwin/django-terraform.git']]])
     sshagent (credentials: ['b8c5efcc-d20a-4b4b-a6c4-090d619dee0e']) {
              sh '''
set -e
. ~/load_env.sh 
terraform init
terraform taint null_resource.ProvisionRemoteHosts[0] || true
terraform taint null_resource.ProvisionRemoteHosts[1] || true
echo "$ENVIRONMENT"
terraform apply -var "environment=$ENVIRONMENT" -auto-approve
'''
            }
        }
    }
}
}

