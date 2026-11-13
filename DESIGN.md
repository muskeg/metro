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
- Carte minimaliste sans decor, blanc casse mat le jour et sombre la nuit.
  La grille de construction reste orthogonale mais invisible.
- Identite Metro : M ferroviaire orange/turquoise/violet avec correspondances,
  redessine en chemins SVG autonomes a partir de la reference fournie.
  Symbole compact pour les icones ; symbole et mot-symbole vectoriels dans le
  titre, avec le fondu existant (opaque 10s, disparu a 30s). Logo empile pour le
  splash natif/Web sur papier creme. Les exports utilisent les PNG derives
  des memes sources ; pas de police externe, de shell Web personnalise ni de
  dependance graphique ajoutee. Le generateur est dans
  [build_branding.gd](scripts/tools/build_branding.gd).
- Le fond est dessine dans le monde et change de palette au fil de la journee.
  Les voies, trains et controles ne subissent pas la modulation sombre du
  decor. Phares et fenetres deviennent plus visibles la nuit.
- La musique de fond utilise « lofi_metro_NO_DRUMS », fourni en WAV et encode
  en MP3 stereo 128 kbit/s (3.35 Mo au lieu de 55.45 Mo), sans couper ses 209.56s.
  La piste boucle sur toute sa duree. Les effets ferroviaires sont a zero par
  defaut et leur curseur est retire temporairement, en attendant de nouveaux sons.
  Les volumes general et musique restent disponibles.

Le Web accepte un demarrage explicite en veille avec `?kiosk=1` dans l'URL
(`URLSearchParams`, valeur exacte `1`). Sans ce parametre, aucun changement
au demarrage. Activation apres chargement du reseau, via le meme mode veille,
sans demande de plein ecran automatique (restriction de geste navigateur).
Pas de persistance ni de verrouillage ; Echap/clic/toucher gardent leur sortie
normale. Le navigateur gere le plein ecran kiosque et les permissions audio.
Le parametre independant `layout` selectionne `metro_demo`, `montreal` ou
`jr_east` parmi les presets inclus, ou `saved:Nom` pour une sauvegarde du meme
site/profil navigateur via `LayoutStore.load_layout` et ses validations normales.
Le nom est decode par URLSearchParams ; les caracteres speciaux doivent etre
encodes dans le lien. Le lien ne transporte pas le contenu du reseau.
Sans valeur, conserver le preset habituel ; valeur inconnue : erreur visible,
pas de veille ni de chargement arbitraire par chemin/URL.

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
- Les voies partagees sont espacees par ligne entre les stations : centres de
  corridors a 48 pixels (bandes de 28 pixels), pour conserver un espace visible.
  Chaque service rejoint localement les stations qu'il dessert. Simulation,
  trains, ombres et illumination utilisent les memes chemins, pas un simple
  decalage de couleur. Les croisements hors station
  sont autorises pour tous les reseaux et restent purement visuels, sans creer
  de correspondance ni signalisation commune. Chaque trace reste valide
  individuellement : pas de retour sur ses pas ni d'auto-intersection.
- Chaque ligne et chaque sens sont independants, meme aux stations communes.
  L'autorisation de mouvement suit la distance jusqu'a l'arriere de la rame
  precedente dans le meme circuit ; plusieurs trains peuvent etre entre stations.
  Les corrections d'horaire se font surtout par de courtes attentes en station.
  Les convergences peuvent se superposer visuellement : pas d'interlocking
  geometrique entre lignes ou entre sens.

## Verification

- Tests deterministes des chemins snappes, virages, voie retour, wagons,
  arrets, espacement et edition des lignes.
- Demarrage Godot sans erreur de script et verification graphique jour/nuit.
- Verification des niveaux, du silence et de la boucle audio.
- Export Windows x86_64 avec donnees embarquees.

## Implementation retenue

- Chaque ligne ouverte dispose d'un circuit aller/retour avec voies communes
  aux terminus et changement de cabine a l'arret. Les arrets sont des distances
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
  maximum reglable par ligne (4 souhaite par defaut), plafonne par la capacite
  du trajet et non par son nombre de stations. La recommandation est le temps
  de cycle / intervalle souhaite, arrondi au-dessus et plafonne par la capacite.
  Les lignes vides/isolees ne dispatchent pas. Une reduction sous le
  nombre actuel retire progressivement le surplus aux terminus/origines,
  sans interrompre les autres lignes ni faire disparaitre les rames en mouvement.
- Un clic sur une motrice ou un wagon suit ce train avec un zoom rapproche.
  La camera suit exactement la pose interpolee affichee, sans second lissage ;
  le lissage de navigation reste inchange hors suivi. Le suivi cinematographique
  utilise cette meme pose, pas la derniere position de simulation.
  Echap, un deplacement manuel de la vue ou la reconstruction du reseau
  interrompt ce suivi.
- Le freinage respecte la station suivante et l'autorisation de mouvement.
  La regulation de service est distincte de cette securite. Le reglage
  d'intervalle reste un minimum souhaite ; le maximum de rames reste un plafond.
  Simulation a pas fixe de 60 Hz, pilotee par un accumulateur independant du
  rendu ; quatre pas au plus par frame, le reliquat est conserve sans perte de
  temps. Les poses interpolees traversent le bouclage, mais pas un changement de
  direction. Les croisements hors station restent independants.
- Le fond atmospherique et les rails sont deux couches independantes. Les tests
  graphiques comparent les pixels : nuit tres sombre, rails illumines seulement
  la nuit, fond intact hors du halo local.
- Les lignes sont des bandes opaques de 28 pixels avec deux pistes sombres
  de 4 pixels le jour. La nuit ajoute un coeur lumineux de 1.2px et trois
  couches de halo colore de 30/22/14px, sans changer le corridor ni ses caps.
  Ces halos sont des polygones caches issus d'un offset arrondi de chaque voie :
  l'union resout les replis interieurs, sans traits superposes ni largeur variable.
  Les trous de boucles sont preserves en decoupant les contours avant soustraction.
  Les couleurs par sommet conservent le fondu pres des stations partagees et
  le recoloriage. La largeur reste constante dans les courbes comme sur les droites.
  Les voies ouvertes gardent une bordure coloree de 8 pixels ; les raccords
  des terminus suivent les chemins physiques visibles. L'aperçu garde ses largeurs.
