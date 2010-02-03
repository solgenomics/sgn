# do not remove the { } from the top and bottom of this page!!!
# Translation by: Marco Mangone <mangone@cshl.edu>
{

 CHARSET =>   'ISO-8859-1',
   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Visualizzatore Genomico',

   SEARCH_INSTRUCTIONS => <<END,
Cerca utilizzando un nome di sequenza, nome di gene,
locus%s o altri punti di riferimento. Utilizzare *
per indicare un carattere qualsiasi.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Per centrare su un punto, fare clic sul righello. Usare i pulsanti Sfoglia/Zoom
per cambiare la scala e la posizione. Per memorizzare questa videata,
<a href="%s">salvare questo collegamento tra i preferiti.</a>
END

   EDIT_INSTRUCTIONS => <<END,
Da qui è possibile modificare i dati di annotazione.
I campi possono essere separati mediante spazi semplici o tabulatori,
ma i campi contenenti spazi spazi devono essere delimitati
da virgolette o apostrofi.
END

   SHOWING_FROM_TO => 'Mappa di %s da %s, posizione %s - %s',

   INTRUCTIONS    => 'Istruzioni',

   HIDE           => 'Nascondi',

   SHOW           => 'Mostra',
  
   SHOW_INSTRUCTIONS => 'Mostra Istruzioni',

   HIDE_INSTRUCTIONS => 'Nascondi Istruzioni',

   SHOW_HEADER       => 'Mostra banner',

   HIDE_HEADER       => 'Nascondi banner',

   LANDMARK => 'Elemento Genomico o Regione',

   BOOKMARK => 'Aggiungi ai Preferiti',

   IMAGE_LINK => "Vai all'Immagine",

   SVG_LINK   => 'Immagine ad Alta Risoluzione',

   GO       => 'Vai',

   FIND     => 'Cerca',

   DUMP     => 'Scarica',

   ANNOTATE     => 'Annota',

   SCROLL   => 'Sfoglia/Zoom',

   RESET    => 'Ripristina',

   DOWNLOAD_FILE    => 'Scarica File',

   DOWNLOAD_DATA    => 'Scarica dati',

   DOWNLOAD         => 'Scarica',

   DISPLAY_SETTINGS => 'Visualizza parametri',

   TRACKS   => 'Tracce',

   ALPHABETIC  => 'Alphabetico',

   BENEATH     => 'Sotto',

   BETWEEN     => 'In Mezzo',

   FLIP     => 'Gira',

   HIDE_HEADER       => 'Nascondi Banner',

   HIDE_INSTRUCTIONS => 'Nascondi Instruzioni',

   HIGHLIGHT   => 'Evidenzia',

   EXTERNAL_TRACKS => '(Tracce esterne in corsivo)',

   EXAMPLES => 'Esempi',

   HELP     => 'Guida',

   HELP_FORMAT => 'Aiuto con in formati dei files',

   CANCEL   => 'Annulla',

   ABOUT    => 'Informazioni...',

   REDISPLAY   => 'Rivisualizza',

   CONFIGURE   => 'Configura',

   EDIT       => 'Modifica file',

   DELETE     => 'Cancella file',

   EDIT_TITLE => 'Inserisci/modifica dati',

   IMAGE_WIDTH => 'Lunghezza immagine',

   SET_OPTIONS => 'Configura opzioni delle tracce...',

   UPDATE      => 'Aggiorna immagine',

   DUMPS       => 'Scaricamento, Ricerca e altre operazioni',

   DATA_SOURCE => 'Origine dei dati',

   UPLOAD_TITLE=> 'Carica le tue annotazioni',

   UPLOAD_FILE => 'Carica un file',

   BROWSE      => 'Sfoglia...',

   UPLOAD      => 'Carica',

   REMOTE_TITLE => 'Aggiungi annotazioni remote',

   REMOTE_URL   => 'Inserisci URL di annotazioni remote',

   UPDATE_URLS  => 'Aggiorna URLs',


   PRESETS      => '--Scegli URL predefinito--',

   FILE_INFO    => 'Ultima modifica %s. Oggetti annotati: %s',

   FOOTER_1     => <<END,
Nota: Questa pagina usa cookie per memorizzare e ripristinare configurazioni preferite.
Le informazioni non vengono ridistribuite.
END

   FOOTER_2    => 'Visualizzatore genomico generico versione %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Le seguenti %d regioni soddisfano la tua richiesta',

  POSSIBLE_TRUNCATION  => 'I risultati della ricerca sono limitati a %d\' valori; La lista potrebbe essere incompleta',

   MATCHES_ON_REF => 'Corrispondenza su %s',

   SEQUENCE        => 'sequenza',

   SCORE           => 'punteggio=%s',

   NOT_APPLICABLE => '..',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Configurazione per %s',

   UNDO     => 'Annulla modifiche',

   REVERT   => 'Torna alla configurazione standard',

   REFRESH  => 'Aggiorna',

   CANCEL_RETURN   => 'Annulla modifiche e torna indietro...',

   ACCEPT_RETURN   => 'Accetta le modifiche e torna indietro...',

   OPTIONS_TITLE => 'Opzioni di traccia',

   SETTINGS_INSTRUCTIONS => <<END,
Il pulsante <I>Mostra</I> attiva o disattiva la traccia. 
L' opzione <I>Compatto</I> forza la compressione delle tracce
sì che le annotazioni vengano sovrapposte.
Le opzioni <I>Espandi</I> e <I>Iper-espandi</I> attivano il controllo
di collisione utilizzando algoritmi di allineamento rispettivamente lenti o veloci.
Le opzioni <I>Espandi &amp; Etichetta</I> e <I>Iper-espandi &amp; Etichetta</I>
servono a contrassegnare le annotazioni.
Selezionando <I>Automatico<I>, il controllo di collisione e le opzioni di etichettatura
vengono attivate automaticamente, spazio consentendo.
Per cambiare l'ordine delle tracce, usare il menu <I>Cambia ordine delle tracce<I>
per assegnare un'annotazione ad una traccia.
Per limitare il numero di annotazioni di questo tipo visualizzate,
cambiare il valore del menu <I>Limiti</I>.
END

IMAGE_DESCRIPTION => <<END,
<p>
Per creare una immagine allegata usando questa immagine 'taglia e incolla' questo Indirizzo Internet in una pagina ipertestuale:</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
L`immagine rassomigliera` a questa:
</p>
<p>
<img src="%s" />
</p>

<p>
Se l`immagine mostrata (sia cromosomica o del contiguo) e` parziale o incompleta, prova a ridurre la grandezza della regione.
</p>
END


SVG_DESCRIPTION => <<END,
<p>
Il Seguente link ipertestuale generera` questa immagine in formato vettoriale Scalabile (SVG). Il formato SVG offre molti vantaggi rispetto a il formato jpeg oppure png.
</p>
<ul>
<li>e` completamente scalabile senza perdita di risoluzione
<li>e` completamente editabile usando i comuni programmi di grafica vettoriale 
<li>se necessario, puo` essere convertito in formato EPS per necessita` di pubblicazione
</ul>
<p>
Per poter vedere una immagine in formato SVG e` necessario avere in browser compatibile e il Plug-in di Adobe chiamato 'SVG browser' oppure una applicazione che permette di leggere files con le estensioni .SVG come Adobe Illustrator.
</p>
<p>
Adobe's SVG browser plugin: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Gli utenti Linux possono utilizzare il  <a href="http://xml.apache.org/batik/">Visualizzatore SVG di Batik SVG</a>.
</p>
<p>
<a href="%s" target="_blank">Apri l`immagine in una nuova finestra</a></p>
<p>
Per salvare questa immagine nel disco rigido premi control (utenti Machintosh) oppure tasto destro del mouse (utenti Windows) e seleziona l`opzione 'salva' su disco rigido.
</p>   
END

   SVG_LINK   => 'Immagine in qualita` di pubblicazione',

TIMEOUT  => <<'END',
La tua richiesta e` espirata. Tu potresti aver selezionato una regione troppo grande da mostrare in una schermata. Puoi o de-selezionare alcune tracce oppure provare con una regione piu` piccola. Se il problema si ripropone 

Either turn off some tracks or try a smaller region.  If you are experiencing persistent
timeouts, please press the red "Reset" button.
END

   TRACK_NAMES => 'Tavola nomi tracce',

   IMAGE_LINK => 'Collega questa schermata ad un`immagine',

   VARYING     => 'Variazione',

   INSTRUCTIONS      => 'Istruzioni',

   KEY_POSITION => 'Posizione tasto',

   LEFT        => 'Sinistra',

   RIGHT       => 'Destra',

   NEW         => 'Nuovo...',

   POSSIBLE_TRUNCATION  => 'I risulati di questa ricerca sono limitati a %d ; Questa lista potrebbe essere incompleta.',

   SEARCH   => 'Cerca',

   SHOW_HEADER       => 'Mostra Banner',

   SHOW_INSTRUCTIONS => 'Mostra Istruzioni',

   TRACK  => 'Traccia',

   TRACK_TYPE => 'Tipo traccia',

   SHOW => 'Mostra',

   FORMAT => 'Formato',

   LIMIT  => 'Limiti',

   ADJUST_ORDER => 'Riordina',

   CHANGE_ORDER => 'Cambia l\'ordine delle tracce',

   AUTO => 'Automatico',

   COMPACT => 'Compatto',

   EXPAND => 'Espandi',

   EXPAND_LABEL => 'Espandi & Etichetta',

   HYPEREXPAND => 'Iper-espandi',

   HYPEREXPAND_LABEL =>'Iper-espandi & Etichetta',

   NO_LIMIT    => 'Senza limiti',


   OVERVIEW   => 'Panoramica',

   EXTERNAL  => 'Esterna',

   ANALYSIS  => 'Analisi',

   GENERAL  =>  'Generale',

   DETAILS  => 'Dettagli',

   ALL_ON   => 'Mostra tutto',

   ALL_OFF  => 'Nascondi tutto',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Chiudi la finestra',

   TRACK_DESCRIPTIONS => 'Descrizione delle tracce & Citazioni',

   BUILT_IN           => 'Tracce annotate su questo server', 

   EXTERNAL           => 'Tracce annotate esternamente',

   ACTIVATE           => 'Attivare questa traccia per visualizzare le relative informazioni.',

   NO_EXTERNAL        => 'Nessuna caratteristica esterna è caricata.',

   NO_CITATION        => 'Informazioni addizionali non disponibili.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'Informazioni su %s',

 BACK_TO_BROWSER => 'Torna al Visualizzatore',

 PLUGIN_SEARCH_1   => '%s (mediante ricerca %s)',

 PLUGIN_SEARCH_2   => '&lt;ricerca %s&gt;',

 CONFIGURE_PLUGIN   => 'Configura',

 BORING_PLUGIN => 'Questo plugin non ha alcuna configurazione extra.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => "L'oggetto <I>%s</I> è sconosciuto. Vedi la pagina di aiuto per suggerimenti.",

 TOO_BIG   => "Visualizzazione dei dettagli limitata a %s basi. Fare clic sull'immagine per selezionare una regione di %s bp.",

 PURGED    => "Non trovo il file %s. Non sarà stato cancellato?.",

 NO_LWP    => "Questo server non è configurato per accedere ad URL esterni.",

 FETCH_FAILED  => "Non riesco a prelevare %s: %s.",

 TOO_MANY_LANDMARKS => '%d punti sono troppi per elencarli singolarmente.',

 SMALL_INTERVAL    => 'Computazione piccolo intervallo a %s pb',

 NO_SOURCES   =>'input dati non e` stato configurato oppure non hai il permesso di vederli',
};
