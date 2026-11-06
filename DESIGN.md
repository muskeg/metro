# Metro - decisions de conception

## Objectif

Un constructeur de reseau tranquille : aucune economie, aucune demande a
satisfaire, aucun compte a rebours. Le nom du jeu devient **Metro**.

## Decisions confirmees

- Relier les stations avec un apercu elastique, independant de l'historique
  et de la vitesse de souris. Chaque section libre utilise au plus un coude,
  avec directions horizontales, verticales et diagonales a 45 degres sur la
  grille invisible de 48 pixels. Les coins restent arrondis.
- Glisser directement entre stations ou cliquer pour fixer des coudes.
  Tab et une poignee a deux fleches inversent la posture diagonale/droite ;
  Retour arriere retire toute la derniere section fixee. Relacher dans le vide
  fixe une section et continue par clics ; seul un terminus valide engage le rail.
- Deux voies physiques paralleles permettent l'aller et le retour simultanes.
  Les fleches sont supprimees. Le rendu des trains et la simulation utilisent
  les memes chemins et longueurs.
- Les wagons suivent le chemin, y compris dans les virages. Le nombre de
  wagons est configurable par ligne. La securite tient compte de la rame
  complete, pas seulement du point representant sa tete.
- Les trains suivent un circuit aller/retour avec retournement aux terminus,
  au lieu de se teleporter sur la voie inverse.
- Carte minimaliste sans decor, blanche le jour et sombre la nuit.
  La grille de construction reste orthogonale mais invisible.
- Le fond est dessine dans le monde et change de palette au fil de la journee.
  Les voies, trains et controles ne subissent pas la modulation sombre du
  decor. Phares et fenetres deviennent plus visibles la nuit.
- Une composition lo-fi originale de 48 secondes : piano electrique chaleureux,
  batterie a 80 BPM avec hats legrement swingues, harmonies evolutives et
  pauses musicales. Les annonces sont des accords graves et doux ; le bruit
  des rails reste discret. Musique et sons ferroviaires ont des volumes separes.

## Organisation du travail

1. Controleur, graphe et circulation : implementation principale, avec tests
   des deux voies, distances entre rames, dessin et editions de stations.
2. Decor urbain : agent specialise en implementation graphique, dans un
   composant de fond independant du rendu ferroviaire.
3. Audio : agent specialise en implementation audio, composition originale
   et effets proceduraux, sans fichiers tiers.
4. Integration : interface, wagons, eclairage, documentation et export Windows.

Les agents utilisent les modeles adaptes par leur configuration, sans imposer
une surcharge de modele. Les responsabilites de fichiers sont distinctes.

## Regles d'edition et de securite

- Une ligne se prolonge par ses extremites. Une liaison existante peut etre
  redessinee depuis un point d'ancrage. Les tracés invalides sont signales.
- Les modifications de geometrie remettent le reseau en service
  progressivement : les voies partagees peuvent modifier les chemins de
  plusieurs lignes. Les trains ne conservent pas de positions incoherentes.
- Les chemins trop courts pour une rame ou les chevauchements de segments
  non partages sont refuses explicitement.
- Les voies partagees sont espacees par ligne. Les croisements non connectes
  sont refuses dans cette iteration : aucune rame ne doit traverser une autre
  sur un croisement sans signalisation.
- Aux stations communes ou les itineraires divergent, une reservation
  exclusive et une file FIFO ordonnent le passage des rames. L'approche
  est freinee avant la zone, et la reservation dure jusqu'a la sortie de
  toute la rame, y compris pendant son arret en station.

## Verification

- Tests deterministes des chemins snappes, virages, voie retour, wagons,
  arrets, espacement et edition des lignes.
- Demarrage Godot sans erreur de script et verification graphique jour/nuit.
- Verification des niveaux, du silence et de la boucle audio.
- Export Windows x86_64 avec donnees embarquees.

## Implementation retenue

- Chaque ligne dispose d'un circuit continu : voie aller, courbe de
  retournement, voie retour, second retournement. Les arrets sont des distances
  mesurees sur ce circuit, et non des indices de segments qui se decaleraient
  lors des editions.
- Une ligne fermee conserve chaque station une fois, sauf la premiere repetee
  en fin de liste pour representer le rail de fermeture. Les deux voies sont
  des circuits independants, parcourus dans des sens opposes, sans retournement.
  La suppression d'un rail ou d'une station ouvre la boucle en une ligne continue.
- Une rame est representee par une distance de tete et un nombre de wagons.
  Les corps rigides suivent la tangente du meme chemin utilise par le rendu.
