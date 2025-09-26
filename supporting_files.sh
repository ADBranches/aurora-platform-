# Create a simple package.json for Node.js service
cat > services/api-gateway/package.json << 'EOF'
{
  "name": "api-gateway",
  "version": "1.0.0",
  "description": "Aurora API Gateway",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo 'Tests would run here'"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

# Create a simple Node.js app
cat > services/api-gateway/index.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Aurora API Gateway is running!');
});

app.listen(port, () => {
  console.log(`API Gateway listening on port ${port}`);
});
EOF

# Create a Python service example
mkdir -p services/auth-service
cat > services/auth-service/requirements.txt << 'EOF'
flask==2.3.0
python-dotenv==1.0.0
EOF

cat > services/auth-service/app.py << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return 'Auth Service is running!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF
