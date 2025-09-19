#!/bin/bash
set -e

# Config
FRONTEND_DIR="/home/wecom/frontend"
WEB_DIR="/home/wecom/web"

echo "🚀 Building Flutter Web..."
cd "$FRONTEND_DIR"
flutter build web --release

echo "🔄 Deploying to $WEB_DIR..."
sudo rm -rf "$WEB_DIR"
sudo cp -r build/web "$WEB_DIR"

echo "🔧 Setting permissions..."
sudo chown -R ubuntu:www-data "$WEB_DIR"
sudo find "$WEB_DIR" -type d -exec chmod 755 {} \;
sudo find "$WEB_DIR" -type f -exec chmod 644 {} \;

echo "♻️ Restarting backend API..."
sudo systemctl restart wecom-api

echo "✅ Deployment complete!"

