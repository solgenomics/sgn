/** 
* @class FormattingHelpers
* Functions used with the perl module of the same name
* @author Robert Buels <rmb32@cornell.edu>
*
*/

//JSAN.use("jquery");

var CXGN;
if(!CXGN) CXGN = {};
if(!CXGN.Page) CXGN.Page = {};
if(!CXGN.Page.FormattingHelpers) CXGN.Page.FormattingHelpers = {};

//////////////////////////////////////////////////////////////////////
// for two-level select box (see CXGN::FormattingHelpers::twolevel_selectbox_html)
//////////////////////////////////////////////////////////////////////
//low-level function to set the options in a select box from a passed array of options
CXGN.Page.FormattingHelpers.set_selectbox_options = function(selbox,options) {
  if( !selbox || !options || !options.length )
    return;

  //save what option we've selected
  var selected_option = selbox.selectedIndex >= 0 ? selbox.options[selbox.selectedIndex] : null;
  selbox.options.length = 0;

  var new_selected_index = 0;
  for( i = 0; i < options.length; i++ ) {
    selbox.options[i] = options[i];
    if( selected_option && options[i].text == selected_option.text ) {
      new_selected_index = i;
    }
  }
  selbox.selectedIndex = new_selected_index;
};
  
//update the contents of the dependent selection box based on what's
//selected in the parent selection box
//used by CXGN::FormattingHelpers::hierarchical_selectboxes_html
//args: parentindex - array index of selected option in parent selectbox
//      optionset   - 2D array of options to be placed in the child selectbox
//      dependent   - child selectbox object
CXGN.Page.FormattingHelpers.update_hierarchical_selectbox = function(parentindex,optionset,dependent) {
  CXGN.Page.FormattingHelpers.set_selectbox_options(dependent,optionset[parentindex]);
};


CXGN.Page.FormattingHelpers.update_numerical_range_input = function(id,unitstr) {
  var rangeI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source) { return source; } };
  var rangeAnd = rangeI18n.p('global.formatting.range.and', 'and');
  var range = id+'_r';
  var value2 = id+'_2';
  var middle = id+'_m';
  var end    = id+'_e';
  document.getElementById(value2).style.visibility= ( (document.getElementById(range).value=='bet') ? 'visible' : 'hidden' );
  document.getElementById(end).style.visibility= ( (document.getElementById(range).value=='bet') ? 'visible' : 'hidden' );
  if (document.getElementById(range).value=='bet') {
    document.getElementById(middle).textContent = rangeAnd;
    document.getElementById(end).innerHTML = unitstr;
  } else {
    document.getElementById(middle).innerHTML = unitstr;
    document.getElementById(end).textContent = rangeAnd;
  }
};


// used by FormattingHelpers::modesel() to make the mode selection buttons feel more responsive
CXGN.Page.FormattingHelpers.modesel_switch_highlight =  function(frombutton,tobutton) {
  var id_leaves      = new Array( '_bl','_b','_br','_l','_c','_r','_tl','_t','_tr');
  var needs_fg_image = new Array(   1,    0,    1,   1,   0,   1,    1,   0,    1 );
  var image_file_name = new Array('<img class="modesel" src="/documents/img/modesel','.gif" alt="" />');

  for(var i=0;i<id_leaves.length;i++) {
    if(frombutton) {
      document.getElementById(frombutton+id_leaves[i]).className = 'modesel'+id_leaves[i];
    }
    document.getElementById(tobutton+id_leaves[i]).className = 'modesel'+id_leaves[i]+'_hi';
    
    if(needs_fg_image[i]) {
      if(frombutton) {
	document.getElementById(frombutton+id_leaves[i]).innerHTML = 
	  image_file_name[0] + id_leaves[i] + image_file_name[1];
      }
      document.getElementById(tobutton+id_leaves[i]).innerHTML = 
	image_file_name[0] + id_leaves[i] + '_hi' + image_file_name[1];
    }
  }
};

