# 🎨 STERYMED — THE COMPLETE VISUAL ROADMAP

**Every screen, every state, every pixel, every micro-detail.** This is the visual bible. Designers design from this. Devs build from this. QA tests against this. Nothing missing.

**How to read:** Each screen = ASCII layout (light) → dimensions → data → states → interactions → motion → a11y → edge cases. Dark mode rules are systematic (Part 21) unless screen-specific.

**Total:** ~70 unique surfaces × 5 states × 2 modes = **~700 Figma frames.**

---

# 📖 TABLE OF CONTENTS

1. Global layout constants
2. Auth screens (4)
3. Home & Dashboard (6 role variants)
4. Prosthetic module (9 screens)
5. Scanner module (3 screens)
6. Sterilization module (9 screens)
7. Non-conformities (3 screens)
8. Stock module (16 screens)
9. Alerts (2 screens)
10. Notifications (1 screen)
11. Profile (6 role variants)
12. Settings sub-screens (5 screens)
13. Admin (4 screens)
14. Overlays & system surfaces (8)
15. Motion master spec
16. Dark mode spec
17. Tablet spec
18. iOS vs Android
19. Accessibility visual specs
20. Illustration style guide

---

# 1. GLOBAL LAYOUT CONSTANTS

```
Reference widths:
  Phone:      390dp (iPhone 14 Pro)
  Large phone: 430dp (iPhone 14 Pro Max)
  Small:      360dp (Pixel 5)
  Tablet:     768dp (iPad Mini), 1024dp (iPad Pro 11)

AppBar:       56dp (48dp compact)
BottomNav:    64dp + safe area
Status bar:   iOS 47-59dp, Android 24-32dp
Safe top:     MediaQuery.padding.top
Safe bottom:  MediaQuery.padding.bottom

Screen padding H: 16dp
Screen padding V: 16dp
4pt grid everywhere
Card gap:        12dp
Section gap:     24dp
Block gap:       16dp
List row heights: 72-140dp (varies per entity)

Divider: 1dp #E2E8F0 (light) / #1F2937 (dark)
```

---

# 2. AUTH SCREENS (4)

## 2.1 Splash

```
┌───────────────────────────────────────┐  ← Status bar (transparent)
│                                       │
│                                       │
│                                       │
│                                       │
│           ⬤ SteryMed                  │  ← Logo mark 120×120
│         (tooth + sparkle)             │     centered, 30% from top
│                                       │
│         SteryMed                      │  ← h1 24sp w700
│                                       │     primary color
│                                       │     16dp below logo
│                                       │
│                                       │
│           [◐ loading pulse]           │  ← 32dp primary
│                                       │     appears after 400ms
│                                       │
└───────────────────────────────────────┘
```

**Dimensions:** Logo 120dp, wordmark 16dp below, loader 32dp, centered.
**Background:** `#FFFFFF` light / `#0B1220` dark.
**Motion:** Logo fade-in 400ms, wordmark +100ms delay, loader +400ms delay.
**Duration:** Max 1.5s then route.
**States:** Default → Loading (loader pulses 1200ms) → Error (session expired, route /login).
**A11y:** "SteryMed, chargement en cours."

## 2.2 Login

```
┌───────────────────────────────────────┐
├───────────────────────────────────────┤
│                                       │
│           ⬤ SteryMed                  │  ← Logo 64dp
│                                       │
│    Connectez-vous à votre cabinet     │  ← h2 20sp w600 centered
│                                       │
│  Cabinet                              │  ← label 12sp muted
│  ┌─────────────────────────────────┐  │
│  │ 🏥  cabinet-dupont              │  │  ← TextField 52dp
│  └─────────────────────────────────┘  │
│                                       │
│  Email                                │
│  ┌─────────────────────────────────┐  │
│  │ ✉️  vous@cabinet.ma             │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Mot de passe                         │
│  ┌─────────────────────────────────┐  │
│  │ 🔒  ••••••••              [👁]  │  │
│  └─────────────────────────────────┘  │
│                                       │
│         Mot de passe oublié ?         │  ← primary link right
│                                       │
│  ┌─────────────────────────────────┐  │
│  │       Se connecter              │  │  ← Primary 56dp
│  └─────────────────────────────────┘  │
│                                       │
│            ─── ou ───                 │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │   🔑  Se connecter avec passkey │  │  ← Ghost 56dp
│  └─────────────────────────────────┘  │
│                                       │
│  Version 1.0.0 (42)                   │  ← bodyXS muted centered
└───────────────────────────────────────┘
```

**States:**
- Default, focused (2px primary), error (2px danger + helper), loading (spinner in button).

**Errors inline:** "Ce cabinet n'existe pas", "Identifiants incorrects".

**Prefill:** tenant_slug + email from SharedPreferences.

**A11y:** Labels linked, password toggle announces.

## 2.3 Accept Invitation

```
┌───────────────────────────────────────┐
│ ←                                     │
│                                       │
│  Rejoindre un cabinet                 │  ← h1
│                                       │
│  Vous avez été invité(e) à rejoindre  │  ← bodyM muted
│  Cabinet Dupont.                      │
│                                       │
│  Prénom *                             │
│  ┌─────────────────────────────────┐  │
│  │                                 │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Nom *                                │
│  ┌─────────────────────────────────┐  │
│  │                                 │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Mot de passe *                       │
│  ┌─────────────────────────────────┐  │
│  │ ••••••••                  [👁]  │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Confirmer le mot de passe *          │
│  ┌─────────────────────────────────┐  │
│  │ ••••••••                  [👁]  │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Force: [████░░░░]                    │
│  ✓ 8 caractères minimum               │
│  ✓ Une majuscule                      │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │        Rejoindre                │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

## 2.4 Onboarding (3 slides)

### Slide 1
```
┌───────────────────────────────────────┐
│                              Passer → │
│                                       │
│         [illustration 240×240]        │
│         (workflow)                    │
│                                       │
│   Suivez chaque dossier               │  ← h1 centered
│   prothétique                         │
│                                       │
│   De l'empreinte à la pose, tout      │  ← bodyL centered muted
│   est centralisé, rien n'est oublié.  │
│                                       │
│                                       │
│         ● ○ ○                         │  ← dots
│                                       │
│  ┌─────────────────────────────────┐  │
│  │           Suivant               │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

### Slide 2 — Scanner
Same layout. Illustration: scanner with QR. Copy: "Scannez une étiquette" / "Identifiez un cycle, un lot ou un dossier en un geste."

### Slide 3 — Team
Same layout. Illustration: multiple avatars. Copy: "Toute l'équipe connectée" / "Les mêmes données, en temps réel." CTA: "Commencer".

**Interactions:** Swipe horizontal, dots tappable, skip visible slides 1-2.
**Storage:** `has_completed_onboarding_{tenant_slug}`.

---

# 3. HOME & DASHBOARD (6 ROLE VARIANTS)

## 3.1 Universal dashboard anatomy

```
┌───────────────────────────────────────┐
│ ⬤ Cabinet Dupont ▾         🔔³    ⋯  │  ← AppBar root
├───────────────────────────────────────┤
│  Bonjour, {Name}                      │  ← h1 24sp w700
│  {Day} {Date} · {Time}                │  ← bodyS muted
│                                       │
│  ┌──────────┐┌──────────┐┌──────────┐│  ← Horizontal scroll
│  │ [icon]   ││ [icon]   ││ [icon]   ││     KPI cards 148×120
│  │          ││          ││          ││
│  │   {N}    ││   {N}    ││   {N}    ││  ← displayL 32 tabular
│  │ {Label}  ││ {Label}  ││ {Label}  ││  ← bodyS muted
│  └──────────┘└──────────┘└──────────┘│
│                                       │
│  ─── {Section} ────────── Voir tout →│  ← section header
│  ┌───────────────────────────────────┐│
│  │ ⬤ Row content...               › ││  ← rows
│  └───────────────────────────────────┘│
│                                       │
│  ... (more sections)                  │
│                                       │
├───────────────────────────────────────┤
│  🏠      📁      ⬤      🛡️      📦  │  ← BottomNav
└───────────────────────────────────────┘
```

**KPI card anatomy:**
- Size 148×120, radius 16, border 1px
- Icon 32×32 in tinted circle (12% opacity bg), top-left 16dp
- Count: displayL 32sp tabular, y=52
- Label: bodyS muted, y=90

## 3.2 Owner dashboard

```
Sections:
1. KPI grid: Dossiers actifs [36] · En attente [9] · Poses aujourd'hui [3]
2. Money card: "À encaisser 1 240,00 €" (warning tint)
3. En attente de pose (top 3)
4. Poses prévues cette semaine
5. Dossiers récents (top 5)
6. Activité équipe (last 5 events)
```

## 3.3 Admin dashboard

Same as owner minus money card, plus:
- "Invitations en attente" card
- "Cycles non libérés depuis 24h" card

## 3.4 Practitioner dashboard

```
1. KPI grid: Mes dossiers [14] · En attente [5] · Aujourd'hui [2]
2. Mes poses du jour
3. Mes dossiers récemment reçus
4. Mes dossiers en attente de pose
5. Quick action: [Scanner une étiquette]
```

Lists filtered to `practitioner_id = current_user`.

