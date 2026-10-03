# Guide utilisateur — SteryMed Mobile

Ce guide est écrit à partir des écrans et des droits réels de l'application
(`docs/ROLE_MATRIX.md`). Les captures d'écran seront ajoutées après les essais
sur téléphone (`docs/DEVICE_TEST_LOG.md`) ; chaque section indique l'écran à
photographier.

## 1. Pour commencer

**Se connecter.** Saisissez l'identifiant du cabinet, votre e-mail et votre mot
de passe. La session reste ouverte sur le téléphone ; après quelques minutes en
arrière-plan, l'application demande votre empreinte ou votre code pour
reprendre. Les données du cabinet sont chiffrées sur le téléphone.

**Les six onglets du bas.**

| Onglet | À quoi il sert |
|---|---|
| Accueil | La situation du cabinet en un coup d'œil, adaptée à votre rôle, et l'accès à tous les modules |
| Scanner | Lire une étiquette (QR ou DataMatrix) ou un produit, et enregistrer son utilisation |
| Cycles | Les cycles de stérilisation : préparer, démarrer, contrôler, libérer |
| Stock | Niveaux, lots, mouvements, inventaires |
| Alertes | Stock bas, péremption proche, périmé, cycle en échec |
| Plus | Votre profil, les écrans du cabinet auxquels vous avez accès, l'état de synchronisation, les notifications |

**Retour.** La flèche en haut à gauche et le bouton retour du téléphone ramènent
à l'écran précédent ; depuis un onglet, ils ramènent à l'Accueil.

**Sans réseau.** Les mouvements de stock, les utilisations d'étiquettes, les
réceptions et les changements de cycle sont mis en file et envoyés dès que le
réseau revient (bandeau « en attente » en haut ; détail dans Plus → Synchronisation).
Rien n'est envoyé deux fois. Un élément qui échoue reste visible pour être
renvoyé ou abandonné : rien ne disparaît en silence.

## 2. Ce que fait chaque rôle

| Rôle | Peut faire | Ne peut pas faire |
|---|---|---|
| **Propriétaire / Administrateur** | tout : équipe, sites, appareils, stock, commandes, cycles, libération, patients, prothèses et paiements, audit, exports | — (seul le propriétaire modifie les règles de DLU) |
| **Responsable de stock** | produits, fournisseurs, commandes, réceptions, mouvements, lots, inventaires, alertes, préparation des cycles | libérer un cycle, créer un patient, modifier les paiements prothèses |
| **Responsable de libération** | consulter ; **libérer ou rejeter** un cycle ; gérer les non-conformités | modifier le stock, les commandes |
| **Praticien** | scanner et enregistrer une utilisation, créer un dossier patient, créer et suivre les dossiers prothétiques | libérer un cycle, modifier le stock, les paiements |
| **Lecture seule** | tout consulter | rien modifier |

L'application n'affiche jamais un bouton que votre rôle ne peut pas utiliser :
si une action manque, c'est que votre rôle ne l'a pas.

## 3. Parcours courants

### Scanner une étiquette et enregistrer une utilisation (praticien)
1. Onglet **Scanner**, visez le code de l'étiquette.
2. L'écran montre le cycle, l'appareil, la date limite d'utilisation. Une
   étiquette **bloquée** (rappelée, périmée) est refusée avec la raison.
3. **Enregistrer l'utilisation** : choisissez le patient (référence), le
   praticien et l'acte. Un double scan n'enregistre qu'une seule utilisation.

### Sortir ou ajuster du stock (responsable de stock)
Onglet **Stock** → *Nouveau mouvement* : sortie, ajustement (motif obligatoire)
ou transfert. Choisissez le lot ; l'écran affiche le stock restant avant
validation. Vous pouvez aussi scanner le produit pour le retrouver.

### Réceptionner une commande (responsable de stock)
Accueil → **Commandes** → la commande → **Réceptionner** : saisissez le
numéro de lot et la date limite pour chaque ligne, une raison en cas d'écart,
et prenez une photo du bon de réception. La réception peut être partielle.

### Faire un cycle de stérilisation
1. **Cycles** → *Nouveau cycle* : appareil et programme (l'aperçu montre ce qui
   sera créé), puis ajoutez les instruments du chargement.
2. **Démarrer**, puis **Terminer** quand l'autoclave a fini.
3. Saisissez les **tests de contrôle** (un test échoué est signalé en rouge en
   haut du cycle), ajoutez les photos ou rapports.
4. Le responsable de libération ouvre le cycle et **libère** ou **rejette**,
   avec une raison. Le bandeau en haut du cycle dit toujours « prochaine étape ».

### Traiter une alerte
Onglet **Alertes** : les plus graves en premier, avec l'ancienneté et un bouton
pour ouvrir le stock, les lots ou le cycle concerné. **Marquer comme résolu**
(rôles de gestion) demande confirmation.

### Suivre un travail prothétique (praticien, administrateur)
Accueil → **Prothèses**. La première ligne dit ce qui est à traiter en priorité ;
chaque carte ouvre la liste correspondante. *Nouveau dossier* : patient, type de
travail, praticien, laboratoire, priorité. Dans le dossier, la frise montre
l'avancement ; changez le statut en un geste. Avant la pose, un avertissement
(jamais bloquant) signale un solde ou un acompte à vérifier. Le suivi des
paiements est réservé aux administrateurs.

## 4. Alertes sur le téléphone

Plus → **Notifications** → *Alertes sur ce téléphone*. Le téléphone demande
alors son autorisation. Le message est volontairement général (« 2 nouvelles
alertes dont 1 critique ») : aucun nom de patient ni de produit n'apparaît
sur un écran verrouillé. Toucher la notification ouvre l'onglet Alertes. Si
l'interrupteur est absent, cette version de l'application n'a pas les
notifications : les alertes restent toujours visibles dans l'onglet.

## 5. Ce qui se fait sur le web, pas sur le téléphone

Création des sites et emplacements, impression et réimpression des étiquettes,
réglages des seuils d'alerte, gestion fine de l'équipe. L'application l'indique
plutôt que de le simuler.

## 6. En cas de problème

| Je vois… | Que faire |
|---|---|
| « Hors ligne » / « en attente d'envoi » | Rien : l'envoi reprend seul au retour du réseau. Plus → Synchronisation pour le détail |
| « Mise à jour requise » | Installer la dernière version de l'application |
| Écran de déverrouillage | Empreinte ou code du téléphone ; sans verrouillage d'écran, l'application se déconnecte (rien n'est perdu) |
| Une action manque | Votre rôle ne l'a pas : demander à l'administrateur du cabinet |
| Un élément « à vérifier » dans la synchronisation | L'ouvrir, puis **Renvoyer** ou **Abandonner** |
| Autre | Le canal d'assistance du cabinet (à renseigner : voir `docs/RELEASE.md`) |
