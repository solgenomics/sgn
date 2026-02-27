# Keycloak

1. Build and push the docker image.

   ```bash
   docker build -t <DOCKERHUB NAME>/keycloak:26.5.1-0-breedbase-testing .
   docker push <DOCKERHUB NAME>/keycloak:26.5.1-0-breedbase-testing
   ```

2. Update the image in: `.github/workflows/test.yml`

   ```yaml
   keycloak:
     image: <DOCKERHUB NAME>/keycloak:26.5.1-0-breedbase-testing
   ```