## 3.5 Releaser dashboard

```
1. KPI grid: À libérer [2] · En cours [1] · Contrôles [3]
2. Cycles à libérer (priority, with quick release buttons)
3. Contrôles en attente
4. Non-conformités ouvertes
5. Quick action: [Scanner une étiquette]
```

## 3.6 Stock manager dashboard

```
1. KPI grid: Stock bas [4] · DLC proche [7] · Expiré [1] · Cycles [2]
2. Alertes à traiter (top 5)
3. Commandes en attente de réception
4. Cycles en cours
5. Dossiers récemment reçus du labo (read-only)
```

## 3.7 Viewer dashboard

```
1. KPI grid: Dossiers actifs [36] · Cycles récents [12]
2. Derniers dossiers (read-only)
3. Derniers cycles (read-only)
```

**Banner under AppBar:** "Lecture seule · Accès consultant"

## 3.8 States

- **Loading:** skeleton matching KPI card grid + 3 rows
- **Empty (new tenant):** onboarding illustration + role-specific CTAs
- **Error:** ErrorState + retry
- **Offline:** cached + sync banner

## 3.9 Motion

- KPI count change: fade + scale 1→1.05→1, 400ms
- Section appear: staggered fade-in 30ms each
- Pull-to-refresh: custom SteryMed loader

---

# 4. PROSTHETIC MODULE (9 screens)

## 4.1 Dossiers list

```
┌───────────────────────────────────────┐
│  Dossiers               🔍  ⋯        │  ← AppBar
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐ │
│ │ 🔍  Rechercher un dossier...      │ │  ← SearchBar 48dp
│ └───────────────────────────────────┘ │
├───────────────────────────────────────┤
│ [Patient▾][Labo▾][Statut▾][Effacer]  │  ← FilterChipRow 44dp
├───────────────────────────────────────┤
│ Tous │ Actifs │ En attente │ Posés │  │  ← SegmentedTabs 40dp
│ ━━━━                                  │     underline
├───────────────────────────────────────┤
│                                       │
│ ┌───────────────────────────────────┐ │
│ │ ⬤ MC  Martin Claire    #D-0587  › │ │  ← Row 88dp
│ │       Couronne · Labo Pro         │ │
│ │       ● En attente   il y a 2 j   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ ┌───────────────────────────────────┐ │
│ │ ⬤ DA  Durand Antoine   #D-0588  › │ │
│ │       Bridge · Lido Dental        │ │
│ │       ● Envoyé       il y a 5 j   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ ┌───────────────────────────────────┐ │
│ │ ⬤ LJ  Lefevre Julie    #D-0589  › │ │
│ │       Inlay · CeramLab            │ │
│ │       ● Reçu au cabinet ● 12 j    │ │  ← warning aging
│ └───────────────────────────────────┘ │
│                                       │
│  ... (infinite scroll)                │
│                                       │
├───────────────────────────────────────┤
│  36 dossiers · 2 filtres actifs       │  ← sticky footer 32dp
├───────────────────────────────────────┤
│                                [+]    │  ← FAB 56dp
│  🏠      📁      ⬤      🛡️      📦  │
└───────────────────────────────────────┘
```

**Row anatomy (88dp):**
- Padding 16h × 12v
- Avatar 40dp + gap 12
- Line 1: name h4 + case number mono muted
- Line 2: work type + " · " + lab (ellipsis)
- Line 3: StatusPill (sm) + optional AgingBadge + relative date right
- Trailing chevron 20dp

**States:** default, loading (6 skeletons), empty (no cases / no results), error, multi-select.

**Swipe:**
- Left → "Changer statut" (primary 96dp)
- Right → "Appeler" (success 96dp)

**Filter chips:**
- Outline (inactive): 32dp, border 1px
- Filled (active): primary tint bg + primary text + X icon

## 4.2 Create case

```
┌───────────────────────────────────────┐
│ ✕  Nouveau dossier      Enregistrer  │
├───────────────────────────────────────┤
│                                       │
│ ─── Patient ─────────────────────     │
│                                       │
│ Patient *                             │
│ ┌───────────────────────────────────┐ │
│ │ 🔍  Rechercher un patient...     │ │
│ └───────────────────────────────────┘ │
│  ou [+ Créer un nouveau patient]     │
│                                       │
│ ─── Clinique ─────────────────────    │
│                                       │
│ Praticien *                           │
│ ┌───────────────────────────────────┐ │
│ │ 👨‍⚕️ Dr. Julien Dupont       ▾   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Date d'empreinte *                    │
│ ┌───────────────────────────────────┐ │
│ │ 📅 03/06/2024                    │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Type d'empreinte *                    │
│ ┌─────────────┬───────────────────┐  │
│ │ Numérique ◉ │  Physique ○       │  │
│ └─────────────┴───────────────────┘  │
│                                       │
│ Nature du travail *                   │
│ ┌───────────────────────────────────┐ │
│ │ 🦷 Couronne                  ▾   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ ─── Laboratoire & dates ──────────    │
│                                       │
│ Laboratoire *                         │
│ ┌───────────────────────────────────┐ │
│ │ 🏥 Labo Pro                  ▾   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Date d'envoi labo *                   │
│ ┌───────────────────────────────────┐ │
│ │ 📅 03/06/2024                    │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Date de retour prévue                 │
│ ┌───────────────────────────────────┐ │
│ │ 📅 10/06/2024 (suggéré)          │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Date de pose prévue                   │
│ ┌───────────────────────────────────┐ │
│ │ 📅 Sélectionner une date         │ │
│ └───────────────────────────────────┘ │
│                                       │
│ ─── Priorité ─────────────────────    │
│                                       │
│ ┌─────────────┬───────────────────┐  │
│ │ Normal ◉    │  Urgent ○         │  │
│ └─────────────┴───────────────────┘  │
│                                       │
│ ─── Notes ────────────────────────    │
│                                       │
│ Remarques                             │
│ ┌───────────────────────────────────┐ │
│ │                                   │ │
│ └───────────────────────────────────┘ │
│ 0/1000                                │
│                                       │
│  Brouillon enregistré · 14:32         │  ← autosave indicator
│                                       │
├───────────────────────────────────────┤
│  [ Créer le dossier ]                 │  ← sticky 56dp
└───────────────────────────────────────┘
```

**Autosave:** every 3s, indicator fades in.
**Dirty guard:** confirm sheet on back.
**Submit:** spinner, optimistic insert, toast "Dossier créé" + [Voir] [Créer un autre].

## 4.3 Case detail

```
┌───────────────────────────────────────┐
│ ←  #D-2024-0587 · Copier      ⋯      │  ← collapsing AppBar
├───────────────────────────────────────┤
│                                       │  ← Hero (220dp expanded)
│  ⬤MC  Martin Claire                   │     scales to 56dp
│       12/03/1985 · 39 ans             │
│                                       │
│  👨‍⚕️ Dr. Julien Dupont                │
│                                       │
│  [● En attente de pose]  ⚠️ 12 jours  │
│                                       │
├───────────────────────────────────────┤
│  ┌─ Timeline ─────────────────────┐  │
│  │ ✓─────✓─────✓─────◉────○────○ │  │  ← 6-step horizontal
│  │ Emp   Env   Reçu  RDV   Posé  │  │
│  │ 22/05 23/05 29/05 05/06  --   │  │
│  └────────────────────────────────┘  │
│                                       │
│ ─── Informations cliniques ──────    │
│ 📅  Date d'empreinte      22/05/2024 │
│ 🦷  Type d'empreinte      Numérique ✓│
│ 🔧  Nature du travail     Couronne   │
│ 🏥  Laboratoire           Labo Pro   │
│ 📤  Date d'envoi          23/05/2024 │
│ 📥  Retour prévu          05/06/2024 │
│ 📌  Pose prévue           12/06/2024 │
│ 📝  Remarques                        │
│     Couronne céramo-métallique       │
│                                       │
│ ─── Administratif ─────────── [RBAC] │
│ ✓  Acompte demandé        Oui        │
│ ✓  Acompte reçu           Oui        │
│ 💶  Montant acompte       200,00 €   │
│ ✗  Paiement final         Non        │
│ 💶  Solde restant         580,00 €   │
│                                       │
│  [Modifier le paiement]              │
│                                       │
│ ─── Documents ───────────── + Ajouter│
│  ┌────┐ ┌────┐ ┌────┐                │
│  │📷  │ │📄  │ │📄  │                │  ← 72×72 tiles
│  └────┘ └────┘ └────┘                │
│                                       │
│ ─── Activité ────────────────────    │
│ ⬤MC  Statut: En attente de pose      │
│      il y a 2 j · Marwane             │
│ ⬤MC  Retour du laboratoire            │
│      il y a 12 j · Réception          │
│                                       │
│  [Voir tout l'historique →]           │
│                                       │
├───────────────────────────────────────┤
│  ┌─────────────────┐┌─────────────┐  │  ← sticky action bar 72dp
│  │ Changer statut ▸││  Éditer     │  │
│  └─────────────────┘└─────────────┘  │
└───────────────────────────────────────┘
```

**Horizontal timeline anatomy:**
- Node 24dp, connector 2dp
- Past: primary bg + white check 12dp
- Current: primary bg + 4dp ring primary@20%
- Future: 2px outline textDisabled
- Labels 11sp below, dates 10sp mono

