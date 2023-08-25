#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
############          Explore Cloud Run Hello Application           #############
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-cloudrun-gateway
export PROJDIR=`pwd`/gcp-cloudrun-gateway
export SCRIPTNAME=gcp-cloudrun-gateway.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-east4
export GCP_ZONE=us-east4-a
EOF
source $PROJDIR/.env
fi

export GCP_CLUSTER=gcp-gke-cluster
export APPLICATION_NAME=hello

# Display menu options
while :
do
clear
cat<<EOF
================================================
Explore CloudRun Gateway Configuration
------------------------------------------------
Please enter number to select your choice:
(1) Enable APIs
(2) Deploy backend service to Cloud Run 
(3) Configure API
(4) Secure API
(5) Rate limit API
(G) Launch user guide
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable apigateway.googleapis.com run.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com iap.googleapis.com gkehub.googleapis.com anthos.googleapis.com # to enable APIs" | pv -qL 100
    echo
    echo "$ gcloud container hub cloudrun enable --project=\$GCP_PROJECT # to Cloud Run" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud services enable apigateway.googleapis.com run.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com iap.googleapis.com gkehub.googleapis.com anthos.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable apigateway.googleapis.com run.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com iap.googleapis.com gkehub.googleapis.com anthos.googleapis.com
    echo
    echo "$ gcloud container hub cloudrun enable --project=$GCP_PROJECT --quiet # to Cloud Run" | pv -qL 100
    gcloud container hub cloudrun enable --project=$GCP_PROJECT --quiet
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
    echo "2. Enable Cloud Run" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"        
    echo
    echo "$ gcloud run deploy hello-api-service --image us-docker.pkg.dev/cloudrun/container/hello:latest --platform managed --region \$GCP_REGION --max-instances 3 --min-instances 1 --memory 128Mi --ingress all --allow-unauthenticated # to run appication" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"        
    echo
    echo "$ gcloud run deploy hello-api-service --image us-docker.pkg.dev/cloudrun/container/hello:latest --platform managed --region $GCP_REGION --max-instances 3 --min-instances 1 --memory 128Mi --ingress all --allow-unauthenticated # to run appication" | pv -qL 100
    gcloud run deploy hello-api-service --image us-docker.pkg.dev/cloudrun/container/hello:latest --platform managed --region $GCP_REGION --max-instances 3 --min-instances 1 --memory 128Mi --ingress all --allow-unauthenticated
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"        
    echo
    echo "$ gcloud run services delete hello-api-service --platform managed --region $GCP_REGION  # to delete appication" | pv -qL 100
    gcloud run services delete hello-api-service --platform managed --region $GCP_REGION 
else
    export STEP="${STEP},2i"
    echo
    echo "1. Run Application" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"        
    echo
    echo "$ cat << OPENAPI > \$PROJDIR/openapi2-run.yaml
swagger: '2.0'
info:
  title: Hello API Service
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://\${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run Hello API Service
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
OPENAPI" | pv -qL 100
    echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config --api=hello-api-service-api --openapi-spec=\$PROJDIR/openapi2-run.yaml --project=\$GCP_PROJECT # to create the API config" | pv -qL 100
    echo
    echo "$ gcloud api-gateway gateways create hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config --location=\$GCP_REGION --project=\$GCP_PROJECT # to deploy the API config to a gateway" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ export ADDRESS=\$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url) # to set address" | pv -qL 100
    export ADDRESS=$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url)
    echo
    echo "$ export ADDRESS=\${ADDRESS:8} # to set address URL" | pv -qL 100
    export ADDRESS="${ADDRESS:8}"
    echo
    echo "$ cat << OPENAPI > $PROJDIR/openapi2-run.yaml
