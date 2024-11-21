###############
### STAGE 1: Build app
###############
ARG BUILDER_IMAGE=node:19-alpine
ARG NGINX_IMAGE=nginx:1.19.3

FROM $BUILDER_IMAGE as builder
ARG NPM_REGISTRY_URL=https://registry.npmjs.org/
ARG BUILD_ENVIRONMENT_OPTIONS="--configuration production"
ARG PUPPETEER_DOWNLOAD_HOST_ARG=https://storage.googleapis.com
ARG PUPPETEER_CHROMIUM_REVISION_ARG=1011831
ARG PUPPETEER_SKIP_DOWNLOAD_ARG

# Set the environment variable to increase Node.js memory limit
ENV NODE_OPTIONS="--max-old-space-size=8192"

RUN apk add --no-cache git python3 make g++

WORKDIR /usr/src/app

ENV PATH /usr/src/app/node_modules/.bin:$PATH

# Export Puppeteer env variables for installation with non-default registry.
ENV PUPPETEER_DOWNLOAD_HOST $PUPPETEER_DOWNLOAD_HOST_ARG
ENV PUPPETEER_CHROMIUM_REVISION $PUPPETEER_CHROMIUM_REVISION_ARG
ENV PUPPETEER_SKIP_DOWNLOAD $PUPPETEER_SKIP_DOWNLOAD_ARG

# Copy package files first for better caching
COPY package*.json ./

RUN npm config set fetch-retry-maxtimeout 120000 \
    && npm config set registry $NPM_REGISTRY_URL --location=global

RUN npm install --location=global @angular/cli@14.2.12

# Install dependencies with legacy peer deps for compatibility
RUN npm install --legacy-peer-deps

# Copy the rest of the application
COPY ./ /usr/src/app/

# Build with specific flags for better stability
RUN ng build --output-path=/dist $BUILD_ENVIRONMENT_OPTIONS \
    --progress false \
    --stats-json false

###############
### STAGE 2: Serve app with nginx ###
###############
FROM $NGINX_IMAGE

COPY --from=builder /dist /usr/share/nginx/html

EXPOSE 80

# When the container starts, replace the env.js with values from environment variables
CMD ["/bin/sh",  "-c",  "envsubst < /usr/share/nginx/html/assets/env.template.js > /usr/share/nginx/html/assets/env.js && exec nginx -g 'daemon off;'"]