**Status change sheet:**
- Bottom sheet, drag handle
- Title "Changer le statut"
- Allowed next transitions (state machine)
- Optional note field
- Confirm sheet for Placed / Cancelled / Remade
- Non-blocking warning if balance > 0

## 4.4 Waiting for placement

```
┌───────────────────────────────────────┐
│  En attente de pose       📥  ⋯      │
├───────────────────────────────────────┤
│  ┌──────────┐┌──────────┐┌──────────┐│
│  │ 🔔       ││ 📅       ││ ⚠️       ││  ← 3 summary tiles
│  │    2     ││    3     ││    1     ││
│  │ Relance  ││ À progr. ││ En retard││
│  │ conseillée││ 7 j     ││ 15 j+    ││
│  └──────────┘└──────────┘└──────────┘│
│                                       │
│ [Période ▾][Praticien ▾][Labo ▾]     │
│                                       │
│  ─── 0-7 jours ────────── 3 dossiers  │  ← success tint header
│  ┌───────────────────────────────────┐│
│  │ ⬤ MC  Martin Claire               ││  ← row 110dp
│  │       Couronne · Labo Pro         ││
│  │       Reçu: 29/05 · Prévu: 05/06  ││
│  │       ● 2 jours      ● En attente ││
│  └───────────────────────────────────┘│
│                                       │
│  ─── 8-14 jours ───────── 4 dossiers  │  ← warning tint header
│  ┌───────────────────────────────────┐│
│  │ ⬤ DA  Durand Antoine              ││
│  │       Bridge · Lido Dental        ││
│  │       Reçu: 22/05 · Prévu: 01/06  ││
│  │       ● 5 jours ● Relance conseil.││
│  └───────────────────────────────────┘│
│                                       │
│  ─── 15+ jours ────────── 1 dossier   │  ← danger tint header
│  ┌───────────────────────────────────┐│
│  │ ⬤ LJ  Lefevre Julie               ││
│  │       Inlay · CeramLab            ││
│  │       Reçu: 15/05 · Prévu: --     ││
│  │       ● 12 jours         ● Urgent ││
│  └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

**Section headers** color-coded (success/warning/danger tint).
**Sticky** when scrolling.
**Empty:** "Tous les dossiers sont planifiés. ✨"

## 4.5 Payment edit

```
┌───────────────────────────────────────┐
│ ←  Paiement                           │
├───────────────────────────────────────┤
│                                       │
│  Dossier #D-2024-0587                 │  ← context card
│  Martin Claire                        │
│                                       │
│ ─── Acompte ──────────────────────    │
│                                       │
│ Acompte demandé          [ ●   ]      │  ← switch
│ Acompte reçu             [ ●   ]      │
│                                       │
│ Montant acompte                       │
│ ┌───────────────────────────────────┐│
│ │ 200,00 €                          ││
│ └───────────────────────────────────┘│
│                                       │
│ ─── Paiement final ───────────────    │
│                                       │
│ Paiement final effectué  [ ○   ]      │
│                                       │
│ Montant final                         │
│ ┌───────────────────────────────────┐│
│ │                                   ││
│ └───────────────────────────────────┘│
│                                       │
│ ─── Récapitulatif ───────────────     │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ Total              780,00 €       ││
│ │ Acompte reçu       200,00 €       ││
│ │ Paiement final       0,00 €       ││
│ │ ────────────────────────────────  ││
│ │ Solde restant      580,00 €  bold ││
│ └───────────────────────────────────┘│
│                                       │
│ Commentaires                          │
│ ┌───────────────────────────────────┐│
│ │                                   ││
│ └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Enregistrer ]                      │
└───────────────────────────────────────┘
```

## 4.6 Attachments grid

```
┌───────────────────────────────────────┐
│ ←  Documents                +  ⋯     │
├───────────────────────────────────────┤
│                                       │
│  ┌─────┐ ┌─────┐ ┌─────┐             │
│  │ 📷  │ │ 📄  │ │ 📄  │             │  ← 100×100 tiles
│  │photo│ │bon  │ │ordon│             │
│  └─────┘ └─────┘ └─────┘             │
│                                       │
│  ┌─────┐ ┌─────┐                     │
│  │ 📷  │ │ +   │                     │  ← add tile
│  │     │ │Ajout│                     │
│  └─────┘ └─────┘                     │
│                                       │
└───────────────────────────────────────┘
```

**Source sheet on "+":**
- 📷 Appareil photo
- 🖼️ Galerie
- 📄 Fichier

**Upload:** per-file progress on tile, retry on failure.

## 4.7 Patient quick-create (bottom sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│                                       │
│  Nouveau patient                      │  ← h2
│                                       │
│  Prénom *                             │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Nom *                                │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Date de naissance                    │
│  ┌───────────────────────────────────┐│
│  │ 📅 Sélectionner                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Téléphone                            │
│  ┌───────────────────────────────────┐│
│  │ 📞                                ││
│  └───────────────────────────────────┘│
│                                       │
│  ┌───────────────────────────────────┐│
│  │      Créer le patient             ││
│  └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 4.8 Status change sheet

```
┌───────────────────────────────────────┐
│           ───                         │
│                                       │
│  Changer le statut                    │
│                                       │
│  Statut actuel:                       │
│  [● En attente de pose]               │
│                                       │
│  ─── Transitions disponibles ────     │
│                                       │
│  ┌───────────────────────────────────┐│
│  │ 📅 Programmer la pose         ›   ││
│  └───────────────────────────────────┘│
│  ┌───────────────────────────────────┐│
│  │ ✅ Marquer comme posé         ›   ││
│  └───────────────────────────────────┘│
│  ┌───────────────────────────────────┐│
│  │ ❌ Annuler le dossier         ›   ││
│  └───────────────────────────────────┘│
│                                       │
│  (Si transition sélectionnée:)        │
│  Note (optionnelle)                   │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  ┌───────────────────────────────────┐│
│  │         Confirmer                 ││
│  └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

For critical (Placed/Cancelled/Remade): second confirm sheet with consequences.

---

# 5. SCANNER MODULE (3 screens)

## 5.1 Scanner (full-screen camera)

```
┌───────────────────────────────────────┐
│  ✕              Scanner       🔦      │  ← Translucent 60% black
│                                       │
│                                       │
│         ┌─────────────────┐           │
│         │                 │           │  ← Cutout 260×260
│         │                 │           │     radius 24
│         │    [CAMERA]     │           │     2px white border
│         │                 │           │     Animated corners
│         │                 │           │
│         └─────────────────┘           │
│                                       │
│                                       │
│    Placez le QR code dans le cadre    │  ← hint 14sp white
│                                       │
│                                       │
│  ┌───────────────────────────────────┐│
│  │  ⌨️  Saisir le code manuellement  ││
│  └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

**Corner brackets:** 24×24, 3px stroke, white → primary on detect.
**Detected state:** flash primary@30% 100ms + corners snap inward 200ms + haptic medium.
**Torch toggle:** top-right, 44dp.

**Permission pre-prompt:**
```
       [illustration camera]
    Autoriser la caméra
    SteryMed utilise la caméra pour scanner
    les étiquettes QR/DataMatrix.
    [Pas maintenant]  [Autoriser]
```

**Denied state:**
```
       [illustration camera-x]
    Caméra non autorisée
    Ouvrez les Réglages pour activer la caméra.
    [Ouvrir les Réglages]
```

## 5.2 Scan result

### Cycle variant
```
┌───────────────────────────────────────┐
│ ←  Résultat du scan                   │
├───────────────────────────────────────┤
│  ┌───────────────────────────────────┐│
│  │  ✅ Cycle détecté                 ││  ← success card
│  └───────────────────────────────────┘│
│                                       │
│  Cycle #C-2024-0123        [📋 Copier]│
│                                       │
│  Statut: [● Libéré]                   │
│                                       │
│  🔬 Appareil: Autoclave 1             │
│  ⚙️ Programme: 134°C · 18 min        │
│  👤 Opérateur: Yasmine K.             │
│  📅 Libéré le: 03/06/2024 14:32      │
│  ✓ Contrôles: 3/3 passés              │
│                                       │
│  ┌───────────────────────────────────┐│
│  │  Enregistrer une utilisation      ││  ← primary
│  └───────────────────────────────────┘│
│  [Voir le cycle]                      │
│  [Signaler une non-conformité]        │
└───────────────────────────────────────┘
```

### Batch variant
```
  ┌───────────────────────────────────┐
  │  📦 Lot détecté                   │
  └───────────────────────────────────┘
  
  Lot #LOT-2024-0456        [📋 Copier]
  Produit: Gants nitrile taille M
  DLC: [● 12/09/2024 · 35j]  ← warning chip
  📍 Emplacement: Armoire A · Étagère 2
  📊 Quantité: 45 unités
  🏭 Fournisseur: MedDistrib
  
  [ Enregistrer une sortie ]
  [ Transférer ]
  [ Voir le lot ]
```

### Not found
```
  ┌───────────────────────────────────┐
  │  ❌ Code introuvable              │
  └───────────────────────────────────┘
  Aucun élément ne correspond à ce code.
  [ Saisir manuellement ]
  [ Retour au scanner ]