swagger: '2.0'
info:
  title: Hello API Service
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello Service
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
OPENAPI" | pv -qL 100
cat << OPENAPI > $PROJDIR/openapi2-run.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello Service
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
OPENAPI
    echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-run.yaml --project=$GCP_PROJECT # to create the API config" | pv -qL 100
    gcloud api-gateway api-configs create hello-api-service-config --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-run.yaml --project=$GCP_PROJECT
    echo
    echo "$ gcloud api-gateway gateways create hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config --location=$GCP_REGION --project=$GCP_PROJECT # to deploy the API config to a gateway" | pv -qL 100
    gcloud api-gateway gateways create hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config --location=$GCP_REGION --project=$GCP_PROJECT
    echo
    echo "$ export defaultHostname=\$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname) # to set default hostname" | pv -qL 100
    export defaultHostname=$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname)
    sleep 10
    echo
    echo "$ curl -s https://${defaultHostname}/hello | grep -o \"<title>.*</title>\" # to confirm the service is addressable via API Gateway" | pv -qL 100
    curl -s https://${defaultHostname}/hello | grep -o "<title>.*</title>"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ gcloud api-gateway api-configs delete hello-api-service-config --api=hello-api-service-api --project=$GCP_PROJECT # to delete API config" | pv -qL 100
    gcloud api-gateway api-configs delete hello-api-service-config --api=hello-api-service-api --project=$GCP_PROJECT
    echo
    echo "$ gcloud api-gateway gateways delete hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT # to delete API gateway" | pv -qL 100
    gcloud api-gateway gateways delete hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create the API config" | pv -qL 100
    echo "2. Deploy the API config to a gateway" | pv -qL 100
    echo "3. Set default hostname" | pv -qL 100
    echo "4. Confirm the service is addressable via API Gateway" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"   
    echo
    echo "$ cat << OPENAPI > \$PROJDIR/openapi2-secure.yaml
swagger: '2.0'
info:
  title: Hello API Service
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
security:
- jwt-auth: []
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://\${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
securityDefinitions:
  jwt-auth:
    authorizationUrl: \"https://accounts.google.com/o/oauth2/auth\"
    flow: \"implicit\"
    type: \"oauth2\"
    x-google-issuer: \"https://accounts.google.com\"
    x-google-jwks_uri: \"https://www.googleapis.com/oauth2/v3/certs\"
    x-google-audiences: \"\${APIKEY}\"
