# Metro

Un constructeur de réseau ferroviaire tranquille, natif, réalisé avec Godot 4
et GDScript. Dessinez les tracés ; les rames circulent réellement sur deux voies.

## Lancer

Ouvrez ce dossier dans Godot 4.2 ou plus récent et lancez la scène principale.
Version vérifiée : Godot 4.7.2, moteur de rendu Compatibility. La fenêtre est
redimensionnable ; F11 active le plein écran.

L'interface est en anglais par défaut. **Menu → Language** permet de choisir
**English** ou **Français** sans redémarrer ni modifier le réseau. Ce choix est
mémorisé pour les prochains lancements.

## Construire et modifier

- **Station** : cliquez sur la grille de 48 pixels pour placer une station.
  Cliquez sur un rail pour y insérer une station : toutes les lignes qui le
  partagent sont mises à jour, dans les deux sens. Une insertion trop proche
  d'une station pour la longueur des rames est refusée.
- Survolez une station : son **+** unique permet de relier dans n'importe
  quelle direction, son centre de déplacer, et **×** de supprimer.
  Glissez le **+** vers une autre station : un aperçu élastique calcule un
  tracé propre, horizontal, vertical ou diagonal à 45°, avec coins arrondis.
  Le résultat ne dépend plus de la vitesse ou de la précision du geste.
- Vous pouvez aussi cliquer sur **+**, puis sur les emplacements des coudes,
  et terminer en cliquant sur une station. Relâcher un glissement sur le vide
  fixe aussi un coude et poursuit le dessin par clics. **Tab** ou la poignée
  à deux flèches près du départ inverse l'ordre diagonale/segment droit.
  **Retour arrière** retire le dernier coude fixé et son segment automatique.
- Survolez un rail pour afficher ses **losanges** : glissez un coude pour le
  remodeler sans redessiner toute la liaison. Le losange sous le **+** du rail
  permet aussi d'ajouter un détour sur un segment droit. Les extrémités et les
  coudes éloignés restent fixes ; la modification est validée au relâchement.
- Une ligne se prolonge depuis une de ses extrémités. Avec au moins trois
  stations, reliez ses deux extrémités pour former une boucle. La liaison peut
  être dessinée dans les deux sens. Pour modifier une liaison existante,
  redessinez entre ses deux stations.
- Clic droit ou Échap annule le dessin ou restaure un déplacement en cours.
  Relâcher sur l'interface annule aussi le geste. Un aperçu rouge signale un
  tracé invalide avant validation ; une arrivée refusée reste corrigeable.
  Un remodelage refusé conserve intégralement le rail d'origine.
- Les onglets de lignes permettent de changer la sélection ; **+ Nouvelle**
  crée une autre ligne.
- Glissez le **centre** d'une station pour la déplacer. Le premier coude de
  chaque rail connecté s'adapte ; les coudes éloignés restent en place.
  Les cases occupées, croisements non autorisés et segments trop courts pour
  une rame sont signalés et refusés, sans modification partielle.
- Survolez une station ou un rail et cliquez sur **×** pour supprimer, avec
  confirmation. **Suppr** agit aussi sur la station sélectionnée ou le rail
  survolé. Une station supprimée emporte ses rails ; les lignes sont séparées,
  jamais reconnectées automatiquement. Tous les fragments restent dans les
  onglets, avec leur couleur et leurs réglages. Même une station isolée peut
  redevenir le départ d'une ligne.
- Le **+** contextuel d'un rail permet aussi d'insérer une station sans outil.
  Recliquez sur **Station** pour désactiver les ajouts sur les espaces vides.
- Réglez l'intervalle de dispatch, le maximum de trains (1 à 16, 4 par défaut),
  l'arrêt en station, la vitesse et le nombre de wagons (1 à 6, en plus de la
  motrice) pour la ligne sélectionnée. Abaisser le maximum sous le nombre de
  trains présents redémarre le réseau pour appliquer la limite immédiatement.
- Cliquez sur une motrice ou un wagon pour suivre ce train de près. La molette
  ajuste le zoom ; Échap ou déplacer la vue interrompt le suivi. Modifier le
  réseau ou la composition interrompt aussi le suivi lors du redémarrage.
- Cliquez sur la pastille à côté du nom de la ligne pour choisir sa couleur :
  sélecteur complet et couleurs prédéfinies. La modification est immédiate,
  sur les rails, les rames et l'onglet, sans interrompre la circulation.
- Les contrôles occupent une carte compacte, non toute la hauteur de la
  fenêtre. **Aide** affiche les gestes ; **Menu** ouvre les réglages.