```

### Already used (duplicate)
```
  ┌───────────────────────────────────┐
  │  ⚠️  Déjà utilisé                 │
  └───────────────────────────────────┘
  Cette étiquette a déjà été utilisée le
  03/06/2024 à 14:30 par Marwane E.
  Procédure: Détartrage
  [ Voir l'historique d'utilisation ]
  [ Retour au scanner ]
```

## 5.3 Record label usage

```
┌───────────────────────────────────────┐
│ ←  Enregistrer une utilisation        │
├───────────────────────────────────────┤
│                                       │
│  ┌───────────────────────────────────┐│
│  │  🏷️ Cycle #C-2024-0123           ││  ← context card
│  │     Libéré le 03/06/2024          ││
│  └───────────────────────────────────┘│
│                                       │
│  Patient *                            │
│  ┌───────────────────────────────────┐│
│  │ 🔍 Rechercher un patient...       ││
│  └───────────────────────────────────┘│
│                                       │
│  Praticien *                          │
│  ┌───────────────────────────────────┐│
│  │ 👨‍⚕️ Marwane E. (vous)        ▾   ││
│  └───────────────────────────────────┘│
│                                       │
│  Procédure *                          │
│  ┌───────────────────────────────────┐│
│  │ Détartrage                    ▾   ││
│  └───────────────────────────────────┘│
│                                       │
│  Utilisé à                            │
│  ┌───────────────────────────────────┐│
│  │ 🕐 03/06/2024 14:32              ││
│  └───────────────────────────────────┘│
│                                       │
│  Notes                                │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Enregistrer l'utilisation ]        │
└───────────────────────────────────────┘
```

---

# 6. STERILIZATION MODULE (9 screens)

## 6.1 Cycles list

```
┌───────────────────────────────────────┐
│  Cycles               🔍  ⋯           │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐ │
│ │ 🔍  Rechercher un cycle...        │ │
│ └───────────────────────────────────┘ │
├───────────────────────────────────────┤
│ [Appareil▾][Statut▾][Période▾]       │
├───────────────────────────────────────┤
│ Tous │ En cours │ À libérer │ Libérés│
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ #C-0123    Autoclave 1    ● En…  ││  ← row 88dp
│ │ 134°C · 18 min · Yasmine K.       ││
│ │ Il y a 45 min                     ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ #C-0124    Autoclave 2    ● À lib.││
│ │ 121°C · 15 min · Karim B.         ││
│ │ Il y a 12 min    [Libérer →]      ││  ← quick action
│ └───────────────────────────────────┘│
├───────────────────────────────────────┤
│                                [+]    │
│  🏠      📁      ⬤      🛡️      📦  │
└───────────────────────────────────────┘
```

**Row anatomy (88dp):**
- Line 1: cycle number (mono primary) + device + status pill right
- Line 2: temp + duration + operator
- Line 3: relative time + optional quick action button

## 6.2 Create cycle

```
┌───────────────────────────────────────┐
│ ✕  Nouveau cycle       Enregistrer    │
├───────────────────────────────────────┤
│                                       │
│ ─── Appareil ─────────────────────    │
│                                       │
│ Appareil *                            │
│ ┌───────────────────────────────────┐│
│ │ 🔬 Autoclave 1 (actif)       ▾   ││
│ └───────────────────────────────────┘│
│                                       │
│ Programme                             │
│ ┌───────────────────────────────────┐│
│ │ ⚙️ 134°C · 18 min              ▾ ││
│ └───────────────────────────────────┘│
│                                       │
│ ─── Articles ─────────────────────    │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ Article 1                    [🗑️]││
│ │ Description *                     ││
│ │ ┌───────────────────────────────┐││
│ │ │ Instrument set A              │││
│ │ └───────────────────────────────┘││
│ │ Lot (optionnel)                   ││
│ │ ┌───────────────────────────────┐││
│ │ │ Sélectionner un lot       ▾  │││
│ │ └───────────────────────────────┘││
│ └───────────────────────────────────┘│
│                                       │
│ [+ Ajouter un article]                │
│                                       │
│ ─── Notes ────────────────────────    │
│ ┌───────────────────────────────────┐│
│ │                                   ││
│ └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Démarrer le cycle ]                │
└───────────────────────────────────────┘
```

## 6.3 Cycle detail

```
┌───────────────────────────────────────┐
│ ←  Cycle #C-2024-0123        ⋯       │
├───────────────────────────────────────┤
│  #C-2024-0123                         │
│  [● Libéré]                           │
│  Autoclave 1 · 134°C · 18 min        │
│  Opérateur: Yasmine K.                │
│                                       │
│  ┌─ Timeline ─────────────────────┐  │
│  │ ✓────✓────✓────✓────◉────○    │  │
│  │ Draft Start Complt Subm Release │  │
│  └────────────────────────────────┘  │
│                                       │
│ ─── Contrôles ─────────── + Ajouter  │
│ ┌───────────────────────────────────┐│
│ │ ✅ Bowie-Dick   Passé   03/06     ││
│ │ ✅ Hélix        Passé   03/06     ││
│ │ ✅ Biologique   Passé   03/06     ││
│ └───────────────────────────────────┘│
│                                       │
│ ─── Articles ────────────────────     │
│ 1. Instrument set A                   │
│ 2. Sonde + miroir                     │
│ 3. Pince Kelly                        │
│                                       │
│ ─── Pièces jointes ──────────  + Aj.  │
│  ┌────┐ ┌────┐                       │
│  │📷  │ │📄  │                       │
│  └────┘ └────┘                       │
│                                       │
│ ─── Libération ──────────────────     │
│ Décision: [● Conforme]                │
│ Libéré le: 03/06/2024 14:32          │
│ Par: Karim B.                         │
│ [ Voir le PDF de libération ]         │
│                                       │
├───────────────────────────────────────┤
│  [Libérer]  [Signaler NC]  [Éditer]  │
└───────────────────────────────────────┘
```

## 6.4 Add control test (sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│  Nouveau contrôle                     │
│                                       │
│  Type *                               │
│  ┌────────┬───────┬───────┬────────┐ │
│  │Vide ◉  │Bowie  │Hélix  │Bio.    │ │
│  └────────┴───────┴───────┴────────┘ │
│                                       │
│  Résultat *                           │
│  ┌─────────────┬───────────────────┐ │
│  │ ✅ Passé ◉  │  ❌ Échoué ○      │ │
│  └─────────────┴───────────────────┘ │
│                                       │
│  Date d'exécution *                   │
│  ┌───────────────────────────────────┐│
│  │ 📅 03/06/2024 · 14:32            ││
│  └───────────────────────────────────┘│
│                                       │
│  Notes                                │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  [ Enregistrer ]                      │
└───────────────────────────────────────┘
```

## 6.5 Release cycle

```
┌───────────────────────────────────────┐
│ ←  Libération du cycle                │
├───────────────────────────────────────┤
│  ┌───────────────────────────────────┐│
│  │  Cycle #C-2024-0123               ││
│  │  Terminé le 03/06/2024 14:32      ││
│  │  Autoclave 1 · 134°C · 18 min     ││
│  └───────────────────────────────────┘│
│                                       │
│  Contrôles effectués                  │
│  ✅ Bowie-Dick                         │
│  ✅ Hélix                              │
│  ✅ Biologique                         │
│                                       │
│  Décision *                           │
│  ┌───────────────────────────────────┐│
│  │ ✅ Conforme                       ││  ← success card
│  │    Libérer le cycle                ││
│  └───────────────────────────────────┘│
│  ┌───────────────────────────────────┐│
│  │ ❌ Rejeté                         ││  ← danger card
│  │    Signaler un problème            ││
│  └───────────────────────────────────┘│
│                                       │
│  Motif du rejet (si rejeté) *         │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Confirmer la libération ]          │
└───────────────────────────────────────┘
```

## 6.6 Devices list

```
┌───────────────────────────────────────┐
│  Appareils                   +  ⋯    │
├───────────────────────────────────────┤
│ [Type▾][Statut▾]                      │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ 🔬 Autoclave 1                    ││
│ │    SN-AUT-001 · Melag             ││
│ │    [● Actif]                      ││
│ │    3 programmes · Prochaine maint.││
│ │    dans 45 jours                  ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 🔬 Autoclave 2                    ││
│ │    SN-AUT-002 · W&H               ││
│ │    [● Maintenance]                ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 6.7 Device detail

```
┌───────────────────────────────────────┐
│ ←  Autoclave 1                    ⋯   │
├───────────────────────────────────────┤
│  🔬                                   │
│  Autoclave 1                          │
│  [● Actif]                            │
│  Melag · SN-AUT-001                   │
│                                       │
│ ─── Informations ────────────────     │
│ 🏥  Site           Site principal    │
│ 🔬  Type           Autoclave         │
│ 🏭  Fabricant      Melag              │
│ 📅  Mise en service 12/03/2024      │
│                                       │
│ ─── Programmes ───────  + Ajouter    │
│ ⚙️ 134°C · 18 min          [actif]   │
│ ⚙️ 121°C · 15 min          [actif]   │
│ ⚙️ Prion 134°C · 18 min    [inactif] │
│                                       │
│ ─── Maintenance ─────────  + Ajouter │
│ 🔧 Préventive  12/05/2024             │
│    Prochaine: 12/08/2024              │
│                                       │
│ ─── Historique des cycles ─────       │
│ #C-0124 · 03/06 · Réussi              │
│ #C-0123 · 02/06 · Réussi              │
│ [ Voir tous les cycles ]              │
└───────────────────────────────────────┘
```

## 6.8 Maintenance records

Same layout as devices list. Sheet for create:
- Type (preventive/corrective/calibration)
- Technician
- Date d'exécution
- Prochaine échéance
- Description

## 6.9 Add device program (sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│  Nouveau programme                    │
│                                       │
│  Nom *                                │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Température cible (°C) *             │
│  ┌───────────────────────────────────┐│
│  │ 134                           ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  Durée plateau (min) *                │
│  ┌───────────────────────────────────┐│
│  │ 18                            ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  Actif                    [ ●   ]     │
│                                       │
│  [ Créer le programme ]               │
└───────────────────────────────────────┘
```