- Le dispatch lance un train depuis chaque terminus si l'espace est libre.
  Le nombre en circulation est limite par la longueur disponible et par un
  maximum reglable par ligne (1 a 16, 4 par defaut). Une reduction sous le
  nombre actuel redispatche le reseau pour appliquer la limite immediatement.
- Un clic sur une motrice ou un wagon suit ce train avec un zoom rapproche.
  Echap, un deplacement manuel de la vue ou la reconstruction du reseau
  interrompt ce suivi.
- La distance de freinage et l'espacement incluent la longueur du train
  precedent. Un controle geometrique des corps empeche les chevauchements
  entre lignes et dans les retournements. Simulation subdivisee a 60 Hz.
- Ce modele remplace la reservation unique d'un bloc bidirectionnel qui
  empechait la circulation simultanee. Les croisements non connectes sont
  refuses avant de modifier le graphe.
- Le fond atmospherique et les rails sont deux couches independantes. Les tests
  graphiques comparent les pixels de nuit et de jour : fond sombre, rails stables.
- Les lignes sont des bandes opaques de 28 pixels avec deux pistes sombres
  de 4 pixels, sans halo ni trait brillant. Les voies ouvertes gardent une
  bordure coloree de 8 pixels, sans afficher les retournements. L'aperçu reprend les memes largeurs ; les
  chemins physiques, wagons et rayons de courbure ne changent pas.
- La musique est une miniature originale de 48 secondes, composee de notes
  avec des silences et des decays, generee une fois et mise en cache. Pas de
  synthese par echantillon dans la boucle de rendu.

## Limites assumees

Pas de vraie scene 3D, de simulation de voyageurs ou d'actifs sous licence.
Les croisements ferroviaires independants et aiguillages complexes restent
hors de cette iteration ; les correspondances se font aux stations.

## Langues et diversite de la carte

- Anglais par defaut, francais selectionnable dans le menu. Traductions Godot
  natives via CSV ; les messages avec parametres et erreurs composees sont
  traduits avant leur formatage. Changement immediat, sans recreer le reseau.
- Le choix de langue est conserve dans `user://settings.cfg`. Les erreurs de
  lecture ou d'ecriture sont signalees, le fichier est preserve lors des mises
  a jour d'un seul reglage.
- La carte reste minimaliste, sans decor procedural ni grille visible. Un
  fond couvre la vue pendant le zoom, le deplacement et le resize.
- Le fond passe doucement du blanc pur a midi a un discret degrade bleu nuit,
  avec une teinte chaude au crepuscule. La grille invisible, le dessin aimante
  et les controles contextuels sont conserves.
- Les trains sont des miniatures vectorielles a voitures rectangulaires
  rapprochees et passages souples, sans roues decoratives ni ombre portee.
  Les roues sont cachees sous les caisses dans cette vue du dessus. Les phares
  produisent des faisceaux doux a la nuit. Le lissage de lignes est desactive au
  zoom rapproche car sa frange en unites monde rend les contours flous.

## Edition contextuelle et topologie

- Les modes Dessiner et Deplacer sont retires. Au survol d'une station :
  centre a glisser pour deplacer, un seul + pour relier dans toutes les
  directions, et une poignee de suppression. Station et rail partagent le meme
  langage visuel : disques jour/nuit, bord fin, + vert, suppression rouge et
  losange neutre pour remodeler. Taille et hit-testing restent constants a l'ecran.
- Les losanges des rails permettent de deplacer un coude ; une poignee sous
  le + permet aussi de remodeler un segment droit. Les chemins adjacents sont
  reconstruits a 45 degres sans deplacer les autres points. Aucun rail ni train
  ne change pendant l'apercu : validation de toutes les lignes partagees au
  relachement, puis reconstruction du reseau, ou abandon atomique en cas d'erreur.
- Apercu de la couleur de ligne, rouge si invalide, cible entouree et guides
  locaux temporaires. Pas de grille permanente. Les tooltips nomment les icones ;
  les erreurs longues sont bornees a la fenetre. Une arrivee invalide reste
  modifiable, et Echap/clic droit ou relachement sur l'interface annule le geste.
- Les positions des evenements souris sont converties par le transform du
  canvas, plutot que de relire une position globale potentiellement differente.
- L'outil Station reste disponible pour ajouter sur le vide ou inserer sur
  un rail. Le + au survol d'un rail permet egalement l'insertion.
- Decision utilisateur : supprimer une station supprime ses rails incidents,
  sans reconnecter ses voisins. Supprimer un rail separe aussi les lignes.
  Chaque fragment reste selectionnable et conserve couleur, wagons et
  reglages. La premiere partie garde la ligne existante ; les autres
  obtiennent de nouveaux onglets. Une ligne vide reste reutilisable.
