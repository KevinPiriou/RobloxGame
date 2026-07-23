# Carte de projet Codex

Ce document est une carte d'orientation, pas un inventaire exhaustif. Le dernier bloc daté fait foi ; les évolutions sont ajoutées à la fin.

## 2026-07-23 07:59:42 +02:00 — socle observé

- `default.project.json` est le manifeste Rojo du projet `TestRoblox`.
- `src/shared` est monté dans `ReplicatedStorage.Shared` : configurations et contrats partagés.
- `src/server` est monté dans `ServerScriptService.Server` : services et initialisation serveur.
- `src/client` est monté dans `StarterPlayer.StarterPlayerScripts.Client` : contrôleurs, UI et présentation client.
- `aftman.toml` épingle Rojo `7.7.0`. Le build Rojo est une validation distincte d'un smoke Studio.
- `docs/` conserve l'historique des chantiers. Pour un sujet, cibler les documents par mots-clés et date ; ne pas charger tout l'historique.
- À éviter par défaut : `assets/`, `MegaSeedValidator/output/`, les rapports générés de `MetaBuildLab_v1/` et les caches Python.

## Parcours minimal d'un chantier

1. Lire `AGENTS.md`, cette carte, `CURRENT_STATUS.md`, puis le dernier handoff lié au sujet.
2. Lire `default.project.json` si le point de montage est utile, puis seulement les fichiers d'entrée probables du sous-système.
3. Consigner le périmètre et la définition de terminé dans `ACTIVE_TASK.md` avant de modifier du code.

## 2026-07-23 08:28:56 +02:00 — entrées principales par système

Carte courte et non exhaustive, établie à partir de l'arborescence et des noms de fichiers. Les entrées marquées « à vérifier » ne sont pas confirmées par une lecture de code dans cette passe.

| Système | Configurations shared principales | Services serveur d'entrée | Contrôleurs client d'entrée | Référence historique récente confirmée |
|---|---|---|---|---|
| Personnages et skins | `CharacterConfig`, `CharacterSkinConfig`, `CharacterDefinitionValidator` | `CharacterService`, `CharacterSkinService` | `RunLauncher.client`, `LobbyPanels.client` (à vérifier) | `post_audit_2026-07-23_054644_rufus_valorcrest_production_v1.md` |
| Combat et armes | `CombatConfig`, `WeaponConfig`, `WeaponSkinConfig`, `WeaponDefinitionValidator` | `WeaponService`, `WeaponHitService`, `MeleeWeaponService` | `WeaponChoiceV2Adapter.client`, `CombatUI.client` | `post_audit_2026-07-23_054644_rufus_valorcrest_production_v1.md` |
| Runs et cycle de vie | `RunGenerationConfig`, `RunItemConfig`, `RunLoadingConfig`, `RunTeleportConfig` | `RunStateService`, `RunSessionService`, `RunWorldService` | `RunLauncher.client`, `RunLoadingUI.client`, `RunSummaryUI.client` | `post_audit_2026-07-22_024711_rattrapage_personnages_lancement_run_visuels_v1.md` |
| Génération procédurale et monde | `ProceduralMapConfig`, `EnvironmentConfig`, `ChapterConfig` | `ProceduralMapService`, `RunMapService`, `WorldSpawnService` | `EnvironmentController.client`, `MiniMapUI.client` | `post_audit_2026-07-16_072042_foliage_procedural_v1.md` |
| Progression | `ProgressionConfig`, `MetaProgressionConfig`, `PerkConfig` | `MetaProgressionService`, `XpService`, `ChapterProgressService` | `MetaProgressionUI.client`, `PerkUI.client` | `post_audit_2026-07-13_run_result_meta_progression_v1.md` |
| UI | `UiTheme`, `UiTemplateConfig`, `UiVisualAssetsV2`, `RunHudLayout` | `HudMessageService` | `UI.client`, `LobbyPanels.client`, `RunLayoutV2Controller.client` | `post_audit_2026-07-22_024711_rattrapage_personnages_lancement_run_visuels_v1.md` |
| Audio, graphismes et préférences | `AudioConfig`, `GraphicsConfig`, `PlayerPreferencesConfig` | `AudioService`, `PlayerPreferencesService` | `AudioClient.client`, `AudioController`, `GraphicsController`, `GraphicsSettingsUI.client` | `post_audit_2026-07-13_graphics_preferences_v1.md` ; `post_audit_2026-07-13_audio_preferences_persistence_v1.md` |
| VFX | `VfxConfig` | `ProjectileVisualService` (à vérifier) | `VfxQualityController`, `ProjectileVfxController.client`, `MeleeWeaponVfxController.client`, `InvocationVfxController.client` | `post_audit_2026-07-23_010729_rusal_gale_revenants_vfx_calibration_v1.md` |
| Performance | `PerformanceBaselineConfig`, `DebugConfig` | `PerformanceBenchmarkService`, `PerformanceTelemetryService`, `PhysicsAuditService` | `PerformanceBenchmarkClient.client`, `DebugUI.client` | `post_audit_2026-07-18_165213_performance_p0_p3_synthese_etat_prod.md` |
| i18n | `I18n` | Aucun service dédié identifiable par nom (à vérifier) | `I18nBootstrap.client`, `I18nClient` | `post_audit_2026-07-22_104352_fondation_i18n_localisation_v1.md` |
