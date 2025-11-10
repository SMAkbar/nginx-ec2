#!/bin/bash
# Script to initialize SSL certificates for HTTPS deployment
# Usage: ./init-ssl.sh your-domain.com your-email@example.com

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain-name> <email>"
    echo "Example: $0 example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "🚀 Initializing SSL certificates for domain: $DOMAIN"
echo "📧 Email: $EMAIL"
echo ""

# Create required directories
mkdir -p nginx-https/certbot/conf nginx-https/certbot/www nginx-https/logs

# Update nginx config with domain name
echo "📝 Updating Nginx configuration with domain: $DOMAIN"
sed -i.bak "s/YOUR_DOMAIN/$DOMAIN/g" nginx-https/conf.d/nginx.conf
rm -f nginx-https/conf.d/nginx.conf.bak

# Start nginx temporarily for certificate validation
echo "🔧 Starting Nginx container for certificate validation..."
docker-compose -f docker-compose.https.yml up -d nginx

# Wait for nginx to be ready
echo "⏳ Waiting for Nginx to be ready..."
sleep 5

# Request certificate from Let's Encrypt
echo "🔐 Requesting SSL certificate from Let's Encrypt..."
docker-compose -f docker-compose.https.yml run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

# Restart nginx with SSL configuration
echo "🔄 Restarting Nginx with SSL configuration..."
docker-compose -f docker-compose.https.yml restart nginx

echo ""
echo "✅ SSL certificate initialized successfully!"
echo "🔒 Your site should now be accessible at https://$DOMAIN"
echo ""
echo "To start the full HTTPS stack:"
echo "  docker-compose -f docker-compose.https.yml up -d"

