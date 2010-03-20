# translation from: Franck Aniere <aniere@genoscope.cns.fr>
# do not remove the { } from the top and bottom of this page!!!
{
   #----------
   # MAIN PAGE
   #----------

 CHARSET =>   'ISO-8859-1',

   PAGE_TITLE => 'Genome browser',

   SEARCH_INSTRUCTIONS => <<END,
Vous pouvez faire une recherche en utilisant un
nom de séquence, un nom de gène, un locus %s,
ou un autre référentiel. Le caractère spécial * est
autorisé.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Pour vous recentrer sur un emplacement, cliquez sur la règle. Utilisez
les boutons Défil./Zoom pour changer l'échelle et la position. Pour
sauvegarder cette vue, <a href="%s">ajoutez ce lien à vos favoris.</a>
END

   EDIT_INSTRUCTIONS => <<END,
Editez vos données d'annotations additionnelles ici. Vous pouvez
utiliser des tabulations ou des espaces pour séparer les champs,
mais les champs contenant des espaces doivent être contenus dans
des quotes (simples ou doubles).
END

   SHOWING_FROM_TO => 'Vue de %s depuis %s, positions %s à %s',

   INSTRUCTIONS      => 'Instructions',

   HIDE              => 'Cacher',

   SHOW              => 'Montrer',

   SHOW_INSTRUCTIONS => 'Montrer les instructions',

   HIDE_INSTRUCTIONS => 'Cacher les instructions',

   SHOW_HEADER       => 'Montrer l\'en-tête',

   HIDE_HEADER       => 'Cacher l\'en-tête',

   LANDMARK => 'Référentiel ou Région',

   BOOKMARK => 'Ajouter cet affichage à vos favoris',

   IMAGE_LINK => 'Lien vers une image de cet affichage',

   SVG_LINK   => 'Image haute qualité pour les publications',

   SVG_DESCRIPTION => <<END,
<p>
Le lien suivant permet de générer une image au format Scalable Vector Graphic (SVG). Les images SVG disposent de certains avantages sur les images bitmap (jpeg or png for exampe).
</p>
<ul>
<li>Possibilité de redimmensionner l'image sans perte de résolution
<li>Edition objet par objet dans dans des applications de dessin vectoriel
<li>Conversion au format EPS (Encapsulated PostScript) si nécessaire pour des soumissions de publications
</ul>
<p>
Pour voir des images SVG, vous devez disposer d'un navigateur qui sache les afficher, le plugin Adobe SVG, ou une application de visualisation/édition SVG telle qu'Adobe Illustrator.
</p>
<p>
Plugin Adobe pour navigateurs : <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Les utilisateurs de Linux peuvent regarder le <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a>.
</p>
<p>
<a href="%s" target="_blank">Voir l'image SVG dans une nouvelle fenêtre du navigateur.</a></p>
<p>
Pour Sauver cette image sur votre disque, control-click (Macintosh) ou bouton-droit de la souris (windows) et choisisser l'option pour sauver le lien sur disque.
</p>
END

   IMAGE_DESCRIPTION => <<END,
<p>
Pour créer une image incrustée de cet affichage, il faut copier et coller
cette URL dans une page HTML :
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
L'image ressemblera à ceci :
</p>
<p>
<img src="%s" />
</p>

<p>
Si seul l'aperçu (affichage d'un chromosome ou contig) est visible, il
faut essayer de réduire la taille de la région.
</p>
END

