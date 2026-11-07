// PROTOTYPE - NOT FOR PRODUCTION
// Dados do protótipo — espelham os Tuning Knobs de
// design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md.
// No jogo real vivem em assets/data/*.json; aqui são JS para o protótipo abrir via file://.
window.GAME_DATA = {
  attributes: {
    primary: ['STR', 'AGI', 'INT', 'VIT', 'SPI'],
    derived: ['max_hp', 'max_resource', 'resource_regen', 'attack_power', 'spell_power',
              'armor', 'resist', 'crit_chance', 'haste', 'move_speed'],
  },

  // Classes: só dados. Guerreiro, Paladino e Arqueiro estão aqui para provar o esquema;
  // o protótipo joga apenas com o Mago de Fogo.
  classes: {
    fire_mage: {
      name: 'Mago de Fogo', resource_type: 'mana',
      primary: { STR: 3, AGI: 5, INT: 12, VIT: 6, SPI: 8 },
      base:   { max_hp: 60, max_resource: 40, resource_regen: 0, spell_power: 8, attack_power: 2,
                crit_chance: 0.05, resist: 5, armor: 3, move_speed: 120 },
      coeff:  { max_hp: { VIT: 8 }, max_resource: { INT: 4, SPI: 2 }, resource_regen: { SPI: 0.5 },
                spell_power: { INT: 2 }, crit_chance: { AGI: 0.004 }, attack_power: { STR: 1 } },
      growth: { max_hp: 6, max_resource: 4, spell_power: 2 },
      abilities: ['fire_spark', 'fireball', 'flame_pillar', 'fire_nova'],
    },
    warrior: {
      name: 'Guerreiro', resource_type: 'rage',
      primary: { STR: 12, AGI: 6, INT: 2, VIT: 11, SPI: 3 },
      base:   { max_hp: 90, max_resource: 100, attack_power: 6, crit_chance: 0.05, armor: 15, resist: 5, move_speed: 115 },
      coeff:  { max_hp: { VIT: 10 }, attack_power: { STR: 2 }, armor: { VIT: 1.5 }, crit_chance: { AGI: 0.003 } },
      growth: { max_hp: 10, attack_power: 2 },
      abilities: [],
    },
    paladin: {
      name: 'Paladino', resource_type: 'faith',
      primary: { STR: 9, AGI: 4, INT: 5, VIT: 10, SPI: 10 },
      base:   { max_hp: 85, max_resource: 60, resource_regen: 1, attack_power: 4, spell_power: 4, armor: 12, resist: 10, move_speed: 115 },
      coeff:  { max_hp: { VIT: 9 }, attack_power: { STR: 1.5 }, spell_power: { SPI: 1.5 }, resist: { SPI: 1 } },
      growth: { max_hp: 8, attack_power: 1, spell_power: 1 },
      abilities: [],
    },
    archer: {
      name: 'Arqueiro', resource_type: 'focus',
      primary: { STR: 5, AGI: 13, INT: 4, VIT: 7, SPI: 5 },
      base:   { max_hp: 70, max_resource: 100, resource_regen: 8, attack_power: 4, crit_chance: 0.08, armor: 6, move_speed: 130 },
      coeff:  { max_hp: { VIT: 8 }, attack_power: { AGI: 2 }, crit_chance: { AGI: 0.005 } },
      growth: { max_hp: 7, attack_power: 2 },
      abilities: [],
    },
  },

  abilities: {
    fire_spark:   { name: 'Fagulha', key: 'Digit1', label: '1', cast_time: 0, cooldown: 0, cost: 0, range: 320,
                    target: 'enemy', power_stat: 'spell_power', school: 'magic', base: 6, scaling: 0.3,
                    projectile: { speed: 420, size: 'small' }, burn_stacks: 1, tier: 'light' },
    fireball:     { name: 'Bola de Fogo', key: 'Digit2', label: '2', cast_time: 1.2, cooldown: 0, cost: 18, range: 320,
                    target: 'enemy', power_stat: 'spell_power', school: 'magic', base: 20, scaling: 0.8,
                    projectile: { speed: 320, size: 'big' }, aoe: { radius: 56 }, burn_stacks: 2, tier: 'medium', ignites: true },
    flame_pillar: { name: 'Pilar de Chamas', key: 'Digit3', label: '3', cast_time: 0, cooldown: 8, cost: 25, range: 288,
                    target: 'enemy', power_stat: 'spell_power', school: 'magic', base: 30, scaling: 1.2,
                    ground: { telegraph: 0.6 }, aoe: { radius: 64 }, knockback: 48, tier: 'heavy' },
    fire_nova:    { name: 'Anel de Fogo', key: 'Digit4', label: '4', cast_time: 0, cooldown: 12, cost: 20, range: 0,
                    target: 'self', power_stat: 'spell_power', school: 'magic', base: 15, scaling: 0.5,
                    aoe: { radius: 80 }, knockback: 72, tier: 'medium' },
  },

  passives: { ignite: { threshold: 3, per_stack: 12, tier: 'heavy' } },
  status:   { burn: { tick_damage: 3, tick_interval: 1.0, duration: 6, max_stacks: 5 } },

  combat: {
    mitigation_K: 100, crit_damage_mult: 1.5, gcd: 0.75, spell_queue_window: 0.2,
    target_acquire_range: 400, aoe_inner_radius_ratio: 0.5, aoe_falloff_min: 0.6,
    knockback_duration: 0.18,
    aoe_y_squash: 0.75, // AoEs são elipses no chão por causa da vista 3/4
  },

  feel: {
    tiers: {
      light:  { hitstop: 0,  flash: 50, shake: 0,    squash: null,       embers: 4,  wobble: 0.06 },
      medium: { hitstop: 50, flash: 70, shake: 0.25, squash: [0.9, 80],  embers: 12, wobble: 0.14 },
      heavy:  { hitstop: 90, flash: 90, shake: 0.5,  squash: [0.85, 100], embers: 24, wobble: 0.22 },
    },
    shake_max_px: 8, trauma_decay: 1.6, scorch_duration: 3,
  },

  enemies: {
    training_dummy: { name: 'Boneco de Treino', primary: { VIT: 20 }, base: { max_hp: 240, resist: 20, armor: 20 },
                      coeff: { max_hp: { VIT: 8 } }, respawn: 3 },
    slime:          { name: 'Slime', primary: { VIT: 8 }, base: { max_hp: 60, resist: 10, armor: 5, move_speed: 55 },
                      coeff: { max_hp: { VIT: 6 } } },
  },

  anim: {
    idle:   { frames: 4, fps: 6 },
    walk:   { frames: 6, fps: 10 },
    attack: { frames: 6, fps: 12, release: 3 }, // índice 3 = frame 4 do spec
  },

  // Se este PNG existir (layout do ASSET-001), ele substitui o mago procedural.
  sprite: { cell: 64, pivot: [32, 58], sheet: 'assets/spr_mage_fire_sheet.png',
            rows: { idle: [0, 1, 2], walk: [3, 4, 5], attack: [6, 7, 8] } },
};