- La musique de fond utilise la piste MP3 fournie, mise en boucle comme un flux audio ; elle remplace le groove PCM et les notes synthetisees.
  Les effets ferroviaires sont conserves mais leur volume commence a zero et leur
  curseur est retire temporairement, en attendant de nouveaux sons.
  Pas de synthese par echantillon dans la boucle de rendu.

## Limites assumees

### Sauvegardes locales

Menu propose plusieurs reseaux nommes, chargement et carte vide. Godot `user://`
est commun aux releases Windows/macOS/Web : fichiers natifs ou IndexedDB,
sans dependance SQLite, serveur ou dialogue de fichiers incompatible Web.
Chaque nom correspond a un fichier JSON versionne (nom de fichier SHA-256 pour
eviter les chemins saisis par le joueur), ecrit puis renomme pour remplacer
une sauvegarde uniquement apres fermeture du fichier complet. Le chargement
valide les types, references et reglages dans un nouveau graphe avant de
remplacer l'etat vivant. Les voies partagees et leurs orientations sont
reconstruites une seule fois ; les trains/visites repartent, pas leurs positions.
Les reglages de ligne et la camera sont conserves, pas la langue, l'audio,
l'heure ou la pause, qui restent ceux de la session. Charger/vider/remplacer
demandent confirmation, sans sauvegarde automatique. Vider conserve les fichiers.
Le demarrage desktop ouvre [metro_demo.json](./layouts/metro_demo.json), reseau de
16 stations avec une boucle et deux lignes ouvertes qui se croisent uniquement
aux correspondances. Ce JSON en `res://` est inclus explicitement dans les
six presets d'export. Le preset Web utilise la feature `montreal_startup` :
`LayoutStore.load_starter_layout()` choisit alors
[montreal.json](./layouts/montreal.json), y compris sur GitHub Pages.
Le choix est propre a l'export, sans detection de domaine ni stockage utilisateur.
Load distingue l'original inclus des fichiers utilisateur
par metadata, pas par nom traduit : une copie du meme nom ne le masque pas.
Save ne propose que les copies utilisateur ; vider laisse l'original accessible.
Tout demarrage/chargement (inclus ou utilisateur) recentre et ajuste le zoom
aux bornes de toutes les stations, waypoints et circuits decales des trains,
avec 24 pixels monde de marge et 32 pixels ecran lateraux / 80 haut / 112 bas
pour les controles. Une dimension remplit exactement l'espace disponible,
sans deformation ni recadrage. Le zoom peut augmenter par rapport au JSON.
Les reseaux immenses peuvent descendre sous 0.08 ; ce zoom ajuste devient
leur plancher de navigation, permettant un aller-retour de zoom sans saut.
Le schema conserve la camera sauvegardee pour compatibilite, mais le menu
Load recadre toujours. Vider garde camera zero/zoom 1 ; redimensionner ensuite
ne recadre pas automatiquement une vue deplacee manuellement.
Les boutons zoom -/+ et ajustement (quatre coins) sont places au-dessus du
rail, cotes et cibles de 44 pixels ; tooltips EN/FR. Ajuster ferme les feuilles,
annule le geste/suivi et recadre sans reconstruire circuits ou trains, ni changer
la pause. Masquer le HUD les masque aussi ; replier le rail les conserve.
Le catalogue `LayoutStore.BUNDLED_LAYOUTS` relie chaque chemin `res://` a une
cle traduite, et les options Load portent ce chemin en metadata. Les originaux
restent distincts des fichiers utilisateur, meme en cas de nom identique.
Les stations et lignes peuvent avoir un nom facultatif (`station_names` et
`lines[].name` dans le JSON version 1), preserve par les sauvegardes ; les
anciennes sauvegardes sans noms restent compatibles. Les noms factuels ne sont
pas traduits comme des cles UI. Les fragments de ligne conservent leur nom.
Export/Import dans Menu utilisent le meme JSON version 1 et validateur que les
sauvegardes, avec precision numerique complete pour conserver le cadrage ajuste.
`LayoutTransfer` gere les FileDialog natifs (destination explicite avec confirmation
d'ecrasement) et JavaScriptBridge Web (download_buffer, input file et arrayBuffer).
La selection Web borne la taille avant lecture ; callbacks conserves, generation
pour ignorer une lecture obsolete, puis validation differee hors du callback JS.
Pas de serveur, clipboard, script importe, load() de ressource externe ni chemin
derive de donnees. Les octets sont uniquement parses comme JSON/UTF-8.
Import valide dans un graphe separe puis demande confirmation avant installation,
recadre, preserve pause/langue/audio et ne sauvegarde pas automatiquement.
Annulation/erreur conservent la carte et les fichiers locaux. Export reutilise
l'ecriture temporaire/rename des sauvegardes et signale les erreurs I/O.
Le validateur borne les collections, coordonnees, longueur totale, flottes et
complexite des geometries avant dispatcher/rendu ; les limites exactes sont dans
LayoutStore et README. Pre-scan lexical borne profondeur, chaines et jetons
avant allocations du parseur JSON. Positions uniques, grille exacte, tracés
sans retour/croisement propre et longueurs suffisantes pour trains/marqueurs.
Les voies independantes peuvent toujours se croiser. Un JSON avec noms ressemblant
a du code/HTML reste du texte de Label, jamais execute ni interprete comme chemin.
Le preset Montreal contient uniquement les quatre lignes de metro et leurs
68 stations existantes, avec correspondances partagees. REM/exo, bus,
extremites de continuation et extensions projetees sont exclus.
Sa geometrie est positionnee explicitement pour conserver les relations
visuelles du reseau : bras orange diagonaux, retour au sud de Lionel-Groulx,
axe vert du centre-ville et bras nord-est en decrochements, coude de la bleue
entre Edouard-Montpetit et Outremont, branche jaune horizontale puis diagonale.
Les stations utilisent un espacement de base de 48 pixels, avec des sections
de 144 pixels sur la queue horizontale Angrignon–De l'Eglise pour conserver
la place des trains a deux wagons ; les coudes qui
definissent ces formes sont des waypoints explicites, pas des colonnes arbitraires
ou des chemins elastiques recalcules sans contexte.
Le preset Tokyo JR central remplace le reseau regional JR East : 90 stations,
107 voies physiques et onze corridors, boucle Yamanote complete de 30 stations (Takanawa Gateway
inclus) et axes centraux Chuo rapide/local, Keihin-Tohoku, Saikyo, Joban et
Keiyo. Une extension sud-ouest ajoute Tokaido Tokyo–Odawara avec Hiratsuka et
deux Shonan-Shinjuku depuis Akabane : Tokaido-bound rapid vers Odawara
(tous les arrets Tokaido au sud de Totsuka, pas special rapid) et
Yokosuka-bound local vers Zushi, ainsi que le Tokyo Monorail Hamamatsucho–Haneda
Terminal 2 (11 stations, le long de la baie). Les correspondances et voies consecutives
communes sont partagees. Les rapides suivent les memes axes geometriques que
les locaux, sans ajouter les stations sautees a leur liste d'arrets.
`TrackGeometry.corridor_layout` regroupe les segments collineaires connectes,
reserve des bandes de 48 pixels par service entre les stations et joint leurs
axes decales par intersection. Le service avec le plus d'arrets locaux reste
sur l'axe central ; chaque autre service rejoint seulement ses propres stations
par de courtes transitions, sans detour vers les arrets qu'il saute.
Une transition peut occuper jusqu'a 45 % de la section d'extremite
(`STATION_TRANSITION_SHARE`) : a 30 %, une bande exterieure arrivait trop a plat
et repliait ses deux voies au virage de Yoyogi sur la grille resserree.
Un axe collineaire est recoupe a une station ou l'ensemble des services
change, si chaque service qui la traverse s'y arrete : les bandes y sont
recalculees (Tokaido seule et centree de Shinagawa a Yokohama, local de Zushi
centre de Yokohama a Ofuna), sans decalage pour un express qui la saute.
Les arrets Keihin-Tohoku Oimachi–Kamata sont sur leur propre rangee, une bande
(48 pixels) sous l'axe Tokaido, pour que Tokaido traverse Kawasaki en ligne droite. Ce plan
est calcule une fois par reconstruction et partage par les circuits de
simulation et le rendu. Les voies physiques partagees rejoignent egalement leurs
stations, meme sans recouvrement entre voies stop-a-stop distinctes ; Montreal
conserve sa geometrie existante. Les stations et parcours existants gardent
les memes identites, connexions et reglages. La geometrie reprend
l'arrangement aplati de la carte de numerotation : longs cotes droits de
Yamanote, quatre epaules diagonales equilibrees et plateaux centres
Otsuka–Tabata et Shinagawa–Tamachi pour une silhouette facettee, puis Tokaido horizontal
vers l'ouest jusqu'a Ofuna et replie vers le nord a Chigasaki. Odawara reste
presque a la hauteur de Shinagawa ; seule la branche Kamakura–Zushi descend
legerement plus bas. Coordonnees schematiques originales a 96 pixels par unite (le plus petit
multiple de la grille de 48 pixels ou les sections de deux unites, 192 pixels,
gardent de la marge pour des trains de trois wagons de 82 pixels) ; l'echelle
precedente etait 144. Takadanobaba, Kamonomiya et Haneda Terminal 1 sont a des
demi-unites pour garder 144 pixels sur leurs sections courtes et laisser la zone
de convergence des terminus hors de la station voisine. Les bandes partagees
gardent 48 pixels, donc paraissent plus larges relativement a la carte.
Cadrage stocke centre (-1152,-96), zoom 0.12 ; le chargement ajuste ensuite le cadre aux bornes
reelles et aux marges de l'interface. Pas de placement automatique regional.
Les extremites sont des limites de cadrage, pas des terminus
officiels. Tokyo fixe `max_trains` a 10/8/4/6/4/4/4/8/6/6/4 (64 au total,
le plafond) avec trois wagons ; Montreal a 10/12/2/6 avec trois wagons,
sauf la jaune qui garde deux wagons : a trois, elle ne tient plus qu'un
train. Quatre wagons ne tiennent pas sur les diagonales compactes de
Montreal. Intervalle demande : 24s a Tokyo, 12s a Montreal.
Le service respecte toujours son intervalle minimal et sa capacite : ces
reglages permettent les flottes demandees, mises en service progressivement.
Le trajet jaune garde le minimum teste de 240 pixels horizontaux puis
deux cases diagonales pour soutenir deux trains simultanes, pas seulement
faire tenir une rame. Les plafonds restent modifiables.
Les halos de corridors decomposent les contours qui se touchent en boucles
simples avant de soustraire leurs trous. Les intensites aux correspondances
utilisent un index spatial et des rayons caches ; l'apparence ne change pas,
mais les grands presets evitent les recherches globales a chaque sommet.
Les sources et limites figurent dans les JSON et le README. Les schemas sont
originaux, pas une copie des illustrations officielles.
Les tests qui construisent leur propre graphe desactivent le demarrage demo
avant d'ajouter la scene ; le test de sauvegardes valide le vrai demarrage.
Le Web depend des autorisations et de la retention du navigateur : avertissement
si `OS.is_userfs_persistent()` est faux, sans promesse si vrai. Pas de cloud
ni de synchronisation entre appareils. Voir [README.md](./README.md).

Pas de vraie scene 3D, de simulation de voyageurs ou d'actifs sous licence.
Les aiguillages complexes et conflits entre lignes restent hors de cette
iteration ; les correspondances se font aux stations. Les croisements visuels
hors station ne sont pas une simulation de passages a niveau.

## Langues et diversite de la carte

- Anglais par defaut, francais selectionnable dans le menu. Traductions Godot
  natives via CSV ; les messages avec parametres et erreurs composees sont
  traduits avant leur formatage. Changement immediat, sans recreer le reseau.
- Le choix de langue est conserve dans `user://settings.cfg`. Les erreurs de
  lecture ou d'ecriture sont signalees, le fichier est preserve lors des mises
  a jour d'un seul reglage.
- La carte reste minimaliste, sans decor procedural ni grille visible. Un
  fond couvre la vue pendant le zoom, le deplacement et le resize.
- Le fond passe doucement du blanc casse a midi a un degrade bleu presque noir.
  Des etapes distinctes donnent une aube bleutee, un coucher peche et une heure
  bleue. Un shader Compatibility ajoute un grain mat ancre dans le monde et
  des variations lentes tres faibles, sans decor, grille ni reflets de verre.
  Le grain est attenue lors du dezoom pour eviter le scintillement. Une lueur
  chaude vient du cote du soleil au lever/coucher. La grille invisible reste.
- Les voies et trains ont des ombres solaires discretes. La direction change
  d'est en ouest, les ombres sont plus longues a l'aube/au coucher, courtes a midi
  et s'effacent la nuit. Les stations ne projettent plus d'ombre. Une source
  partagee parcourt un arc de gauche a droite entre l'aube et le coucher ;
  la lumiere chaude et les ombres suivent cette meme position, sans saut a midi.
  Le corridor complet projette
  une ombre legere sur le fond, a partir de contours arrondis caches (largeurs
  29/31px), avec seulement 45 % du decalage solaire et 36 % de son opacite
  par couche. Les trous de boucles sont preserves. Les ombres des trains restent
  au-dessus de leur voie, sous les voitures et les voies superieures.
- Aux croisements, l'ordre existant des lignes definit automatiquement la
  hauteur visuelle : chaque ligne dessine ses rails, leur eclairage, ses quais
  temporaires puis ses rames avant la ligne suivante. Une voie superieure cache
  donc les voitures, soufflets, ombres et phares des rames inferieures sans
  masquer la rame entiere. Les stations et controles restent au-dessus.
  Aucun niveau manuel ni changement de simulation. Le champ optionnel
  `lines[].render_priority` du JSON v1 est un entier de 0 a 15 (0 par defaut) :
  priorites croissantes, puis ordre existant des lignes en cas d'egalite.
  Le preset Tokyo met Yamanote a 1 et toutes les autres lignes a 0.
  Sauvegarde/import/export et fragments conservent cette priorite, sans changer
  les identifiants de simulation ni l'ordre des onglets ou anneaux de station.
- Le monde n'a pas de bord fixe. Molette et pincement partagent le zoom
  0,08-6x, contre 0,45-6x auparavant, pour les grandes cartes. Pas d'import
  geographique ni de garantie de performances pour les grandes cartes.
- Les trains sont des miniatures vectorielles a voitures rectangulaires
  rapprochees et passages souples, sans roues decoratives ; seules les ombres
  solaires discretes les ancrent sur la surface mate.
  Les deux extremites portent des cabines assorties, nez adouci et pare-brise
  sombre ; phares blancs en tete, feux rouges en queue. Le toit metal clair
  reste neutre lors d'une recoloration, la couleur de ligne borde les caisses.
  Fenetres et portes doubles rythment les flancs. Ventilation, plis des
  intercirculations et reflets apparaissent progressivement entre zoom 1.5 et 3 ;
  les grilles et joints fins entre 3 et 4.5. A l'echelle carte, seuls toit,
  silhouette et cabines restent visibles. Pas de nouveau curseur.
  Chaque passage relie les extremites rigides des deux voitures avec leurs
  normales propres : les plis se resserrent naturellement a l'interieur du coude.
  Toutes les voitures, cabines comprises, gagnent encore 10 % de longueur :
  19.8px, largeur 7px, pas 20.8px (intervalle de 1px inchange).
  Une echelle longitudinale commune guide caisses, portes, phares et soufflets.
  Caisses, toits, portes, soufflets, quais et degagements utilisent ces proportions.
  Les roues restent cachees. Les phares ont des halos locaux visibles et des
  faisceaux plus intenses mais decroissants a la nuit. Le lissage est desactive au
  zoom rapproche car sa frange en unites monde rend les contours flous.
- Sous 0.8x, chaque rame devient un point lumineux avec trainee suivant les rails :
  tete blanche de rayon 2.2 pixels, contour sombre de 1 pixel et halo de rayon 4.
  La trainee memorise la derniere seconde de mouvement interpole :
  elle s'allonge avec la vitesse et s'efface progressivement a l'arret.
  La disparition avance depuis l'arriere vers la tete : expiration des
  positions anciennes et raccourcissement smoothstep a l'arret en une seconde.
  Aucun multiplicateur d'opacite global selon l'age : l'avant reste lumineux.
  Gradient spatial (exposant 1.4, maximum 0.8), coeur de 1.5 pixels et halo de 4
  (opacite maximale 0.18) ;
  longueur plafonnee a 1.5 fois la longueur physique de chaque rame ou un tour.
  Historique echantillonne a environ 30 Hz, gele en pause, efface lors des
  changements de geometrie, retraits et inversions de cabine (pas de teleport).
  Tous les sommets du circuit sont inclus pour respecter les virages.
  Les voies superieures et stations recouvrent toujours marqueurs et voitures.
  Fondu complementaire smoothstep entre marqueur et voitures de 0.5x a 0.8x,
  via deux enfants du meme calque de ligne ; aucun changement de z-index.
  Les phares/ombres des voitures sont omis en vue point lumineux. Le picking et la
  marge de culling suivent la meme representation, sans changer la simulation.

## Edition contextuelle et topologie

- Les modes Dessiner et Deplacer sont retires. Au survol d'une station :
  centre a glisser pour deplacer, un seul + pour relier dans toutes les
  directions, et une poignee de suppression. Station et rail partagent le meme
  langage visuel : disques jour/nuit, bord fin, + vert, suppression rouge et
  losange neutre pour remodeler. Taille et hit-testing restent constants a l'ecran.
  Le survol reste ancre dans un couloir continu entre les poignees du rail :
  traverser leur espacement ne deplace ni ne masque le popup, meme sur rail vertical.
  Une station deja survolee conserve aussi ses controles dans le couloir centre
  vers poignee : le + d'insertion du rail ne peut pas capturer le + de connexion
  visible, meme si un rail part a droite et que la nouvelle liaison va a gauche.
  Sans ce survol, l'insertion directe sur rail reste accessible.
- Les losanges des rails permettent de deplacer un coude ; les poignees du
  segment sont disposees perpendiculairement au rail, plutot que toujours
  verticalement. Les halos de survol des stations ne volent pas ces poignees
  sur les petites sections ; le centre d'une station reste prioritaire.
  Le losange d'une section ne reconstruit que le chemin entre ses deux points
  d'ancrage voisins, marques par de petits cercles fixes. Un losange de coude
  conserve ses deux voisins. Les points eloignes restent identiques, meme si
  un ancrage devient collineaire ; la simplification du rendu reste inchangee.
  Les chemins adjacents sont reconstruits a 45 degres. Aucun rail ni train
  ne change pendant l'apercu : validation de toutes les lignes partagees au
  relachement, puis reconstruction du reseau, ou abandon atomique en cas d'erreur.
- Apercu de la couleur de ligne, rouge si invalide, cible entouree et guides
  locaux temporaires. Pas de grille permanente. Les tooltips nomment les icones ;
  les erreurs longues sont repliees a 16px, jamais reduites ni tronquees.
  En remodelage, l'erreur suit le coude deplace, pas la station distante.
  Un mouvement dans la meme case affiche une indication de grille ; relacher
  sans modification ne redispatche pas les trains. Une arrivee invalide reste
  modifiable, et Echap/clic droit ou relachement sur l'interface annule le geste.
- Les positions des evenements souris sont converties par le transform du
  canvas, plutot que de relire une position globale potentiellement differente.
  Le survol entre images utilise aussi la derniere position d'evenement,
  reconvertie avec le canvas courant pour suivre le zoom et le deplacement.
- Un clic ajoute sur le vide ou insere sur un rail, sans outil Station.
  Le + au survol d'un rail permet egalement l'insertion.
- Decision utilisateur : supprimer une station reconnecte les voisins de chaque
  ligne en concatenant les chemins orientes et en conservant les anciens ancrages.
  Les branches d'un carrefour ne sont pas reliees arbitrairement entre elles.
  Une voie deja presente entre les voisins est reutilisee sans la redessiner.
  Les boucles restent fermees avec au moins trois stations ; a deux stations,
  elles deviennent ouvertes sur la voie survivante (pas de rails paralleles).
  Supprimer un rail avec son x de survol separe les lignes ; ce controle reste
  visible au survol d'un coude, pas seulement au milieu d'un segment.
  Chaque fragment reste selectionnable et conserve couleur, wagons et
  reglages. La premiere partie garde la ligne existante ; les autres
  obtiennent de nouveaux onglets. Une ligne vide reste reutilisable.
- Les suppressions demandent confirmation avec un texte propre a l'action.
  La carte de confirmation est sans chrome de fenetre, avec des angles droits
  pour son corps et ses boutons, sans melange carre/capsule.
  Les IDs restent des indices
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

## Espacement mobile et regulation

- Echange leger de voyageurs, sans economie ni simulation de demande globale.
  Chaque voiture offre deux portes et douze places abstraites. Au moins deux
  entrants par porte quand la capacite le permet ; les flux sont plus fournis.
  Le flux local
  varie de facon deterministe par ligne/arret/visite, sans dependance au zoom
  ni aux identifiants globaux des trains d'autres lignes. Les voyageurs restent
  a bord entre arrets ; tous descendent au terminus. Pas de destinations/transferts.
  Descente avant montee, avec departs et vitesses decales dans chaque lot.
  Un generateur local initialise par ligne/arret/visite choisit les trajectoires
  et horaires une seule fois ; le rendu ne consomme pas de hasard global.
  Le comptage a bord suit la fin de chaque trajet, pas la fin d'un lot.
  Le temps d'echange est
  plafonne a l'arret minimum choisi + 2s lors de l'arrivee ; la recuperation au
  terminus reste separee. Les estimations de cycle/intervalle/capacite integrent
  la marge de 2s, pour conserver un dimensionnement prudent de la flotte.
- Au-dessus du zoom 1.5, quais et minuscules silhouettes apparaissent doucement
  jusqu'au zoom 3. Un seul quai continu suit la position et l'orientation de
  chaque voiture, y compris dans les courbes ; ce n'est pas un rectangle impose.
  Un ruban guide par les centres des voitures et les deux extremites conserve
  les caps, sans les marches formees par chaque bout de caisse. Echantillonnage
  commun aux deux bords (2px maximum), moyenne locale et quatre passes de lissage ;
  simplification des bords limitee aux segments quasi collineaires (0.00001),
  pour garder les courbes sans facettes ; tours locaux testes sous 8 degres.
  les joints et points tactiles suivent la longueur du bord lisse.
  Une union du ruban resout les replis en un contour simple : beton discret, joints,
  bordure et bande tactile chaude continue, sans plaques separees par voiture.
  Les silhouettes sont plus petites (rayon 0.34 au lieu de 0.48), avec couleurs
  de manteaux/peaux variees, positions d'attente dispersees, vitesses individuelles
  et courts trajets contenus sur le quai. L'aire de marche est le contour du quai
  reduit du rayon du voyageur + 0.2px avec jointures en onglet ; chaque trajet
  est coupe a cette aire,
  avec vitesse limitee a 4px/s (pic du smoothstep). Les sortants continuent leur
  trajet sur le quai apres avoir quitte la rame ; les entrants commencent leur
  approche plus tot, avant leur lot. Le temps visuel est distinct du comptage
  d'embarquement : pas de prolongation d'arret. Seuls les entrants sans assez
  de temps ont un trajet raccourci.
  Ces chemins sont caches a la creation de la visite, sans projection par image.
  Les portes
  du cote quai s'ouvrent, les sortants marchent un peu puis s'effacent sur le quai ;
  les entrants emergent puis rejoignent les portes. Quais effaces 1.2s apres
  depart/retrait de service. Horloge de simulation partagee : pause fige tout,
  y compris l'ambiance jour/nuit ; edition efface les visites. Pas de nouveaux
  boutons ; rendu hors vue ignore.

- L'interlocking global, les sections entieres reservees et l'echange atomique
  des places en station sont retires. Ces derniers synchronisaient des vagues
  de departs et limitaient artificiellement les longs trajets entre stations.
- Chaque rame calcule son autorisation jusqu'a l'arriere de celle qui precede,
  avec longueur complete, marge de 14 pixels et temps de reaction de 0.25s.
  Le freinage prend cette autorisation et la station suivante comme limites.
  La station connue utilise une marge d'un sous-pas, plutot que les 0.25s
  reserves a la rame precedente, evitant une longue fin d'approche au ralenti.
  Les deplacements sous-pixel conservent leur vitesse et leur acceleration.
  Les boucles isolent les sens ; une ligne ouverte conserve son circuit continu
  aller/retour. Aucun test geometrique ne couple deux lignes.
- L'utilisateur a rejete les grandes courbes aux stations : retour aux arrondis
  quadratiques serres d'origine, 12px aux stations et 24px ailleurs, limites a
  35 % du segment adjacent. Pas de zones droites imposees ni suppression des ancrages.
  Les arrets retrouvent leur projection sur la station ; les plateformes
  s'adaptent a la rame, jamais l'inverse. Les terminus gardent leurs caps normaux
  et un raccord vers une voie terminale commune. Toutes les voitures restent
  dessinees et selectionnables ; seul le marqueur opaque les recouvre.
- Acceleration 80 px/s2 et freinage 100 px/s2 sont independants de la vitesse
  maximale. La marche nominale utilise 90% de cette vitesse, laissant une
  marge pour rattraper un retard. Pas de nouveau curseur ni de retard aleatoire.
- L'intervalle cible est le maximum de l'intervalle choisi, du cycle / flotte
  et d'un intervalle minimal estime par arret et degagement de la rame.
  Il n'est plus impose par le temps de la section interstation la plus longue.
  Le cycle estime integre les rampes d'acceleration/freinage, les arrets et
  une recuperation de 4s a chaque terminus (aucune recuperation sur boucle).
- Un depart trop proche du precedent recoit une attente proportionnelle,
  plafonnee a 3s. L'erreur d'intervalle au depart ajuste ensuite la marche,
  au plus 10% sous la vitesse nominale et jamais au-dessus du maximum choisi.
  La protection de mouvement reste prioritaire, y compris hors station.
- Capacite conservatrice : minimum de la place geometrique (double espacement
  rame+marge et une place libre) et du cycle / intervalle minimal par circuit.
  Ce n'est pas une certification de capacite ferroviaire reelle.
  La flotte conseillee somme les cycles / intervalle souhaite de chaque sens
  d'une boucle. Le service utilise le minimum du plafond manuel et de cette
  recommandation. Le tooltip du maximum montre conseil et capacite.
- Les apparitions sont echelonnees et reessaient si l'origine est occupee.
  Une baisse de frequence ou du plafond retire les rames excedentaires au terminus ou a
  l'origine d'une boucle, sans couper les rames en marche. Les fragments
  heritent des reglages de marche/recuperation et du plafond souhaite.
  Vitesse/arret/intervalle changent en marche ; une baisse de vitesse freine
  progressivement. La pause fige l'horloge ; une edition efface rames/historique.
- Tests de progression sur six minutes : croisement perpendiculaire,
  terminus partage, stations proches avec segment commun, trois lignes a
  vitesses differentes. Verification de l'espacement complet et de la progression
  des deux sens, pas seulement du premier train. Tests d'horaires dedies :
  independance exacte face a une ligne seule, plusieurs trains entre stations,
  acceleration/freinage mesures, leader arrete, recommandations de flotte,
  departs et changements de reglages en marche. Comparaison controlee avec
  regulation desactivee : ecart-type des intervalles reduit d'au moins 25%.
  Terminus charges et reseau reproduisant la capture utilisateur inclus.

## Interface integree a la carte

- Un ecran de veille distinct du mode contemplation manuel se lance avec K
  ou Menu. Il masque tout le HUD, y compris la poignee et le curseur, et
  demande le plein ecran sans le rendre permanent. Vue complete 35s, suivi
  40s, panoramique zoome 40s, autre suivi 40s : boucle continue, transitions
  smoothstep de 6s. Les suivis privilegient une autre ligne puis une autre rame ;
  sans train, ils gardent une vue complete. Le panoramique suit une petite
  section du circuit et parcourt au plus la moitie du petit axe de l'ecran
  pour rester lent meme sur Tokyo. L'ajustement partage les bornes de la
  carte avec le bouton Ajuster, mais ne reserve que 32px sur chaque bord
  puisque le HUD est absent. Un redimensionnement adapte cet apercu.
  Les trains existants continuent sans reconstruction, temporairement
  depauses ; sortie par Echap ou clic/toucher consomme l'action et sa fin,
  restaure pause, cadrage, suivi manuel, curseur et mode de fenetre exacts.
  Mouvement, molette et autres touches sont ignores pour un usage kiosque.
  Aucun lancement automatique par inactivite ni etat persiste.
  Un passage FXAA avec stabilisation des details sous-pixel lisse les bords
  en pixels ecran pendant ce mode uniquement. Il reduit le scintillement des
  rails et voitures lors des mouvements fractionnaires, sans elargir la frange
  en unites monde ni toucher au HUD (compose ensuite). Le mode Compatibility
  ne permet pas de compter sur le MSAA 2D ; aucun historique temporel ou
  arrondi des positions de camera/train n'est utilise.

- La carte reste le premier plan : plus de panneau lateral permanent.
  Une barre discrete en haut regroupe Pause, Aide et Menu ; un
  rail plat de 60 pixels logiques longe tout le bord inferieur, sans capsule,
  ombre ni coins arrondis. Les onglets numerotes ont un trait de la couleur
  de ligne ; la selection reste lisible quelle que soit cette couleur.
  Le + partage le style souligne des onglets et suit immediatement la derniere
  ligne dans leur conteneur defilant, sans grand vide entre les actions.
  Le repli reste fixe a droite ; onglets et + gardent des largeurs minimales.
  Le repli montre une icone de panneau avec fleche descendante,
  et laisse la meme icone avec la fleche inverse au meme endroit, en bas a droite.
  Les rectangles de clic restent identiques, meme quand les onglets defilent.
  Les deux sont sans texte, avec infobulle traduite et cible de 44px.
  L'icone inferieure rouvre le rail
  sans changer de ligne ni mettre les trains en pause.
- Apres huit secondes d'inactivite, les commandes passent progressivement a
  28 % d'opacite le jour, 70 % la nuit sombre, en 0,6 seconde. Le seuil suit
  la transition jour/nuit ; les panneaux papier et textes contrastes restent
  lisibles. Mouvement, touche ou toucher les restaure
  immediatement, sans consommer l'action. Feuilles, dialogues, picker et gestes
  en cours empechent l'estompage. Aucun etat de repli n'est persiste.
- Quand la simulation est en pause et que les transitions, le titre et les
  notifications sont termines, la boucle de rendu s'arrete. Une entree ou un
  redimensionnement la relance ; le mode contemplation conserve son animation.
  La pause fige aussi l'ambiance jour/nuit, afin que l'image reste stable.
- Aide et reglages sont centres sur la zone sure de la vue, independamment
  du rail inferieur. Aide, reglages et sauvegardes ont un ScrollContainer
  borne par la hauteur disponible, pour rester utilisables en portrait et avec
  les traductions. Le titre Metro utilise 48px logiques en haut a gauche,
  reste opaque dix secondes, puis suit une
  courbe smoothstep jusqu'a disparaitre a trente secondes. Ce delai reel continue
  pendant la pause et le mode contemplation ; ni l'activite, ni les changements
  de langue ou de taille ne le font revenir. Son opacite est independante du HUD.
- Cliquer une ligne deplie ses cinq reglages dans le meme rail, au-dessus
  des onglets, sans panneau flottant ni bordure coloree. La hauteur suit le
  contenu, plafonnee a 300 pixels ; les colonnes s'adaptent (une sur telephone,
  trois sur portable, cinq sur grand ecran). Retoucher la ligne active replie
  les reglages ; changer de ligne garde les reglages ouverts.
  L'entete fixe comporte un bouton explicite Replier de 44 pixels ; le contenu
  defile en dessous sans faire disparaitre ce bouton. La pastille de couleur
  elargie est placee a cote du libelle Couleur de la ligne. Supprimer la ligne
  demande confirmation et retire les trains, voies et stations exclusives ;
  les interchanges, voies partagees et toute infrastructure independante restent.
  `TransitGraph.remove_line()` reindexe les lignes/voies/stations survivantes.
  La derniere suppression laisse une ligne vide ; pause et camera sont conservees,
  les circuits et trains sont reconstruits comme lors des autres edits topologiques.
  Menu et Aide restent des feuilles, une seule surface detaillee ouverte a
  la fois. Fermer ou Echap rend tout l'espace a la carte sans mettre en pause.
  Sous 620 pixels, les feuilles passent a une colonne avec defilement ;
  les lignes debordantes defilent horizontalement vers la selection.
  Le bouton Reglages de ligne, redondant avec les onglets, est supprime.
