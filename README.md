# Skeleton server builder

An Angular application using Sinatra Restful-API skeleton.

## Build with [Docker](https://www.docker.com)

Build `Debian` package:

    $ docker-compose up -d builder

Build `Alpine` package:

    $ docker-compose up -d apk-builder

Build `Ubuntu` package:

    $ docker-compose up -d deb-builder

### Notes

- View the build logs: `docker-compose logs`
- Shutdown the Docker containers: `docker-compose down`

## License

The skeleton is available as open source under the terms of the [MIT License](LICENSE).