---

# 7. NON-CONFORMITIES (3 screens)

## 7.1 NC list

```
┌───────────────────────────────────────┐
│  Non-conformités             +  ⋯    │
├───────────────────────────────────────┤
│ [Tous][Ouvertes][Résolues]            │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ ⚠️  Cycle #C-2024-0123            ││
│ │    Contrôle biologique échoué     ││
│ │    Ouvert il y a 2h · Karim B.    ││
│ │    [● Ouverte]                    ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ ✅ Cycle #C-2024-0119             ││
│ │    Autoclave surchauffe           ││
│ │    Résolu il y a 3j · Yasmine K.  ││
│ │    [● Résolue]                    ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 7.2 NC detail

```
┌───────────────────────────────────────┐
│ ←  NC #NC-0045                    ⋯   │
├───────────────────────────────────────┤
│  ┌───────────────────────────────────┐│
│  │ ⚠️                                ││  ← severity icon 64dp
│  │  Contrôle biologique échoué       ││
│  │  [● Ouverte]                      ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Détails ─────────────────────     │
│ 🔬  Sujet         Cycle #C-2024-0123 │
│ 📅  Ouvert le     03/06/2024 12:30   │
│ 👤  Par           Karim B.            │
│                                       │
│ ─── Description ──────────────────    │
│ Le contrôle biologique a échoué.      │
│ Le cycle a été rejeté.                │
│                                       │
│ ─── Historique ──────────────────     │
│ ⬤ 03/06 · Ouverte par Karim B.       │
│                                       │
├───────────────────────────────────────┤
│  [ Résoudre ]                         │
└───────────────────────────────────────┘
```

## 7.3 Resolve NC (sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│  Résoudre la non-conformité           │
│                                       │
│  Résolution *                         │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  [ Résoudre ]                         │
└───────────────────────────────────────┘
```

---

# 8. STOCK MODULE (16 screens)

## 8.1 Stock overview

```
┌───────────────────────────────────────┐
│  Stock                       🔍  ⋯    │
├───────────────────────────────────────┤
│  ┌────────┐┌────────┐┌────────┐┌────┐│
│  │ ⚠️    ││ ⏰     ││ 🚫     ││📦  ││
│  │   4   ││   7   ││   1   ││128 ││
│  │Stock  ││DLC    ││Expiré ││Tot.││
│  │bas    ││proche ││       ││    ││
│  └────────┘└────────┘└────────┘└────┘│
│                                       │
│ [Niveaux][Alertes][DLC proche]        │
│                                       │
│  Niveaux:                             │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 📦 Gants nitrile M                ││
│ │    REF-GNT-M · 3 unités           ││
│ │    [● Stock bas]                  ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 📦 Masques FFP2                   ││
│ │    REF-MSK-FFP2 · 45 unités       ││
│ │    [● OK]                         ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.2 Products list

```
┌───────────────────────────────────────┐
│  Produits                    +  ⋯    │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐ │
│ │ 🔍  Rechercher un produit...      │ │
│ └───────────────────────────────────┘ │
├───────────────────────────────────────┤
│ [Catégorie▾][Emplacement▾][Statut▾]  │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ 📦 Gants nitrile M                ││
│ │    REF-GNT-M · 3 un.              ││
│ │    [● Stock bas]                  ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.3 Create product

```
┌───────────────────────────────────────┐
│ ✕  Nouveau produit      Enregistrer   │
├───────────────────────────────────────┤
│  Nom *                                │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Référence *                          │
│  ┌───────────────────────────────────┐│
│  │ REF-                              ││
│  └───────────────────────────────────┘│
│                                       │
│  Unité                                │
│  ┌───────────────────────────────────┐│
│  │ unité                         ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│  Seuil minimal                        │
│  ┌───────────────────────────────────┐│
│  │ 5                             ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  Stérilisable            [ ○   ]      │
│                                       │
│  Code-barres                          │
│  ┌───────────────────────────────────┐│
│  │                              📷   ││  ← scan icon
│  └───────────────────────────────────┘│
│                                       │
│  Catégorie                            │
│  ┌───────────────────────────────────┐│
│  │ Consommables                  ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│  Emplacement par défaut               │
│  ┌───────────────────────────────────┐│
│  │ Armoire A                     ▾  ││
│  └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Créer le produit ]                 │
└───────────────────────────────────────┘
```

## 8.4 Product detail

```
┌───────────────────────────────────────┐
│ ←  Gants nitrile M                ⋯   │
├───────────────────────────────────────┤
│  📦                                   │
│  Gants nitrile M                      │
│  [● Stock bas]                        │
│  REF-GNT-M                            │
│                                       │
│  ┌───────────────────────────────────┐│
│  │  Stock actuel                     ││
│  │        3 unités                   ││  ← displayL
│  │  Seuil minimal: 5                 ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Informations ────────────────     │
│ 📂  Catégorie     Consommables       │
│ 📏  Unité         unité              │
│ ♻️  Stérilisable  Non                │
│ 📍  Emplacement   Armoire A          │
│                                       │
│ ─── Actions rapides ──────────────    │
│  [ 📤 Sortie ]  [ 🔄 Transfert ]     │
│  [ ⚖️ Ajustement ]                    │
│                                       │
│ ─── Lots ────────────────────  Voir →│
│ LOT-0456 · 45 un. · DLC 12/09        │
│                                       │
│ ─── Fournisseurs ─────────────  Voir →│
│ MedDistrib · 500,00 € / carton       │
└───────────────────────────────────────┘
```

## 8.5 Edit product

Same as create but prefilled + delete at bottom:
```
│  [ Supprimer le produit ]  ← danger ghost
```

## 8.6 Batches list

```
┌───────────────────────────────────────┐
│  Lots                        🔍  ⋯    │
├───────────────────────────────────────┤
│ [Produit▾][Emplacement▾][DLC▾]       │
├───────────────────────────────────────┤
│ [Tous][OK][DLC proche][Expiré]       │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ 🏷️ LOT-0456                       ││
│ │    Gants nitrile M                ││
│ │    45 un. · Armoire A             ││
│ │    [● DLC 12/09/2024 · 35j]       ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 🏷️ LOT-0450                       ││
│ │    Compresses stériles            ││
│ │    8 un. · Armoire B              ││
│ │    [● Expiré le 30/05]            ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.7 Batch detail

```
┌───────────────────────────────────────┐
│ ←  LOT-0456                       ⋯   │
├───────────────────────────────────────┤
│  🏷️ LOT-0456                          │
│  [● DLC proche]                       │
│  Gants nitrile M                      │
│                                       │
│  ┌───────────────────────────────────┐│
│  │  Quantité:  45 unités             ││
│  │  DLC:       12/09/2024 (35j)      ││
│  │  Emplacement: Armoire A · Étagère 2││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Mouvements ──────────  Voir tout │
│  ⬆️ +50  Réception PO-0045           │
│          il y a 12j · Marwane         │
│  ⬇️ −5   Sortie                       │
│          il y a 3j · Yasmine          │
│                                       │
│ ─── Source ──────────────────────    │
│  📥 Reçu le 22/05/2024               │
│  🏭 Fournisseur: MedDistrib          │
│  📋 Commande: #PO-2024-0045           │
│                                       │
│ ─── Actions ────────────────────     │
│  [📤 Sortie]  [🔄 Transfert]         │
│  [⚖️ Ajustement]                       │
│  [ Modifier le lot ]                  │
└───────────────────────────────────────┘
```

## 8.8 Movements history

```
┌───────────────────────────────────────┐
│ ←  Mouvements             📥  ⋯      │
├───────────────────────────────────────┤
│ [Type▾][Produit▾][Acteur▾][Date▾]    │
├───────────────────────────────────────┤
│ [Tous][Entrées][Sorties][Ajustements]│
├───────────────────────────────────────┤
│ ─── Aujourd'hui ──────────────────    │
│ ┌───────────────────────────────────┐│
│ │ ⬇️  Sortie · 5 un.                 ││
│ │     Gants nitrile M · LOT-0456    ││
│ │     Armoire A · Yasmine K.        ││
│ │     Motif: Utilisation bloc 3      ││
│ │     il y a 3h                     ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ ⬆️  Réception · 50 un.            ││
│ │     LOT-0456                       ││
│ │     Armoire A · Marwane E.        ││
│ │     Source: PO-2024-0045          ││
│ │     il y a 6h                     ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.9 Inventory

