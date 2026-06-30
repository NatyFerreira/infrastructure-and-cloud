# Image de base: Node.js 18 sur Alpine Linux (légère, ARM64 compatible)
FROM node:18-alpine

# Métadonnée: auteur de l'image
LABEL maintainer="NatyFerreira"

# Répertoire de travail dans le container
WORKDIR /app

# Copier package.json en premier pour optimiser le cache Docker
# Si package.json ne change pas, Docker réutilise la couche npm install
COPY package.json .
COPY app.js .
COPY .env .

# Installer les dépendances (exécuté au build, pas au runtime)
RUN npm install

# Variable d'environnement: port d'écoute de l'application
ENV PORT=3000

# Documenter le port exposé
EXPOSE 3000

# Commande exécutée au démarrage du container
CMD ["npm", "start"]