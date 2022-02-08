#!/bin/env bash

cd ./terraform
terraform init && terraform apply --auto-approve

cd ../ffl

echo '
< Just a sec!!! >
 --------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
'
sleep 10 

serverless deploy

#foo#