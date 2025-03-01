# docker-updater

This script operates on the Docker Compose containers specified in the configuration file, pulling the latest updates for the container images in the stack. If any updates are found, it **restarts the entire Docker Compose stack** to apply the changes.

Additionally, it logs the process and sends an email notification when a restart occurs.

## Prerequisites

- Docker and Docker Compose installed on your system
- A working mail service for email notifications and, on Debian-based systems, the `mailutils` package installed

## Installation

1. Clone or download the script

1. Create the required configuration files, see "Configuration" below

1. Add a cron job to run the script automatically for example:
```sh
0 9 * * * /home/user/docker-updater/docker-updater.sh
```

## Configuration

The script uses the following configuration files:

### `$HOME/.config/docker-updater/projects.conf` **(required)**

This file contains either the absolute path of the directories containing the `docker-compose.yml` files, or the absolute paths of the `docker-compose.yml` files themselves, one per line.

Lines starting with `#` and empty lines are ignored.

### `$HOME/.config/docker-updater/mail.conf` **(required)**

This file contains a single email address to which email notifications will be sent.

Lines starting with `#` and empty lines are ignored.

### `$HOME/.config/docker-updater/always_send_report` **(optional)**

If present, the mail report is always sent, even if there were no updates. The content of the file is ignored.


## License

This project is licensed under the MIT License.
