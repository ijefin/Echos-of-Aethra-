# Servidor dedicado do Ecos de Aethra (protótipo 3D) — Godot 4.7.2 headless, ENet UDP.
# Build (na raiz do repositório):  docker build -f server/Dockerfile -t aethra-server .
# O contexto é filtrado por server/Dockerfile.dockerignore (só os scripts do servidor entram).
FROM debian:trixie-slim

ARG GODOT_VERSION=4.7.2
# SHA-512 do zip oficial (linha "Godot_v4.7.2-stable_linux.x86_64.zip" do SHA512-SUMS.txt da release).
# Vazio = não confere (preencha antes de publicar).
ARG GODOT_SHA512=""

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" && if [ -n "$GODOT_SHA512" ]; then echo "$GODOT_SHA512  /tmp/godot.zip" | sha512sum -c -; fi && unzip -q /tmp/godot.zip -d /opt/godot && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm -rf /tmp/godot.zip /opt/godot

RUN useradd --system --create-home --home-dir /home/aethra --uid 10001 aethra && mkdir -p /data && chown aethra:aethra /data

WORKDIR /app
COPY project.godot /app/project.godot
COPY prototypes/pixel3d/first_adventure_state.gd /app/prototypes/pixel3d/first_adventure_state.gd
COPY prototypes/pixel3d/data/first_adventure.json /app/prototypes/pixel3d/data/first_adventure.json
COPY prototypes/pixel3d/data/classes.json /app/prototypes/pixel3d/data/classes.json
COPY prototypes/pixel3d/data/core_skills.json /app/prototypes/pixel3d/data/core_skills.json
COPY prototypes/pixel3d/ai/ /app/prototypes/pixel3d/ai/
COPY prototypes/pixel3d/net/ /app/prototypes/pixel3d/net/
RUN chown -R aethra:aethra /app

USER aethra
ENV AETHRA_PORT=7777 AETHRA_DATA_DIR=/data AETHRA_LOG_LEVEL=info XDG_DATA_HOME=/data/.godot-user
VOLUME ["/data"]
EXPOSE 7777/udp

# Primeira execução importa o projeto (só scripts); depois sobe o servidor.
CMD ["godot", "--headless", "--path", "/app", "-s", "res://prototypes/pixel3d/net/server_main.gd"]
