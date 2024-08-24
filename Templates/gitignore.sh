echo "Creating .gitignore"
cat << 'EOF' > $(dirname "$0")/.gitignore
.gitignore
.env
docker-compose.yml
docker-compose.override.yml
aspnet_image_directory/prometheus-net
EOF