TIMEOUT  => <<'END',
Le délai alloué pour votre requête a expiré. Vous avez probablement choisi une
région trop grande pour être affichée. Vous pouvez décocher quelques pistes ou essayer une région plus petite. Si le problème persiste, veuillez cliquer sur le bouton rouge ("Remise à zéro").
END


   GO       => 'Lancer',

   FIND     => 'Trouver',

   SEARCH  => 'Chercher',

   DUMP     => 'Sortie',

   HIGHLIGHT   => 'Surligner',

   ANNOTATE     => 'Annoter',

   SCROLL   => 'Défil./Zoom',

   RESET    => 'Remise à zéro',

   FLIP     => 'Inversion',

   DOWNLOAD_FILE    => 'Télécharger un fichier',

   DOWNLOAD_DATA    => 'Télécharger des données',

   DOWNLOAD         => 'Télécharger',

   DISPLAY_SETTINGS => 'Préférences d\'affichage',

   TRACKS   => 'Pistes',

   EXTERNAL_TRACKS => '(Pistes externes en italique)',

   OVERVIEW_TRACKS => '<sup>*</sup>Piste d\'aperçu',

   REGION_TRACKS => '<sup>**</sup>Piste des régions',

   EXAMPLES => 'Exemples',

   REGION_SIZE => 'Taille de la région (pb)',

   HELP     => 'Aide',

   HELP_FORMAT => 'Aide sur le format de fichiers',

   CANCEL   => 'Annuler',

   ABOUT    => 'A propos...',

   REDISPLAY   => 'Rafraichir l\'affichage',

   CONFIGURE   => 'Configurer...',

   CONFIGURE_TRACKS   => 'Configurer les pistes...',

   EDIT       => 'Editer le fichier...',

   DELETE     => 'Effacer le fichier',

   EDIT_TITLE => 'Entrer/éditer des données d\'annotation',

   IMAGE_WIDTH => 'Largeur d\'image',

   BETWEEN     => 'Entre les pistes',

   BENEATH     => 'Sous l\'affichage',

   LEFT        => 'Left',

   RIGHT       => 'Right',

   TRACK_NAMES => 'Tableau des pistes',
 
   ALPHABETIC => 'Tri alphabétique',

   VARYING => 'Pas de tri',

   SET_OPTIONS => 'Configurer les pistes...',

   CLEAR_HIGHLIGHTING => 'Supprimer le surlignage',

   UPDATE      => 'Mise à jour de l\'image',

   DUMPS       => 'Sorties, recherches et autres opérations',

   DATA_SOURCE => 'Source de données',

   UPLOAD_TRACKS =>'Ajouter vos propres pistes',

   UPLOAD_TITLE => 'Ajouter vos propres annotations',

   UPLOAD_FILE => 'Ajouter un fichier',

   KEY_POSITION => 'Position des légendes',

   BROWSE      => 'Parcourir...',

   UPLOAD      => 'Ajouter',

   NEW         => 'Nouveau...',

   REMOTE_TITLE => 'Ajouter des annotations distantes',

   REMOTE_URL   => 'Entrer une URL pour des annotations distantes',

   UPDATE_URLS  => 'Mettre à jour les URLs',

   PRESETS      => "--Choix d'une URL prédéfinie--",

   FEATURES_TO_HIGHLIGHT => 'Surligner les informations (info1 info2...)',

   REGIONS_TO_HIGHLIGHT => 'Surligner les régions (région1:début..fin région2:début..fin)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Astuce : utilisez information@couleur pour choisir la couleur, par exemple \'NUT21@lightblue\'',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Astuce : utilisez région@couleur pour choisir la couleur, par exemple \'Chr1:10000..20000@lightblue\'',
	    
   NO_TRACKS    => '*aucune*',

   FILE_INFO    => 'Dernière modif. %s.  Référentiel annoté : %s',

   FOOTER_1     => <<END,
NB: Cette page utilise un cookie pour sauver et restituer les informations
de configuration. Vos informations ne sont pas partagées.
END

   FOOTER_2    => 'Generic genome browser version %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Les  %d régions suivantes correspondent à votre requête.',

   POSSIBLE_TRUNCATION => 'Les résultats de la recherche sont limités à %d hits ; la liste risque d\'être incomplète.',

   MATCHES_ON_REF => 'Correspondance avec %s',

   SEQUENCE        => 'séquence',

   SCORE           => 'score=%s',

   NOT_APPLICABLE => 'n/a',

   BP             => 'pb',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Paramètres pour %s',

   UNDO     => 'Annuler les modifications',

   REVERT   => 'Valeurs par défaut',

   REFRESH  => 'Rafraichir',

   CANCEL_RETURN   => 'Annuler les modifications et revenir...',

   ACCEPT_RETURN   => 'Accepter les modifications et revenir...',

   OPTIONS_TITLE => 'Options de pistes',

   SETTINGS_INSTRUCTIONS => <<END,
