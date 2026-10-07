#=============================================================
# Build Stage for dependency 
#=============================================================
FROM node:20-alpine AS build 
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

#=============================================================
# Production Stage
#=============================================================
FROM node:20-alpine AS production 

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Security: remove unnecessary packages
RUN apk --no-cache add dumb-init

WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY src ./src/

# Security: own files by non-root user
RUN chown -R appuser:appgroup /app

USER appuser 

EXPOSE 5000

# Security: use dumb-init for proper signal handling (PID 1 problem)
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]