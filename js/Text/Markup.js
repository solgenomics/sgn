if (typeof(JSAN) != 'undefined' ) {
    JSAN.use("jQuery", []);
}


var Text;
if(!Text) Text = {};

Text.Markup = function(styles) {
  if(! (this.markup_styles = styles) ) {
    console.error('must pass style to new Text.Markup()');
  }
}

Text.Markup.prototype.inflate_regions = function( regions ) {
  var mu = this;
  var ordering = 0;
  return jQuery.map( regions, function(a,i) {
    var style = mu.markup_styles[a[0]];
    ordering++;
      
    if(! style ) {
      console.error('markup style "' + a + '" not defined');
      return;
    }

    if( typeof style == 'object' ) {
      return [[[style[0],a[1]],999000-ordering],[[style[1],a[2]],-ordering]];
    } else {
      return [[[style,a[1]],999000-ordering]];
    }
  });
};

Text.Markup.prototype.markup = function( regions, target_string ) {
  // expand the two-position markups into two one-position markups and decorate with ordering
  var markup_defs = this.inflate_regions(regions);

  // sort the markup definitions in reverse order by coordinate and
  // sequence number
  markup_defs.sort( function(a,b) {
    return (b[0][1] - a[0][1]) || (b[1] - a[1]);
  });


  // do the string insertions and return a new string
  for ( var i = 0; i < markup_defs.length; i++ ) {
        var def = markup_defs[i][0];
        target_string = target_string.slice( 0, def[1] ) + def[0] + target_string.slice( def[1] );
  }

  return target_string;
};
