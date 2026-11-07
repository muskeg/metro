# Metro

Dessinez un réseau de métro, regardez les rames circuler, prenez votre temps.
Pas de budget, pas d'objectifs imposés : des lignes colorées, une ambiance
jour/nuit et une musique lo-fi originale.

**[Jouer dans le navigateur](https://muskeg.github.io/metro/)** ·
[Commandes](#commandes) · [Développement](#développement) ·
[Déploiement](#github-pages)

| Jour | Nuit |
| --- | --- |
| ![Deux lignes de métro et leurs rames sur la carte de jour](docs/images/metro-day.png) | ![Le même réseau dans l'ambiance nocturne](docs/images/metro-night.png) |

## Pour commencer

1. Survolez la carte : une station fantôme indique où un clic la placera.
2. Survolez une station et glissez son **+** vers une autre pour les relier.
3. Les trains partent dans les deux sens. Réglez leur fréquence, leur vitesse
   et leurs wagons en cliquant sur leur ligne dans le bandeau du bas.
4. Ajoutez une ligne avec **+** dans ce bandeau, ou reliez les extrémités d'une ligne
   d'au moins trois stations pour former une boucle.

**Menu → Language** permet de passer de l'anglais au français. Le menu propose
aussi les volumes, le plein écran et la sortie du jeu.
Les commandes restent lisibles sur écran Retina et dans le navigateur.
Les réglages et l'aide s'ouvrent à la demande ; **Close / Échap** les referme
sans interrompre le réseau.
Les lignes occupent un rail fin sur toute la largeur du bas. Leurs réglages
se déplient directement dans ce rail ; toucher à nouveau la ligne les referme.
Le bouton de repli laisse seulement une petite poignée au bord inférieur ;
touchez cette poignée pour rouvrir le rail. Après huit secondes sans activité,
les commandes s'estompent doucement. Un mouvement ou un toucher les réveille ;
les menus ouverts et les gestes en cours restent visibles.

## Commandes

| Action | Geste |
| --- | --- |
| Déplacer la vue | Glisser à deux doigts ; clic milieu ou Espace + glisser |
| Zoomer | Pincer sur le trackpad ou utiliser la molette |
| Placer une station | Cliquer sur un espace libre, à l'emplacement de l'aperçu |
| Déplacer une station | Glisser son centre |
| Dessiner par étapes | Cliquer sur **+**, fixer des coudes, terminer sur une station |
| Inverser le coude / retirer le dernier | Tab / Retour arrière |
| Remodeler un rail | Glisser un losange au survol |
| Insérer une station | Cliquer sur un rail ou son **+** |
| Supprimer | **×** au survol ou Suppr, puis confirmer |
| Suivre un train | Cliquer sur une motrice ou un wagon |
| Annuler / arrêter le suivi | Échap ; déplacer la vue arrête aussi le suivi |
| Pause / plein écran | P / F11 |
| Regarder sans interface | H ou **Menu → Hide interface** ; toucher la poignée en bas, H ou Échap pour revenir |

Sans interface, le réseau continue de vivre : déplacez la vue, zoomez ou suivez
une rame sans risquer de modifier la carte. La pause existante est conservée.
La poignée discrète conserve une grande zone tactile, même sans clavier sur téléphone.
Le suivi d'une rame masque aussi les aperçus et poignées d'édition ; les clics
sur la carte ne la modifient pas. Échap ou déplacer la vue rend l'édition.

**Aide** dans le jeu rappelle les gestes. Les suppressions séparent les lignes
sans reconnecter les rails. Les croisements hors station ne sont pas pris en
charge ; utilisez une station commune.
L'aide est une fiche courte. Les actions réussies restent silencieuses :
la carte montre le résultat. Avant la première liaison, un **+** discret
suggère le geste ; pendant le tracé, les destinations valides sont entourées.
Seules les erreurs demandant une action affichent un message.
Les stations reprennent la couleur assombrie de leur ligne. Aux correspondances,
les lignes ajoutées forment des anneaux concentriques ; le centre reste blanc.

### Une circulation régulière

Chaque ligne et chaque sens circulent indépendamment, même aux correspondances.
Plusieurs rames peuvent circuler entre deux stations : leur freinage conserve
une distance sûre. De courtes attentes en station et de petits ajustements de
vitesse corrigent les écarts ; les terminus offrent un temps de récupération.
L'approche des quais freine progressivement sans longue fin de parcours au ralenti,
tout en conservant la marge de sécurité derrière les autres rames.

**Intervalle minimum** fixe la fréquence souhaitée. Le maximum de rames reste
réglable, plafonné par la capacité du trajet plutôt que par le nombre de stations.
Survolez ce réglage pour voir la flotte conseillée selon le temps de parcours.
Les rames excédentaires quittent le service au terminus, ou à l'origine d'une boucle.
Les chemins qui convergent en station peuvent se superposer visuellement sans
bloquer les autres lignes ou l'autre sens.

## Développement

Projet Godot 4 / GDScript, vérifié avec **Godot 4.7.2**, moteur **Compatibility**.
Ouvrez [project.godot](./project.godot) dans Godot et appuyez sur **F6** depuis
la scène principale, ou **F5** pour lancer le projet.

Les commandes ci-dessous supposent que `godot` est accessible dans le terminal.
Sur macOS, utilisez au besoin `/Applications/Godot.app/Contents/MacOS/Godot`.
Installez les modèles d'export **de la même version** depuis
**Editor → Manage Export Templates**.

### Exporter

```sh
mkdir -p dist/web
godot --headless --editor --path . --quit
godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
godot --headless --path . --export-release "Web" dist/web/index.html
```

- **Windows** : exécutable x86_64 autonome.
- **macOS** : ZIP contenant une app universelle Intel / Apple Silicon, signée
  ad hoc, non notariée. Gatekeeper peut demander **Ouvrir quand même** dans
  **Réglages Système → Confidentialité et sécurité**.
- **Web** : sans threads, compatible avec GitHub Pages sans en-têtes spéciaux.
  Pour l'essayer : `python3 -m http.server 8000 --directory dist/web`, puis
  ouvrez `http://localhost:8000/`. Un premier clic peut être nécessaire pour le son.
  La musique générée utilise le mode audio Stream dans le navigateur.

Les tests, captures de documentation et exports précédents sont exclus des
builds. Gardez l'import ETC2/ASTC activé pour les exports ARM64.

### Vérifier

```sh
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/schedule_smoke.gd
godot --headless --path . --script res://tests/interface_smoke.gd
godot --headless --path . --script res://tests/audio_smoke.gd
godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
```

Le test visuel nécessite un écran. La liste complète des validations et les
derniers résultats figurent dans [MEMORY.md](./MEMORY.md#validation-and-delivery).

## GitHub Pages

Le workflow [pages.yml](./.github/workflows/pages.yml) :

- vérifie simulation, horaires, audio, interface, traductions et export Web sur les PR vers `main` ;
- publie `dist/web/` à chaque push sur `main` ;
- peut être relancé avec **Actions → Build and deploy Metro to Pages →
  Run workflow**, sur `main`.

Dans **Settings → Pages**, choisissez **GitHub Actions** comme source.
L'URL du site apparaît dans le résultat du déploiement. Le lien en haut de ce
document sera disponible après le premier déploiement réussi.

## Repères du projet

- [scripts/](./scripts/) : interaction, simulation, rendu et audio.
- [tests/](./tests/) : tests de simulation, d'interface et de rendu.
- [translations/ui.csv](./translations/ui.csv) : textes anglais et français.
- [DESIGN.md](./DESIGN.md) : décisions de conception et détails techniques.
- [AGENTS.md](./AGENTS.md) et [MEMORY.md](./MEMORY.md) : workflow et contexte des agents.
