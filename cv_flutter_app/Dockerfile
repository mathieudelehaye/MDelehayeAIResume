# Stage 1: Build the Flutter web app
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -ms /bin/bash flutter
USER flutter
WORKDIR /home/flutter

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git
ENV PATH="/home/flutter/flutter/bin:${PATH}"
RUN flutter doctor
RUN flutter channel stable
RUN flutter upgrade

# Set up web
RUN flutter config --enable-web

# Copy the app files
WORKDIR /home/flutter/app
COPY --chown=flutter:flutter . .

# Get app dependencies
RUN flutter pub get

# Build args for configuration
ARG BACKEND_URL=http://192.168.0.62:8000

# Build for web using HTML renderer
ENV FLUTTER_WEB_RENDERER=html
RUN flutter build web --release \
    --dart-define=BACKEND_URL=$BACKEND_URL \
    --dart-define=FLUTTER_WEB_USE_SKIA=false

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the built Flutter web app
COPY build/web /usr/share/nginx/html

# Copy custom nginx config
COPY default.conf.template /etc/nginx/conf.d/default.conf.template

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 