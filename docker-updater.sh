#!/bin/bash
set -e

VERSION="1"

CONFIG_DIR="$HOME/.config/docker-updater"

MAIL_CONF="$CONFIG_DIR/mail.conf"
COMPOSE_LIST="$CONFIG_DIR/projects.conf"
ALWAYS_SEND_REPORT="$CONFIG_DIR/always_send_report"

if [[ ! -f "$MAIL_CONF" ]]; then
    echo "Error: Configuration file $MAIL_CONF not found."
    exit 1
fi
EMAIL=$(grep -vE '^\s*#|^\s*$' "$MAIL_CONF" | head -n 1)
if [[ -z "$EMAIL" ]]; then
    echo "Error: No valid email found in $MAIL_CONF."
    exit 1
fi

if [[ ! -f "$COMPOSE_LIST" ]]; then
    echo "Error: Configuration file $COMPOSE_LIST not found."
    exit 1
fi

LOGFILE="/tmp/docker-updater.log"

echo "===== docker-updater version $VERSION @ $(hostname) =====" > "$LOGFILE"
echo -e "$(date)\n" >> "$LOGFILE"

UPDATED=false
GLOBALLY_UPDATED=false

while IFS= read -r COMPOSE_PATH; do
    # Ignore empty lines and comments
    [[ -z "$COMPOSE_PATH" || "$COMPOSE_PATH" =~ ^# ]] && continue

    if [ -d "$COMPOSE_PATH" ]; then
        COMPOSE_FILE="$COMPOSE_PATH/docker-compose.yml"
        if [ -f "$COMPOSE_FILE" ]; then
            cd "$COMPOSE_PATH"
        else
            echo "!! docker-compose.yml not found in directory $COMPOSE_PATH, skipping" >> "$LOGFILE"
            continue
        fi
    elif [ -f "$COMPOSE_PATH" ]; then
        COMPOSE_FILE="$COMPOSE_PATH"
        cd "$(dirname "$COMPOSE_FILE")"
    else
        echo "!! $COMPOSE_PATH not found, skipping" >> "$LOGFILE"
        continue
    fi

    IMAGES=$(docker compose -f "$COMPOSE_FILE" config | awk '/image:/ {print $2}')

    STACK_RUNNING=false
    if [ -n "$(docker compose -f "$COMPOSE_FILE" ps -q)" ]; then
        STACK_RUNNING=true
    fi

    UPDATED=false

    for IMAGE in $IMAGES; do
        echo "~~ Checking updates for $IMAGE" >> "$LOGFILE"
        BEFORE=$(docker images --format '{{.Repository}}:{{.Tag}}@{{.Digest}}' | grep "^$IMAGE" || true)
        docker pull "$IMAGE" > /dev/null 2>&1
        AFTER=$(docker images --format '{{.Repository}}:{{.Tag}}@{{.Digest}}' | grep "^$IMAGE" || true)

        if [[ "$BEFORE" != "$AFTER" ]]; then
            echo "!! Image $IMAGE updated" >> "$LOGFILE"
            UPDATED=true
            GLOBALLY_UPDATED=true
        fi
    done

    if [ "$UPDATED" = true ]; then
        if [ "$STACK_RUNNING" = true ]; then
            echo "   Restarting docker-compose in $COMPOSE_FILE..." >> "$LOGFILE"
            docker compose -f "$COMPOSE_FILE" down >> "$LOGFILE" 2>&1
            docker compose -f "$COMPOSE_FILE" up -d >> "$LOGFILE" 2>&1
            echo "   Docker Compose restarted in $COMPOSE_FILE." >> "$LOGFILE"
        else
            echo "   Stack in $COMPOSE_FILE not running, so not restarted" >> "$LOGFILE"
        fi
    fi

done < "$COMPOSE_LIST"

echo -e "\n-> Completed! <-" >> "$LOGFILE"

if [ "$GLOBALLY_UPDATED" = true ]; then
    cat "$LOGFILE" | mail -s "[docker-updater @ $(hostname)] Docker update report - Updates applied" "$EMAIL"
elif [ -f "$ALWAYS_SEND_REPORT" ]; then
    cat "$LOGFILE" | mail -s "[docker-updater @ $(hostname)] Docker update report" "$EMAIL"
fi
