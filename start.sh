#!/bin/bash
set -e

# Start D-Bus system bus
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Wait for VNC to initialize
sleep 2

# Start all services with Supervisor (systemd replacement)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
