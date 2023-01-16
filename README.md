# Zero-Config Nextcloud Instance

This is a "single click" out-of-the-box solution for local network.

## Installation

  1.  Mount your big storage at `/mnt/data`.
  2.  Build and run:
      ```bash
      $ sudo docker compose up -d
      ```
  3. Open in browser http://localhost:8080/, log in with user 'admin', password 'admin'.

## Configuration

### Security

Since the installation is aimed at trusted local networks, the safety (and complexity) of the setup is reduced.

  * Only HTTP transport is enabled. Use VPN for remote access.
  * The default admin user is "admin" with password "admin".

### Storage

  * A data storage (could be a RAID drive) is supposed to be mounted at `/mnt/data`.
  * The "external" data path is `/mnt/data/data/`. This is for storing all of your data. \
    Feel free to put and remove files there locally or over SMB.
    This location gets regularly reindexed by Nextcloud.
  * All Nextcloud-related files are at `/mnt/data/nextcloud/`. This includes:
    * `/mnt/data/nextcloud/log` for container's system logs.
    * `/mnt/data/nextcloud/mysql` for mysql database.
    * `/mnt/data/nextcloud/datadir` for all user files.

### Apps

  * The list of default apps is in Dockerfile on `app:install` lines.
  * Whatever apps are installed, they don't persist across the container restart.\
To add apps persistence, add a volume for `/var/www/nextcloud/apps`.\
Apps settings however are saved in the database and will outlive restarts.
  * `/var/www/nextcloud/config/config.php` is not persistent either.

## Uninstallation

```bash
### Stop docker
$ sudo docker compose down -d

### Clean up Docker
$ sudo docker kill nextcloud-local
$ sudo docker system prune -a --volumes -f   # WARNING! This also removes local cache and all stopped containers!
$ sudo docker volume rm -f nextcloud_nextcloud-datadir nextcloud_nextcloud-log nextcloud_nextcloud-mysql

### Remove nextcloud files and configuration
$ sudo rm -rf /mnt/data/nextcloud
```

## TODO

  * Configurable Dockerfile.
  * Optional Elasticsearch.
  * Optional apps.

## Links

  * Nextcloud
    * https://github.com/nextcloud/all-in-one \
      This unfortunately doesn't support a local network installation.
      It requires a global domain and internet access.
    * https://docs.nextcloud.com/server/latest/admin_manual/installation/example_ubuntu.html
    * https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html#apache-configuration-label
    * https://docs.nextcloud.com/server/latest/admin_manual/installation/command_line_installation.html
    * https://docs.nextcloud.com/server/latest/admin_manual/office/example-docker.html
  * Elasticsearch
    * https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html
    * https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
    * https://github.com/nextcloud/vm/blob/master/apps/fulltextsearch.sh
