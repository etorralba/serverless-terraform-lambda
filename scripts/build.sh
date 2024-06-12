#!/bin/bash

npm install
mkdir -p dist

cd lambda_handlers

for file in *.ts; do
    npx esbuild $file --bundle --platform=node --outfile=../dist/${file%.*}.js
    cd ../dist
    zip -r ${file%.*}.zip ${file%.*}.js
    rm ${file%.*}.js
    cd ../lambda_handlers
done