- Le tactile ne simule plus l'edition a la souris : un doigt deplace la vue,
  deux doigts pincent/recadrent, un toucher selectionne. Un panneau persistant
  expose Deplacer/Relier/Supprimer pour une station, Inserer/Remodeler/Supprimer
  pour un rail, et Ajouter une station sans selection. Placement et remodelage
  ont un apercu puis Confirmer ; Deplacer garde une restauration des voies
  d'origine jusqu'a Confirmer. Annuler restaure l'etat, sans suppression implicite.
  Relier utilise les memes chemins elastiques et validations que la souris,
  avec actions tactiles Annuler l'etape/Inverser/Annuler. Aucune station n'est
  creee par un toucher libre ou une navigation. Les evenements souris emules
  restent disponibles au GUI, jamais a l'edition du monde. Les vrais evenements
  souris retrouvent les commandes desktop.
  Les actions font 48px, la selection des stations au moins 48px de diametre.
  La selection d'une station la garde au-dessus du panneau sans changer le zoom.
  Portrait et paysage suivent les capteurs mobiles ; les controles respectent
  la zone sure native ou les insets CSS du navigateur. La rotation ne refait
  pas le cadrage manuel et annule un geste tactile encore en contact.
- Papier chaud, encre sombre, bordures fines et formes arrondies reprennent
  le vocabulaire des stations et des plans de transport, plutot que celui
  d'un tableau de bord logiciel. Les couleurs choisies restent originales ;
  aucun actif tiers n'est utilise.
