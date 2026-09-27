# Guide utilisateur — SteryMed Mobile

**Statut : squelette — captures d'écran manquantes.** Ce document liste
les parcours réels de l'application (vérifiés dans le code) avec un
emplacement réservé pour chaque capture d'écran. Il faut faire tourner
l'application sur un appareil réel ou un simulateur pour les produire —
hors de portée de cette session. La structure et le texte descriptif
sont prêts à être complétés.

## Sommaire

1. Connexion
2. Tableau de bord
3. Scanner une étiquette
4. Enregistrer une utilisation
5. Cycles de stérilisation
6. Stock
7. Commandes fournisseurs
8. Patients
9. Non-conformités
10. Prothèses
11. Paramètres et gestion d'équipe

---

## 1. Connexion

`Routes.login` — email + mot de passe, sélection du tenant si
applicable.

`[Capture d'écran : écran de connexion]`

## 2. Tableau de bord

`Routes.dashboard` — contenu et indicateurs différents selon le rôle
(voir `lib/core/router/guards/role_guard.dart` et
`lib/features/dashboard/`).

`[Capture d'écran : tableau de bord]`

## 3. Scanner une étiquette

`Routes.scanner` → `Routes.labelsDetail` — nécessite la permission
`labels.view`.

`[Capture d'écran : scanner]`
`[Capture d'écran : détail d'une étiquette]`

## 4. Enregistrer une utilisation

`Routes.labelsUsage` — nécessite `usages.manage`. Le brouillon est
conservé automatiquement si l'application est fermée en cours de
saisie (seul formulaire de l'application à avoir cette protection
aujourd'hui).

`[Capture d'écran : formulaire d'utilisation]`

## 5. Cycles de stérilisation

`Routes.cycles` → `Routes.cyclesDetail` — création (`cycles.manage`),
démarrage/fin/soumission (`cycles.manage`), décision de libération
(`cycles.release`, action distincte).

`[Capture d'écran : liste des cycles]`
`[Capture d'écran : détail d'un cycle]`
`[Capture d'écran : décision de libération]`

## 6. Stock

`Routes.stock` (lecture : `inventory.view`) →
sortie/ajustement/transfert (`inventory.manage`).

`[Capture d'écran : niveaux de stock]`

## 7. Commandes fournisseurs

`Routes.purchases` (`purchasing.view`) → réception
(`purchasing.manage`).

`[Capture d'écran : liste des commandes]`
`[Capture d'écran : réception de marchandise]`

## 8. Patients

`Routes.patients` (`patients.view` / `patients.manage` pour créer ou
modifier).

`[Capture d'écran : recherche patient]`

## 9. Non-conformités

`Routes.nonConformities` (`non_conformities.view` /
`non_conformities.manage` pour créer/résoudre).

`[Capture d'écran : liste des non-conformités]`

## 10. Prothèses

`Routes.prosthetic` (`prosthetic_cases.view`) → création
(`Routes.prostheticCreate`, `prosthetic_cases.manage`), détail
(`Routes.prostheticDetail`) avec modification rapide, changement de
statut et suivi du paiement (`prosthetic_cases.manage` /
`prosthetic_payments.manage` séparément — un praticien sans ce dernier
droit voit l'état du paiement en lecture seule), liste "en attente de
pose" (`Routes.prostheticWaitingPlacement`) et gestion des laboratoires
(`Routes.prostheticLaboratories`). Voir `docs/PROSTHETIC_MODULE.md` pour
le détail technique complet.

`[Capture d'écran : liste des dossiers prothétiques]`
`[Capture d'écran : création d'un dossier]`
`[Capture d'écran : détail d'un dossier — statut et paiement]`
`[Capture d'écran : en attente de pose]`

## 11. Paramètres et gestion d'équipe

`Routes.settings`, `Routes.team` (invitation : `invitations.create`).

`[Capture d'écran : paramètres]`
`[Capture d'écran : équipe]`

---

## Ce qui manque pour compléter ce guide

- [ ] Captures d'écran réelles (19 emplacements dans ce document, dont 4
  ajoutés pour le module prothétique le 2026-09-26 — le plan initial,
  P12, en prévoyait 14 avant que ce module existe) — nécessite un
  appareil ou un simulateur.
- [ ] Relecture par le porteur de produit pour le ton et la
  terminologie métier.
- [ ] Un parcours par rôle (administrateur, praticien, gestionnaire de
  stock, etc.) — ce guide couvre les écrans, pas encore qui voit quoi.
