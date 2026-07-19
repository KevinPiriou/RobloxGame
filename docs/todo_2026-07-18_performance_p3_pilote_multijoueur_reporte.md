# Todo - P3 pilote projectile multijoueur reporte

Date : 2026-07-18 16:40 Europe/Paris

Le pilote `ClientPilot` est valide uniquement en solo admin. Il ne doit pas
etre active globalement tant que les points suivants ne sont pas demontres :

1. deux clients voient une presentation lisible des projectiles de chacun ;
2. le proprietaire conserve ses VFX complets et les observateurs recoivent une
   representation volontairement budgetee ;
3. les impacts, rebonds et destructions restent coherents avec un retard ou
   une perte de correction visuelle ;
4. la bande passante est mesuree a deux clients et comparee au noyau replique ;
5. le smoke simple de run multijoueur ne degrade ni degats, ni recompenses,
   ni visibilite de combat.

Cette dette est explicite. Elle ne doit pas etre "corrigee" en activant le
pilote solo pour tous les joueurs, ni en ajoutant une couche de replication
sans nouvelle mesure avant/apres.
