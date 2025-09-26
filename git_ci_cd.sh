# Initialize git
git init

# Create .gitignore file
cat > .gitignore << EOF
# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc
.env
.venv/

# Kubernetes
kubeconfig

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
logs/

# Temporary files
tmp/
temp/
EOF