- Corps de texte de 16 pixels logiques minimum, titres de 22/26 pixels,
  boutons de 44 pixels et curseurs de 32 pixels minimum. Les contrastes sont
  testes : 7:1 pour le texte principal, 4.5:1 pour le texte secondaire et
  les onglets selectionnes. Un numero accompagne toujours la couleur.
- Le facteur de densite de l'ecran pilote `Window.content_scale_factor` avec
  rendu `canvas_items`, sans reduire l'interface pour faire entrer un panneau.
  La fenetre native et sa taille minimale sont aussi exprimees en pixels
  logiques. La Web conserve son canvas haute resolution et ses tailles CSS.
- Une pastille par ligne ouvre un selecteur de teinte libre, un champ
  hexadecimal et les presets, sans les curseurs RGB techniques ni alpha.
  Il tient sur un petit ecran. Les retours d'action sont lisibles mais
  temporaires, et n'interceptent pas les clics sur la carte. Aucun message de
  succes pour placer/deplacer/sauver/supprimer/recolorer ou changer de ligne :
  le resultat est visible. Erreurs et avertissements gardent huit secondes.
  Le toast mesure le texte avec la police courante (largeur max 520 pixels,
  hauteur du texte replie plus marges). Il n'utilise pas la taille minimale
  conservee d'un PanelContainer/autowrap, et retrecit apres un message long.
  Seule la feuille visible recoit le retour : ne jamais afficher/remplir les
  labels de retour des feuilles cachees, dont l'autowrap peut fausser la taille.
  L'aide est une fiche de gestes concise, pas un tutoriel en paragraphes.
