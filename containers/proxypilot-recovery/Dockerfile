FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed python gopass

WORKDIR /workspace

COPY scripts/proxypilot_recover.py /usr/local/bin/proxypilot_recover.py

ENTRYPOINT ["python3", "/usr/local/bin/proxypilot_recover.py"]
