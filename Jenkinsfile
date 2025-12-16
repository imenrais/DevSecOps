pipeline {
  agent { label 'linux' }
  options { buildDiscarder(logRotator(numToKeepStr: '5')) }

  environment {
    IMAGE_REPO = 'imenrais/devsecops'   // your Docker Hub repo
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/imenrais/DevSecOps'
      }
    }

    stage('Secrets Scan (Gitleaks)') {
      steps {
        sh '''
          set -eux
          gitleaks version
          GITLEAKS_FLAGS="--no-banner --redact --report-format=json --report-path=gitleaks-report.json -s ."
          if [ "${GITLEAKS_FAIL:-0}" = "1" ]; then
            gitleaks detect $GITLEAKS_FLAGS
          else
            gitleaks detect $GITLEAKS_FLAGS || true
          fi
        '''
      }
      post {
        always { archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        script {
          def scannerHome = tool 'sonarqubepipe'
          withSonarQubeEnv('sonarqube') {
            sh """
              ${scannerHome}/bin/sonar-scanner \
                -Dsonar.projectKey=DevSecOps \
                -Dsonar.projectName=DevSecOps \
                -Dsonar.sources=. \
                -Dsonar.python.version=3.10 \
                -Dsonar.host.url=\$SONAR_HOST_URL
            """
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        waitForQualityGate abortPipeline : false
        timeout(time: 10, unit: 'MINUTES') {
          script {
        def qg = waitForQualityGate(abortPipeline: false)
        echo "Quality Gate: ${qg.status}"
        if (qg.status != 'OK') { currentBuild.result = 'UNSTABLE' }
          }
        }
      }
    }

    stage('Dependency Scan (OWASP DC)') {
  steps {
    withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
      sh '''
        dependency-check.sh \
          --scan . \
          --format ALL \
          --out dependency-check-report \
          --project DevSecOps \
          --failOnCVSS 7.0 \
          --data .odc-data \
          --nvdApiKey "$NVD_API_KEY" \
          --disableAssembly
      '''
    }
  }
  post {
    always {
      dependencyCheckPublisher pattern: 'dependency-check-report/dependency-check-report.xml'
      archiveArtifacts artifacts: '''
        dependency-check-report/dependency-check-report.html,
        dependency-check-report/dependency-check-report.json
      ''', allowEmptyArchive: true
    }
  }
}


    stage('Set Image Tag') {
      steps {
        script {
          env.SHORT_SHA = sh(script: "git rev-parse --short=7 HEAD", returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"
          echo "Building ${env.IMAGE_REPO}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Docker Login') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
        }
      }
    }

    stage('Build Image') {
      steps {
        sh '''
          set -eux
          docker build -t ${IMAGE_REPO}:${IMAGE_TAG} -t ${IMAGE_REPO}:latest .
        '''
      }
    }
    
stage('Image Scan (Trivy)') {
  steps {
    sh '''
      set +e
      docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" aquasec/trivy:latest image --no-progress \
        --format json --output /work/trivy-image-report.json \
        --severity HIGH,CRITICAL --exit-code 1 ${IMAGE_REPO}:${IMAGE_TAG}
      rc=$?; [ $rc -ne 0 ] && echo "Trivy found HIGH/CRITICAL issues; continuing as UNSTABLE" || true
      exit 0
    '''
  }
  post { always { archiveArtifacts artifacts: 'trivy-image-report.json', allowEmptyArchive: true } }
}

stage('FS Scan (Trivy)') {
  steps {
    sh '''
      set +e
      docker run --rm -v "$PWD:/work" aquasec/trivy:latest fs --no-progress \
        --format json --output /work/trivy-fs-report.json \
        --severity HIGH,CRITICAL /work || true
    '''
  }
  post { always { archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true } }
}



    stage('Push Image') {
      steps {
        sh '''
          set -eux
          docker push ${IMAGE_REPO}:${IMAGE_TAG}
          docker push ${IMAGE_REPO}:latest
        '''
      }
    }

    stage('Docker Logout') {
      steps { sh 'docker logout || true' }
    }
stage('Notify (Email Reports)') {
  steps {
    script {
      def attachments = [
        'gitleaks-report.json',
        'dependency-check-report/dependency-check-report.html',
        'dependency-check-report/dependency-check-report.json',
        'trivy-image-report.json',
        'trivy-fs-report.json'
      ].findAll { fileExists(it) }.join(',')

      emailext(
        subject: "CI reports: ${env.JOB_NAME} #${env.BUILD_NUMBER} (${env.IMAGE_REPO}:${env.IMAGE_TAG})",
        body: """Build: ${env.BUILD_URL}
Sonar: ${env.SONAR_HOST_URL ?: 'http://localhost:9000'}/dashboard?id=DevSecOps
Status: ${currentBuild.currentResult}
Attached: ${attachments}
""",
        to: 'imen.rais1@gmail.com',
        attachmentsPattern: attachments ?: '',
        mimeType: 'text/plain'
      )
    }
  }
}


    
  }
}