- Avant la premiere liaison de la session, un + discret reste visible sur la
  premiere station, sans texte ni pulsation. Il disparait apres une liaison
  reussie, meme si le reseau est ensuite supprime. Pendant le dessin, un cercle
  discret indique les destinations compatibles avec le chemin epingle courant,
  la geometrie et la longueur de rame. Annuler efface ces indications ;
  feuilles ouvertes et mode observation masquent toute guidance.
- Les couleurs des rails, rames, onglets et apercus changent immediatement.
  Aucun circuit ni train n'est reconstruit pour une modification de couleur.
  Changer de ligne ferme le picker et synchronise la pastille selectionnee.
- Aucun mode Station : cliquer sur un espace libre place une station ; un
  disque translucide anticipe sa position sur la grille invisible. L'apercu
  utilise exactement le meme arrondi que le placement, sans modifier le graphe.
  Il disparait sur les stations, rails, trains, controles, feuilles et dialogues,
  pendant un geste, un deplacement de vue ou lorsque le pointeur sort du jeu.
- H ou Menu masque l'interface pour regarder le reseau. Une poignee de
  36 x 3 pixels, sans texte ni fond, reste au bord inferieur. Sa zone tactile
  de 96 x 44 pixels est independante de l'interface masquee ; elle ne
  s'estompe jamais et adapte son contraste au jour/nuit. H ou Echap fonctionne
  aussi. Ce mode conserve la
  pause existante, la musique et la circulation ;
  deplacement, zoom et suivi des trains restent disponibles, mais les clics
  n'editent jamais le graphe. Les gestes en cours sont annules proprement.
  Les selections, poignees, apercus et legendes sont aussi masques.
