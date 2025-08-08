#!/bin/bash

# User data script for application instances
# This script installs and configures the application

set -e

# Update system
yum update -y

# Install required packages
yum install -y \
    httpd \
    php \
    php-pgsql \
    postgresql \
    git \
    unzip \
    wget

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure Apache to listen on port 8080
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

# Create application directory
mkdir -p /var/www/html/app

# Create a simple health check endpoint
cat > /var/www/html/health << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'healthy', 'timestamp' => date('c')]);
?>
EOF

# Create a simple application
cat > /var/www/html/app/index.php << 'EOF'
<?php
header('Content-Type: text/html');

$db_host = '${db_host}';
$db_name = '${db_name}';
$db_user = '${db_user}';
$db_pass = '${db_password}';

try {
    $pdo = new PDO("pgsql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create table if it doesn't exist
    $pdo->exec("CREATE TABLE IF NOT EXISTS visits (
        id SERIAL PRIMARY KEY,
        ip_address VARCHAR(45),
        user_agent TEXT,
        visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Insert visit record
    $stmt = $pdo->prepare("INSERT INTO visits (ip_address, user_agent) VALUES (?, ?)");
    $stmt->execute([$_SERVER['REMOTE_ADDR'], $_SERVER['HTTP_USER_AGENT']]);
    
    // Get visit count
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM visits");
    $count = $stmt->fetch()['count'];
    
    echo "<h1>Welcome to Multi-Tier Application</h1>";
    echo "<p>This is a simple web application running on AWS with:</p>";
    echo "<ul>";
    echo "<li>Application Load Balancer</li>";
    echo "<li>Auto Scaling Group</li>";
    echo "<li>RDS PostgreSQL Database</li>";
    echo "<li>VPC with public and private subnets</li>";
    echo "</ul>";
    echo "<p><strong>Total visits: $count</strong></p>";
    echo "<p><em>Instance ID: " . gethostname() . "</em></p>";
    
} catch (PDOException $e) {
    echo "<h1>Database Connection Error</h1>";
    echo "<p>Error: " . $e->getMessage() . "</p>";
}
?>
EOF

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache
systemctl restart httpd

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/multi-tier-app/application",
                        "log_stream_name": "{instance_id}/access.log",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/aws/ec2/multi-tier-app/application",
                        "log_stream_name": "{instance_id}/error.log",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create a simple monitoring script
cat > /usr/local/bin/monitor.sh << 'EOF'
#!/bin/bash

# Simple monitoring script
while true; do
    # Check Apache status
    if ! systemctl is-active --quiet httpd; then
        echo "$(date): Apache is down, restarting..."
        systemctl restart httpd
    fi
    
    # Check disk usage
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        echo "$(date): Disk usage is high: ${DISK_USAGE}%"
    fi
    
    sleep 60
done
EOF

chmod +x /usr/local/bin/monitor.sh

# Start monitoring in background
nohup /usr/local/bin/monitor.sh > /var/log/monitor.log 2>&1 &

echo "Application setup completed successfully!" 