# Brouillons pour Google Play et la confidentialité (à valider par le cabinet)

Ces textes sont rédigés **uniquement à partir de ce que l'application fait réellement**
(`PRIVACY.md`, `SECURITY.md`). Ce sont des **brouillons** : le responsable du
cabinet (ou son DPO / conseil juridique) doit les relire et les valider avant toute
publication. Ils ne constituent pas un avis juridique.

---

## 1. Fiche Google Play

**Nom** : SteryMed

**Description courte (80 caractères max)**
Traçabilité de la stérilisation, stocks et prothèses pour cabinets dentaires.

**Description longue**
SteryMed accompagne le cabinet dentaire au quotidien :

• Stérilisation : préparez un cycle, saisissez les contrôles, faites libérer ou rejeter le cycle, et gardez la preuve (opérateur, appareil, pièces jointes).
• Étiquettes : scannez le QR code ou le DataMatrix d'une pochette, vérifiez sa validité et enregistrez son utilisation sur un patient (référence pseudonymisée).
• Stock et commandes : niveaux, lots et dates limites, sorties, ajustements, réceptions avec photo du bon, inventaires.
• Alertes : stock bas, péremption proche, cycle en échec.
• Prothèses : suivez chaque travail de l'empreinte à la pose, avec laboratoire, paiements et liste des travaux en attente.
• Hors ligne : les actions sont conservées sur le téléphone et envoyées au retour du réseau, sans doublon.

Chaque rôle (administrateur, responsable de stock, responsable de libération, praticien, lecture seule) ne voit et ne peut faire que ce qui lui est permis. Les données du cabinet sont chiffrées sur le téléphone et protégées par le verrouillage de l'appareil.

Application réservée aux cabinets disposant d'un compte SteryMed.

**Catégorie** : Médecine. **Public** : professionnels. **Contenu** : aucune publicité, aucun achat intégré.

---

## 2. Formulaire « Sécurité des données » (Google Play) — réponses proposées

| Question | Réponse | Justification (dans le code) |
|---|---|---|
| L'application collecte-t-elle ou partage-t-elle des données ? | Oui, collecte | Compte et activité du cabinet envoyés au serveur du cabinet |
| Les données sont-elles chiffrées en transit ? | Oui | HTTPS exigé en production (l'application refuse un serveur non sécurisé) |
| Peut-on demander la suppression des données ? | Oui, via le cabinet | Le cabinet est responsable du traitement ; procédure à définir (voir `PRIVACY.md`) |
| **Infos personnelles** : nom, e-mail, identifiants utilisateur | Collectés, non partagés | Compte du membre du cabinet |
| **Santé** : référence pseudonymisée du patient liée à un acte | Collectée, non partagée | Aucune donnée directement identifiante : le serveur génère la référence |
| **Photos** | Collectées (facultatif), non partagées | Pièces jointes de cycle, de réception, de dossier prothétique, choisies par l'utilisateur |
| **Journaux de plantage** | Collectés, non partagés (sous-traitant : Sentry, si activé) | Données personnelles retirées avant envoi |
| **Identifiants d'appareil** | Seulement si les notifications sont activées (jeton de notification) | Fonction non active tant que le serveur ne la propose pas |
| Localisation, contacts, SMS, micro, calendrier, publicité, suivi | **Non collectés** | — |
| Finalité | Fonctionnalité de l'application, sécurité, fiabilité | — |

**Permissions Android et leur raison** : Caméra (scanner les codes, photographier un bon ou une pièce jointe) ; Internet ; Notifications (alertes, uniquement si l'utilisateur les active) ; Biométrie (déverrouillage après inactivité).

---

## 3. Politique de confidentialité — brouillon à publier à une adresse web

**Politique de confidentialité de l'application SteryMed**
*Dernière mise à jour : [date]*

**1. Qui est responsable ?**
Le responsable du traitement est le cabinet dentaire qui vous a ouvert un compte SteryMed : [nom, adresse, contact du cabinet / DPO]. [Nom du prestataire] intervient en tant que sous-traitant pour fournir l'application et le service.

**2. Quelles données sont traitées ?**
• Votre compte : nom, adresse e-mail, rôle dans le cabinet.
• L'activité de traçabilité : cycles de stérilisation et contrôles, étiquettes scannées, utilisations rattachées à un patient, mouvements de stock, commandes et réceptions, dossiers de travaux prothétiques, journal des actions.
• Les patients sont désignés **uniquement par une référence générée par le serveur** (par exemple PAT-000042). L'application ne demande ni nom, ni date de naissance, ni autre donnée directement identifiante.
• Les photos et documents que vous joignez volontairement (bon de réception, rapport de cycle, photo d'un dossier prothétique).
• Des rapports de plantage techniques, dont les données personnelles sont retirées avant l'envoi.

**3. Pourquoi ?**
Assurer la traçabilité de la stérilisation, la gestion du stock et le suivi des travaux prothétiques, conformément aux obligations du cabinet [base légale à confirmer par le cabinet : obligation légale de traçabilité / intérêt légitime].

**4. Où et comment sont-elles protégées ?**
Les données sont envoyées par connexion sécurisée (HTTPS) au serveur du cabinet, hébergé par [hébergeur, certification HDS à confirmer]. Sur le téléphone, elles sont chiffrées et l'application se verrouille après une courte inactivité. La sauvegarde automatique Android est désactivée pour ces données.

**5. Combien de temps ?**
[Durée de conservation à fixer par le cabinet, selon ses obligations de traçabilité.]

**6. Vos droits**
Vous pouvez demander l'accès, la rectification, l'export ou, lorsque la loi le permet, l'effacement de vos données en écrivant à [contact]. Le cabinet peut exporter l'ensemble de ses données depuis l'application. Vous pouvez saisir la CNIL (www.cnil.fr).

**7. Qui reçoit les données ?**
Uniquement le cabinet, son hébergeur et, pour les rapports de plantage, [Sentry — si activé]. Aucune publicité, aucun suivi commercial, aucune vente de données.

**8. Contact**
[Nom, e-mail, téléphone du responsable ou du DPO]

---

## 4. Avant de publier

* Le cabinet remplit les parties entre crochets et fait valider le texte.
* Le texte est publié à une adresse web stable ; cette adresse est saisie dans Google Play.
* Les réponses du formulaire « Sécurité des données » sont revérifiées si une fonction change (notifications, nouveaux champs patient).