- Molette : zoom. Clic milieu ou Espace + glisser : déplacer la vue. P : pause.
- **Menu** : plein écran, volume général, musique, sons ferroviaires et quitter.

Les trains partent des deux terminus, s'arrêtent aux stations et suivent les
retournements sans se téléporter. Les wagons suivent les virages. L'espacement
tient compte de la rame complète. Les tracés partagés sont décalés par ligne.
Aux stations communes, les trains attendent leur tour avant le croisement ;
le passage reste réservé jusqu'à la sortie du dernier wagon. Les carrefours
proches sont coordonnés ensemble pour éviter un blocage mutuel.
Les retournements aux terminus sont aussi réservés jusqu'au dernier wagon.
Sur une boucle, les rames circulent continuellement dans les deux sens, sans
retournement. Supprimer une station ou un rail ouvre la boucle sans inventer
de nouvelle liaison.
Les courbes sont lissées avant de séparer les voies, pour qu'elles ne se
resserrent pas aux stations. Les lignes ouvertes se terminent en arrondi derrière
la station, sans dessiner la boucle de retournement de la simulation.
Les croisements hors station ne sont pas disponibles dans cette version.

Une modification de tracé, de station ou de composition redispatche le réseau
pour éviter des positions invalides sur les nouvelles voies.

## Ambiance

Carte minimaliste : fond blanc à midi, nuances atmosphériques au crépuscule
et dégradé bleu nuit discret, avec une transition douce. Aucun décor, point
ou ligne de grille n'est affiché.
L'alignement sur la grille reste actif pour construire et déplacer les
stations et les rails. Les rails et l'interface restent lisibles ; les rames
présentent des voitures de métro rapprochées, reliées par des passages souples,
sans ombre portée. Leur équipement roulant est masqué par la carrosserie vue
du dessus. Leurs phares diffus éclairent doucement la voie la nuit.
Chaque ligne est une bande de couleur unie, plus fine, avec deux pistes
sombres proches du centre pour les trains. Les stations sont des points
blancs à bordure contrastée, sans ombre ; leurs couleurs s'adaptent à la nuit.
Les courbes restent arrondies, sans halo ni
reflet sur les rails. L'aperçu de dessin utilise le même style.

La musique est une composition lo-fi originale de 48 secondes : accords chauds
de piano électrique, groove de batterie syncopé à 80 BPM et pauses aérées.
Les annonces d'arrivée sont des accords doux et graves ; le roulement des rails
reste discret sous la musique. Les effets ferroviaires ont leur propre volume
et peuvent être réglés ou coupés séparément.

## Exporter pour Windows et macOS

Installez les modèles d'export correspondant à votre version de Godot, puis :

```sh
mkdir -p dist
godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
```

Le préréglage Windows génère un exécutable x86_64 avec les données embarquées.
Le préréglage macOS génère une archive ZIP contenant **Metro.app**, universelle
Intel et Apple Silicon. L'import ETC2/ASTC doit rester activé pour l'export ARM64.
Les tests et les builds précédents ne sont inclus dans aucun des deux exports.

La version macOS utilise une signature **ad hoc**, sans notarisation Apple.
Après décompression, Gatekeeper peut demander une autorisation dans
**Réglages Système → Confidentialité et sécurité → Ouvrir quand même**.
Une distribution notarialisée nécessite un certificat Apple Developer ID et
une configuration de signature dédiée. L'identifiant actuel est `org.metro.game`.
L'archive est vérifiée depuis Linux ; son lancement doit être confirmé sur un Mac.

## Vérifier

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/intersection_smoke.gd
godot --headless --path . --script res://tests/editing_smoke.gd
godot --headless --path . --script res://tests/interface_smoke.gd
godot --headless --path . --script res://tests/audio_smoke.gd
godot --headless --path . --script res://tests/urban_smoke.gd
godot --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
godot --headless --path . --script res://tests/localization_smoke.gd
godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
```

Le dernier test nécessite un écran. Il vérifie la transition jour/nuit et
écrit des captures temporaires dans `/tmp` sur Linux.

Les décisions et limites sont détaillées dans [DESIGN.md](./DESIGN.md).
Le contexte de reprise des agents est dans [MEMORY.md](./MEMORY.md) ; leur
workflow de lecture et de mise à jour est défini dans [AGENTS.md](./AGENTS.md).

## Architecture

- `scripts/sim/` : données de stations, tracés, lignes et rames, sans Node.
- `scripts/dispatch/` : distances, arrêts, espacement, collisions et dispatch.
- `scripts/render/` : courbes, voies, rames, phares et décor urbain.
- `scripts/audio/` : composition et effets originaux générés en PCM.
- `translations/ui.csv` : textes anglais et français, importés par Godot.
