# P1 — Stabilite multi-run reportee

Date : 2026-07-18

## Contexte

La phase P1 a valide les normalisations physiques a faible risque pour les collectables, les interactables et le relief genere. Son dernier proof of done exige toutefois plusieurs cycles comparables de creation puis destruction de map.

Ce smoke est bloque par un defaut plus fondamental : apres une mort ou une sortie volontaire apres victoire, le joueur ne peut pas lancer la run suivante. Le lanceur reste dans un etat de generation, ou la session precedente peut rester retenue si un nettoyage runtime echoue.

## Restant a faire P1

Lorsque le cycle de vie de run sera de nouveau fiable :

1. enchainer au minimum trois runs completes dans la meme session Studio ;
2. lancer l'inventaire physique apres chaque retour lobby ;
3. comparer `PhysicsParts`, `PhysicsCollision`, le nombre de parties runtime et les familles `MapRuntime` ;
4. verifier que la seconde et la troisieme generation conservent les proprietes runtime normalisees ;
5. cloturer P1 uniquement si aucun residu physique ou etat de map ne croit de maniere non expliquee.

## Pourquoi ce report est bloquant

Le cycle multi-run est un cas canonique du produit. Une comparaison de memoire apres destruction de map n'a pas de valeur tant que le joueur ne peut pas recreer une run de facon fiable. Le redressement du cycle de vie prime donc sur la poursuite de P1.

---

## Mise a jour - 2026-07-18 09:45:00

Le blocage de cycle de vie est leve : le smoke manuel de morts puis relances successives est valide. Trois variantes de map ont ete regenerees et auditees pendant leurs runs respectives.

Le restant a faire est reduit a un seul releve : apres la sortie de la derniere run vers le lobby, lancer `Inventaire physique P1` et verifier l'absence de map runtime residuelle. Ce document reste ouvert tant que ce releve hors run n'est pas fourni.

---

## Resolution - 2026-07-18 10:15:00

Le releve `P1-Physics-65580531` a ete produit au lobby apres une run. Les neuf familles runtime sont a zero, y compris `MapRuntime`. Le blocage est resolu et P1 est cloturee dans le document post-audit associe.
