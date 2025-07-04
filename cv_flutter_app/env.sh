#!/bin/sh

# Create runtime environment configuration
cat > /usr/share/nginx/html/assets/config/env.js <<EOF
window.env = {
  'BACKEND_URL': ''
};
EOF