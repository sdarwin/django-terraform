pipeline {
    agent any
    environment {
        BAKE = 'yes'
        DEPLOY = 'yes'
    }
    stages {
        stage('Test') {
            when { environment name: 'BAKE', value: 'yes' }
            steps {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']],
     userRemoteConfigs: [[url: 'git@github.com:sdarwin/django-terraform.git']]])
     sshagent (credentials: ['b8c5efcc-d20a-4b4b-a6c4-090d619dee0e']) {
              sh '''
set -e
. ~/env/bin/activate
.  ~/load_env.sh
git clone git@github.com:sdarwin/django-website.git || true
cd django-website
git fetch --all
git reset --hard origin/master
pip3 install -r requirements.txt
python manage.py test polls
cd ..
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
terraform apply -auto-approve
'''
            }
        }
    }
}
}