OPENAPI" | pv -qL 100
    echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config-secure --api=hello-api-service-api --openapi-spec=\$PROJDIR/openapi2-secure.yaml --project=\$GCP_PROJECT # to create api config" | pv -qL 100
    echo
    echo "$ gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-secure --location=\$GCP_REGION --project=\$GCP_PROJECT # to update api config" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    export BRAND_NAME=$(gcloud alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1
    if [ -z "$BRAND_NAME" ]
    then
        echo
        echo "$ gcloud alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=\$(gcloud config get-value core/account) # to create brand" | pv -qL 100
        gcloud alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=$(gcloud config get-value core/account)
    fi
    export BRAND_ID=$(gcloud alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1 # to set brand ID
    echo
    echo "*** APIs & Services > Credentials ***" | pv -qL 100
    echo "*** + CREATE CREDENTIALS > OAuth client ID ***" | pv -qL 100
    echo "*** Application type > Web application > hello-client-1 > Authorized redirect URIs > +ADD URI > https://localhost/callback > CREATE ***" | pv -qL 100
    echo "*** Download the JSON file ***" | pv -qL 100
    echo
    echo "*** Enter the Client ID ***" | pv -qL 100
    read APIKEY
    echo
    echo "$ export ADDRESS=\$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url) # to get address" | pv -qL 100
    export ADDRESS=$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url)
    echo
    echo "$ export ADDRESS=\${ADDRESS:8} # to set URL" | pv -qL 100
    export ADDRESS=${ADDRESS:8}
    echo
    echo "$ cat << OPENAPI > $PROJDIR/openapi2-secure.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
security:
- jwt-auth: []
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
securityDefinitions:
  jwt-auth:
    authorizationUrl: \"https://accounts.google.com/o/oauth2/auth\"
    flow: \"implicit\"
    type: \"oauth2\"
    x-google-issuer: \"https://accounts.google.com\"
    x-google-jwks_uri: \"https://www.googleapis.com/oauth2/v3/certs\"
    x-google-audiences: \"${APIKEY}\"
OPENAPI" | pv -qL 100
cat << OPENAPI > $PROJDIR/openapi2-secure.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
security:
- jwt-auth: []
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
securityDefinitions:
  jwt-auth:
    authorizationUrl: "https://accounts.google.com/o/oauth2/auth"
    flow: "implicit"
    type: "oauth2"
    x-google-issuer: "https://accounts.google.com"
    x-google-jwks_uri: "https://www.googleapis.com/oauth2/v3/certs"
    x-google-audiences: "${APIKEY}"
OPENAPI
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config-secure --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-secure.yaml --project=$GCP_PROJECT # to create api config" | pv -qL 100
    gcloud api-gateway api-configs create hello-api-service-config-secure --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-secure.yaml --project=$GCP_PROJECT
    echo
    echo "$ gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-secure --location=$GCP_REGION --project=$GCP_PROJECT # to update api config" | pv -qL 100
    gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-secure --location=$GCP_REGION --project=$GCP_PROJECT
    echo
    echo "$ export defaultHostname=\$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname) # to set default hostname" | pv -qL 100
    export defaultHostname=$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname)
    echo
    echo "$ curl -k https://${defaultHostname}/hello # to validate User Authentication is being enforced" | pv -qL 100
    curl -k https://${defaultHostname}/hello
    echo
    echo "$ export URL=\"https://accounts.google.com/o/oauth2/v2/auth?response_type=id_token&client_id=\${APIKEY}&scope=openid+email&redirect_uri=https://localhost/callback&nonce=abcxyz\" # to set URL" | pv -qL 100
    export URL="https://accounts.google.com/o/oauth2/v2/auth?response_type=id_token&client_id=${APIKEY}&scope=openid+email&redirect_uri=https://localhost/callback&nonce=abcxyz"
    echo
    echo "$ echo \$URL # to generate the URL to retrieve a valid JSON Web Token from Google's OAuth service" | pv -qL 100
    echo $URL
    echo
    echo "*** Click URL, login, copy and paste the browser URL below (NB: URL will not be displayed in terminal) ***" | pv -qL 100
    read REDIRECTED_URL
    while [[ -z "$REDIRECTED_URL" ]] ; do
        echo
        echo "$ echo \$URL # to generate the URL to retrieve a valid JSON Web Token from Google's OAuth service" | pv -qL 100
        echo $URL
        echo
        echo "*** Copy and paste the browser URL below (NB: URL will not be displayed in terminal) ***" | pv -qL 100
        read REDIRECTED_URL
    done
    echo
    echo "$ export token=\$(echo ${REDIRECTED_URL} | awk -F'[=&]' '{print \$2}') # to set token" | pv -qL 100
    export token=$(echo ${REDIRECTED_URL} | awk -F'[=&]' '{print $2}')
    echo
    echo "$ echo \$token # to retrieve the token from the URL string" | pv -qL 100
    echo $token
    echo
    echo "$ curl -s -o /dev/null -k -H \"Authorization: Bearer \${token}\" -w \"%{http_code}\\n\" https://${defaultHostname}/hello # to invoke API using JSON Web Token" | pv -qL 100
    curl -s -o /dev/null -k -H "Authorization: Bearer ${token}" -w "%{http_code}\n" https://${defaultHostname}/hello        
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "$ gcloud api-gateway api-configs delete hello-api-service-config-secure --api=hello-api-service-api --project=$GCP_PROJECT # to delete api config" | pv -qL 100
    gcloud api-gateway api-configs delete hello-api-service-config-secure --api=hello-api-service-api --project=$GCP_PROJECT
else
    export STEP="${STEP},4i"
    echo
    echo "1. Create the API config" | pv -qL 100
    echo "2. Update API Gateway to use API Config" | pv -qL 100
    echo "3. Set default hostname" | pv -qL 100
    echo "4. Validate User Authentication is being enforced" | pv -qL 100
    echo "5. Invoke API using JSON Web Token" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"   
    echo
    echo "$ cat << OPENAPI > \$PROJDIR/openapi2-quota.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://\${ADDRESS}
x-google-management:
  metrics:
    - name: \"read-requests\"
      displayName: \"Read Requests\"
      valueType: INT64
      metricKind: DELTA
  quota:
    limits:
      - name: \"read-limit\"
        metric: \"read-requests\"
        unit: \"1/min/{project}\"
        values:
          STANDARD: 5
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
        x-google-quota:
          metricCosts:
            \"read-requests\": 1
