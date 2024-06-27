pipeline {
    environment {
        IMAGE_NAME = "ic-webapp"
        APP_CONTAINER_PORT = "8080"
        DOCKERHUB_ID = "cdobe01"
        DOCKERHUB_PASSWORD = credentials('dockerhub_password')
        ANSIBLE_IMAGE_AGENT = "registry.gitlab.com/robconnolly/docker-ansible:latest"
        SNYK_TOKEN = credentials('snyk_token')
    }
    agent none
    stages {
        stage('Installer Git si nécessaire') {
            agent any
            steps {
                script {
                    def gitInstalled = sh(script: 'command -v git', returnStatus: true) == 0
                    if (!gitInstalled) {
                        error("Git ne peut pas être trouvé, veuillez installer Git.")
                    } else {
                        sh 'git --version'
                    }
                }
            }
        }
        stage('Cloner la bibliothèque partagée') {
            agent any
            steps {
                script {
                    sh '''
                    if [ ! -d "/var/lib/jenkins/workspace/ic-webapp@libs/SharedLibrary" ]; then
                        echo "Clonage du dépôt..."
                        git clone https://github.com/ComeDobe/SharedLibrary.git /var/lib/jenkins/workspace/ic-webapp@libs/SharedLibrary || { echo "Échec du clonage du dépôt"; exit 1; }
                    else
                        echo "Le dépôt existe déjà et n'est pas vide"
                    fi
                    '''
                }
            }
        }
        stage('Vérifier la configuration Git') {
            agent any
            steps {
                script {
                    sh '''
                    if ! git config --global user.name &> /dev/null; then
                        echo "Git user.name n'est pas configuré, configuration..."
                        git config --global user.name "jenkins"
                    fi
                    if ! git config --global user.email &> /dev/null; then
                        echo "Git user.email n'est pas configuré, configuration..."
                        git config --global user.email "jenkins@example.com"
                    fi
                    '''
                }
            }
        }
        stage('Vérifier le répertoire de cache Git') {
            agent any
            steps {
                script {
                    sh '''
                    if [ ! -d "/var/lib/jenkins/caches/git-b323b2547a45924730c1ee3a4330e67e" ]; alors
                        echo "Le répertoire de cache Git n'existe pas, création..."
                        mkdir -p /var/lib/jenkins/caches/git-b323b2547a45924730c1ee3a4330e67e
                    else
                        echo "Le répertoire de cache Git existe déjà"
                    fi
                    '''
                }
            }
        }
        stage('Construire l\'image') {
            agent any
            steps {
                script {
                    sh '''
                    if [ -z "${IMAGE_TAG}" ]; alors
                        echo "IMAGE_TAG n'est pas défini, utilisation de 'latest'"
                        IMAGE_TAG="latest"
                    fi
                    DOCKERFILE_NAME="Dockerfile_v4.0"
                    if [ ! -f "./sources/${DOCKERFILE_NAME}" ]; alors
                        echo "Dockerfile non trouvé : ./sources/${DOCKERFILE_NAME}"
                        exit 1
                    fi
                    docker build --no-cache -f ./sources/${DOCKERFILE_NAME} -t ${DOCKERHUB_ID}/$IMAGE_NAME:$IMAGE_TAG ./sources
                    '''
                }
            }
        }
        stage('Analyser l\'image avec SNYK') {
            agent any
            steps {
                script {
                    sh '''
                    echo "Démarrage de l'analyse de l'image ${DOCKERHUB_ID}/$IMAGE_NAME:$IMAGE_TAG ..."
                    SCAN_RESULT=$(docker run --rm -e SNYK_TOKEN=$SNYK_TOKEN -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/app snyk/snyk:docker snyk test --docker $DOCKERHUB_ID/$IMAGE_NAME:$IMAGE_TAG --json)
                    if [ $? -ne 0 ]; alors
                        echo "Avertissement, vous devez voir le résultat de l'analyse"
                        exit 1
                    else
                        echo "PASS : Rien à signaler"
                    fi
                    echo "Analyse terminée"
                    '''
                }
            }
        }
        stage('Exécuter le conteneur basé sur l\'image construite') {
            agent any
            steps {
                script {
                    sh '''
                    echo "Nettoyage des conteneurs existants s'ils existent"
                    docker ps -a | grep -i $IMAGE_NAME && docker rm -f ${IMAGE_NAME}
                    docker run --name ${IMAGE_NAME} -d -p $APP_EXPOSED_PORT:$APP_CONTAINER_PORT  ${DOCKERHUB_ID}/$IMAGE_NAME:$IMAGE_TAG       
                    sleep 5
                    '''
                }
            }
        }
        stage('Tester l\'image') {
            agent any
            steps {
                script {
                    sh '''
                    curl -I http://${HOST_IP}:${APP_EXPOSED_PORT} | grep -i "200"
                    '''
                }
            }
        }
        stage('Nettoyer le conteneur') {
            agent any
            steps {
                script {
                    sh '''
                    docker stop $IMAGE_NAME
                    docker rm $IMAGE_NAME
                    '''
                }
            }
        }
        stage('Se connecter et pousser l\'image sur Docker Hub') {
            agent any
            steps {
                script {
                    sh '''
                    echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_ID --password-stdin
                    docker push ${DOCKERHUB_ID}/$IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }
        stage('Préparer l\'environnement Ansible') {
            agent any
            environment {
                VAULT_KEY = credentials('vault_key')
                PRIVATE_KEY = credentials('private_key')
            }          
            steps {
                script {
                    sh '''
                    echo $VAULT_KEY > vault.key
                    echo $PRIVATE_KEY > id_rsa
                    chmod 600 id_rsa
                    '''
                }
            }
        }
        stage('Déployer l\'application') {
            agent { docker { image 'registry.gitlab.com/robconnolly/docker-ansible:latest' } }
            stages {
                stage('Installer les dépendances des rôles Ansible') {
                    steps {
                        script {
                            sh 'ansible-galaxy install -r roles/requirement.yml'
                        }
                    }
                }
                stage('Tester la connexion aux hôtes cibles') {
                    steps {
                        script {
                            sh '''
                            apt update -y
                            apt install sshpass -y 
                            export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                            ansible all -m ping --private-key id_rsa -l prod
                            '''
                        }
                    }
                }
                stage('Vérifier la syntaxe de tous les playbooks') {
                    steps {
                        script {
                            sh '''
                            export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                            ansible-lint -x 306 sources/ansible-ressources/playbooks/* || echo "Linter passant"
                            echo ${GIT_BRANCH}
                            '''
                        }
                    }
                }
                stage('Déploiement en PRODUCTION') {
                    when { expression { GIT_BRANCH == 'origin/main' } }
                    stages {
                        stage('PRODUCTION - Installer Docker sur tous les hôtes') {
                            steps {
                                script {
                                    sh '''
                                    export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                                    ansible-playbook sources/ansible-ressources/playbooks/install-docker.yml --vault-password-file vault.key --private-key id_rsa -l odoo_server,pg_admin_server
                                    '''
                                }
                            }
                        }
                        stage('PRODUCTION - Déployer pgadmin') {
                            steps {
                                script {
                                    sh '''
                                    export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                                    ansible-playbook sources/ansible-ressources/playbooks/deploy-pgadmin.yml --vault-password-file vault.key --private-key id_rsa -l pg_admin
                                    '''
                                }
                            }
                        }
                        stage('PRODUCTION - Déployer odoo') {
                            steps {
                                script {
                                    sh '''
                                    export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                                    ansible-playbook sources/ansible-ressources/playbooks/deploy-odoo.yml --vault-password-file vault.key --private-key id_rsa -l odoo
                                    '''
                                }
                            }
                        }
                        stage('PRODUCTION - Déployer ic-webapp') {
                            steps {
                                script {
                                    sh '''
                                    export ANSIBLE_CONFIG=$(pwd)/sources/ansible-ressources/ansible.cfg
                                    ansible-playbook sources/ansible-ressources/playbooks/deploy-ic-webapp.yml --vault-password-file vault.key --private-key id_rsa -l ic_webapp
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                slackNotifier currentBuild.result
            }
        }
    }
}
