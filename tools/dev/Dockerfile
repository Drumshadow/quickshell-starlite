# Development container for quickshell-starlite.
#
# Matches the TARGET (Fedora 44) so API differences found here are real target
# differences. Runs a headless wlroots compositor, so the shell renders and can
# be screenshotted with no display, over SSH, without touching the host session.
FROM fedora:44

RUN dnf -y install --setopt=install_weak_deps=False \
      quickshell \
      sway grim wl-clipboard \
      mesa-dri-drivers mesa-libEGL mesa-libGL \
      qt6-qtbase qt6-qtdeclarative qt6-qtwayland qt6-qtsvg \
      google-noto-sans-fonts google-noto-sans-mono-fonts \
      procps-ng findutils jq wtype \
 && dnf clean all

# Fedora ships sway with cap_sys_nice=ep. Docker strips file capabilities, and
# the kernel then refuses to exec the binary at all ("Operation not permitted").
# cp does not preserve file caps, so a plain copy is a capability-free sway —
# and headless sway has no use for realtime scheduling anyway. This avoids
# needing --privileged.
RUN cp /usr/sbin/sway /usr/local/bin/sway-headless && chmod 0755 /usr/local/bin/sway-headless

COPY sway.conf /etc/sway-headless.conf

ENV LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    WLR_HEADLESS_OUTPUTS=1 \
    XDG_RUNTIME_DIR=/tmp/xdg \
    QT_QPA_PLATFORM=wayland

RUN mkdir -p /tmp/xdg && chmod 700 /tmp/xdg
# A launchable app that leaves evidence, so "the application actually started"
# can be asserted rather than eyeballed.
RUN mkdir -p /usr/share/applications && \
    printf '[Desktop Entry]\nType=Application\nName=SliceProbe\nExec=/usr/local/bin/slice-probe\nTerminal=false\n' \
      > /usr/share/applications/slice-probe.desktop && \
    printf '#!/bin/sh\ndate -Is > /tmp/slice-launched\nsleep 30\n' > /usr/local/bin/slice-probe && \
    chmod +x /usr/local/bin/slice-probe

WORKDIR /shell
