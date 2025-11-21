# FROM: Specifies the base image to build upon
# We use the official Node.js 23 Alpine image (Alpine is a lightweight Linux distribution)
# This provides the Node.js runtime needed to run our Express application
FROM node:23-alpine

# WORKDIR: Sets the working directory inside the container
# All subsequent commands will be executed from this directory
# This keeps our application organized and isolated
WORKDIR /app

# COPY: Copies files from your local machine into the container
# We copy package.json first (before copying all code)
# This is a best practice for layer caching - if dependencies don't change,
# Docker can reuse the cached layer and skip reinstalling node_modules
COPY package.json ./

# RUN: Executes commands inside the container during the build process
# npm install downloads and installs all dependencies listed in package.json
# The --production flag ensures only production dependencies are installed (no dev dependencies)
RUN npm install --production

# COPY: Now we copy the rest of our application code
# This happens AFTER installing dependencies so that code changes don't
# invalidate the dependency cache layer
COPY . .

# EXPOSE: Documents which port the container will listen on at runtime
# This is informational and helps other developers understand the container
# The application listens on port 3000 (defined in server.js)
EXPOSE 3000

# CMD: Specifies the command to run when the container starts
# This starts our Node.js application using the npm start script
# Only one CMD instruction is allowed per Dockerfile (the last one takes effect)
CMD ["npm", "start"]