La boite <i>Voir</i> active ou désctive la piste. L'option
<i>Compacter</i> force la piste à être consensée pour que 
les annotations se chevauchent. Les options <i>'Etendre'</i>
et <i>Hyperétendre</i> activent un contrôle de collision qui
utilise des algorithmes de mise en page plus lents et plus rapides.
Les options <i>Etendre</i> &amp; <i>étiqueter</i> et <i>Hyperétendre</i>
&amp; <i>étiqueter</i> rend obligatoire l'étiquetage des annotations.
Si <i>Auto</i> est sélectionné, le contrôle de collision et les
options d'étiquetage seront réglées automatiquements si l'espace
le permet. Pour changer l'ordre des pistes, utilisez le menu 
<i>Changer l'ordre des pistes</i> pour assigner une annotation
à une piste. Pour limiter le nombre d'annotations de ce type
devant être affichées, il faut changer la valeur du menu
<i>Limite</i>.
END

   TRACK  => 'Piste',

   TRACK_TYPE => 'Type de Piste',

   SHOW => 'Voir',

   FORMAT => 'Format',

   LIMIT  => 'Limite',

   ADJUST_ORDER => 'Ajuster l\'ordre',

   CHANGE_ORDER => 'Changer l\'ordre des pistes',

   AUTO => 'Auto',

   COMPACT => 'Compacter',

   EXPAND => 'Etendre',

   EXPAND_LABEL => 'Etendre & étiqueter',

   HYPEREXPAND => 'Hyperétendre',

   HYPEREXPAND_LABEL =>'Hyperétendre & étiqueter',

   NO_LIMIT    => 'Pas de limite',

   OVERVIEW    => 'Aperçu',

   EXTERNAL    => 'Externe',

   ANALYSIS    => 'Analyse',

   GENERAL     => 'Général',

   DETAILS     => 'Détails',

   REGION      => 'Région',

   ALL_ON      => 'Tout activer',

   ALL_OFF     => 'Tout désactiver',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Fermer cette fenêtre',

   TRACK_DESCRIPTIONS => 'Description de la piste citations',

   BUILT_IN           => 'Pistes disponibles sur ce serveur',

   EXTERNAL           => 'Pistes d\'annotation externes',

   ACTIVATE           => 'Veuillez activer cette piste pour voir ses informations.',

   NO_EXTERNAL        => 'Il n\'y a pas de caractéristiques externes chargées.',

   NO_CITATION        => 'Il n\'y a pas d\'informations supplémentaires disponibles.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'A propos de %s',

 BACK_TO_BROWSER => 'Retour au Browser',

 PLUGIN_SEARCH_1   => '%s (via la recherche %s)',

 PLUGIN_SEARCH_2   => '&lt; Recherche %s &gt;',

 CONFIGURE_PLUGIN   => 'Configurer',

 BORING_PLUGIN => "Ce module n'a pas de paramètres de configuration supplémentaires.",

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => "Le référentiel <i>%s</i> n'est pas reconnu. Voyez l\'aide pour des suggestions.",

 TOO_BIG   => 'La vue détaillée est limitée à %s bases.  Cliquez sur la vue d\'ensemble pour sélectionner une région de largeur %s pb.',

 PURGED    => "Impossible de trouver le fichier nommé %s.  Peut être a-t-il été supprimé ?",

 NO_LWP    => "Ce serveur n\'est pas configuré pour ramener des URLs externes.",

 FETCH_FAILED  => "Je n\'ai pas pu retrouver %s: %s.",

 TOO_MANY_LANDMARKS => '%d référentiels.  La liste est trop grande.',

 SMALL_INTERVAL    => 'Redimmensionnement du petit intervalle à %s pb',

 NO_SOURCES        => 'Vous n\'avez pas configuré de sources de données. Peut-être n\'avez-vous pas les droits pour les voir.',

};
