# Demande au client — éléments nécessaires à la mise en service

À envoyer au porteur du projet / au responsable du cabinet. Chaque ligne dit
**ce qu'on demande, pourquoi, et sous quelle forme répondre**. Les éléments
marqués ⛔ bloquent la publication de l'application ; les autres bloquent la
mise en route du cabinet pilote. Conformément au cahier des charges, **tous les
comptes restent la propriété du client** : le prestataire y est ajouté comme
utilisateur nommé, jamais l'inverse.

---

Bonjour,

L'application mobile SteryMed est terminée et testée côté logiciel. Pour la
livrer au cabinet, nous avons besoin des éléments ci-dessous. Un simple retour
par e-mail suffit pour la plupart.

## A. Comptes et accès (propriété du client)

| # | Demande | Pourquoi | Réponse attendue |
|---|---|---|---|
| A1 ⛔ | **Compte développeur Google Play** (25 $, une fois) au nom du cabinet ou de sa société | Distribuer l'application aux téléphones du cabinet (piste « test interne », pas de publication publique avant validation) | Création du compte par le client, puis invitation du prestataire comme utilisateur |
| A2 ⛔ | **Identifiant définitif de l'application** (proposé : `com.sterymed.mobile`) | Il est **définitif** après le premier envoi sur Google Play | « OK » ou un autre identifiant |
| A3 ⛔ | **Clé de signature** de l'application (fichier + mots de passe), générée sur un poste du client | Chaque version est signée ; perdre la clé bloque les mises à jour | Fichier conservé dans le gestionnaire de mots de passe du client, 2 copies |
| A4 ⛔ | **Hébergement de production et de recette** (serveur, nom de domaine, accès DNS) | L'application exige une adresse sécurisée en HTTPS ; aujourd'hui seul un serveur de développement existe | Deux adresses : une pour l'API, une pour les fichiers (ex. `api.cabinet.fr`, `fichiers.cabinet.fr`) |
| A5 | **Projet Sentry** (suivi des plantages) | Voir les erreurs rencontrées sur les téléphones | Clé DSN fournie par le client |
| A6 | **Projet Firebase** (notifications) | Prévenir le téléphone d'une alerte. Fonctionnalité complète côté application ; dépend d'un ajout côté serveur décidé avec l'équipe web | 4 valeurs de l'application Android + une clé de service |
| A7 | **Service d'envoi d'e-mails** (domaine vérifié) | Invitations, réinitialisation de mot de passe | Compte et domaine d'expédition |
| A8 | **Personne de support** nommée (e-mail partagé ou téléphone) | Recevoir les alertes techniques et surveiller la synchronisation pendant 2 semaines | Nom + contact |

## B. Décisions à prendre

| # | Question | Pourquoi | Notre recommandation |
|---|---|---|---|
| B1 | **iPhone dans le pilote ?** | Demande un compte Apple (99 $/an) et un Mac | Android d'abord ; iPhone en version suivante |
| B2 | **Identification du patient** : référence pseudonymisée (actuel) ou nom/prénom ? | Le cahier exige une analyse **RGPD / HDS** avant toute donnée patient réelle | Garder les références pour le pilote ; ajouter les noms après l'analyse |
| B3 | **Rôle « réception »** : le cahier prothèses parle d'une réception qui vérifie les paiements. Le serveur propose 6 rôles (propriétaire, administrateur, responsable de stock, responsable de libération, praticien, lecture seule) | Qui modifie les paiements | Rôle « administrateur » pour la réception pendant le pilote |
| B4 | **Fréquence des contrôles** de stérilisation (vide, Bowie-Dick, biologique…) : tous les jours ? à chaque cycle ? | Permet une alerte « contrôle en retard », qui n'existe pas aujourd'hui | Règle écrite par le cabinet |
| B5 | **Politique de conservation** des données et des exports | Durée de conservation légale | Valeur confirmée par le DPO / le cabinet |
| B6 | **Logo et nom définitifs**, icône de l'application | L'icône actuelle est provisoire | Fichier vectoriel ou PNG 1024×1024 |

## C. Informations sur le cabinet (pour paramétrer le pilote)

| # | Demande | Format |
|---|---|---|
| C1 | **Liste des utilisateurs** : nom, e-mail, et pour chacun le rôle voulu | tableau (nom, e-mail, rôle) |
| C2 | **Sites, salles et emplacements de stockage** (réserve, bloc, armoire…) | liste |
| C3 | **Appareils** : marque, modèle, numéro de série de chaque autoclave, et leurs **programmes** (température, durée de plateau) | tableau |
| C4 | **Produits** : nom, référence, code-barres, unité, **seuil minimal**, fournisseur, emplacement habituel | tableau (export du logiciel actuel si possible) |
| C5 | **Fournisseurs** : nom, contact, e-mail, téléphone | tableau |
| C6 | **Règles de DLU** (durée de validité après stérilisation selon l'emballage et le stockage ; norme EN 868) | tableau emballage × stockage → durée |
| C7 | **Laboratoires partenaires** (prothèses) : nom, contact | liste |
| C8 | **Modèle de l'imprimante d'étiquettes** et un exemple d'étiquette actuelle | marque/modèle + photo |
| C9 | **Téléphones du cabinet** : marque, modèle, version d'Android | liste (pour la matrice de compatibilité) |
| C10 | **Date de démarrage souhaitée** et créneaux pour la formation | dates |

## D. Documents à fournir ou valider

| # | Demande | Pourquoi |
|---|---|---|
| D1 | **Politique de confidentialité** (une adresse web) | Exigée par Google Play dès la publication ; décrit quelles données sont traitées |
| D2 | **Textes de la fiche Google Play** (description courte et longue) | Nous proposons un texte en français ; à valider |
| D3 | **Validation écrite de la recette** | Le cahier des charges n'accepte le MVP qu'après démonstration du parcours complet et validation écrite |

## E. Ce que nous livrons en retour

* Application Android signée, installée sur les téléphones du cabinet (piste test interne).
* Guide utilisateur par rôle (`USER_GUIDE.md`) et formation sur site.
* Démonstration **enregistrée** des 6 parcours du cahier des charges, sur serveur de recette.
* Liste des anomalies, sans anomalie bloquante ni critique ouverte.
* Code, accès et documentation remis au client ; aucun composant critique ne dépend d'un compte personnel du prestataire.

## À savoir dès maintenant

* L'impression et la réimpression des étiquettes, la création des sites/emplacements et le réglage des seuils d'alerte se font sur l'**application web** (conformément au cahier des charges).
* Les **notifications sur le téléphone** nécessitent un ajout côté serveur ; en attendant, les alertes sont visibles dans l'onglet **Alertes**.
* Le serveur limite à 10 connexions par minute depuis une même connexion internet ; à signaler si le cabinet a de nombreux postes derrière une seule box.

Merci de répondre point par point (A1, A2…). Les éléments ⛔ sont à fournir en priorité.
