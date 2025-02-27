# Simplified Build Script
$arch = "amd64"  # Change to "arm64" if needed

Write-Host "Building $arch version..."
if ($arch -eq "amd64") {
    docker buildx build --platform linux/amd64 -f Dockerfile.amd64 -t steverx/libpostal-builder:latest --push --progress=plain .
} else {
    docker buildx build --platform linux/arm64 -f Dockerfile.arm64 -t steverx/libpostal-builder:latest --push --progress=plain .
}

Write-Host "Build process completed."