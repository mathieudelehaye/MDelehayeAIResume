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

# Build for web using HTML renderer
RUN flutter build web --release --wasm \
    --dart-define=BACKEND_URL=$BACKEND_URL

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the compiled web assets out of the builder image
COPY --from=builder /home/flutter/app/build/web /usr/share/nginx/html

# our nginx template that gets env-substituted at container start-up
COPY default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
