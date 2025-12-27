# WordPress Penta - Docker Setup

WordPress 6.9 with MariaDB 11 running in Docker containers.

## Prerequisites

- Docker
- Docker Compose

## Directory Structure

The application uses the following host directories for persistent data:

- `/home/docker/wordpress-penta/data` - WordPress files (themes, plugins, uploads)
- `/home/docker/wordpress-penta/db` - MariaDB database files

These directories will be created automatically when you start the containers.

## Configuration

Create a `.env` file in this directory to customize settings (optional):

```bash
# Database Configuration
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=your_secure_wp_password

# WordPress Port (default: 8080)
WORDPRESS_PORT=8080
```

If you don't create a `.env` file, default values will be used.

## Quick Start

1. Start the containers:
   ```bash
   docker-compose up -d
   ```

2. Access WordPress at `http://localhost:8080` (or your configured port)

3. Complete the WordPress installation wizard

## Managing the Application

### Stop containers
```bash
docker-compose stop
```

### Start containers
```bash
docker-compose start
```

### Restart containers
```bash
docker-compose restart
```

### Stop and remove containers
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f
```

### View logs for specific service
```bash
docker-compose logs -f wordpress
docker-compose logs -f db
```

## Backup

### Database Backup
```bash
docker exec wordpress-penta-db mysqldump -u wordpress -p wordpress > backup.sql
```

### WordPress Files Backup
```bash
tar -czf wordpress-backup.tar.gz /home/docker/wordpress-penta/data
```

## Restore

### Database Restore
```bash
docker exec -i wordpress-penta-db mysql -u wordpress -p wordpress < backup.sql
```

## Security Notes

- Change default passwords in `.env` file before deploying to production
- Consider using a reverse proxy with SSL/TLS for production deployments
- Regularly update Docker images for security patches

## Troubleshooting

### Permission Issues
If you encounter permission issues with the data directories:
```bash
sudo chown -R 33:33 /home/docker/wordpress-penta/data
sudo chown -R 999:999 /home/docker/wordpress-penta/db
```

### Database Connection Issues
Check that the database container is running and healthy:
```bash
docker-compose ps
docker-compose logs db
```