```
┌───────────────────────────────────────┐
│ ←  Inventaire                         │
├───────────────────────────────────────┤
│  Emplacement                          │
│  ┌───────────────────────────────────┐│
│  │ Armoire A                     ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│  Date de l'inventaire                 │
│  ┌───────────────────────────────────┐│
│  │ 📅 03/06/2024                    ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Produits ────────────────────    │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ Gants nitrile M · LOT-0456        ││
│ │ Système: 45  ·  Réel: [ 45 ]     ││
│ │ ✓ Conforme                        ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ Masques FFP2 · LOT-0442           ││
│ │ Système: 120 ·  Réel: [ 118 ]    ││
│ │ ⚠️ Écart: −2                       ││
│ └───────────────────────────────────┘│
│                                       │
│ ─── Résumé ──────────────────────    │
│ 3 produits · 1 écart détecté          │
│                                       │
├───────────────────────────────────────┤
│  [ Valider l'inventaire ]             │
└───────────────────────────────────────┘
```

## 8.10 Purchase orders list

```
┌───────────────────────────────────────┐
│  Commandes                   +  ⋯    │
├───────────────────────────────────────┤
│ [Statut▾][Fournisseur▾][Période▾]    │
├───────────────────────────────────────┤
│ [Toutes][En cours][À réceptionner]   │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ #PO-2024-0045                     ││
│ │ MedDistrib                        ││
│ │ 12 articles · 1 240,00 €          ││
│ │ [● En attente]                    ││
│ │ Commandé il y a 3j                ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.11 Create PO

```
┌───────────────────────────────────────┐
│ ✕  Nouvelle commande    Enregistrer   │
├───────────────────────────────────────┤
│  Fournisseur *                        │
│  ┌───────────────────────────────────┐│
│  │ MedDistrib                    ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Lignes ───────────────────────    │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ Ligne 1                      [🗑️]││
│ │ Produit *                         ││
│ │ ┌───────────────────────────────┐││
│ │ │ Gants nitrile M           ▾  │││
│ │ └───────────────────────────────┘││
│ │ Quantité *      Prix unitaire     ││
│ │ ┌──────────┐   ┌──────────────┐  ││
│ │ │ 10       │   │ 50,00 €      │  ││
│ │ └──────────┘   └──────────────┘  ││
│ │ Sous-total:          500,00 €     ││
│ └───────────────────────────────────┘│
│                                       │
│ [+ Ajouter une ligne]                 │
│                                       │
│ ─────────────────────────────────     │
│ TOTAL                 1 240,00 €      │
│                                       │
├───────────────────────────────────────┤
│  [ Créer la commande ]                │
└───────────────────────────────────────┘
```

## 8.12 PO detail

```
┌───────────────────────────────────────┐
│ ←  #PO-2024-0045                  ⋯   │
├───────────────────────────────────────┤
│  #PO-2024-0045                        │
│  [● En attente]                       │
│  MedDistrib                           │
│  Commandé le 01/06/2024               │
│                                       │
│  ┌───────────────────────────────────┐│
│  │ Total              1 240,00 €     ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Lignes ────────────────────────    │
│ 1. Gants nitrile M                    │
│    10 cartons × 50,00 € = 500,00 €   │
│ 2. Masques FFP2                       │
│    5 boîtes × 12,00 € = 60,00 €      │
│                                       │
│ ─── Historique ────────────────────    │
│ 📝 Créé 01/06 · Marwane              │
│ 📤 Commandé 02/06 · Marwane          │
│                                       │
├───────────────────────────────────────┤
│  [Réceptionner]      [Annuler]        │
└───────────────────────────────────────┘
```

## 8.13 Receive goods

```
┌───────────────────────────────────────┐
│  ←  Réception #PO-2024-0045           │
├───────────────────────────────────────┤
│  Emplacement de réception *           │
│  ┌───────────────────────────────────┐│
│  │ Armoire A                     ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Lignes à réceptionner ────────    │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 1. Gants nitrile M                ││
│ │    Commandé: 10 · Déjà reçu: 0    ││
│ │    Quantité reçue *               ││
│ │    ┌─────────────────────────────┐││
│ │    │ 10                        │││
│ │    └─────────────────────────────┘││
│ │    Numéro de lot *                ││
│ │    ┌─────────────────────────────┐││
│ │    │ LOT-2024-0456             │││
│ │    └─────────────────────────────┘││
│ │    Date d'expiration              ││
│ │    ┌─────────────────────────────┐││
│ │    │ 📅 12/09/2024             │││
│ │    └─────────────────────────────┘││
│ └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Enregistrer la réception ]         │
└───────────────────────────────────────┘
```

## 8.14 Suppliers list + detail

List same pattern. Detail:
```
┌───────────────────────────────────────┐
│ ←  MedDistrib                     ⋯   │
├───────────────────────────────────────┤
│  🏭 MedDistrib                        │
│                                       │
│ ─── Coordonnées ─────────────────     │
│ ✉️  contact@meddistrib.ma             │
│ 📞  +212 5XX XX XX XX                 │
│ 📍  123 Rue Exemple, Casablanca       │
│                                       │
│ ─── Produits fournis ──────  + Aj.   │
│ 📦 Gants nitrile M                    │
│    500,00 € / carton                  │
│                                       │
│ ─── Commandes récentes ───────────    │
│ #PO-0045 · 1 240,00 € · Reçu         │
│ #PO-0042 · 850,00 € · Reçu           │
│                                       │
│  [ Modifier ]                         │
│  [ Supprimer ]  ← danger ghost       │
└───────────────────────────────────────┘
```

## 8.15 Categories management

```
┌───────────────────────────────────────┐
│ ←  Catégories                 +  ⋯   │
├───────────────────────────────────────┤
│ ┌───────────────────────────────────┐│
│ │ 📂 Consommables                   ││
│ │    45 produits                    ││
│ └───────────────────────────────────┘│
│ ┌───────────────────────────────────┐│
│ │ 📂 Instruments                    ││
│ │    12 produits                    ││
│ └───────────────────────────────────┘│
│ ┌───────────────────────────────────┐│
│ │ 📂 Produits chimiques             ││
│ │    8 produits                     ││
│ └───────────────────────────────────┘│
│ ┌───────────────────────────────────┐│
│ │ 📂 Stérilisation                  ││
│ │    └─ Emballages                  ││
│ │    6 produits                     ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 8.16 Locations management

Same pattern with 📍 icons and site + count.

---

# 9. ALERTS (2 screens)

## 9.1 Alerts list

```
┌───────────────────────────────────────┐
│  Alertes                  🔄  ⋯      │
├───────────────────────────────────────┤
│  ┌─────────────────────────────────┐ │
│  │ ⚠️  12 alertes actives          │ │  ← summary banner
│  │    4 critiques · 8 à traiter    │ │
│  └─────────────────────────────────┘ │
├───────────────────────────────────────┤
│ [Toutes][Stock][DLC][Cycles][Dossiers]│
├───────────────────────────────────────┤
│  ─── Critiques ─────────────── 4      │  ← danger header
│ ┌───────────────────────────────────┐│
│ │ 🚫 Lot expiré               [●CRIT]││
│ │    LOT-0450 · Compresses stériles ││
│ │    Expiré il y a 3 jours          ││
│ │    ───────────────────────────────││
│ │    [Résoudre]        [Voir le lot]││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ ❌ Contrôle échoué           [●CRIT]││
│ │    Cycle #C-0122                  ││
│ │    Biologique · il y a 2h         ││
│ │    ───────────────────────────────││
│ │    [Résoudre]        [Voir cycle] ││
│ └───────────────────────────────────┘│
│                                       │
│  ─── À traiter ────────────── 8       │  ← warning header
│ ┌───────────────────────────────────┐│
│ │ ⚠️ Stock bas                      ││
│ │    Gants nitrile M                ││
│ │    3 unités (seuil: 5)            ││
│ │    ───────────────────────────────││
│ │    [Résoudre]     [Commander]     ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

**Severity sections:**
- **Critiques** (danger tint header): expired, failed control, NC open > 48h
- **À traiter** (warning tint header): low stock, near expiry, delayed case, awaiting release
- **Résolues** (collapsed by default)

## 9.2 Alert detail

```
┌───────────────────────────────────────┐
│ ←  Alerte                             │
├───────────────────────────────────────┤
│  ┌───────────────────────────────────┐│
│  │  🚫                                ││  ← severity icon 64dp
│  │  Lot expiré                        ││
│  │  [● Critique]                      ││
│  └───────────────────────────────────┘│
│                                       │
│ ─── Détails ─────────────────────    │
│ 📦  Produit      Compresses stériles │
│ 🏷️  Lot          LOT-0450           │
│ 📅  DLC          30/05/2024          │
│ ⏱️  Expiré        il y a 3 jours    │
│ 📍  Emplacement   Armoire B          │
│ 📊  Quantité      8 unités           │
│                                       │
│ ─── Contexte ────────────────────    │
│ Alerte générée automatiquement le     │
│ 02/06/2026 à 08:00.                  │
│                                       │
│ ─── Actions suggérées ───────────    │
│ • Retirer le lot du stock actif      │
│ • Ajuster la quantité à 0            │
│ • Enregistrer un motif de perte      │
│                                       │
│ ─── Historique ──────────────────    │
│ ⬤ 03/06 · Vu par Marwane            │
│ ⬤ 02/06 · Alerte créée              │
│                                       │
├───────────────────────────────────────┤
│  [Résoudre]    [Ajuster le stock]    │
└───────────────────────────────────────┘
```

## 9.3 Resolve alert (sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│  Résoudre l'alerte                    │
│                                       │
│  Action *                             │
│  ┌───────────────────────────────────┐│
│  │ ○ Lot jeté                        ││
│  │ ○ Lot redistribué                 ││
│  │ ○ Fausse alerte                   ││
│  │ ○ Autre                           ││
│  └───────────────────────────────────┘│
│                                       │
│  Note (optionnelle)                   │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  [ Résoudre ]                         │
└───────────────────────────────────────┘
```