- Les suppressions demandent confirmation. Les IDs restent des indices
  compacts : stations, rails, lookup des paires et toutes les listes de
  lignes sont remis en coherence avant de reconstruire les circuits.
  Le dispatcher integre egalement les nouveaux fragments.
- Une insertion coupe le chemin canonique a un point de grille du rail,
  conserve ses coudes et met a jour toutes les lignes partagees, y compris
  celles parcourant le rail dans l'ordre inverse. La longueur des deux
  nouveaux segments est verifiee avant toute mutation.
- Un deplacement adapte le coude adjacent en preservant les directions
  existantes quand possible. Sinon, il recalcule ce coude sur la grille ;
  les coudes eloignes restent fixes. Tous les rails incidents sont valides
  ensemble, ou restaures ensemble. Un glissement repart de la geometrie
  initiale a chaque mouvement pour eviter les distorsions cumulatives.
  Echap, clic droit ou relachement sur l'interface restaure la geometrie.
- Les tests d'edition couvrent insertions partagees et inversees, refus sans
  mutation, suppressions successives, remappage, fragments, reextension,
  hit-testing des poignees et annulation des mouvements.

## Croisements aux stations

- Le simple refus de collision geometrique arrivait trop tard : plusieurs
  rames pouvaient se bloquer mutuellement en entrant au centre. Le controle
  des corps reste actif, mais un interlocking reserve maintenant l'approche
  et la traversée avant qu'elles puissent se rencontrer.
- Les zones couvrent les voies decalees et les retournements de terminus.
  Les passages sont mesures sur les circuits reels, avec une marge pour
  la motrice et le dernier wagon. Les intervalles qui se recouvrent, y
  compris a la jonction debut/fin du circuit, sont fusionnes.
- Les stations proches sont regroupees en un seul interlocking lorsque
  l'espace ne permet pas a une rame de liberer la premiere avant d'approcher
  la seconde. Cela evite de tenir une reservation en attendant une autre.
- Les lignes parcourant exactement les memes rails incidents conservent
  leurs voies paralleles independantes. Aux terminus, chaque couloir dispose
  de sa propre reservation, sans bloquer les autres couloirs.
- L'apparition d'une rame dans une zone protegee exige aussi sa reservation.
  La pause conserve les reservations ; une edition les efface avec les rames.
- Tests de progression sur six minutes : croisement perpendiculaire,
  terminus partage, stations proches avec segment commun, trois lignes a
  vitesses differentes. Verification des corps de tous les wagons et de
  la progression des deux sens, pas seulement du premier train.
  Terminus charges et reseau reproduisant la capture utilisateur inclus.

## Interface compacte et couleurs

- Le panneau principal devient une carte de 276 x 460 pixels maximum,
  avec defilement si necessaire, plutot qu'une barre occupant toute la
  hauteur. Les reglages s'ouvrent dans une carte de 240 pixels de large.
  L'aide detaillee reste accessible a la demande.
- Une pastille par ligne ouvre le ColorPicker Godot complet avec les six
  couleurs initiales en presets. Pas d'alpha : les lignes restent opaques.
- Les couleurs des rails, rames, onglets et apercus changent immediatement.
  Aucun circuit ni train n'est reconstruit pour une modification de couleur.
  Changer de ligne ferme le picker et synchronise la pastille selectionnee.

## Voies rapprochees et stations simples

- Les voies physiques passent a +/-8 pixels du centre, au lieu de +/-11 :
  16 pixels entre les rames, pour des voitures de 7 pixels de large.
  Le rendu, l'apercu et la simulation partagent toujours le meme offset.
- Les stations deviennent des disques blancs de rayon 10 avec une bordure
  de 2 pixels, sans ombre ni halo. La nuit, le blanc est legerement adouci
  et la bordure eclaircie. Selection et poignees restent accessibles.

## Courbes aux stations et fins de ligne

- Le chemin central complet est arrondi avant la separation des deux voies.
  L'ancien raccord quadratique entre voies deja decalees pincait les voies
  au centre des stations en virage, causant un blocage face a face.
- Les arrets sont projetes sur les segments du circuit, et pas uniquement
  sur ses sommets : supprimer un sommet collineaire ne deplace pas un arret.
- Tous les terminus protegent le retournement de la rame complete, meme
  sur une ligne seule. Les reservations fusionnent avec les carrefours
  proches uniquement si elles concernent au moins une ligne commune.
- Le circuit de simulation conserve les retournements continus, mais le
  dessin des rails utilise seulement le centre et les deux voies ouvertes.
  Un cap arrondi de la couleur de la ligne termine la bande derriere la station
  sans dessiner le demi-tour. Le rendu et la circulation partagent les courbes.
