"#!/bin/bash
# scripts/frontend_userdata.sh
# Frontend EC2 initialization script

# Update system
yum update -y

# Install nginx
yum install -y nginx

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

# Create a simple index page
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Frontend Server</title>
</head>
<body>
    <h1>Frontend Server Running</h1>
    <p>This is the frontend tier of your 3-tier application</p>
</body>
</html>
EOF

# Configure firewall if needed
# firewall-cmd --permanent --add-service=http
# firewall-cmd --permanent --add-service=https
# firewall-cmd --reload

---

#!/bin/bash
# scripts/backend_userdata.sh
# Backend EC2 initialization script

# Update system
yum update -y

# Install Node.js (optional - replace with your backend runtime)
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install MySQL client to test database connection
yum install -y mysql

# Create a simple health check script
mkdir -p /opt/backend
cat > /opt/backend/health.sh <<EOF
#!/bin/bash
echo "Backend server is healthy"
EOF
chmod +x /opt/backend/health.sh

# Install Git (for deploying code)
yum install -y git

echo "Backend server initialization complete""