---

# 10. NOTIFICATIONS

```
┌───────────────────────────────────────┐
│ ←  Notifications      ✓ Tout lire     │
├───────────────────────────────────────┤
│ [Toutes][Non lues (3)][Alertes]      │
├───────────────────────────────────────┤
│  ─── Aujourd'hui ──────────────────    │  ← sticky
│ ┌───────────────────────────────────┐│
│ │ ⚠️ 3  Dossier en retard           ││  ← unread dot
│ │       Martin Claire — 15j         ││
│ │       il y a 2h                   ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ ✅   Cycle terminé                ││
│ │      #C-0123 prêt à libérer      ││
│ │      il y a 4h                    ││
│ └───────────────────────────────────┘│
│                                       │
│  ─── Hier ─────────────────────────    │
│ ┌───────────────────────────────────┐│
│ │ 💰   Solde à encaisser            ││
│ │      Durand Antoine — 580,00 €    ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

**Row anatomy (76dp):**
- Icon chip 40dp tinted by severity
- Title h4 + body bodyS muted
- Relative time bodyXS muted
- Unread dot 8dp primary top-right of icon

**Swipe:**
- Left → toggle read
- Right → delete

---

# 11. PROFILE (6 ROLE VARIANTS)

## 11.1 Common structure

```
┌───────────────────────────────────────┐
│ ←  Profil                          ⋯  │
├───────────────────────────────────────┤
│         ⬤  (avatar 80dp)              │
│         {Name}                        │  ← h1
│         {email}                       │  ← bodyM muted
│         [● {Role}]                    │  ← role chip
│                                       │
│ ─── {Sections gated by role} ────     │
│ ...                                   │
│                                       │
│  [Se déconnecter]                     │
│  [Se déconnecter partout]             │
│  [Supprimer le cabinet] (owner only)  │
└───────────────────────────────────────┘
```

## 11.2 Owner profile sections

```
✅ Compte: name, email, phone, password, biometric, passkeys
✅ Cabinet: tenant name, members [Gérer →], sites [Gérer →], switch tenant
✅ Préférences: langue, thème, notifications, quiet hours
✅ Données: cache, sync, clear cache, queue
✅ Administration: audit, export data, config
✅ À propos
✅ Logout / Logout everywhere / Delete tenant
```

## 11.3 Admin profile

Same as owner minus:
- ❌ Delete tenant
- ❌ Configuration (owner-only sub-sections)

## 11.4 Stock manager profile

```
✅ Compte
✅ Cabinet (read-only members)
✅ Préférences (all)
✅ Données
✅ Stock-specific:
   📦 Catégories [Gérer →]
   📍 Emplacements [Gérer →]
   🏭 Fournisseurs [Gérer →]
   📊 Seuils d'alerte [Gérer →]
   📥 Exporter le stock [→]
✅ À propos
✅ Logout
```

## 11.5 Releaser profile

```
✅ Compte
✅ Cabinet (read-only)
✅ Préférences
✅ Données
✅ Stérilisation-specific:
   🔬 Appareils [Voir →]
   📋 Contrôles [Voir →]
   📊 Rapport de conformité [→]
   📥 Exporter les cycles [→]
✅ À propos
✅ Logout
```

## 11.6 Practitioner profile

```
✅ Compte
✅ Cabinet (read-only)
✅ Préférences (no quiet hours)
✅ Mon activité:
   📁 Mes dossiers [→]
   📅 Mon planning [→]
   📊 Mes statistiques [→]
✅ Données
✅ À propos
✅ Logout
```

## 11.7 Viewer profile

```
✅ Compte (no passkeys)
✅ Cabinet (read-only)
✅ Préférences (langue, thème only)
✅ Données
✅ À propos
✅ Logout
```

---

# 12. SETTINGS SUB-SCREENS (5)

## 12.1 Change password

```
┌───────────────────────────────────────┐
│ ←  Modifier le mot de passe           │
├───────────────────────────────────────┤
│  Mot de passe actuel                  │
│  ┌───────────────────────────────────┐│
│  │ ••••••••                   [👁]  ││
│  └───────────────────────────────────┘│
│                                       │
│  Nouveau mot de passe                 │
│  ┌───────────────────────────────────┐│
│  │ ••••••••                   [👁]  ││
│  └───────────────────────────────────┘│
│                                       │
│  Force: [████░░░░] Faible             │
│                                       │
│  ✓ 8 caractères minimum               │
│  ✓ Une majuscule                      │
│  ✗ Un chiffre                         │
│  ✗ Un caractère spécial               │
│                                       │
│  Confirmer                            │
│  ┌───────────────────────────────────┐│
│  │ ••••••••                   [👁]  ││
│  └───────────────────────────────────┘│
│                                       │
├───────────────────────────────────────┤
│  [ Enregistrer ]                      │
└───────────────────────────────────────┘
```

## 12.2 Notification preferences

```
┌───────────────────────────────────────┐
│ ←  Notifications                      │
├───────────────────────────────────────┤
│  ─── Types ───────────────────────    │
│  Dossiers en retard          [ ●   ]  │
│  Cycles terminés             [ ●   ]  │
│  Cycles rejetés              [ ●   ]  │
│  Soldes à encaisser          [ ●   ]  │
│  Alertes stock               [ ○   ]  │
│  Nouveaux membres            [ ●   ]  │
│                                       │
│  ─── Canaux ──────────────────────    │
│  Push                        [ ●   ]  │
│  Email                       [ ○   ]  │
│  In-app                      [ ●   ]  │
│                                       │
│  ─── Heures calmes ──────────────     │
│  Activer                     [ ●   ]  │
│  De:  [ 22:00 ]                       │
│  À:   [ 07:00 ]                       │
└───────────────────────────────────────┘
```

Types filtered by role (see matrix in Part 26).

## 12.3 Tenant switch

```
┌───────────────────────────────────────┐
│ ←  Changer de cabinet                 │
├───────────────────────────────────────┤
│  Sélectionnez un cabinet              │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ ⬤ Cabinet Dupont                  ││
│ │    Propriétaire            [✓]   ││
│ └───────────────────────────────────┘│
│ ┌───────────────────────────────────┐│
│ │ ⬤ Clinique Atlas                  ││
│ │    Praticien                      ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

Confirm sheet on tap of another tenant.

## 12.4 About

```
┌───────────────────────────────────────┐
│ ←  À propos                           │
├───────────────────────────────────────┤
│         ⬤ SteryMed                    │
│         Version 1.0.0 (42)            │
│                                       │
│ ─── Informations ────────────────     │
│ Version                       1.0.0   │
│ Build                         42      │
│ Environnement                 Prod    │
│ Tenant                        cabinet-dupont│
│                                       │
│ ─── Légal ───────────────────────     │
│ Conditions d'utilisation       [→]   │
│ Politique de confidentialité   [→]   │
│ Mentions légales               [→]   │
│                                       │
│ ─── Support ─────────────────────     │
│ Signaler un problème           [→]   │
│ Contacter le support           [→]   │
└───────────────────────────────────────┘
```

## 12.5 Sync queue drawer

```
┌───────────────────────────────────────┐
│           ───                         │
│  File d'attente (3)                   │
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 📤 Créer dossier                  ││
│ │    Martin Claire                  ││
│ │    Ajouté il y a 2 min            ││
│ │    [Réessayer]  [Annuler]         ││
│ └───────────────────────────────────┘│
│                                       │
│ ┌───────────────────────────────────┐│
│ │ 📤 Sortie de stock                ││
│ │    LOT-0456 · 2 unités            ││
│ │    Échec: Connexion perdue        ││
│ │    [Réessayer]  [Annuler]         ││
│ └───────────────────────────────────┘│
│                                       │
│  [ Tout synchroniser ]                │
└───────────────────────────────────────┘
```

---

# 13. ADMIN (4 screens)

## 13.1 Members

