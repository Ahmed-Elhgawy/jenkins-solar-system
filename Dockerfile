FROM node:18-alpine3.17

WORKDIR /usr/app

COPY package*.json /usr/app/

RUN npm install

COPY . .

ENV MONGO_URI=mongodb://54.162.38.232
ENV MONGO_USERNAME=mongoadmin
ENV MONGO_PASSWORD=mongo-password

EXPOSE 5000

CMD [ "npm", "start" ]