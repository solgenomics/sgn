# do not remove the { } from the top and bottom of this page!!!
# Guenther Weberndorfer <guenther.weberndorfer@insilico.com>
{

 CHARSET =>   'ISO-8859-1',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Genome Browser',

   SEARCH_INSTRUCTIONS => <<END,
Suche nach Sequenz Namen, Gen Namen,
Locus Namen oder anderen Landmarks. 
Der Platzhalter * ist erlaubt.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Um einen Locus zu zentrieren, auf das Lineal klicken.
Um zu vergr&ouml;ssern oder die Position zu ver&auml;ndern 
verwendet man die Scroll/Zoom Kn&ouml;pfe.
END

   EDIT_INSTRUCTIONS => <<END,
Die hinaufgeladenen Annotationsdaten k&ouml;nnen hier editiert 
werden. Tabulatoren und Leerzeichen sind erlaubt um Felder zu 
trennen, Felder die Leerzeichen enthalten m&uuml;ssen in einfache 
oder doppelten Anf&uum;hrungszeichen gesetzt werden.
END

   SHOWING_FROM_TO => 'Darstellung %s von %s, Position %s bis %s',

   INSTRUCTIONS      => 'Anleitungen',

   HIDE              => 'Ausblenden',

   SHOW              => 'Zeigen',

   SHOW_INSTRUCTIONS => 'Anleitungen anzeigen',

   HIDE_INSTRUCTIONS => 'Anleitungen ausblenden',

   SHOW_HEADER       => 'Banner zeigen',

   HIDE_HEADER       => 'Banner ausblenden',

   LANDMARK => 'Landmark oder Region',

   BOOKMARK => 'Bookmark f&uuml;r diese Ansicht',

   IMAGE_LINK => 'Link zur Abbildung dieser Ansicht',

   SVG_LINK   => 'Abbildung in Publikationsqualit&auml;t',

   SVG_DESCRIPTION => <<END,
<p>
Der Folgende Link wird eine Abbildung im Scalable Vector
Graphic (SVG) Format erzeugen. SVG Bilder bietet einige Vorteile 
gegen&uuml;ber Raster basierten Formaten wie jpeg oder png:
</p>
<ul>
<li>Voll skalierbar ohne Verlust an Aufl&oum;sung.</li>
<li>Einzelne Features sind in gebr&auml;uchlich Vektor Grafik Programmen editierbar.</li>
<li>wenn notwendig ist eine Konvertierung in EPS zur Einreichung von Publikationen m&ouml;glich</li>
</ul>
<p>
Um SVG zu betrachten brauchen sie einen SVG f&auml;higen Browser, das Adobe SVG Browser Plugin oder Programm zum Editieren oder Betrachten von SVG wie zum Beispiel Adobe Illustrator.
</p>
<p>
Adobe's SVG Browser plugin: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Linux Anwendern sei der <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a> empfohlen.
</p>
<p>
<a href="%s" target="_blank">SVG Abbildung in einem neuen Browser Fenster &ouml;ffnen</a></p>
<p>
Um diese Abbildung auf ihre lokale Festplatte zu speichern 
control-click (Macintosh) oder 
right-click (Windows) dr&uuml;cken und Speichern ausw&auml;hlen.
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
Um eine Abbildung dieser Ansicht in eine HTML Seite einzubetten folgendes URL durch cut and paste einf&uuml;gen:
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
Das Bild wird folgendermassen aussehen:
</p>
<p>
<img src="%s" />
</p>

<p>
!!!!!!!
Wenn nur die &Uuml;bersicht (Chromosomen oder Contig Ansicht) angezeigt wird, 
versuchen Sie die Gr&ouml;&szilig;e der Region zu verringern
</p>
END

   TIMEOUT  => <<'END',
Der Anfrage hat das Zeitlimit &uuml;berschritten. M&ouml;glicherweise wurde eine Region gew&auml;hlt, die zu gro&szilig; ist um angezeigt zu werden. Entweder kann man Tracks abschalten oder eine kleinere Region probieren. Dr&uuml;cken sie den roten "Reset" Knopf, wenn Sie dauernd timeouts bekommen. 
END

   GO       => 'Los',

   FIND     => 'Finden',

   SEARCH   => 'Suche',

   DUMP     => 'Dump',

   HIGHLIGHT   => 'Markieren',

   ANNOTATE     => 'Annotieren',

   SCROLL   => 'Scroll/Zoom',

   RESET    => 'Reset',

   FLIP     => 'Umdrehen',

   DOWNLOAD_FILE    => 'Download File',

   DOWNLOAD_DATA    => 'Download Daten',

   DOWNLOAD         => 'Download',

   DISPLAY_SETTINGS => 'Display Einstellungen',

   TRACKS   => 'Tracks',

   EXTERNAL_TRACKS => '<i>Externe Tracks kursiv</i>',

   OVERVIEW_TRACKS => '<sup>*</sup>',
 
   REGION_TRACKS => '<sup>**</sup>Track Region',

   EXAMPLES => 'Beispiele',

   REGION_SIZE => 'Gr&ouml;&szlig;e der Region (bp)',

   HELP     => 'Hilfe',

   HELP_FORMAT => 'Hilfe zum Datei Format',

   CANCEL   => 'Abbrechen',

   ABOUT    => '&Uuml;ber...',

   REDISPLAY   => 'Neu Zeichnen',

   CONFIGURE   => 'Konfiguration...',

   CONFIGURE_TRACKS   => 'Track Konfiguration...',

   EDIT       => 'Datei Editieren...',

   DELETE     => 'Datei L&ouml;',

   EDIT_TITLE => 'Annotations Daten Eingeben/Editieren',

   IMAGE_WIDTH => 'Bild Weite',

   BETWEEN     => 'Zwischen',

   BENEATH     => 'Unter',

   LEFT        => 'Links',

   RIGHT       => 'Rechts',

   TRACK_NAMES => 'Track Name Tabelle',

   ALPHABETIC  => 'Alphabetisch',

   VARYING     => 'Variierend',

   SET_OPTIONS => 'Einstellung Track Optionen...',

   CLEAR_HIGHLIGHTING => 'Markierungen entfernen',

   UPDATE      => 'Bild Neu Zeichen',

   DUMPS       => 'Dumps, Suchen und andere Operationen',

   DATA_SOURCE => 'Daten Quelle',

   UPLOAD_TRACKS=>'Eigene Tracks hinzuf&uuml;gen',

   UPLOAD_TITLE=> 'Eigene Annotationen hochladen',

   UPLOAD_FILE => 'Datei hochladen',

   KEY_POSITION => 'Schl&uuml;ssel Position',

   BROWSE      => 'Durchsuchen...',

   UPLOAD      => 'Hochladen',

   NEW         => 'Neu...',

   REMOTE_TITLE => 'Remote Annotationen hinzuf&uuml;gen',

   REMOTE_URL   => 'Eingabe Remote Annotations URL',

   UPDATE_URLS  => 'Update URLs',

   PRESETS      => '--Auswahl voreingestellter URLs--',

   FEATURES_TO_HIGHLIGHT => 'Markierte Feature(s) (Feature1 Feature2...)',

   REGIONS_TO_HIGHLIGHT => 'Markierte Regionen (region1:start..end region2:start..end)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Hinweis: Verwende Feature@color um die Farbe auszuw&auml;hlen wie zum Beispiel in \'NUT21@lightblue\'',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Hinweis: Verwende Region@color um die Farbe auszuw&auml;hlen wie zum Beispiel in  \'Chr1:10000..20000@lightblue\'',

   NO_TRACKS    => '*keine*',

   FILE_INFO    => 'Letzte &Auml;nderung %s.  Annotierte Landmarks: %s',

   FOOTER_1     => <<END,
Anmerkung: Diese Seite verwendet Cookies um Einstellungen zu speichern us wiederherzustellen. Es wird keine Information geteilt.
END

   FOOTER_2    => 'Generic Genome Browser Version %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Folgende %d Regionen entsprechen ihrer Abfrage.',

   POSSIBLE_TRUNCATION  => 'Such Ergebnisse werden auf %d Treffer limiterit; die Liste ist m&ouml;glicherweise unvollst&auml;ndig.',

   MATCHES_ON_REF => 'Treffer auf %s',

   SEQUENCE        => 'Sequenz',

   SCORE           => 'score=%s',

   NOT_APPLICABLE => 'n/a',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Einstellungen für %s',

   UNDO     => 'Ändnerungen Rückgängig',

   REVERT   => 'Original Einstellungen Wiederherstellen',

   REFRESH  => 'Erneuern',

   CANCEL_RETURN   => 'Ändnerungen verwerfen und Zurück...',

   ACCEPT_RETURN   => 'Ädnerungen akzeptieren und Zurück...',

   OPTIONS_TITLE => 'Track Optionen',

   SETTINGS_INSTRUCTIONS => <<END,
Mit Hilfe der <i>Zeigen</i> Checkbox k&ouml;nnen Tracks an- und abgeschalten werden. Die Option <i>Kompakt</i> kondensiert die Darstellung des Track, soda&szilig; die Annotationen &uuml;berlappen. Die <i>Expandieren</i> und <i>Hyperexpandieren</i> Optionen steuern die Kollisionskontrolle und verwenden langsamere und schnellere Layout Algorithmen. Die <i>Expandieren &amp; Label</i> und <i>Hyperexpand &amp; Label</i> Optionen erzeugen zwingend Label auf den Annotationen.
Wenn <i>Auto</i> gew&auml;hlt so wird Kollisionskontrolle 
und Label Optionen automatisch selektiert, wenn es der Platz erlaubt. Um die Reihenfolge der Tracks zu &auml;ndern kann das <i>Track Reihenfolge &Auml;ndern</i> Men&uuml; verwendet werden. Die Anzahl der Annotationen eines Typs kann &uuml;der die <i>Limit</i> Option gesteuert werden.
END

   TRACK  => 'Track',

   TRACK_TYPE => 'Track Typ',

   SHOW => 'Anzeigen',

   FORMAT => 'Format',

   LIMIT  => 'Limit',

   ADJUST_ORDER => 'Reihenfolge Einstellen',

   CHANGE_ORDER => 'Track Reihenfolge &Auml;ndern',

   AUTO => 'Auto',

   COMPACT => 'Kompakt',

   EXPAND => 'Expandieren',

   EXPAND_LABEL => 'Expandieren & Label',

   HYPEREXPAND => 'Hyperexpandieren',

   HYPEREXPAND_LABEL =>'Hyperexpandieren & label',

   NO_LIMIT    => 'Kein Limit',

   OVERVIEW    => '&Uuml;berblick',

   EXTERNAL    => 'Extern',

   ANALYSIS    => 'Analyse',

   GENERAL     => 'Allgemein',

   DETAILS     => 'Details',

   REGION      => 'Region',

   ALL_ON      => 'Alles an',

   ALL_OFF     => 'Alles aus',






   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Fenster schlie&szlig;en',

   TRACK_DESCRIPTIONS => 'Track Beschreibung und Zitate',

   BUILT_IN           => 'Eingebaute Tracks diese Servers',

   EXTERNAL           => 'Externe Annotations Tracks',

   ACTIVATE           => 'Bitte diesen Track aktivieren, um seine Information anzuzeigen.',

   NO_EXTERNAL        => 'Keine Externen Features geladen.',

   NO_CITATION        => 'Keine Zusatzinformation verf&uuml;gbar.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => '&Uuml;ber %s',

 BACK_TO_BROWSER => 'Zur&uuml;ck zum Browser',

 PLUGIN_SEARCH_1   => '%s (&uuml;ber %s Suche)',

 PLUGIN_SEARCH_2   => '&lt;%s Suche&gt;',

 CONFIGURE_PLUGIN   => 'Konfiguration',

 BORING_PLUGIN => 'Diese Plugin hat keine zus&auml;tzlichen Konfigurations Einstellungen.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => 'Die Landmark <i>%s</i> wurde nicht erkannt. Vorschl&auml;ge sind in den Hilfe Seiten zu finden.',

 TOO_BIG   => 'Die Detail Ansicht ist limitiert auf %s. Klicken Sie in den &Uuml;berblick um eine Region von %s Weite auszuw&auml;hlen.',

 PURGED    => "Die Datei mit dem Namen %s kann nicht gefunden werden. M&ouml;glicherweise wurde sie entfernt?.",

 NO_LWP    => "Dieser Server wurde nicht Konfiguriert um externe URLs zu holen.",

 FETCH_FAILED  => "Konnte nicht geholt werden %s: %s.",

 TOO_MANY_LANDMARKS => '%d Landmarks. Liste zu lang.',

 SMALL_INTERVAL    => 'Kleines Intervall wird auf %s bp angepasst',

 NO_SOURCES        => 'Es wurden keine lesbaren Datenquellen konfiguriert. M&ouml;glicherweise haben Sie nicht ausreichend Berechtigungen um sie zu sehen.',
};

