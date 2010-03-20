# do not remove the { } from the top and bottom of this page!!!
{

#Icelandic translation done by Gudmundur A. Thorisson <mummi@cshl.edu>

#$Id: is.pm,v 1.7 2006-07-14 12:38:52 lstein Exp $

 CHARSET =>   'ISO-8859-1',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Genome browser',
   
   SEARCH_INSTRUCTIONS => <<END,
Leitið að nafni á röð, nafni á geni, lókus eða öðru kennileiti. Hægt er að nota * (e. wildcard) fyrir frjálsa leit.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Til að miðja á staðsetningu, smellið á stikuna. Notið Skrun/Zoom takkana til að breyta stækkun og staðsetningu
END

   EDIT_INSTRUCTIONS => <<END,
Hér má breyta vistuðum annoteringum. Hægt er að nota innsláttartáknið (e. tab) eða stafabil til að aðskilja reiti, en reitir sem innihalda stafabil þurfa að vera innan einfaldra eða tvöfaldra gæsalappa.
END

   SHOWING_FROM_TO => 'Sýni %s á %s,frá %s til %s',

   INSTRUCTIONS      => 'Leiðbeiningar',

   HIDE              => 'Fela',
   
   SHOW              => 'Sýna',

   SHOW_INSTRUCTIONS => 'Sýna leiðbeiningar',

   HIDE_INSTRUCTIONS => 'Fela leiðbeiningar',

   SHOW_HEADER       => 'Sýna haus',

   HIDE_HEADER       => 'Fela haus',

   LANDMARK => 'Kennileiti eða svæði',

   BOOKMARK => 'Vista sem bókamerki',

   IMAGE_LINK => 'Fá vefslóð á mynd',

   SVG_LINK   => 'Mynd sem hentar til birtingar',

   SVG_DESCRIPTION => <<END,
<p>
Eftirfarandi slóð mynd býr til þessa sömu mynd á Scalable Vector Graphic (SVG) sniði. SVG býður upp á nokkra umfram "raster"-byggðar myndir eins og jpeg eða png.
</p>
<ul>
<li>hægt að breyta stærð án þess að tapa upplausn
<li>hægt að vinna með myndirnar í myndvinnsluforritum sem höndla vector-grafík, til dæmis færa til annoteringar ef vill
<li>ef nauðsyn krefur er hægt að breyta yfir í EPS-snið til að senda til birtingar í vísindaritum
</ul>
<p>
Til að skoða SVG-myndir þarftu að hafa vafra sem styður SVG-sniðið, td. Adobe "plugin" fyrir vefvafra, eða Adobe Illustrator myndvinnsluforritið.
</p>
<p>
Adobe "plugin": <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Linuxnotendur geta skoðað þennan hér: <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a>.
</p>
<p>
<a href="%s" target="_blank">Skoða SVG-mynd í nýjum vafraglugga</a></p>
<p>
Til að vista þessa mynd á harða diskinn hjá þér, Ctrl-klikkaðu (Macintosh) eða hægri-klikkaðu (Windows) og veldu "Save link to disk".
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
Til að setja þessa mynd á heimasíðu, afritið þessa vefslóð og setjið í HTML-kóðann svona:
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
Myndin mun líta svona út:
</p>
<p>
<img src="%s" />
</p>

<p>
Ef aðeins yfirlitsmyndin  sést að ofan, reynið að minnka stærðina á svæðinu</p>
END

   TIMEOUT  => <<'END',
Fyrirspurn þín tók of langan tíma. Þú gætir hafa valið svæði sem er of stórt til að sýna. Prófaðu að slökkva á einhverjum brautanna, eða minnka svæðið. Ef þetta gerist trekk í trekk, vinsamlega ýttu á "Endursetja" takkann.
END

   GO       => 'Keyra',

   FIND     => 'Finna',

   SEARCH   => 'Leita',

   DUMP     => 'Vista',

   HIGHLIGHT => 'Merkja',

   ANNOTATE     => 'Annotera',

   SCROLL   => 'Skrun/Zoom',

   RESET    => 'Endursetja',

   FLIP     => 'Snúa við',

   DOWNLOAD_FILE    => 'Vista skrá',

   DOWNLOAD_DATA    => 'Vista gögn',

   DOWNLOAD         => 'Vista',

   DISPLAY_SETTINGS => 'Stillinga glugga',

   TRACKS   => 'Brautir',

   EXTERNAL_TRACKS => "(Utanaðkomandi brautir skáletraðar)<br><sup>*</sup>Yfirlitsbraut",

   OVERVIEW_TRACKS => '<sup>*</sup>Yfirlitsbraut',

   REGION_TRACKS  => '<sup>**</sup>Svæðisbraut',

   EXAMPLES => 'Dæmi',

   REGION_SIZE  => 'Stærð svæðis (bp)',

   HELP     => 'Hjálp',

   HELP_FORMAT => 'Hjálp fyrir skjásnið',

    CANCEL   => 'Hætta við',

   ABOUT    => 'Um...',

   REDISPLAY   => 'Sýna aftur',

   CONFIGURE   => 'Stillingar...',

   EDIT       => 'Breyta skrá...',

   DELETE     => 'Eyða skrá',

   EDIT_TITLE => 'Bæta við eða breyta annoteringum',

   IMAGE_WIDTH => 'Breidd myndar',

   BETWEEN     => 'Milli',

   BENEATH     => 'Undir',

   LEFT        => 'Vinstri',

   RIGHT       => 'Hægri',

   TRACK_NAMES => 'Tafla yfir nöfn á brautum',

   ALPHABETIC  => 'Stafrófsröð',

   VARYING     => 'Breytilegt',

   SET_OPTIONS => 'Breyta stillingum fyrir brautir...',

   UPDATE      => 'Uppfæra mynd',

   DUMPS       => 'Dump, leitir og aðrar aðgerðir',

   DATA_SOURCE => 'Gagnalind',

   UPLOAD_TRACKS  => 'Bæta við eigin brautum',

   UPLOAD_TITLE=> 'Vista eigin annoteringar á vef',

   UPLOAD_FILE => 'Vista eigin skrá á vef',

   KEY_POSITION => 'Staðsetning lykils',

   BROWSE      => 'Vafra...',

   UPLOAD      => 'Hlaða upp',

   NEW         => 'Nýtt...',

   REMOTE_TITLE => 'Bæta við eigin annoteringum',

   REMOTE_URL   => 'Slá inn vefslóð fyrir utanaðkomandi annoteringar',

   UPDATE_URLS  => 'Uppfæra vefslóðir',

   PRESETS      => '--Velja fyrirfram uppsettar vefslóðir--',

   FEATURES_TO_HIGHLIGHT  => 'Kennileiti sem merkja á (kennileiti1, kennileiti2...)',
     
   FEATURES_TO_HIGHLIGHT_HINT  => 'Vísbending: notaðu kennileiti@litur til að velja litinn, t.d. \'NUT21@lightblue\' ',

   REGIONS_TO_HIGHLIGHT  => 'Merkja svæði (svæði1:start..end svæði2:start..end)',
    
   REGIONS_TO_HIGHLIGHT_HINT  => 'Vísbending: notaðu svæði@litur, t.d. \'Chr1:1000..2000@lightblue\'',

   NO_TRACKS  => '*engar*',

   FILE_INFO    => 'Síðast uppfært %s.  Annoteruð kennileiti: %s',

   FOOTER_1     => <<END,
ATH: Þessi síða notar "smákökur" (e. cookies) til að að vista og endurheimta stillingar. Engum upplýsingum er deilt með utanaðkomandi aðilum
END

   FOOTER_2    => 'Generic genome browser version %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Eftirfarandi %d svæði samsvara fyrirspurninni.',

   POSSIBLE_TRUNCATION  => 'Niðurstöður leitur eru takmarkaðir við %s atriði; listinn er hugsanlega ekki tæmandi',

   MATCHES_ON_REF => ' Fundið á %s',

   SEQUENCE        => 'röð;',

   SCORE           => 'skor=%s',

   NOT_APPLICABLE => 'n/a',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Stillingar fyrir %s',

   UNDO     => 'Afturkalla breytingar',

   REVERT   => 'Breyta yfir i sjálfgefnar stillingar',

   REFRESH  => 'Hlaða síðu aftur',

   CANCEL_RETURN   => 'Hætta við breytingar og fara til baka...',

   ACCEPT_RETURN   => 'Virkja breytingar og fara til baka...',

   OPTIONS_TITLE => 'Brautarstillingar',

   SETTINGS_INSTRUCTIONS => <<END,
 <i>Sýna</i> segir til um hvort braut er sýnileg eða ekki.
 <I>Samþjappað</i> þjappar brautinni saman a eina línu
 þannig að annoteringar munu skarast. 
<i>Breiða úr</i> og <i>Breiða meira úr</i>  hindra annoteringar í að rekast
 hver á aðra, með  hægvirkari og hraðvirkari algorithmum
 <i>Breiða úr & merkja</i> og  <i>Breiða meira úr & mergja</i>  setur 
merki (e. labels) á allar annoteringar. Ef <i>Sjálfvirkt</i> er valið 
eru árekstrar- og merkjastillingar settar eftir því sem pláss leyfir.
 Til að breyta því hvernig brautirnar raðast upp, notið <i>Breyta uppöðun brauta</i>
 til að setja tiltekna annoteringu á brautina. Til að takmarka hversu margar 
annoteringar af tiltekinni tegund eru sýndar, notið 
<i>Takmarka fjölda</i> valmyndina.
END

   TRACK  => 'Braut',

   TRACK_TYPE => 'Tegund brautar',

   SHOW => 'Sýna',

   FORMAT => 'Snið',

   LIMIT  => 'Takmarka fjölda',

   ADJUST_ORDER => 'Stilla uppröðun brauta',

   CHANGE_ORDER => 'Breyta uppröðun brauta',

   AUTO => 'Sjálfvirkt',

   COMPACT => 'Samþjappað',

   EXPAND => 'Breiða úr',

   EXPAND_LABEL => 'Breiða úr & merkja',

   HYPEREXPAND => 'Breiða meira úr',

   HYPEREXPAND_LABEL =>'Breiða meira úr & merkja',

   NO_LIMIT    => 'Engin takmörkun',
       
   OVERVIEW  => 'Yfirlit',

  GENERAL => 'Almennt',

   DETAILS  => 'Nánar',

   ALL_OFF => 'Virkja allar',

   ALL_ON  => 'Afvirkja allar',

   ANALYSIS  => 'Greining',

   REGION  => 'Svæði',
    

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Loka þessum glugga',

   TRACK_DESCRIPTIONS => 'Lýsingar og titlar á brautum',

   BUILT_IN           => 'Brautir innbyggðar í þennan vefþjón',

   EXTERNAL           => 'Utanaðkomandi annoteringarbrautir',

   ACTIVATE           => 'Vinsamlega virkjið þessa braut til að sjá hvað er á henni...',

   NO_EXTERNAL        => 'Engar utanaðkomandi annoteringar hlaðnar inn.',

   NO_CITATION        => 'Engar frekari upplýsingar fáanlegar.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'Um %s',

 BACK_TO_BROWSER => 'Aftur til GBrowse',

 PLUGIN_SEARCH_1   => '%s (leit með %s)',

 PLUGIN_SEARCH_2   => '&lt;%s leit&gt;',

 CONFIGURE_PLUGIN   => 'Stilla',

 BORING_PLUGIN => 'Þessi plugin hefur engar auka stillimöguleika.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => 'Kennileitið <i>%s</i> fannst ekki. Sjá hjálparsíður fyrir uppástungur.',

 TOO_BIG   => 'Nánari sýn er takmörkuð við %s bp.  Smellið á yfirlitsmyndina til velja svæði
   sem er %s bp að stærð.',

 PURGED    => "Finn ekki skrána %s. Hefur henni verið hent?",

 NO_LWP    => "Þessi vefþjónn er ekki stilltur til að ná í utanaðkomandi vefslóðir",

 FETCH_FAILED  => "Gat ekki náð í %s: %s.",

 TOO_MANY_LANDMARKS => '%d kennileiti.  Of mörg til að telja upp!.',

 SMALL_INTERVAL    => 'Breyti stærð svæðis í %s bp',
          
CLEAR_HIGHLIGHTING  => 'Fjarlægja merkingar',

CONFIGURE_TRACKS  => 'Stilla brautir...', 
     
NO_SOURCES  => 'Engar aðgengilegar gagnalindir stilltar. Kannske hefur þú ekki leyfi til að skoða þær',

};