OPENAPI" | pv -qL 100
    echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config-quota --api=hello-api-service-api --openapi-spec=\$PROJDIR/openapi2-quota.yaml --project=\$GCP_PROJECT # to create API Config" | pv -qL 100
    echo
    echo "$ gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-quota --location=\$GCP_REGION --project=\$GCP_PROJECT # to update API Gateway to use API Config" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ export defaultHostname=\$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname) # to set default hostname" | pv -qL 100
    export defaultHostname=$(gcloud api-gateway gateways describe hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT --format=json | jq -r .defaultHostname)
    echo
    echo "$ export ADDRESS=\$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url) # to set address" | pv -qL 100
    export ADDRESS=$(gcloud run services list --platform managed --filter=SERVICE:hello-api-service --format json | jq -r .[].status.address.url)
    echo
    echo "$ export ADDRESS=\${ADDRESS:8} # to set URL" | pv -qL 100
    export ADDRESS=${ADDRESS:8}
    echo
    echo "$ cat << OPENAPI > $PROJDIR/openapi2-quota.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
x-google-management:
  metrics:
    - name: \"read-requests\"
      displayName: \"Read Requests\"
      valueType: INT64
      metricKind: DELTA
  quota:
    limits:
      - name: \"read-limit\"
        metric: \"read-requests\"
        unit: \"1/min/{project}\"
        values:
          STANDARD: 5
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
        x-google-quota:
          metricCosts:
            \"read-requests\": 1
OPENAPI" | pv -qL 100
cat << OPENAPI > $PROJDIR/openapi2-quota.yaml
swagger: '2.0'
info:
  title: Hello Service API
  description: Sample API on API Gateway with a Cloud Run backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://${ADDRESS}
x-google-management:
  metrics:
    - name: "read-requests"
      displayName: "Read Requests"
      valueType: INT64
      metricKind: DELTA
  quota:
    limits:
      - name: "read-limit"
        metric: "read-requests"
        unit: "1/min/{project}"
        values:
          STANDARD: 5
paths:
    /assets/{asset}:
      get:
        parameters:
          - in: path
            name: asset
            type: string
            required: true
            description: Name of the asset.
        summary: Assets
        operationId: getAsset
        responses:
          '200':
            description: A successful response
            schema:
              type: string
    /hello:
      get:
        summary: Cloud Run hello world
        operationId: hello
        responses:
          '200':
            description: A successful response
            schema:
              type: string
        x-google-quota:
          metricCosts:
            "read-requests": 1
OPENAPI
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ gcloud api-gateway api-configs create hello-api-service-config-quota --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-quota.yaml --project=$GCP_PROJECT # to create API Config" | pv -qL 100
    gcloud api-gateway api-configs create hello-api-service-config-quota --api=hello-api-service-api --openapi-spec=$PROJDIR/openapi2-quota.yaml --project=$GCP_PROJECT
    echo
    echo "$ gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-quota --location=$GCP_REGION --project=$GCP_PROJECT # to update API Gateway to use API Config" | pv -qL 100
    gcloud api-gateway gateways update hello-api-service-gateway --api=hello-api-service-api --api-config=hello-api-service-config-quota --location=$GCP_REGION --project=$GCP_PROJECT
    echo
    echo "$ for n in {1..10}; do curl -s -o /dev/null -w \"%{http_code}\\n\" -k https://${defaultHostname}/hello; done # to make a call to the API endpoint multiple times" | pv -qL 100
    for n in {1..10}; do curl -s -o /dev/null -w "%{http_code}\n" -k https://${defaultHostname}/hello; done
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "$ gcloud api-gateway gateways delete hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT # to delete API gateway" | pv -qL 100
    gcloud api-gateway gateways delete hello-api-service-gateway --location=$GCP_REGION --project=$GCP_PROJECT
    echo
    echo "$ gcloud api-gateway api-configs delete hello-api-service-config-quota --api=hello-api-service-api --project=$GCP_PROJECT # to delete API Config" | pv -qL 100
    gcloud api-gateway api-configs delete hello-api-service-config-quota --api=hello-api-service-api --project=$GCP_PROJECT
else
    export STEP="${STEP},4i"
    echo
    echo "1. Create the API config" | pv -qL 100
    echo "2. Update API Gateway to use API Config" | pv -qL 100
    echo "3. Make a call to the API endpoint multiple times" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
