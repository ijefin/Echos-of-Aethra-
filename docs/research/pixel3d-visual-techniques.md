# Pesquisa: técnicas visuais para 3D com cara de pixel art (Godot 4.7.2)

**Data:** 2026-11-03 · Pesquisa feita por agente na web (~14 buscas); fontes em sua maioria shaders da comunidade (godotshaders.com, fórum do Godot) — testar cada uma no 4.7 antes de confiar.

## Mudanças de engine que afetam o projeto
- **Glow (4.6):** aplicado antes do tonemap; blend padrão mudou; reavaliar intensidade.
- **Reversed-Z (desde 4.3):** linearizar profundidade com `INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2-1, depth, 1)` (sem remapear z). Shaders de água antigos quebram por isso.
- **4.7:** AreaLight3D (luz retangular com sombra suave), saída HDR.
- **Física:** Jolt é o padrão desde 4.6 — validar destino de blink/dash com ray/shape cast.

## Top 10 por impacto/esforço
1. Sombras de nuvem por ruído no `light()` (baixo).
2. Grading por LUT/paleta + gradiente dia/noite (baixo).
3. Copas com normais de esfera + grama com a cor do chão (baixo).
4. Lago com gradiente de profundidade e espuma de margem (baixo).
5. Runas com UV2 de fluxo e pulso ligado a skills (médio — assinatura do jogo).
6. Dissolve com borda emissiva + burst no blink (baixo).
7. Vagalumes, pólen, folhas com GPUParticles3D (baixo).
8. Rio em fita no Path3D com UV rolando (médio).
9. FogVolumes localizados com feixes de luz (médio).
10. Afterimages + hitstop no dash (baixo/médio).

## Por tema (resumo)
- **Render:** normais de esfera em copas (Data Transfer no Blender ou `NORMAL = normalize(VERTEX - centro)`); grama herda cor/luz do chão; sombra de nuvem multiplicando `ATTENUATION`; LUT 3D em `Environment.adjustment_color_correction`; dither Bayer só nas transições; volumetric fog com densidade global 0 + FogVolumes; glow dentro do SubViewport.
- **Água:** lago com diferença de profundidade → cor rasa/funda + espuma quantizada; rio em fita (SurfaceTool, UV.y = distância) com UV rolando ou flow map; cáusticas Voronoi; reflexo falso em espaço de tela (SSR com ortográfica dá problema); cachoeira com UV rápido + névoa.
- **População:** ProtonScatter (MIT), Terrain3D 1.1 (MIT, 4.5–4.8+, aceita shader próprio), Godot Road Generator (MIT, Path3D); fontes com GPUParticles + disco d'água; lampiões com OmniLight piscando; vida ambiente (vagalumes, borboletas, pássaros por MultiMesh) com `visibility_range`.
- **Runas na armadura:** máscara de canais + UV2 desenrolada ao longo do canal (Blender), `EMISSION = cor * mask * pulso(fract(UV2.x - TIME*vel))`; veias de magma por Voronoi; uniform `charge` ligado ao cast/dano; rim discreto; faíscas por BoneAttachment3D.
- **Blink/dash:** dissolve por ruído em object space com borda emissiva (scissor/discard, sem problema de ordenação); afterimages = cópia da malha com material próprio e `alpha` por uniform (não existe `modulate` em 3D), pool de 4–6; distorção radial com screen texture; burst one-shot + fita entre origem e destino + decal de runa; hitstop 2–4 frames e shake em pixels inteiros.

## Ferramentas e assets
| Item | Licença | Nota |
|---|---|---|
| [ProtonScatter](https://github.com/HungryProton/scatter) | MIT | suporte a 4.7 não confirmado |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D/releases) | MIT | 4.5–4.8+ |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | MIT | 4.7 citado |
| [godot-mcp (shin2344234)](https://glama.ai/mcp/servers/shin2344234/godot-mcp/tree) | ver repo | exige 4.7+, revisar antes |
| [Kenney](https://kenney.nl/assets) | CC0 | Particle Pack |
| [KayKit](https://kaylousberg.itch.io/) | CC0 | conferir LICENSE de cada pacote |
| [Quaternius](https://quaternius.com) | CC0 (site original) | ports de terceiros podem ter outra licença |
| [Poly Pizza](https://poly.pizza) | misto | filtrar CC0 |
| [PixelAge vegetation demo](https://pixelagegames.itch.io/3d-pixelart-vegetation) | ver página | referência de grama/outline |

## Fontes citadas
[GDQuest 4.6](https://www.gdquest.com/library/godot_4_6_workflow_changes) · [Cloud shadows analíticas](https://godotshaders.com/shader/simulating-cloud-shadows-analytically/) · [paddy-exe Stylized Water](https://github.com/paddy-exe/Godot-3D-Stylized-Water) · [Stylized Water 4.x](https://godotshaders.com/shader/stylized-water-for-godot-4-x) · [Pixel Art Water](https://godotshaders.com/shader/pixel-art-water-shader/) · [Volumetric fog docs](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/volumetric_fog.rst) · [GodotShaderCollection](https://github.com/alfredbaudisch/GodotShaderCollection) · [3D burn dissolve](https://godotshaders.com/shader/3d-burn-dissolve/) · [Stylized lava](https://godotshaders.com/shader/stylized-lava/) · [Fórum: grama t3ssel8r](https://forum.godotengine.org/t/trying-to-replicate-t3ssel8r-grass-shader/123816) · [Fórum: afterimage 4.5](https://forum.godotengine.org/t/afterimage-mesh-effect-not-fading-or-changing-color/126819)
