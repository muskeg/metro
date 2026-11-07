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
  Echap, un deplacement manuel de la vue ou la reconstruction du reseau
  interrompt ce suivi.
- Le freinage respecte la station suivante et l'autorisation de mouvement.
  La regulation de service est distincte de cette securite. Le reglage
  d'intervalle reste un minimum souhaite ; le maximum de rames reste un plafond.
  Simulation subdivisee a 60 Hz ; les croisements hors station restent refuses.
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
  au-dessus des voies, sous les voitures.
- Le monde n'a pas de bord fixe. Molette et pincement partagent le zoom
  0,08-6x, contre 0,45-6x auparavant, pour les grandes cartes. Pas d'import
  geographique ni de certification de performances pour un reseau JR East complet.
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
  edition efface les visites. Pas de nouveaux boutons ; rendu hors vue ignore.

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
- Aide et reglages sont centres sur la taille reelle de la vue, independamment
  du rail inferieur. Les reglages utilisent une pile directe sans ScrollContainer,
  avec hauteur adaptee au contenu et aux traductions ; l'aide garde son defilement
  sur petit ecran. Le titre Metro utilise 48px logiques en haut a gauche,
  reste opaque dix secondes, puis suit une
  courbe smoothstep jusqu'a disparaitre a trente secondes. Ce delai reel continue
  pendant la pause et le mode contemplation ; ni l'activite, ni les changements
  de langue ou de taille ne le font revenir. Son opacite est independante du HUD.
- Cliquer une ligne deplie ses cinq reglages dans le meme rail, au-dessus
  des onglets, sans panneau flottant ni bordure coloree. La hauteur suit le
  contenu, plafonnee a 300 pixels ; les colonnes s'adaptent (une sur telephone,
  trois sur portable, cinq sur grand ecran). Retoucher la ligne active replie
  les reglages ; changer de ligne garde les reglages ouverts.
  Menu et Aide restent des feuilles, une seule surface detaillee ouverte a
  la fois. Fermer ou Echap rend tout l'espace a la carte sans mettre en pause.
  Sous 620 pixels, les feuilles passent a une colonne avec defilement ;
  les lignes debordantes defilent horizontalement vers la selection.
  Le bouton Reglages de ligne, redondant avec les onglets, est supprime.
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
- Stations : centre blanc de rayon 10 pixels, sans halo. Leur ombre solaire
  discrete suit le cycle du jour, contrairement a une ombre fixe de bouton.
  Chaque ligne desservie ajoute un anneau de 2 pixels dans sa couleur assombrie
  de 30 %. Ordre stable des lignes : anciennes a l'exterieur, nouvelles dedans.
  Le rayon total est 10 + 2 x nombre de lignes (minimum 12). Les correspondances
  grandissent sans comprimer le centre ; poignees et selections suivent ce rayon.
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
  pas recalcules a chaque image. Les superpositions de raccords restent
  discretes plutot que soulignees par une croix lumineuse.
