# Safe Whisper Backend - Docker Hub Deployment Guide

This guide will help you deploy your Safe Whisper backend to Docker Hub as a private repository.

## Prerequisites

1. **Docker Desktop** installed and running
2. **Docker Hub account** (free tier supports 1 private repository)
3. **Terminal/Command Line** access

## Quick Deployment

### Step 1: Deploy to Docker Hub

```bash
# Navigate to your project directory
cd /Users/sousavf/Documents/secure-message

# Run the deployment script
./deploy-to-dockerhub.sh v1.0 sousavf
```

The script will:
- ✅ Build your Docker image
- ✅ Push to Docker Hub
- ✅ Create production configuration files
- ✅ Provide deployment instructions

### Step 2: Make Repository Private

1. Go to [Docker Hub](https://hub.docker.com)
2. Navigate to your repository: `https://hub.docker.com/repository/docker/sousavf/safe-whisper-backend`
3. Click the **"Settings"** tab
4. Change **Visibility** from "Public" to **"Private"**
5. Click **"Update"**

## Production Deployment

### Option 1: Direct Docker Run

```bash
# Login to Docker Hub on your production server
docker login

# Pull and run your private image
docker run -d \
  --name safe-whisper-backend \
  -p 8080:8080 \
  -e SPRING_DATASOURCE_URL="jdbc:postgresql://your-db-host:5432/safe_whisper" \
  -e DB_USERNAME="your_db_user" \
  -e DB_PASSWORD="your_db_password" \
  sousavf/safe-whisper-backend:latest
```

### Option 2: Docker Compose (Recommended)

1. **Copy files to your server:**
   ```bash
   scp docker-compose.prod.yml your-server:/path/to/deployment/
   scp .env.prod.example your-server:/path/to/deployment/
   ```

2. **Configure environment:**
   ```bash
   # On your server
   cp .env.prod.example .env.prod
   # Edit .env.prod with your actual values
   nano .env.prod
   ```

3. **Deploy:**
   ```bash
   # Login to Docker Hub
   docker login

   # Start services
   docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
   ```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_NAME` | Database name | `safe_whisper` |
| `DB_USER` | Database username | `safe_user` |
| `DB_PASSWORD` | Database password | `your_secure_password` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BACKEND_PORT` | Port to expose backend | `8080` |
| `REQUIRE_SSL` | Enable HTTPS requirement | `false` |
| `CORS_ORIGIN_1` | Allowed CORS origin 1 | `http://localhost:3000` |
| `CORS_ORIGIN_2` | Allowed CORS origin 2 | `https://localhost:3000` |

## Cloud Platform Deployment

### AWS ECS/Fargate

```yaml
# task-definition.json
{
  "family": "safe-whisper-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "safe-whisper-backend",
      "image": "sousavf/safe-whisper-backend:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "SPRING_DATASOURCE_URL", "value": "jdbc:postgresql://your-rds-endpoint:5432/safe_whisper"},
        {"name": "DB_USERNAME", "value": "your_db_user"},
        {"name": "DB_PASSWORD", "value": "your_db_password"}
      ]
    }
  ]
}
```

### Google Cloud Run

```bash
# Deploy to Cloud Run
gcloud run deploy safe-whisper-backend \
  --image sousavf/safe-whisper-backend:latest \
  --platform managed \
  --region us-central1 \
  --set-env-vars SPRING_DATASOURCE_URL="jdbc:postgresql://your-cloud-sql-ip:5432/safe_whisper" \
  --set-env-vars DB_USERNAME="your_db_user" \
  --set-env-vars DB_PASSWORD="your_db_password" \
  --port 8080
```

### Azure Container Instances

```bash
# Deploy to Azure Container Instances
az container create \
  --resource-group myResourceGroup \
  --name safe-whisper-backend \
  --image sousavf/safe-whisper-backend:latest \
  --registry-login-server index.docker.io \
  --registry-username sousavf \
  --registry-password your-docker-hub-password \
  --dns-name-label safe-whisper \
  --ports 8080 \
  --environment-variables \
    SPRING_DATASOURCE_URL="jdbc:postgresql://your-db-host:5432/safe_whisper" \
    DB_USERNAME="your_db_user" \
    DB_PASSWORD="your_db_password"
```

## Updating Your Deployment

```bash
# Build and push new version
./deploy-to-dockerhub.sh v1.1 sousavf

# Update production (docker-compose)
docker-compose -f docker-compose.prod.yml pull backend
docker-compose -f docker-compose.prod.yml up -d backend

# Or update production (direct docker)
docker pull sousavf/safe-whisper-backend:latest
docker stop safe-whisper-backend
docker rm safe-whisper-backend
# Run new container with same parameters
```

## Security Considerations

### 1. Database Security
- Use strong, unique database passwords
- Configure database firewall rules
- Enable SSL/TLS for database connections

### 2. Application Security
- Set `REQUIRE_SSL=true` in production
- Use environment variables for sensitive data
- Regularly update the Docker image

### 3. Network Security
- Use private networks where possible
- Configure proper CORS origins
- Implement reverse proxy (nginx/Apache) for HTTPS termination

## Monitoring & Logs

### View Logs
```bash
# Docker Compose
docker-compose -f docker-compose.prod.yml logs backend -f

# Direct Docker
docker logs safe-whisper-backend -f
```

### Health Checks
Your backend includes built-in health checks:
- **Health Endpoint:** `http://your-server:8080/actuator/health`
- **Docker Health Check:** Automatic container health monitoring

## Troubleshooting

### Common Issues

1. **"Image not found" error:**
   - Ensure you're logged in: `docker login`
   - Verify image name: `docker images | grep safe-whisper`

2. **Database connection issues:**
   - Check database host/port accessibility
   - Verify credentials in environment variables
   - Ensure database is running and accepting connections

3. **Permission denied:**
   - Check Docker Hub repository privacy settings
   - Verify Docker Hub credentials

### Support Commands

```bash
# Check container status
docker ps

# Inspect container configuration
docker inspect safe-whisper-backend

# Check Docker Hub repositories
docker search sousavf/safe-whisper-backend

# Test database connection
docker exec -it safe-whisper-backend curl http://localhost:8080/actuator/health
```

## Costs & Limits

### Docker Hub Free Tier
- ✅ 1 private repository (perfect for this project)
- ✅ Unlimited public repositories
- ✅ Up to 200 container pulls per 6 hours

### Upgrade if Needed
- **Pro Plan ($5/month):** 5 private repositories
- **Team Plan ($25/month):** Unlimited private repositories

---

## Quick Reference

### Deploy Command
```bash
./deploy-to-dockerhub.sh v1.0 sousavf
```

### Production Start
```bash
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

### Update Image
```bash
docker-compose -f docker-compose.prod.yml pull backend
docker-compose -f docker-compose.prod.yml up -d backend
```

---

**🎉 Your Safe Whisper backend is now ready for private deployment on Docker Hub!**