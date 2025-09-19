#!/bin/bash
set -e

# Unified Deployment Script
# Usage: 
#   ./deploy.sh                    # Deploy web files only (dev mode)
#   ./deploy.sh --api              # Deploy API files only  
#   ./deploy.sh --full             # Full deployment with service restart
#   ./deploy.sh --host ubuntu@server.com  # Specify different host

REMOTE_HOST="ubuntu@wecom.jianantech.com"
REMOTE_PATH="/home/wecom"
LOCAL_FRONTEND_DIR="./frontend"
LOCAL_API_DIR="./api"
DEPLOY_TYPE="web"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api)
      DEPLOY_TYPE="api"
      shift
      ;;
    --full)
      DEPLOY_TYPE="full"
      shift
      ;;
    --host)
      REMOTE_HOST="$2"
      shift 2
      ;;
    *)
      REMOTE_HOST="$1"
      shift
      ;;
  esac
done

if [[ "$DEPLOY_TYPE" == "web" || "$DEPLOY_TYPE" == "full" ]]; then
  echo "🔨 Building Flutter Web locally..."
  cd "$LOCAL_FRONTEND_DIR"

  # Generate build timestamp and version for deployment tracking
  BUILD_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
  VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
  BUILD_SIGNATURE="v$VERSION @ $BUILD_TIMESTAMP"
  echo "📅 Build signature: $BUILD_SIGNATURE"

  flutter build web --release --dart-define=BUILD_TIMESTAMP="$BUILD_SIGNATURE"
  
  echo "🔄 Adding cache busting timestamps..."
  TIMESTAMP=$(date +%s)
  # Add timestamp to main script files for cache busting
  sed -i.bak "s/flutter_bootstrap\.js/flutter_bootstrap.js?v=$TIMESTAMP/g" build/web/index.html
  sed -i.bak "s/main\.dart\.js/main.dart.js?v=$TIMESTAMP/g" build/web/index.html
  # Clean up backup files
  rm -f build/web/index.html.bak
  
  cd ..
  
  echo "🚀 Deploying web files to $REMOTE_HOST..."
  # Use rsync with single SSH connection, compatible with macOS
  rsync -rlpt --progress --partial --timeout=60 --delete \
    -e "ssh -o ControlMaster=no -o ControlPath=none" \
    "$LOCAL_FRONTEND_DIR/build/web/" "$REMOTE_HOST:$REMOTE_PATH/web/"
fi

if [[ "$DEPLOY_TYPE" == "api" || "$DEPLOY_TYPE" == "full" ]]; then
  echo "🐍 Deploying API files to $REMOTE_HOST..."
  rsync -rlpt --progress --partial \
    -e "ssh -o ControlMaster=no -o ControlPath=none" \
    --exclude='__pycache__' \
    --exclude='.venv' \
    --exclude='*.pyc' \
    "$LOCAL_API_DIR/" "$REMOTE_HOST:$REMOTE_PATH/api/"
fi

if [[ "$DEPLOY_TYPE" == "full" ]]; then
  echo "📦 Deploying configuration files..."
  rsync -rlpt --progress nginx/ "$REMOTE_HOST:$REMOTE_PATH/nginx/"
  rsync -rlpt --progress verify/ "$REMOTE_HOST:$REMOTE_PATH/verify/" 2>/dev/null || true
  
  echo "⚙️ Restarting services on remote server..."
  ssh "$REMOTE_HOST" "cd $REMOTE_PATH && \
    sudo chown -R ubuntu:www-data web/ && \
    sudo find web/ -type d -exec chmod 755 {} \; && \
    sudo find web/ -type f -exec chmod 644 {} \; && \
    sudo systemctl restart wecom-api && \
    sudo systemctl reload nginx"
fi

echo "✅ Deployment complete!"
echo "🌐 Site: https://wecom.jianantech.com"

