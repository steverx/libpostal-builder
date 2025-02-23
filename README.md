# libpostal-builder

Pre-builds libpostal library and serves artifacts via nginx.

## Local Development

```bash
# Build the Docker image
docker build -t libpostal-builder .

# Run the container
docker run -p 80:80 libpostal-builder

# Test the artifacts
curl http://localhost/libpostal-artifacts.tar.gz -o test.tar.gz
```

## Railway Deployment

```bash
# Deploy to Railway
railway up
```
