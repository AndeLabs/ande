# Use a lightweight Node.js image
FROM node:20-alpine

# Set the working directory in the container
WORKDIR /app

# Copy dependency definition files
# A package-lock.json file is expected to exist for reproducible builds.
COPY package.json package-lock.json ./

# Install dependencies using the lockfile. `npm ci` is faster and safer for automated environments.
RUN npm ci

# Copy the rest of the application code
COPY . .

# The default command to run when the container starts
CMD ["npm", "run", "test"]
