# do not remove the { } from the top and bottom of this page!!!
{
# Translation to the polish language.
# Translated by Szymon M. Kielbasa <s.kielbasa@molgen.mpg.de>, 14-NOV-2005, V0.1

 CHARSET =>   'UTF-8',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Genome browser',

   SEARCH_INSTRUCTIONS => <<END,
Szukać można używając nazw sekwencji, genów, adnotacji, lokalizacji, itp.
Można używać w zapisie *.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Naciśnięcie na osi ustawia środek rysunku we wskazanej lokalizacji.
Przyciski przewijanie/powiększenie pozwalają na jej dalsze precyzyjne ustawienie.
END

   EDIT_INSTRUCTIONS => <<END,
W poniższym polu można zmieniać lub dopisywać adnotacje.
Kolumny mogą być rozdzielone zarówno znakami odstępu jak i tabulacji,
jednakże jeśli treść adnotacji zawiera odstępy, to musi być objęta
cudzysłowami (pojedynczymi lub podwójnymi).
END

   SHOWING_FROM_TO => 'Widoczne %s z sekwencji %s, fragment od %s do %s',

   INSTRUCTIONS      => 'Wskazówki',

   HIDE              => 'Ukryj',

   SHOW              => 'Pokaż',

   SHOW_INSTRUCTIONS => 'Pokaż wskazówki',

   HIDE_INSTRUCTIONS => 'Ukryj wskazówki',

   SHOW_HEADER       => 'Pokaż nagłówek',

   HIDE_HEADER       => 'Ukryj nagłówek',

   LANDMARK => 'Nazwa lub fragment',

   BOOKMARK => 'Zakładka',

   IMAGE_LINK => 'Odnośnik do rysunku',

   SVG_LINK   => 'Rysunek wektorowy (SVG)',

   SVG_DESCRIPTION => <<END,
<p>
Poniższy odnośnik generuje rysunek w wektorowym, skalowalnym formacie SVG
(Scalable Vector Graphic). Rysunki w tym formacie mogą być łatwiej obrabiane
programami graficznymi (na poziomie adnotacji, nie pikseli). Ponadto,
konwersja z formatu SVG do używanego powszechnie w publikacjach formatu EPS
zapewnia wynik o znacznie wyższej jakości.
</p>
<p>
Aby zobaczyć rysunki w formacie SVG konieczne jest użycie przeglądarki
wspierającej ten format.  Adobe dostarcza wtyczkę do przeglądarek, jak i
oprogramowanie do edycji rysunków w formacie SVG.
</p>
<p>
Wtyczki SVG z Adobe: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>.
<br />
Użytkownicy systemów opartych na Linux mogą użyć <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a>.
</p>
<p>
<a href="%s" target="_blank">Otwórz rysunek SVG w nowym oknie.</a></p>
<p>
Aby zapisać ten rysunek na dysku przytrzymaj "control" podczas naciskania
przycisku myszki (Macintosh), lub użyj prawego guzika myszki i opcji "save
link to disk" (Windows).
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
Jeśli użyjesz wewnątrz strony HTML:
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
otrzymasz poniższy rysunek:
</p>
<p>
<img src="%s" />
</p>

<p>
Jeśli ukazujesz wyłącznie ścieżkę orientacyjną, możesz zmniejszyć wielkość.
</p>
END

   TIMEOUT  => <<'END',
Czas oczekiwania na dane został przekroczony.
Prawdopodobnie wybrany przez Ciebie fragment posiada zbyt wiele adnotacji.
Spróbuj zmniejszyć fragment lub ogranicz liczbę ścieżek.
Jeśli problem się powtarza, użycie przycisku <i>Skasuj</i> może okazać się
pomocne.
END

   GO       => 'Idź',

   FIND     => 'Szukaj',

   SEARCH   => 'Szukaj',

   DUMP     => 'Display',

   HIGHLIGHT   => 'Wyróżnij',

   ANNOTATE     => 'Annotate',

   SCROLL   => 'Przewijanie/powiększenie',

   RESET    => 'Skasuj',

   FLIP     => 'Skieruj oś przeciwnie',

   DOWNLOAD_FILE    => 'Załaduj plik',

   DOWNLOAD_DATA    => 'Załaduj dane',

   DOWNLOAD         => 'Załaduj',

   DISPLAY_SETTINGS => 'Ustawienia',

   TRACKS   => 'Ścieżki',

   EXTERNAL_TRACKS => '<i>Zewnętrzne ścieżki kursywą</i>',

   OVERVIEW_TRACKS => '<sup>*</sup>Ścieżka orientacyjna',

   REGION_TRACKS => '<sup>**</sup>Region track',

   EXAMPLES => 'Przykłady',

   REGION_SIZE => 'Rozmiar fragmentu (bp)',

   HELP     => 'Pomoc',

   HELP_FORMAT => 'Pomoc: formaty plików danych',

   CANCEL   => 'Anuluj',

   ABOUT    => 'O...',

   REDISPLAY   => 'Odśwież',

   CONFIGURE   => 'Ustawienia...',

   CONFIGURE_TRACKS   => 'Ustawienia ścieżek...',

   EDIT       => 'Edytuj plik...',

   DELETE     => 'Usuń plik',

   EDIT_TITLE => 'Wpisz/zmień plik adnotacji',

   IMAGE_WIDTH => 'Szerokość rysunku [punkty]',

   BETWEEN     => 'nad ścieżką',

   BENEATH     => 'u dołu rysunku',

   LEFT        => 'lewostronne',

   RIGHT       => 'prawostronne',

   TRACK_NAMES => 'Kolejność ścieżek',

   ALPHABETIC  => 'alfabetyczna',

   VARYING     => 'inna',

   SET_OPTIONS => 'Ustawienia ścieżek...',

   CLEAR_HIGHLIGHTING => 'Wyłącz wyróżnianie',

   UPDATE      => 'Odśwież',

   DUMPS       => 'Raporty i analizy',

   DATA_SOURCE => 'Źródło danych',

   UPLOAD_TRACKS=>'Dodaj własne ścieżki',

   UPLOAD_TITLE=> 'Załaduj własne adnotacje',

   UPLOAD_FILE => 'Załaduj plik',

   KEY_POSITION => 'Położenie opisów',

   BROWSE      => 'Przeglądaj...',

   UPLOAD      => 'Załaduj',

   NEW         => 'Nowy...',

   REMOTE_TITLE => 'Dodaj zewnętrzne adnotacje',

   REMOTE_URL   => 'Adres zewnętrznych adnotacji (URL)',

   UPDATE_URLS  => 'Odśwież URLs',

   PRESETS      => '--Wybierz URL--',

   FEATURES_TO_HIGHLIGHT => 'Wyróżnij adnotacje (adnotacja1 adnotacja2...)',

   REGIONS_TO_HIGHLIGHT => 'Wyróżnij fragmenty sekwencji (sekwencja1:od..do sekwencja2:od..do)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Wskazówka: by wybrać kolor wyróżnienia użyj adnotacja@kolor (np. \'NUT21@lightblue\')',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Wskazówka: by wybrać kolor wyróżnienia użyj sekwencja:od..do@kolor (np. \'Chr1:10000..20000@lightblue\')',

   NO_TRACKS    => '*brak*',

   FILE_INFO    => 'Ostatnia zmiana %s. Liczba adnotacji: %s',

   FOOTER_1     => <<END,
Uwaga: Technologia "ciasteczek" (cookies) jest używana do zapamiętywania
ustawień użytkownika. Inne informacje nie są wymieniane.
END

   FOOTER_2    => 'Generic genome browser, wersja %s.',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Liczba adnotacji pasujących do poszukiwanej nazwy: %d.',

   POSSIBLE_TRUNCATION  => 'Lista wyników poszukiwania może nie być kompletna (liczba wyników jest ograniczona do %d).',

   MATCHES_ON_REF => 'Adnotacje na sekwencji %s',

   SEQUENCE        => 'sekwencja',

   SCORE           => 'punkty=%s',

   NOT_APPLICABLE => 'n.d.',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Ustawienia %s',

   UNDO     => 'Cofnij zmiany',

   REVERT   => 'Ustawienia standardowe',

   REFRESH  => 'Odśwież',

   CANCEL_RETURN   => 'Anuluj zmiany...',

   ACCEPT_RETURN   => 'Zatwierdź zmiany...',

   OPTIONS_TITLE => 'Ustawienia ścieżek',

   SETTINGS_INSTRUCTIONS => <<END,
Kolumna <i>Widoczność</i> włącza lub wyłącza ukazywanie wybranej ścieżki.
W kolumnie <i>Format</i> definiowany jest sposób prezentacji adnotacji.
Format <i>gęsty</i> pozwala różnym adnotacjom nachodzić na siebie.
Formaty <i>rzadki</i> i <i>bardzo rzadki</i> używają różnych metod układania
w kolejnych wierszach nakładających się adnotacji. Ponadto możliwe jest
włączenie szczegółowych <i>opisów</i> adnotacji. Format <i>domyślny</i>
dobiera rodzaj prezentacji automatycznie, w zależności od ilości dostępnego
miejsca.
Kolumna <i>Limit</i> pozwala na ograniczenie liczby adnotacji pokazywanych w
wybranej ścieżce.
<i>Kolejność ścieżek</i> umożliwia zmianę porządku w jakim
ścieżki są wyświetlane na rysunku.
END

   TRACK  => 'Ścieżka',

   TRACK_TYPE => 'Typ ścieżki',

   SHOW => 'Widoczność',

   FORMAT => 'Format',

   LIMIT  => 'Limit',

   ADJUST_ORDER => 'Zmień kolejność',

   CHANGE_ORDER => 'Kolejność ścieżek',

   AUTO => 'Domyślny',

   COMPACT => 'Gęsty',

   EXPAND => 'Rzadki',

   EXPAND_LABEL => 'Rzadki, z opisem',

   HYPEREXPAND => 'Bardzo rzadki',

   HYPEREXPAND_LABEL =>'Bardzo rzadki, z opisem',

   NO_LIMIT    => 'Bez ograniczeń',

   OVERVIEW    => 'Przegląd',

   ANALYSIS    => 'Analiza',

   GENERAL     => 'Ogólnie',

   DETAILS     => 'Szczegóły',

   REGION      => 'Region',

   ALL_ON      => 'Włącz wszystko',

   ALL_OFF     => 'Wyłącz wszystko',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Zamknij to okno',

   TRACK_DESCRIPTIONS => 'Opisy ścieżek, referencje',

   BUILT_IN           => 'Ścieżki udostępniane przez ten serwer',

   EXTERNAL           => 'Ścieżki zewnętrzne',

   ACTIVATE           => 'Włącz ścieżkę aby zobaczyć jej adnotacje.',

   NO_EXTERNAL        => 'Nie załadowano zewnętrznych adnotacji.',

   NO_CITATION        => 'Brak dalszych referencji.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'O wtyczce %s',

 BACK_TO_BROWSER => 'Powrót',

 PLUGIN_SEARCH_1   => '%s (via %s search)',

 PLUGIN_SEARCH_2   => '&lt;%s search&gt;',

 CONFIGURE_PLUGIN   => 'Ustawienia',

 BORING_PLUGIN => 'Ta wtyczka nie umożliwia ustawiania niczego.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => 'Nazwa/fragment "<i>%s</i>" nie została odnaleziona.',

 TOO_BIG   => 'Szczegóły są widoczne dla fragmentów o długości do %s. Wybierz na ścieżce orientacyjnej miejsce by zobaczyć otaczające %s.',

 PURGED    => "Nie można odnaleźć pliku %s. Może został usunięty?.",

 NO_LWP    => "Ten serwer nie został skonfigurowany do pozyskiwania zewnętrznych adnotacji URL.",

 FETCH_FAILED  => "Nie można pozyskać %s: %s.",

 TOO_MANY_LANDMARKS => '%d nazw/fragmentów. Zbyt wiele by wymienić.',

 SMALL_INTERVAL    => 'Zbyt krótki fragment został powiększony do %s bp.',

 NO_SOURCES        => 'Nie ma dostępnych źródeł danych. Być może nie posiadasz stosownych praw dostępu.',

};