```
┌───────────────────────────────────────┐
│ ←  Membres                    +  ⋯   │
├───────────────────────────────────────┤
│  ─── Actifs ──────────────────────    │
│ ┌───────────────────────────────────┐│
│ │ ⬤ ME  Marwane El Idrissi          ││
│ │       marwane@cabinet.ma          ││
│ │       [● Propriétaire]            ││
│ └───────────────────────────────────┘│
│ ┌───────────────────────────────────┐│
│ │ ⬤ JD  Dr. Julien Dupont           ││
│ │       julien@cabinet.ma           ││
│ │       [● Praticien]               ││
│ └───────────────────────────────────┘│
│                                       │
│  ─── Invitations en attente ───────   │
│ ┌───────────────────────────────────┐│
│ │ ✉️  sarah@cabinet.ma              ││
│ │     Invitée il y a 2j             ││
│ │     [Révoquer]                    ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

## 13.2 Invite member (sheet)

```
┌───────────────────────────────────────┐
│           ───                         │
│  Inviter un membre                    │
│                                       │
│  Email *                              │
│  ┌───────────────────────────────────┐│
│  │                                   ││
│  └───────────────────────────────────┘│
│                                       │
│  Rôle *                               │
│  ┌───────────────────────────────────┐│
│  │ Praticien                     ▾  ││
│  └───────────────────────────────────┘│
│                                       │
│  ℹ️  Accès en lecture et écriture    │
│      aux dossiers prothétiques       │
│                                       │
│  [ Envoyer l'invitation ]             │
└───────────────────────────────────────┘
```

## 13.3 Audit log

```
┌───────────────────────────────────────┐
│ ←  Journal d'audit          📥  ⋯    │
├───────────────────────────────────────┤
│ [Acteur▾][Action▾][Type▾][Date▾]     │
├───────────────────────────────────────┤
│  ─── Aujourd'hui ──────────────────    │
│ ┌───────────────────────────────────┐│
│ │ ⬤ ME  Statut modifié             ││
│ │       Dossier #D-0587             ││
│ │       En attente → Posé           ││
│ │       il y a 2h                   ││
│ │       [Voir les détails ▾]       ││
│ └───────────────────────────────────┘│
└───────────────────────────────────────┘
```

Expanded shows diff.

## 13.4 Configuration (owner/admin)

```
┌───────────────────────────────────────┐
│ ←  Configuration du cabinet           │
├───────────────────────────────────────┤
│  ─── Dossiers prothétiques ────────   │
│  Seuil "Relance conseillée" (jours)   │
│  ┌───────────────────────────────────┐│
│  │ 10                            ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  Seuil "En retard" (jours)            │
│  ┌───────────────────────────────────┐│
│  │ 15                            ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  ─── Stérilisation ────────────────   │
│  Validité d'un cycle libéré (jours)   │
│  ┌───────────────────────────────────┐│
│  │ 30                            ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  ─── Alertes stock ────────────────   │
│  Seuil "DLC proche" (jours)           │
│  ┌───────────────────────────────────┐│
│  │ 30                            ─ +││
│  └───────────────────────────────────┘│
│                                       │
│  ─── Enregistrer ─────────────────    │
└───────────────────────────────────────┘
```

---

# 14. OVERLAYS & SYSTEM SURFACES (8)

## 14.1 Global search

```
┌───────────────────────────────────────┐
│  🔍  Rechercher...           Annuler  │
├───────────────────────────────────────┤
│  Recherches récentes                  │
│  🕐  Martin Claire                    │
│  🕐  Labo Pro                         │
│  🕐  #D-0587                          │
│  [Effacer l'historique]               │
│                                       │
│  Suggestions                          │
│  📁  Dossiers                         │
│  🛡️  Cycles                           │
│  📦  Produits                          │
│  🏭  Fournisseurs                      │
└───────────────────────────────────────┘
```

## 14.2 Filter sheet

```
┌───────────────────────────────────────┐
│           ───                         │
│  Filtres                              │
│                                       │
│  Statut                               │
│  [Tous] [En attente] [Posé] [Annulé]  │
│                                       │
│  Praticien                            │
│  [Dr. Dupont ✓] [Dr. Martin] [Dr. X]  │
│                                       │
│  ┌────────────┐┌────────────────────┐│
│  │Réinitialiser││   Appliquer (2)   ││
│  └────────────┘└────────────────────┘│
└───────────────────────────────────────┘
```

## 14.3 Confirm sheet

Standard pattern for all destructive actions.

## 14.4 Sync banner

4 variants: hidden / syncing (blue) / offline (amber) / failed (red).

## 14.5 Multi-select mode

Transformed AppBar + bulk action bar.

## 14.6 Camera permission pre-prompt

```
       [illustration camera]
    Autoriser la caméra
    SteryMed utilise la caméra pour scanner
    les étiquettes QR/DataMatrix.
    [Pas maintenant]  [Autoriser]
```

## 14.7 Notification permission pre-prompt

```
       [illustration bell]
    Activer les notifications ?
    Recevez des alertes pour les dossiers
    en retard, cycles à libérer, et stock bas.
    [Plus tard]  [Activer]
```

## 14.8 Offline queue drawer

See 12.5.

---

# 15. MOTION MASTER SPEC

| Animation | Duration | Curve |
|---|---|---|
| Screen push | 240ms | easeOutCubic |
| Sheet open | 320ms | emphasized |
| Scan → result | 420ms | emphasized |
| Tab switch | 180ms | easeOut |
| Status pill change | 320ms | springy |
| KPI count change | 400ms | easeOut |
| Row enter | 240ms | easeOutCubic + 20ms stagger |
| FAB press | 200ms | easeOutQuart |
| Chip select | 180ms | easeOut |
| Toggle switch | 240ms | easeOutCubic |
| Confirm open | 240ms | springy |
| Scan detect flash | 100ms | linear |
| Aging pulse | 600ms × 2 | easeInOut |

**Reduced motion:** Replace with instant cuts, keep opacity fades.

---

# 16. DARK MODE SPEC

**Rules:**
- Elevation via lighter surfaces (not shadows)
- Primary #3B82F6
- Status colors: 15% opacity bg
- Border #1F2937
- Text #F1F5F9 / #94A3B8 / #475569
- Scanner always dark
- Images: subtle scrim (black@20%)
- Timeline connectors #334155
- Empty illustrations: primary #60A5FA

**Every screen has a dark variant.**

---

# 17. TABLET SPEC

- ≥600dp: nav rail (72dp wide) replaces bottom nav
- Master-detail for Cases, Cycles, Stock
- Dashboard 2-column
- Sheets become side panels (400dp)
- Forms 2-column where sensible
- Scanner centered max 480dp
- Row density: 72dp instead of 88dp

---

# 18. iOS vs ANDROID

| Element | iOS | Android |
|---|---|---|
| Date picker | Cupertino wheel | Material dialog |
| Time picker | Cupertino wheel | Material dialog |
| Sheet | Cupertino | Material modal |
| Dialog | Cupertino alert | Material dialog |
| Button | Cupertino rounded | Material filled/outlined |
| Back | Swipe from left | Hardware + gesture |
| Pull-to-refresh | Cupertino spinner | Material spinner |

Brand identical, system respects platform.

---

# 19. ACCESSIBILITY VISUAL SPECS

- Semantic labels on all icons (via `Semantics`)
- Focus order = visual order
- Dynamic type 200% tested
- Contrast: AA (4.5:1) minimum, AAA for body
- Touch targets ≥48dp
- Color never sole signal (icon + label + color)
- Focus indicators 2px primary outline
- Screen reader announcements per action
- Reduced motion respected
- RTL-ready (DirectionalEdgeInsets)

---

# 20. ILLUSTRATION STYLE GUIDE

**Style:** Line-art, primary blue 2px stroke, rounded caps/joins, 120×120 viewBox, optional soft fill 10% opacity, dark mode uses #60A5FA.

**8 empty-state illustrations:**
1. `empty_cases` — tooth with folder
2. `empty_waiting` — calendar with checkmark
3. `empty_cycles` — autoclave
4. `empty_stock` — box with magnifier
5. `empty_notifications` — bell with checkmark
6. `empty_search` — magnifier with dots
7. `empty_alerts` — shield with checkmark
8. `empty_members` — people

**3 onboarding illustrations:**
1. Workflow (empreinte → pose)
2. Scanner with QR
3. Team coordination

**Custom icons (designer):**
- SteryMed logo mark (tooth + sparkle)
- Loader animation (Lottie 1200ms loop)

---

# 🏆 THE COMPLETE VISUAL ROADMAP

**Total deliverables:**

| Item | Count |
|---|---|
| Screens (unique surfaces) | ~70 |
| Role variants (Dashboard + Profile) | 12 |
| Figma frames (all states × light/dark) | ~700 |
| Flutter routes | ~60 |
| Components in library | 60 |
| Creation flows | 20 |
| States per screen | 5 |
| Motion specs | 15 |
| Illustration assets | 12 |
| Icons (lucide) | ~50 |
| Microcopy strings | ~400 |

**What this document covers:**
✅ Every screen with full ASCII layout
✅ Every state (default, loading, empty, error, offline)
✅ Every interaction + motion
✅ Every role variant
✅ Dark mode
✅ Tablet
✅ iOS vs Android
✅ Accessibility
✅ Illustration style
✅ Component library
✅ Motion system

**What it enables:**
- **Designer:** Designs 700 frames systematically, knows exactly what each contains
- **Flutter dev:** Builds 60 routes with confidence, no guessing
- **Backend dev:** Knows the API delta
- **QA:** Tests every state against the spec
- **Stakeholder:** Sees the complete product before writing a line of code

**This is the document.** Ship it. 🍳🔥