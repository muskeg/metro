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
   Le **+** reste accessible au-dessus d'un rail existant, même pour partir
   dans la direction opposée.
3. Les trains partent dans les deux sens. Réglez leur fréquence, leur vitesse
   et leurs wagons en cliquant sur leur ligne dans le bandeau du bas.
4. Ajoutez une ligne avec **+**, juste après les boutons de lignes dans ce bandeau,
   ou reliez les extrémités d'une ligne
   d'au moins trois stations pour former une boucle.

**Menu → Language** permet de passer de l'anglais au français. Le menu propose
aussi les volumes, le plein écran et la sortie du jeu.
Les commandes restent lisibles sur écran Retina et dans le navigateur.
Les réglages et l'aide s'ouvrent à la demande ; **Close / Échap** les referme
sans interrompre le réseau.
Ces panneaux sont centrés sur l'écran ; tous les réglages restent visibles
sans barre de défilement. Le titre Metro commence à disparaître après
10 secondes et s'efface complètement à 30 secondes, sans revenir.
Son grand format évoque un titre d'ouverture plutôt qu'un élément du menu.
Les lignes occupent un rail fin sur toute la largeur du bas. Leurs réglages
se déplient directement dans ce rail ; toucher à nouveau la ligne les referme.
Le bouton de repli utilise une icône de panneau avec une flèche descendante,
sans texte. Une fois replié, la même icône avec une flèche montante permet
de rouvrir le rail au même endroit, en bas à droite, pour pouvoir cliquer
deux fois sans déplacer le pointeur.
Après huit secondes sans activité,
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

Le remodelage ne change que la section choisie, entre deux points d'ancrage fixes
indiqués par de petits cercles. Les autres coudes restent en place. Les poignées
se placent à côté du rail, même sur une section courte ou verticale. Le point
déplacé suit la grille ; un aperçu rouge explique le blocage près du curseur.

Sans interface, le réseau continue de vivre : déplacez la vue, zoomez ou suivez
une rame sans risquer de modifier la carte. La pause existante est conservée.
La carte n'a pas de bord fixe. Le dézoom descend à **0,08×** (molette ou pincement),
soit environ 5,6 fois plus de largeur visible qu'avant, pour construire de grands
réseaux. Les tracés réels restent à reproduire manuellement : aucun import géographique.
La poignée discrète conserve une grande zone tactile, même sans clavier sur téléphone.
Le suivi d'une rame masque aussi les aperçus et poignées d'édition ; les clics
sur la carte ne la modifient pas. Échap ou déplacer la vue rend l'édition.

**Aide** dans le jeu rappelle les gestes. Supprimer une station reconnecte ses
voisins sur chaque ligne en conservant le tracé. Le **×** au survol d'un rail
(même près d'un coude) supprime la voie et sépare les lignes. Les suppressions
demandent confirmation. Une voie déjà présente entre les voisins est réutilisée ;
une boucle reste fermée tant qu'il reste au moins trois stations.
Les virages conservent leurs coudes serrés d'origine, avec un arrondi local ;
les stations restent sur la grille, sans élargir les courbes pour les centrer.
Les croisements hors station ne sont pas pris en
charge ; utilisez une station commune.
L'aide est une fiche courte. Les actions réussies restent silencieuses :
la carte montre le résultat. Avant la première liaison, un **+** discret
suggère le geste ; pendant le tracé, les destinations valides sont entourées.
Seules les erreurs demandant une action affichent un message.
Les stations reprennent la couleur assombrie de leur ligne. Aux correspondances,
les lignes ajoutées forment des anneaux concentriques ; le centre reste blanc.
Les marqueurs restent opaques : les rames passent naturellement dessous.

### Une circulation régulière

Chaque ligne et chaque sens circulent indépendamment, même aux correspondances.
Plusieurs rames peuvent circuler entre deux stations : leur freinage conserve
une distance sûre. De courtes attentes en station et de petits ajustements de
vitesse corrigent les écarts ; les terminus offrent un temps de récupération.
Aux terminus, les deux voies convergent vers une courte voie commune :
la rame s'arrête, change de cabine puis rejoint la voie de retour.
Une seule rame peut occuper ce raccord à la fois ; aucune voiture ne glisse
latéralement ni ne fait un demi-tour serré. Les boucles ne changent pas.
La cabine s'arrête légèrement avant le marqueur du terminus : la rame et son
quai restent dehors, sans être masqués par le cercle.
Ce retrait s'applique aussi aux arrêts intermédiaires et aux boucles, dans les
deux sens. En mouvement, les trains passent toujours sous les stations.
L'approche des quais freine progressivement sans longue fin de parcours au ralenti,
tout en conservant la marge de sécurité derrière les autres rames.
Les rames ont des cabines aux deux extrémités et des toits métalliques clairs.
Les voitures sont plus élancées : 50 % plus longues, sans élargir les caisses.
Leur longueur réelle détermine les espacements et la capacité de la ligne.
La nuit devient très sombre ; rails lumineux et halos de phares guident le regard.
Le fond évoque une surface mate légèrement texturée, plutôt qu'une table en verre.
L'aube bleutée, le coucher pêche et l'heure bleue encadrent un midi blanc cassé.
Les voies et les rames projettent des ombres discrètes : courtes à midi,
plus longues et de directions opposées au lever/coucher, absentes au milieu de la nuit.
Les stations ne projettent pas d'ombre. Une source lumineuse traverse la vue
de gauche à droite ; l'ombre du tracé complet passe du côté droit au côté gauche.
Les courbes sont subdivisées selon leur courbure pour rester lisses en gros plan.
Aux stations partagées, l'illumination des rails s'interrompt autour du raccord
pour ne pas souligner les superpositions en croix.
Les contrôles restent contrastés et s'estompent moins qu'en plein jour.
En zoom rapproché, portes doubles, ventilation et soufflets articulés se révèlent ;
à l'échelle de la carte, leur silhouette reste sobre.
Lors d'un arrêt en vue rapprochée, un quai continu apparaît le long de la rame.
Sa bordure tactile et ses joints dessinent un petit quai en béton. Les voyageurs,
plus nombreux et plus petits, attendent en groupes irréguliers et suivent des
petits trajets à des rythmes différents, toujours contenus sur le quai.
Ils utilisent aussi la largeur du quai : les sortants poursuivent leur marche
après la descente, et les entrants s'approchent plus tôt, sans prolonger l'arrêt.
Le quai et sa bande tactile suivent une courbe douce dans les virages, sans
marches entre les voitures ni modification du tracé des rails.
Les voitures et cabines sont légèrement plus longues ; leurs proportions et
les espacements restent cohérents. Les halos nocturnes ont des raccords arrondis,
sans coins lumineux carrés.
Le halo garde une largeur régulière dans les virages ; ses contours fusionnés
évitent les replis lumineux à l'intérieur des courbes.
Sa forme suit les voitures même dans les courbes, sans imposer de zones droites
ni modifier les coudes que vous dessinez. Les trains restent visibles.
Des voyageurs descendent puis montent ; ceux qui partent s'effacent sur le quai,
sans courir au loin. Leur vitesse reste limitée, même pendant les arrêts courts.
Les quais s'effacent au départ. L'embarquement peut prolonger l'arrêt minimum de
deux secondes au plus, même quand la vue est dézoomée. Aucun objectif de fréquentation.

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
