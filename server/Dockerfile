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
COPY src/game/first_adventure_state.gd /app/src/game/first_adventure_state.gd
COPY src/game/data/first_adventure.json /app/src/game/data/first_adventure.json
COPY src/game/data/classes.json /app/src/game/data/classes.json
COPY src/game/data/core_skills.json /app/src/game/data/core_skills.json
# conteúdo autoritativo (net/server_content.gd): missões, segredos, itens e bolsa
COPY src/game/quests.gd /app/src/game/quests.gd
COPY src/game/data/quests.json /app/src/game/data/quests.json
COPY src/game/data/world_regions.json /app/src/game/data/world_regions.json
COPY assets/data/items.json /app/assets/data/items.json
COPY src/core/inventory.gd /app/src/core/inventory.gd
COPY src/core/json_data.gd /app/src/core/json_data.gd
COPY src/game/ai/ /app/src/game/ai/
COPY src/game/net/ /app/src/game/net/
RUN chown -R aethra:aethra /app

USER aethra
ENV AETHRA_PORT=7777 AETHRA_DATA_DIR=/data AETHRA_LOG_LEVEL=info XDG_DATA_HOME=/data/.godot-user
VOLUME ["/data"]
EXPOSE 7777/udp

# Primeira execução importa o projeto (só scripts); depois sobe o servidor.
CMD ["godot", "--headless", "--path", "/app", "-s", "res://src/game/net/server_main.gd"]
