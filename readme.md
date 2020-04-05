# docker-postgres

[![Docker Automated build](https://img.shields.io/docker/cloud/automated/tinslice/postgres.svg?style=flat)](https://hub.docker.com/r/tinslice/postgres/builds)
[![Docker Build Status](https://img.shields.io/docker/cloud/build/tinslice/postgres.svg?style=flat)](https://hub.docker.com/r/tinslice/postgres/builds)
[![Docker Pulls](https://img.shields.io/docker/pulls/tinslice/postgres.svg?style=flat)](https://hub.docker.com/r/tinslice/postgres/)
[![license](https://img.shields.io/github/license/tinslice/docker-postgres.svg)](https://github.com/tinslice/docker-postgres)

Postgresql docker image with database configuration based on environment variables.

## Usage

### Change Postgres default configuration.

To overwrite the Postgres default configuration you need to mount the folder containing the custom Postgres config to `/etc/postgresql/<pg-version>/main/conf.d`.

### Run scripts to initialise database

- `/etc/postgresql/scripts` Location of custom defined scripts that the user can execute through environment variables.

### Environment variables

- `POSTGRES_PASSWORD` set the password for the postgresql user
- `POSTGRES_ROLES` postgres group roles. Example config:

    ```json
    [
      {
        "name": "role_ts_admin",
        "privileges": "NOINHERIT"
      },
      {
        "name": "role_ts_write",
        "privileges": "INHERIT"
      },
      {
        "name": "role_ts_read"
      }
    ]
    ```

- `POSTGRES_USERS` postgres users (roles). Example config:

    ```json
    [
      {
        "name": "ts_admin",
        "password": "changeit",
        "roles": ["role_ts_admin"]
      },
      {
        "name": "ts_owner",
        "password": "changeit"
      },
      {
        "name": "ts_read",
        "password": "changeit_read_only",
        "roles": ["role_ts_read"]
      },
      {
        "name": "ts_test_user",
        "password": "changeit"
      }        
    ]
    ```

- `POSTGRES_DB` configuration for auto creation of databases and user access. It also allows the posibillity to run scripts once, when the database is created. Example config:

    ```json
    {
      "ts_demo": {
        "roles": [
          {
            "name": "ts_owner",
            "owner": "true"
          },
          {
            "name": "ts_test_user",
            "privileges": "ALL"
          },
          {
            "name": "role_ts_admin",
            "schemas": [
              { "name": "public", "privileges": "ALL" }
            ]
          },
          {
            "name": "role_ts_write",
            "schemas": [
              { "name": "public", "privileges": "SELECT,INSERT,UPDATE,DELETE,EXECUTE" }
            ]
          },
          {
            "name": "role_ts_read",
            "schemas": [
              {
                "name": "public",
                "tables": [
                  { "name": "*", "privileges": "SELECT" }
                ],
                "sequences": [
                  { "name": "*", "privileges": "SELECT" }
                ],
                "functions": [
                  { "name": "*", "privileges": "EXECUTE" }
                ]
              }
            ]
          }
        ],
        "init": ["init_db"]
      }
    }
    ```

- `POSTGRES_RUN_SCRIPTS` run scripts on specific databases each time the container starts. The script can be run as postgres or as specific user by specifying the sql file in the following format: `<db-role>:<sql-file>`. Example config:

    ```json
    {
      "ts_demo": [ "ts_owner:run_at_start" ]
    }
    ```

- `POSTGRES_RUN_SQL` run sql statements on specific databases each time the container starts. Example config:

    ```json
    {
      "postgres": [

      ],
      "ts_demo": [
        "delete from public._marker_test;",
        "insert into public._marker_test values(''ts_demo'');"
      ]
    }
    ```

Complete examples can be found in the [example](./example) folder.

