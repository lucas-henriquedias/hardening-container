
FROM node:22.12.0-alpine3.21

ENV NODE_ENV=production

WORKDIR /app
COPY --chown=node:node app/package.json ./

RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

COPY --chown=node:node app/ ./
USER node
EXPOSE 3000

CMD ["node", "server.js"]
