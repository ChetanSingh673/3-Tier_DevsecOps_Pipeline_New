#=======================================================================
#Build Stage
#=======================================================================
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci && npm cache clean --force
COPY . .
RUN npm run build 

#========================================================================
# Production Stage
#========================================================================
FROM nginx:1.27-alpine AS production

# Security: remove default nginx config
RUN rm -rf /etc/nginx/conf.d/default.conf  /usr/share/nginx/html/*

# Copy custum nginx config 
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled frontend from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Security: run nginx as non-root
RUN chown nginx:nginx /usr/share/nginx/html && \
    chown nginx:nginx /var/cache/nginx && \
    chown nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid 

USER nginx

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]