# Usage examples

## docker-compose example

Structure

```yaml
# folder containing configuration files
config
  # postgres config
  conf.d
  # sql scripts
  scripts
# docker-compose env variables
.env
```

To start the Postgres server run `docker-compose up` (or `docker-compose up -d` to run in detach mode).

TO stop the server run `docker-compose down`.

