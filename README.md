# Nginx Deployment Configuration

This repository contains Docker Compose configurations for deploying Nginx as a reverse proxy for your application, with support for both HTTP and HTTPS (using Let's Encrypt via Certbot).

## Structure

```
nginx-deployment/
├── docker-compose.http.yml      # HTTP-only configuration
├── docker-compose.https.yml     # HTTPS with Certbot configuration
├── nginx/
│   ├── conf.d/
│   │   ├── nginx.conf          # HTTP Nginx configuration
│   │   └── nginx-https.conf    # HTTPS Nginx configuration
│   └── logs/                    # Nginx logs (gitignored)
└── README.md
```

## Prerequisites

- Docker and Docker Compose installed
- For HTTPS: A domain name pointing to your EC2 instance's public IP
- For HTTPS: Ports 80 and 443 open in your EC2 security group

## Quick Start

### HTTP Setup (Development/Testing)

1. **Update upstream servers** in `nginx/conf.d/nginx.conf`:
   - Replace `host.docker.internal:8000` with your backend service address
   - Replace `host.docker.internal:3000` with your frontend service address
   - For EC2, use either:
     - Container names if using Docker network: `backend:8000`, `frontend:3000`
     - Host IP if services run on host: `127.0.0.1:8000`, `127.0.0.1:3000`

2. **Start the HTTP server**:
   ```bash
   docker-compose -f docker-compose.http.yml up -d
   ```

3. **Verify it's running**:
   ```bash
   docker ps
   curl http://localhost
   ```

### HTTPS Setup (Production)

1. **Update domain name** in `nginx/conf.d/nginx-https.conf`:
   - Replace `YOUR_DOMAIN` with your actual domain name (e.g., `example.com`)
   - Update upstream servers as described in HTTP setup

2. **Create required directories**:
   ```bash
   mkdir -p nginx/certbot/conf nginx/certbot/www nginx/logs
   ```

3. **Obtain SSL certificate** (first time only):
   ```bash
   # Start nginx temporarily for certificate validation
   docker-compose -f docker-compose.https.yml up -d nginx
   
   # Request certificate from Let's Encrypt
   docker-compose -f docker-compose.https.yml run --rm certbot certonly \
     --webroot \
     --webroot-path=/var/www/certbot \
     --email your-email@example.com \
     --agree-tos \
     --no-eff-email \
     -d your-domain.com
   
   # Restart nginx with SSL configuration
   docker-compose -f docker-compose.https.yml restart nginx
   ```

4. **Start the HTTPS server**:
   ```bash
   docker-compose -f docker-compose.https.yml up -d
   ```

5. **Verify it's running**:
   ```bash
   docker ps
   curl https://your-domain.com
   ```

## Configuration Details

### Upstream Services

The Nginx configuration expects:
- **Backend (FastAPI)**: Running on port 8000
- **Frontend (Next.js)**: Running on port 3000

Update the `upstream` blocks in the Nginx config files to match your deployment:

**Option 1: Docker Network** (if services are in same Docker network):
```nginx
upstream backend {
    server backend:8000;
}
```

**Option 2: Host Network** (if services run on host):
```nginx
upstream backend {
    server 127.0.0.1:8000;
}
```

**Option 3: External IP** (if services are on different machines):
```nginx
upstream backend {
    server 10.0.1.5:8000;
}
```

### Routing

- `/` → Frontend (Next.js)
- `/api/*` → Backend (FastAPI)
- `/health` → Backend health check

### SSL Certificate Renewal

Certbot automatically renews certificates every 12 hours. The Nginx container reloads every 6 hours to pick up renewed certificates.

To manually renew:
```bash
docker-compose -f docker-compose.https.yml run --rm certbot renew
docker-compose -f docker-compose.https.yml restart nginx
```

## EC2 Deployment Steps

1. **SSH into your EC2 instance**:
   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-ip
   ```

2. **Install Docker and Docker Compose** (if not already installed):
   ```bash
   sudo yum update -y
   sudo yum install docker -y
   sudo service docker start
   sudo usermod -a -G docker ec2-user
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Clone this repository**:
   ```bash
   git clone <your-repo-url> nginx-deployment
   cd nginx-deployment
   ```

4. **Configure and start**:
   - For HTTP: Follow "HTTP Setup" above
   - For HTTPS: Follow "HTTPS Setup" above

5. **Configure Security Group**:
   - Allow inbound traffic on port 80 (HTTP)
   - Allow inbound traffic on port 443 (HTTPS, if using)

## Troubleshooting

### Check Nginx logs:
```bash
docker logs nginx-http  # or nginx-https
tail -f nginx/logs/error.log
tail -f nginx/logs/access.log
```

### Test Nginx configuration:
```bash
docker exec nginx-https nginx -t
```

### Restart services:
```bash
docker-compose -f docker-compose.http.yml restart
docker-compose -f docker-compose.https.yml restart
```

### Stop services:
```bash
docker-compose -f docker-compose.http.yml down
docker-compose -f docker-compose.https.yml down
```

## Notes

- The HTTP configuration is suitable for development/testing
- The HTTPS configuration is recommended for production
- Certificates are automatically renewed by Certbot
- Logs are stored in `nginx/logs/` (gitignored)
- SSL certificates are stored in `nginx/certbot/conf/` (gitignored)

