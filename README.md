# MagicVilla Dockerized .NET Application

This project showcases a containerised architecture for a .NET 7 API application, utilising Docker Compose for orchestration and NGINX as a reverse proxy.

## Architecture Overview

The application consists of two main services that work together to provide a robust, scalable web API:

- **magicvilla**: The .NET 7 Web API application
- **nginx**: Reverse proxy server acting as the single entry point

## How It Works

### Service Communication Flow

1. Client sends an HTTP request to `localhost:3000`
2. NGINX receives the request on port 80 (mapped from host port 3000)
3. NGINX forwards the request to `http://magicvilla:8080` via the internal Docker network
4. The .NET application processes the request and returns a response
5. NGINX receives the response and sends it back to the client

### Docker Compose Configuration

The `docker-compose.yml` file orchestrates two services connected via a custom bridge network named `appnet`.

#### MagicVilla Service

```yaml
magicvilla:
  build: .
  container_name: magicvilla
  ports:
    - "8080"
  networks:
    - appnet
```

- **build**: Builds the Docker image from the Dockerfile in the current directory
- **container_name**: Names the container `magicvilla` for easy reference
- **ports**: Exposes port 8080 internally (not published to host machine)
- **networks**: Connects to the `appnet` network for inter-container communication

#### NGINX Service

```yaml
nginx:
  image: nginx:latest
  container_name: nginx
  ports:
    - "3000:80"
  volumes:
    - ./default.conf:/etc/nginx/conf.d/default.conf:ro
  depends_on:
    - magicvilla
  networks:
    - appnet
```

- **image**: Uses the official NGINX image from Docker Hub
- **ports**: Maps host port 3000 to container port 80 (the only externally accessible port)
- **volumes**: Mounts custom NGINX configuration as read-only
- **depends_on**: Ensures the magicvilla service starts before NGINX
- **networks**: Connects to the same `appnet` network

### Dockerfile Explanation

The Dockerfile uses a multi-stage build approach for optimisation:

#### Stage 1: Build (SDK Image)

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish
```

- Uses the full .NET SDK image for building
- Copies project file first and restores dependencies (leverages Docker layer caching)
- Copies remaining source code
- Publishes the application in Release configuration

#### Stage 2: Runtime (Optimised Image)

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_ENVIRONMENT="Development"
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENTRYPOINT ["dotnet", "MagicVilla_VillaAPI.dll"]
```

- Uses the lightweight ASP.NET runtime image (smaller than SDK)
- Copies only the published output from the build stage
- Exposes port 8080 for documentation (actual binding is done via environment variable)
- Configures ASP.NET Core to listen on all interfaces (`0.0.0.0:8080`)
- Sets the entry point to run the compiled DLL

### NGINX Configuration

The `default.conf` file configures NGINX as a reverse proxy:

```nginx
server {
    listen 80;
    location / {
        proxy_pass         http://magicvilla:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

- **listen 80**: NGINX listens on port 80 inside its container
- **proxy_pass**: Forwards all requests to the magicvilla service on port 8080
- **proxy_http_version 1.1**: Uses HTTP/1.1 for upstream connections
- **proxy_set_header**: Preserves original client information in headers for the backend application

## Networking Strategy

The `appnet` custom bridge network enables:

- **Service discovery**: Containers can reference each other by service name (e.g., `magicvilla`)
- **Isolation**: Application traffic is isolated from other Docker networks
- **Security**: The .NET application is not directly accessible from the host; only NGINX is exposed

## Benefits of This Architecture

1. **Single Entry Point**: All traffic goes through NGINX, providing a consistent gateway
2. **Security**: The backend application is not directly exposed to the host network
3. **Scalability**: NGINX can load balance across multiple magicvilla instances
4. **Flexibility**: NGINX can serve static files, handle SSL/TLS termination, or implement rate limiting
5. **Optimised Images**: Multi-stage build reduces final image size significantly
6. **Production-Ready**: Separates concerns between web server and application server

## Running the Application

```bash
# Start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the application
docker-compose down
```

Access the application at `http://localhost:3000`

## Port Summary

- **Host Port 3000** → NGINX Container Port 80 → MagicVilla Container Port 8080
- Only port 3000 is accessible from outside Docker
- Internal communication happens via the `appnet` network using container names
