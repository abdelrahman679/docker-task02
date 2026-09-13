# syntax=docker/dockerfile:1.4

FROM node:lts

ENV CI=true
ENV PORT=3000

WORKDIR /code

COPY package.json package-lock.json ./
COPY .npmrc ./
COPY .yarnrc.yml ./

RUN npm ci

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
