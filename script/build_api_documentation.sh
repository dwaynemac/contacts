#!/bin/bash
bundle exec yardoc --title "Contacts-ws Documentation" --plugin restful --readme API_README --output-dir ./public/documentation app/models/**/*.rb app/controllers/**/*.rb
echo "Open public/documentation/index.html on your browser or browse to your-app-url/documentation"