- Suivre un train conserve le HUD mais masque toute surcouche d'edition :
  station fantome, selections, poignees, guidance et tracés temporaires.
  Clics et Suppr n'editent pas la carte ; choisir une autre rame reste possible.
  Echap/deplacement/redispatch termine le suivi et restaure les surcouches
  seulement si le HUD n'est pas masque.

References de conception consultees :
[Mini Metro, presentation officielle](https://dinopoloclub.com/games/mini-metro/)
pour le langage cartographique minimaliste ;
[taille de texte](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/)
et [couleur non exclusive](https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/)
pour la lisibilite ; [densite et resolutions Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html#hidpi-support)
pour la mise a l'echelle Retina/Web. Les recommandations TV de taille de texte
ne sont pas appliquees directement a un portable vu de pres.

## Voies rapprochees et stations simples

- Les voies physiques passent a +/-8 pixels du centre, au lieu de +/-11 :
  16 pixels entre les rames, pour des voitures de 7 pixels de large.
  Le rendu, l'apercu et la simulation partagent toujours le meme offset.
- Stations : centre blanc de rayon 10 pixels pour zero/une ligne, puis
  +1 pixel par ligne supplementaire, sans halo ni ombre.
  Chaque ligne desservie ajoute un anneau de 2 pixels dans sa couleur assombrie
  de 30 %. Ordre stable des lignes : anciennes a l'exterieur, nouvelles dedans.
  Le rayon total est 10 + max(0, lignes - 1) + 2 x max(1, lignes) :
  12/15/18 pixels pour une/deux/trois lignes. Les correspondances grandissent
  sans comprimer les anneaux ; poignees, selections et degagement des trains
  suivent ce rayon via les helpers partages de TrackGeometry.
  Les boucles ne dupliquent pas l'anneau de leur station de fermeture.
  Recolorer ou retirer une ligne met a jour les anneaux immediatement.
  Sans ligne, la bordure reste neutre. La nuit, le blanc est legerement adouci
  et seule cette bordure neutre est eclaircie.
  Le remplissage et les anneaux restent opaques au-dessus des trains.
  L'essai de transparence a ete rejete : il exposait les rails sous le centre.
  Les rames sont masquees par la geometrie du marqueur, jamais rendues invisibles.

## Courbes aux stations et fins de ligne

- Le chemin central complet est arrondi avant la separation des deux voies.
  Les marqueurs restent sur la grille ; les courbes quadratiques coupent
  legerement le coin, comme auparavant. La preference pour les coudes serres
  remplace les essais de courbes centrees/elargies. Tous les arrondis gardent
  une subdivision adaptative de Casteljau : deviation
  du segment sous 0,01px monde, ecart tangente/segment sous 1 degre, profondeur
  maximale 12. Les tests imposent moins de 3 degres entre segments consecutifs
  sur 45/90/135 degres et huit orientations. Pas de geometrie dependante du zoom.
  L'ancien raccord quadratique entre voies deja decalees pincait les voies
  au centre des stations en virage, causant un blocage face a face.
- Les arrets sont projetes sur les segments du circuit, et pas uniquement
  sur ses sommets : supprimer un sommet collineaire ne deplace pas un arret.
- Les terminus ajoutent une recuperation au temps d'arret. Les voies convergent
  progressivement sur le centre avant la station, sur une zone commune assez
  longue pour toute la rame. Le raccord ne depasse pas la station voisine.
  Seuls ces abords changent ; les coudes intermediaires et ancrages restent fixes.
- Au depart, la tete devient l'ancienne derniere voiture : la distance logique
  avance du nombre de wagons fois le pas plus deux fois le retrait du terminus.
  Ce retrait vaut rayon du marqueur + demi-voiture + 3px : la cabine et son quai
  restent a l'exterieur du cercle, y compris aux terminus partages plus grands.
  Les arrets intermediaires et les deux sens des boucles utilisent la meme
  distance au marqueur : projection puis recul jusqu'au cercle de degagement,
  du cote d'arrivee. Seuls les points d'arret changent, pas les voies ; les
  trains traversent les stations sous les cercles lorsqu'ils repartent.
  Le circuit revient sur le meme chemin
  commun avant de reprendre la voie de retour. Les positions physiques de chaque
  voiture sont identiques au changement de cabine ; aucun glissement lateral,
  demi-tour serre ou chemin cache au-dela du cap. `car_axis` conserve une
  tangente definie au point de rebroussement pour cabines, portes et soufflets.
- Le dispatcher protege independamment chaque raccord de terminus par un seul
  proprietaire, acquis avant la distance de freinage. Les autres rames attendent
  avant le raccord. La reservation reste active jusqu'au degagement du dernier
  wagon, avec marge de securite ; pause la conserve, retrait/rebuild la liberent.
  Les lignes restent independantes. Les boucles n'ont pas cette reservation.
- Une ligne trop courte pour loger deux zones terminales ne dispatchera pas ;
  une erreur localisee demande de l'allonger ou de reduire les wagons.
  Le calcul de cycle retire la distance logique sautee lors du changement de
  cabine ; l'espacement mobile valide aussi cette avance avant le depart.
- Les coeurs lumineux et halos de rails sont decoupes autour des stations
  partagees (rayon du marqueur + 24px), puis reapparaissent progressivement
  sur 16px, sans coupure lumineuse nette ni changer bandes, voies physiques,
  phares ou simulation. Les chemins d'illumination sont caches au rebuild,
  et leurs commandes de dessin sont retenues ; seule l'opacite de nuit varie
  par modulation. Les halos et ombres de corridor sont fusionnes en meshes par
  ligne/couche. Les caisses et nez de cabine sont soumis en un lot de triangles
  par rame, avec les memes sommets, couleurs et ordre entre rames. Les
  superpositions de raccords restent discretes plutot que soulignees par une
  croix lumineuse. Le grain mate utilise une texture periodique ancree au monde,
  echantillonnee a ses deux echelles d'origine.
