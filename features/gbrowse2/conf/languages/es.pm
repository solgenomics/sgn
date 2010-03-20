# do not remove the { } from the top and bottom of this page!!!
# Translation by Marcela Tello-Ruiz
{

 CHARSET =>   'ISO-8859-1',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Buscador de genoma',

   SEARCH_INSTRUCTIONS => <<END,
Buscar usando el nombre de una secuencia, el nombre de un gen, locus%s, u otro punto o región de referencia. El caracter comodín * está permitido.
END

   NAVIGATION_INSTRUCTIONS => <<END,
Para concentrarse en una locación, pulsar sobre la regla. Usar los botones Avanzar/Acercar para cambiar la magnificación y la posición. Para grabar tal imagen,<a href="%s">marcar esta página.</a>
END

   EDIT_INSTRUCTIONS => <<END,
Editar datos anotados que han sido subidos aquí. Puedes usar sangrías (tabs) o espacios para separar campos, pero campos que contengan espacios en blanco deben especificarse entre comillas dobles o sencillas.
END

   SHOWING_FROM_TO => 'Mostrando %s de %s, posiciones %s a %s',

   INSTRUCTIONS      => 'Instrucciones',

   HIDE              => 'Esconder',

   SHOW              => 'Mostrar',

   SHOW_INSTRUCTIONS => 'Mostrar instrucciones',

   HIDE_INSTRUCTIONS => 'Ocultar instrucciones',

   SHOW_HEADER       => 'Mostrar encabezado',

   HIDE_HEADER       => 'Ocultar encabezado',

   LANDMARK => 'Punto o región de referencia',

   BOOKMARK => 'Marcar esta página',

   IMAGE_LINK => 'Ligar a imagen',

   SVG_LINK   => 'Imagen de alta resolución',

   SVG_DESCRIPTION => <<END,
<p>
La siguiente liga generará esta imagen en un formato de Vector Escalable (SVG).  Imagenes SVG ofrecen varias ventajas sobre las imágenes basadas en raster, tales como los formatos jpeg o png.
</p>
<ul>
<li>totalmente escalable sin pérdida en resolución
<li>editable aspecto-por-aspecto en aplicaciones gráficas basadas en vectores
<li>si es necesario, puede ser convertido en EPS para ser incluído en una publicación
</ul>
<p>
Para ver imagenes SVG, necesitas un buscador (browser) que sea capaz de aceptar SVG, el accesorio (plugin) para buscadores Adobe SVG, o una aplicación para ver o editar SVG tal como Adobe Illustrator.
</p>
<p>
Accesorio (plugin) para buscadores Adobe SVG: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Usuarios de Linux pueden explorar el <a href="http://xml.apache.org/batik/">visualizador Batik SVG</a>.
</p>
<p>
<a href="%s" target="_blank">Ver imagen SVG en una ventana distinta</a></p>
<p>
para guardar esta imagen en tu disco, pulsa la tecla de control (Macintosh) o el botón de la derecha de tu ratón (Windows) y selecciona la opción para guardar la liga correspondiente.
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
Para crear una imagen montada/incrustada de esta vista, corta y pega esta dirección (URL):
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
La imagen se verá asi:
</p>
<p>
<img src="%s" />
</p>

<p>
Si sólo aparece la vista global (cromosoma o contig), trata de reducir el tamaño de la región.
</p>
END

   TIMEOUT  => <<'END',
Tu solicitud expiró.  Posiblemente seleccionaste una región muy grande para ver.Puedes eliminar algunas de las pistas que seleccionaste antes o intentar ver una región mas pequeña. Si esto te sucede continuamente, por favor presiona el botón rojo que dice "Reiniciar".
END

   GO       => 'Ir',

   FIND     => 'Encontrar',

   SEARCH   => 'Buscar',

   DUMP     => 'Depositar',

   HIGHLIGHT   => 'Resaltar',

   ANNOTATE     => 'Anotar',

   SCROLL   => 'Avanzar/Acercar',

   RESET    => 'Reiniciar',

   FLIP     => 'Dar la vuelta',

   DOWNLOAD_FILE    => 'Bajar el documento',

   DOWNLOAD_DATA    => 'Bajar los datos',

   DOWNLOAD         => 'Bajar',

   DISPLAY_SETTINGS => 'Mostrar configuraciones',

   TRACKS   => 'Pistas',

   EXTERNAL_TRACKS => '<i>Pistas externas en itálicas</i>',

   OVERVIEW_TRACKS => '<sup>*</sup>Resumen de pistas',

   REGION_TRACKS => '<sup>**</sup>Pistas en región',

   EXAMPLES => 'Ejemplos',

   REGION_SIZE => 'Tamaño de la región (en pares de bases)',

   HELP     => 'Ayuda',

   HELP_FORMAT => 'Ayuda con el formato del documento',

   CANCEL   => 'Cancelar',

   ABOUT    => 'Acerca de...',

   REDISPLAY   => 'Volver a mostrar',

   CONFIGURE   => 'Configurar...',

   CONFIGURE_TRACKS   => 'Configurar pistas...',

   EDIT       => 'Editar documento...',

   DELETE     => 'Borrar documento',

   EDIT_TITLE => 'Insertar/Editar datos de anotación',

   IMAGE_WIDTH => 'Ancho de la imagen',

   BETWEEN     => 'Entre dos puntos de referencia',

   BENEATH     => 'Debajo',

   LEFT        => 'Izquierda',

   RIGHT       => 'Derecha',

   TRACK_NAMES => 'Nombres de las pistas',

   ALPHABETIC  => 'Alfabético',

   VARYING     => 'Variando/Variante',

   SET_OPTIONS => 'Definir Opciones para pistas...',

   CLEAR_HIGHLIGHTING => 'Eliminar resaltado',

   UPDATE      => 'Actualizar imagen',

   DUMPS       => 'Reportes &amp; análisis',

   DATA_SOURCE => 'Fuente de datos',

   UPLOAD_TRACKS=>'Agregar tus propias pistas',

   UPLOAD_TITLE=> 'Subir tus anotaciones',

   UPLOAD_FILE => 'Subir un documento',

   KEY_POSITION => 'Posición de la clave',

   BROWSE      => 'Buscar...',

   UPLOAD      => 'Subir',

   NEW         => 'Nuevo...',

   REMOTE_TITLE => 'Agregar anotaciones remotas',

   REMOTE_URL   => 'Insertar anotación remota - Localizador (URL)',

   UPDATE_URLS  => 'Actualizar URLs',

   PRESETS      => '-Seleccionar URL pre-establecido--',

   FEATURES_TO_HIGHLIGHT => 'Resaltar propiedad(es) (propiedad1 propiedad2...)',

   REGIONS_TO_HIGHLIGHT => 'Resaltar regiones (region1:inicia..termina region2:inicia..termina)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Idea: usar feature@color para seleccionar el color, como en \'NUT21@lightblue\'',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Idea: usar region@color para seleccionar el color, como en \'Chr1:10000..20000@lightblue\'',

   NO_TRACKS    => '*Ninguna pista*',

   FILE_INFO    => '%s Modificados por última vez.  Puntos de referencia anotados: %s',

   FOOTER_1     => <<END,
Nota: Esta página usa "cookies" para grabar y restaurar información sobre preferencias. Ninguna información es compartida.
END

   FOOTER_2    => 'Versión genérica del buscador de genoma %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'Las siguientes %d regiones coinciden con la que solicitaste.',

   POSSIBLE_TRUNCATION  => 'Resultados de búsqueda están limitados a %d aciertos; la lista puede ser incompleta.',

   MATCHES_ON_REF => 'Cantidad de regiones que coinciden (hits) en %s',

   SEQUENCE        => 'secuencia',

   SCORE           => 'valor=%s',

   NOT_APPLICABLE => 'n/a',

   BP             => 'pares de bases',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Configuración para %s',

   UNDO     => 'Deshacer los cambios',

   REVERT   => 'Revertir a la configuración pre-establecida',

   REFRESH  => 'Refrescar',

   CANCEL_RETURN   => 'Cancelar cambios y regresar...',

   ACCEPT_RETURN   => 'Aceptar cambios y regresar...',

   OPTIONS_TITLE => 'Seguir la pista de opciones',

   SETTINGS_INSTRUCTIONS => <<END,
La casilla de <i>Mostrar</i> enciende y apaga la pista. La opción <i>Compactar</i> obliga a condensar la pista, de manera que las anotaciones se sobrepondrán. Las opciones <i>Expander</i> e <i>Hiperexpander</i> encienden el control de colisión usando algoritmos de diseño más lentos y más rápidos. Las opciones <i>Expander</i> &amp; <i>etiqueta</i> e <i>Hiper-extender &amp; etiqueta</i> obligan a las anotaciones a ser marcadas. Si se selecciona <i>Auto</i>, el control de colisión y las opciones de etiquetado serán colocadas automáticamente si el espacio lo permite. Para cambiar el orden de las pistas usar el menú emergente <i>Cambiar el orden de las pistas</i> para asignar una anotación a una pista. Para limitar el número de anotaciones mostradas de este tipo, cambiar el valor del menú de <i>Límite</i>.
END

   TRACK  => 'Pista',

   TRACK_TYPE => 'Tipo de pista',

   SHOW => 'Mostrar',

   FORMAT => 'Formatear',

   LIMIT  => 'Limitar',

   ADJUST_ORDER => 'Ajustar el orden',

   CHANGE_ORDER => 'Cambiar el orden',

   AUTO => 'Auto',

   COMPACT => 'Compacto',

   EXPAND => 'Extender',

   EXPAND_LABEL => 'Extender & etiquetar',

   HYPEREXPAND => 'Hiper-extender',

   HYPEREXPAND_LABEL =>'Hiper-extender & etiquetar',

   NO_LIMIT    => 'Sin límite',

   OVERVIEW    => 'Resumen',

   EXTERNAL    => 'Externo',

   ANALYSIS    => 'Análisis',

   GENERAL     => 'General',

   DETAILS     => 'Detalles',

   REGION      => 'Región',

   ALL_ON      => 'Todo encendido',

   ALL_OFF     => 'Todo apagado',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Cerrar esta ventana',

   TRACK_DESCRIPTIONS => 'Seguir la pista de descripciones & citas',

   BUILT_IN           => 'Pistas incluídas en este servidor',

   EXTERNAL           => 'Pistas de anotación externas',

   ACTIVATE           => 'Favor de activar esta pista para ver sus contenidos.',

   NO_EXTERNAL        => 'Características externas no han sido cargadas.',

   NO_CITATION        => 'No existe información adicional.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'Acerca de %s',

 BACK_TO_BROWSER => 'Regresar al buscador',

 PLUGIN_SEARCH_1   => '%s (por medio de %s búsqueda)',

 PLUGIN_SEARCH_2   => '&lt;%s busca&gt;',

 CONFIGURE_PLUGIN   => 'Configurar',

 BORING_PLUGIN => 'Este accesorio no tiene configuraciones adicionales.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => 'El punto de referencia denominado <i>%s</i> no es reconocido. Ver las páginas de ayuda para sugerencias.',

 TOO_BIG   => 'La vista detallada se limita a %s bases.  Pulsar en el esquema general para seleccionar una región de %s pares de bases de ancho.',

 PURGED    => "No puedo encontrar el documento denominado %s.  Tal vez ha sido eliminado?.",

 NO_LWP    => "Este servidor no está configurado para importar URLs externos.",

 FETCH_FAILED  => "No pude importar %s: %s.",

 TOO_MANY_LANDMARKS => '%d puntos de referencia.  Demasiados para ennumerar.',

 SMALL_INTERVAL    => 'Ajustando el tamaño pequeño del intervalo a %s pares de bases',

 NO_SOURCES        => 'No hay fuentes de datos legibles configuradas. Es posible que no tengas permiso para verlas.',

};
