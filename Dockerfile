FROM debian:bookworm-slim

# Install all dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wine-stable qemu-system-x86 qemu-utils \
    fonts-wqy-zenhei xz-utils dbus-x11 curl firefox-esr \
    gnome-system-monitor mate-system-monitor git \
    xfce4 xfce4-terminal tigervnc-standalone-server \
    wget supervisor dumb-init procps iproute2 net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup noVNC v1.4.0
RUN cd /tmp && \
    wget https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz && \
    tar -xzf v1.4.0.tar.gz && \
    mv noVNC-1.4.0 /opt/noVNC && \
    rm v1.4.0.tar.gz && \
    cd /opt/noVNC && \
    wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz | tar -xzf - && \
    mv websockify-0.11.0 utils/websockify

# Create vncuser and setup VNC
RUN useradd -m -s /bin/bash vncuser && \
    mkdir -p /home/vncuser/.vnc && \
    echo 'admin123' | vncpasswd -f > /home/vncuser/.vnc/passwd && \
    chmod 600 /home/vncuser/.vnc/passwd && \
    chown -R vncuser:vncuser /home/vncuser/.vnc && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# VNC xstartup script
RUN echo '#!/bin/bash
\
export XDG_RUNTIME_DIR=/tmp/runtime-vncuser
\
mkdir -p $XDG_RUNTIME_DIR
\
chmod 700 $XDG_RUNTIME_DIR
\
unset SESSION_MANAGER
\
unset DBUS_SESSION_BUS_ADDRESS
\
[ -r /etc/profile ] && . /etc/profile
\
[ -r ~/.profile ] && . ~/.profile
\
dbus-launch --exit-with-session xfce4-session' \
> /home/vncuser/.vnc/xstartup && \
    chmod +x /home/vncuser/.vnc/xstartup && \
    chown vncuser:vncuser /home/vncuser/.vnc/xstartup

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Supervisor config for reliable process management
RUN cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log

[program:dbus]
command=dbus-daemon --system --fork
autostart=true
autorestart=true
priority=100

[program:vncserver]
command=su - vncuser -c "vncserver :1 -geometry 1360x768 -depth 24 -localhost no"
autostart=true
autorestart=true
priority=200
stderr_logfile=/var/log/vncserver.err.log
stdout_logfile=/var/log/vncserver.out.log

[program:novnc]
command=/opt/noVNC/utils/launch.sh --vnc localhost:5901 --listen 0.0.0.0:7900
autostart=true
autorestart=true
priority=300
stderr_logfile=/var/log/novnc.err.log
stdout_logfile=/var/log/novnc.out.log
EOF

EXPOSE 7900
CMD ["/start.sh"]
