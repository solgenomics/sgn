use strict;
use warnings;

use Memoize;

use JSON;

use Tie::UrlEncoder;
our %urlencode;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      modesel
				      columnar_table_html
				      simple_selectbox_html
				      info_table_html
				      tooltipped_text
				      truncate_string
				    );
use CXGN::Tools::List qw/distinct str_in evens/;

use CXGN::People::BACStatusLog;
use CXGN::Genomic::Search::Clone;
use CXGN::Search::CannedForms;

##########   DATA FIELD DEFINITIONS #######
my @data_fields_defs =
  (
   seq_proj     => { column_name => 'Seq Chrom',
		     tooltip => 'The chromosome project (if any) that is sequencing the BAC',
		   },
   seq_status   => { tooltip => "The BAC's status in sequencing",
		   },
#    gb_status    => { column_name => 'GB Status',
# 		     tooltip => "User-reported HTGS level of this BAC's sequence in GenBank, if any",
#		   },
   il_proj      => { column_name => 'IL Proj',
		     tooltip => "The sequencing project assigned to map this BAC to the Zamir IL bins",
		     value => 'il_proj_id',
		     display => 'il_proj_name',
		   },
   il_chr       => { column_name => 'IL Chr',
		     tooltip => "Chromosome this BAC matches (from IL mapping)",
		     value => 'il_chr',
		   },
   il_bin       => { column_name => 'IL Bin',
		     tooltip => "IL bin this BAC matches",
		     value => 'il_bin_id',
		     display => 'il_bin_name',
		   },
   il_notes     => { column_name => 'IL Notes',
		     tooltip => "Any special notes about this BAC's IL mapping results",
		     value => 'il_notes',
		   },
   ver_int_read => { column_name => 'Ver IR',
		     tooltip => "Check this box if this BAC has been verified with an additional internal read",
		   },
   ver_bac_end  => { column_name => 'Ver BE',
		     tooltip => "Check this box if this BAC has been verified with an additional BAC end read",
		   },
  );
##########  /DATA FIELD DEFINITIONS #######
## data field def post-processing
#fills in defaults in the above data structure, so we don't have to
#write out every damn little thing
{ my @it = @data_fields_defs;
  while(my ($k,$v) = splice @it,0,2) {
    $v->{column_name} ||= do {my @w = split /_/,$k; join ' ',map {ucfirst $_} @w};
    $v->{value} ||= $k;
    $v->{display} ||= $v->{value};
  }
}
my %data_fields_defs = @data_fields_defs; #< make a hash of the same
                                          #name for convenient access


################################
########## PAGE CODE START
################################

#TODO:
# - do activated search term highlighting in search forms

#build some alternate HTML from the search results, adding edit
#controls if the user is logged in

my $dbh = CXGN::Genomic::Clone->db_Main;

my $page = CXGN::Page->new('BAC Registry Editor','Robert Buels');
$page->jsan_use(qw/MochiKit.Base MochiKit.Async MochiKit.Iter MochiKit.DOM MochiKit.Style MochiKit.Logging/);
$page->add_style( text => <<EOS );
td.columnar_table {
  vertical-align: middle;
}
EOS

my ($person,$projects_json,@person_projects) = get_person($dbh);

$page->header(('BAC Registry Viewer/Editor') x 2);


#if logged in, add edit controls
sub get_person {
    my $dbh = shift;
  if(my $person_id = CXGN::Login->new($dbh)->has_session) {
    my $p = CXGN::People::Person->new($dbh, $person_id);

    return unless str_in($p->get_user_type,qw/sequencer curator/);

    my @projects = #do {warn 'THIS IS BOGUS'; @{all_projects()}};
      $p->get_projects_associated_with_person;
    my $pjs = objToJson(\@projects);

    return ($p,$pjs,@projects);
  }
  return;
};



#do a clone search for the BACs to edit here, using the Clone search
my $search = CXGN::Genomic::Search::Clone->new;
my $query = $search->new_query;
my %params = $page->get_all_encoded_arguments;
$query->from_request(\%params);
my $result = $search->do_search($query);

####### now start the actual work

my @table_rows;
while(my $clone = $result->next_result) {

  my $clone_data = $clone->reg_info_hashref;

  my $clone_id = $clone->clone_id;

  my $make_spans = sub {
    my ($name,$data) = @_;
    #make ID'd spans from a clone ID and some key-value pairs
    #if there is more than one pair, the first one will be invisible
    my $val = $data->{val} || '';
    my $disp = $data->{disp} || $val;
    $disp = '-' if $disp eq '';
    return {
	    class => "clone_reg_edit edit_$name",
	    content => qq|<div style="position: relative"><span id="${name}_val_$clone_id" class="invisible">$val</span><span id="${name}_disp_$clone_id">$disp</span></div>|,
	   };
  };

  # fix up the il_notes field with truncation and a mouseover if it is
  # too long
  if( length(my $iln = $clone_data->{il_notes}->{disp}) > 15 ) {
      $clone_data->{il_notes}->{disp} =
	  tooltipped_text(scalar(truncate_string($iln,8)),$iln)
  }

  push @table_rows,
    [
     qq|<span class="invisible">$clone_id</span><a href="/maps/physical/clone_info.pl?id=$clone_id">|.($clone->clone_name_with_chromosome || $clone->clone_name).'</a>',
     map { $make_spans->($_ => $clone_data->{$_}) } evens @data_fields_defs
    ];
}

my $pagination = $search->pagination_buttons_html($query,$result);
my $page_size = $search->page_size_control_html($query);
my $stats = $result->time_html;
my $count = $result->total_results;
my $stat_string = qq|<b>BACs $stats</b>&nbsp;&nbsp;&nbsp;$page_size&nbsp;per&nbsp;page|;

if($person) {
  print <<EOH;
<div id="instructions">
  <dl><dt>Instructions</dt>
      <dd>
      To edit BAC registry information, select BACs to edit using
      the controls at the bottom of the page, then page through and edit
      the BACs by clicking the table cells below.
      </dd>
  </dl>
</div>
EOH
} else {
  print <<EOH;
<div style="text-align: center; margin-bottom: 1em">
  You must be <a href="/solpeople/login.pl">logged in</a> to edit BAC registry information.
</div>
EOH
}
print info_section_html( title => 'Edit Clones',
			 contents =>
			 qq|<div style="text-align: center">$stat_string $pagination</div>|
			 .columnar_table_html( headings =>
					       [
						'Clone',
						map {
						  qq|<span class="invisible">$_</span> |
						    .tooltipped_text($data_fields_defs{$_}{column_name},$data_fields_defs{$_}{tooltip})
						  } evens @data_fields_defs
					       ],

					       data => \@table_rows,
					       __tableattrs => 'summary="" id="editingtable" cellspacing="0" align="center" style="margin-top: 1.2em; margin-bottom: 1.2em"',
					       __border => 1,
					     )
			 .qq|<div style="text-align: center; margin-bottom: 1em">$pagination</div>\n|
		       );


#searches through an array like [query obj,text],[query_obj,text]
#and returns an array like [[qstr,text],[qstr,text]], selected_index
#where the selected_index is the index in the array of the query
#that matches the current page query $query, or undef if none match
#this function is just for use in assembling the args to modesel() below
my $find_selected = sub {
  my $selected;
  my $index = 0;
  my @qs = map {
    my ($q,$t) = @$_;
    $q->page($query->page);
    $q->page_size($query->page_size);

    if ($q->same_bindvals_as($query)) {
      $selected = $index;
    } else {
      $q->page(0);
    }

    $index++;

    [ '?'.$q->to_query_string, $t ]
  } @_;

  return \@qs, $selected;
};

my @seq_searches =
    (
     do {
     my $q = $search->new_query;
     $q->seq_project_name(q(ilike '%Tomato%'|| ? '%'),'unmapped');
     [$q,'unmapped']
   },
   map {
     my $chr = $_;
     my $q = $search->new_query;
     $q->seq_project_name(q(ilike '%Tomato%Chromosome ' || ? || ' %'),$chr);
    [$q,$chr]
  } 1..12
);

my @il_searches = map {
  my ($pid,$country) = @$_;
  my $q = $search->new_query;
  $q->il_project_id('=?',$pid);
  [$q,$country]
} @{ CXGN::People::Project->distinct_country_projects($dbh) };

my @search_sets =
  ( 'BACs to be Sequenced on Chromosome:' =>
    modesel( $find_selected->(@seq_searches) ),
    'BACs to be IL Mapped by Project:' =>
    modesel( $find_selected->(@il_searches) ),
  );

print info_section_html( title => 'Sequencing Stats Overview',
			 contents => '<div id="stats_img_div" style="text-align: center">javascript required</div>'
		       );

print info_section_html( title => 'Select BACs',
			 contents =>
			 info_section_html(title => 'Predefined Sets',
					   is_subsection => 1,
					   contents =>
					   info_table_html( __border => 0,
							    @search_sets,
							  )
					  )
			 .info_section_html(title => 'Custom Set',
					    is_subsection => 1,
					    contents => '<form method="GET">'.$query->to_html.'</form>',
					   )
		       );
#make the javascript for loading the overview image
print <<EOJS;
<script language="JavaScript" type="text/javascript">
  var update_status_image = function() {
    var img_div = document.getElementById('stats_img_div');
    img_div.innerHTML = '<img src="/documents/img/throbber.gif" /><br />updating...';
    var xhr = MochiKit.Async.doSimpleXMLHttpRequest('clone_async.pl',{ action: 'project_stats_img_html' });
    xhr.addCallbacks(function(req) { img_div.innerHTML = req.responseText },
                     function(req) { img_div.getElementById('stats_img_div').innerHTML = 'error fetching image' }
                    );
  };
  update_status_image(); //< update the status image on load
</script>
EOJS

#now print all the hidden edit forms
if($person) {

  print editforms_html($dbh,$person);

  print <<EOS;
<style>
td.clone_reg_edit {
  height: 2.5em;
  cursor: pointer;
}
</style>
EOS

  #UI strategy:
  # - mouseover highlight row, column, and intersection.  highlight shows row locks
  # - click and table cell turns into an edit control if the row is not locked
  # - onchange, locks the table row and POSTs the change to clone_async.pl
  # - on return of the POST, unlocks the row

  #now here is all the JS to do the UI

  #put the data field definitions in the javascript too
  my $data_fields_defs_json = objToJson(\%data_fields_defs);

  print <<EOJS;
<script language="JavaScript" type="text/javascript">

  //import some useful stuff
  var map     = MochiKit.Base.map;
  var partial = MochiKit.Base.partial;
  var foreach = MochiKit.Iter.forEach;
  var keys    = MochiKit.Base.keys;
  var values  = MochiKit.Base.values;
  var log     = MochiKit.Logging.log;

  //this is the color for mouseover-highlighted cells
  var hilite_color = '#c5c5ee';
  var hilite_color_overlap = '#b9b9e0';
  var locked_color = '#f7878f';

  //this is the table where our editing is done
  var edit_table = document.getElementById('editingtable');

  //functions for locking and unlocking rows
  var locks = {};
  var lock_clone = function(row) {
    locks[row.clone_id] = 1;
    foreach( row.tr.cells,
             function(td) {  td.style.backgroundColor = locked_color }
           );

    //create a little 'loading' throbber on the end of the row
    var throbber = MochiKit.DOM.IMG({ src: '/documents/img/throbber.gif',
                                      style: 'display: block; z-index: 3; position: absolute;'
                                    });
    var end_div = row.ver_bac_end.div;
    var end_div_dims = MochiKit.Style.getElementDimensions(end_div);
    MochiKit.Style.setElementPosition(throbber,{x: end_div_dims.w+10, y: 0});
    MochiKit.DOM.appendChildNodes(end_div,throbber);
  };
  var unlock_clone = function(row) {
    locks[row.clone_id] = 0;
    foreach( row.tr.cells,
             function(td) { td.style.backgroundColor = '' }
           );
    //get rid of the throbber
    var end_div = row.ver_bac_end.div;
    foreach(  MochiKit.DOM.getElementsByTagAndClassName('img',null,end_div),
             MochiKit.DOM.removeElement );
  };
  var is_locked = function(a) {
    var clone_id = typeof(a) == 'object' ? get_cell_clone(a) : a;
    return locks[clone_id] ? true : false;
  }

  //determines if a cell is not editable, due to its
  //either being locked by an ongoing XHR, or because this
  //user doesn't have permission to edit it
  //also, the permissions are also checked server-side,
  //so if you're reading this, don't get any funny ideas ;-)
  var is_not_editable = function(cell,clone_id,fieldname) {
    clone_id = clone_id || get_cell_clone(cell);
    fieldname = fieldname || get_cell_field(cell);

    //if the cell isn't locked, check some other permission conditions
    var row = get_clone_elements(clone_id);

    var seq_proj_in_projects_list = MochiKit.Base.findValue(person_projects,row.seq_proj.val.innerHTML.valueOf()) != -1;
    var il_proj_in_projects_list  = MochiKit.Base.findValue(person_projects,row.il_proj.val.innerHTML.valueOf()) != -1;

    switch(fieldname) {
      case 'seq_proj':
        //proj must be null, or in the person's projects list
        if(row.seq_proj.val.innerHTML != '' && !seq_proj_in_projects_list)
          return 'this BAC is already being sequenced by another sequencing project, they must release their claim on this BAC before you can claim it';
      break;
      case 'seq_status':
      case 'gb_status':
        //seq_proj must be in the person's projects list
        if(!seq_proj_in_projects_list)
          return 'this BAC must be assigned to your sequencing project for you to edit its seq or GB status';
      break;
      case 'il_proj':
        //il_proj must be null, or in the person's projects list
        if(row.il_proj.val.innerHTML != '' && !il_proj_in_projects_list)
          return 'this BAC is already being IL bin mapped by another sequencing project, they must release their claim on this BAC before you can claim it';
      break;
      case 'il_bin':
      case 'il_notes':
      case 'il_chr':
        if(!il_proj_in_projects_list)
          return 'this BAC must be assigned to your sequencing project before you can report IL mapping results for it';
      break;
    };

    return;
  };

  var field_defs      = $data_fields_defs_json;
  var person_projects = $projects_json;

  //get the span elements that hold and display data for the relevant clone,
  //and their enclosing td's
  var get_clone_elements = function(clone_id) {
    var elements = { 'clone_id': clone_id };
    foreach( keys(field_defs),
             function( field ) {
               elements[field] = { val:  document.getElementById(field+'_val_'+clone_id),
                                   disp: document.getElementById(field+'_disp_'+clone_id)
                                 };
               if(elements[field].disp) {
                 elements[field].div = elements[field].disp.parentNode;
                 elements[field].td = elements[field].div.parentNode;
                 elements.tr = elements[field].td.parentNode;
               } else {
                 //grab the elements that the form is holding
                 var my_ed = get_editor(field);
                 if(my_ed.is_at_spot(clone_id)) {
                     elements[field] = my_ed.curr_spot;
                 }
               }
             }
           );
    return elements;
  };


  //*** Editor class, used to work with the editors for each data item
  function Editor(n) {
    this.name = n;
    this.myform = document[n+'_edit'];
  }
  //get the element for the appropriate edit form
  Editor.prototype.form = function() {
    return this.myform;
  }
  //hide this editor form
  Editor.prototype.hide = function(cell) {
    if(this.curr_spot) {
      var edform = this.form();
      MochiKit.DOM.removeElement( edform );
      document.getElementById('editor_corral').appendChild( edform );

      //restore the data cells and the onclick handler in the cell we just vacated
      this.curr_spot.td.appendChild(this.curr_spot.div);

      //reinstall the table cell's onclick handler
      this.curr_spot.td.onclick = td_onclick_edit
      //release it
      this.curr_spot = null;
    }
  };
  //is this editor open in this spot?
  Editor.prototype.is_at_spot = function(clone_id) {
    return this.curr_spot && get_cell_clone(this.curr_spot.td) == clone_id;
  };
  //open the editor at a specific clone
  Editor.prototype.open = function(clone_id) {
    //hide any other open editors, including this one
    hide_all_editors();

    var row = get_clone_elements(clone_id);
    this.curr_spot = row[this.name]; //< the two spans that hold this clone's data

    //hide the data in the new cell
    MochiKit.DOM.removeElement(this.curr_spot.div);

    var edform = this.form();

    //set the form's value
    edform.clone_id.value = clone_id;
    if(edform.val_input.type == 'checkbox') {
      edform.val_input.checked = this.curr_spot.val.innerHTML == '1' ? true : false;
    } else {
      edform.val_input.value = this.curr_spot.val.innerHTML;
    }

    //swap the edit form into the td next to the display span
    MochiKit.DOM.removeElement(edform);
    this.curr_spot.td.appendChild(edform);

    //set a checkbox's value again
    if(edform.val_input.type == 'checkbox') {
      edform.val_input.checked = this.curr_spot.val.innerHTML == '1' ? true : false;
    }

    //disable this table cell's onclick handler
    this.curr_spot.td.onclick = null;
  };

  var editors = {};
  //get the clone_id for any cell in the editing table
  var get_cell_clone = function(td) {
    if(td.cellclone) return td.cellclone;
    return td.cellclone = td.parentNode.cells[0].childNodes[0].innerHTML;
  }
  var get_cell_field = function(td) {
    return edit_table.rows[0].cells[td.cellIndex].childNodes[0].innerHTML;
  }

  //the onclick handler for an inactive table cell
  var td_onclick_edit = function() {
    //get the data field name from the invisible span in the head of this column
    var name     = get_cell_field(this);
    var clone_id = get_cell_clone(this);

    if(is_locked(clone_id)) {
      return;
    }
    var not_editable_str = is_not_editable(this,clone_id,name);
    if(not_editable_str) {
      alert('cell not editable: '+not_editable_str);
      return;
    }

    get_editor(name).open(clone_id);
  }
  var hide_all_editors = function() {
    foreach( values(editors),
             function(ed) {
               ed.hide()
             }
           );
  };
  var get_editor = function(name) {
    if(! editors[name]) {
      editors[name] = new Editor(name);
    }
    return editors[name];
  };

  //this function turns row and column highlighting on and off,
  //when given the cell that's under the mouse and whether the highlighting
  //should be turned on or off
  var table_highlight = function(onoff) {
    var cell_coords = [this.parentNode.rowIndex,this.cellIndex];
    var hilite  = function(td,c) {
      c = c || hilite_color;
      if(is_locked(td))
        return;
      td.style.backgroundColor = onoff ? c : '';
    };

    if( is_not_editable(this) ) {
      hilite(this,locked_color);
    } else {
      foreach( edit_table.rows[cell_coords[0]].cells, hilite );
      //foreach( edit_table.rows, function(tr) { hilite(tr.cells[cell_coords[1]]) } );
      hilite(this,hilite_color_overlap);
    }
  };
  var table_highlight_on  = partial(table_highlight,1);
  var table_highlight_off = partial(table_highlight,0);

  //find all the editing TD elements and install their event handlers
  foreach( MochiKit.DOM.getElementsByTagAndClassName('td','clone_reg_edit',edit_table),
           function(cell) {
             cell.onclick     = td_onclick_edit;
             cell.onmouseover = table_highlight_on;
             cell.onmouseout  = table_highlight_off;
           }
         );

  //set the width of all the TH heading elements to be wide enough to
  //accomodate the editing forms in all the cells below
  var set_col_widths = function() {
    foreach( edit_table.rows[0].cells,
             function(th) {
               var name = th.childNodes[0].innerHTML;
               if(! name) return;
               var ed = get_editor(name);
               var edform = ed.form();
               var min_col_width = edform.offsetWidth + 3;
//               log('for '+name+', th width is ' + th.offsetWidth + ' and min is '+min_col_width);
               th.style.width = min_col_width+'px';
             }
           );
  };
  set_col_widths();


  //do a POST XHR to alter the clone in the database,
  //also update its display fields
  var alter_clone = function(edname,clone_id,postcontent) {
    //hide this editor
    get_editor(edname).hide();

    var row = get_clone_elements(clone_id);
    lock_clone(row);

    postcontent.clone_id = clone_id;

    var xhr_opt =
      {  headers:     [["Content-type","application/x-www-form-urlencoded"]],
         method:      'POST',
         sendContent: MochiKit.Base.queryString(postcontent)
      };

    var success_callback = partial(set_row_content,row);
    var err_callback = partial(set_row_error,row);

    //if the action involves the seq status, schedule the overview image to get updated
    //when this comes back
    if(    postcontent.action == 'set_seq_proj'
        || postcontent.action == 'set_gb_status'
        || postcontent.action == 'set_seq_status'
      ) {
      var old_success = success_callback;
      success_callback = function(req) {
        old_success(req);
        update_status_image();
      };
    }

    var res = MochiKit.Async.doXHR('clone_async.pl',xhr_opt);
    res.addCallbacks(success_callback, err_callback);
  };


  var set_row_content = function(row,req) {
    var data;
//    log('set_row_content callback');
    try {
      data = MochiKit.Async.evalJSONRequest(req);
//      log('setting fields...');
      foreach( keys(data),
               function(field) {
//                 log('setting '+field+' contents');
                 if( row[field] ) {
                   row[field].val.innerHTML  = data[field].val;
                   row[field].disp.innerHTML = data[field].disp;
                 }
               }
             );
//      log('unlocking clone '+row.clone_id);
      unlock_clone(row);
    } catch(e) {
      log(e);
      set_row_error(row);
    }
  };

  var set_row_error = function(row) {
//    log('error callback on clone_id '+row.clone_id);
    foreach( values(row),
             function(spans) {
               if(typeof(spans) != 'object' || ! spans.disp)
                 return;

               spans.disp.innerHTML = 'error';
             }
           )
//    log('unlocking clone '+row.clone_id);

    unlock_clone(row);
  };

</script>
EOJS
}

$page->footer;

############ SUBROUTINES ##############

sub il_bin_list {
  return @{our $il_list ||= shift->selectall_arrayref(<<EOQ)}
select genotype_region_id, name
from phenome.genotype_region gr
join sgn.linkage_group lg using(lg_id)
join sgn.map_version mv using(map_version_id)
join sgn.map m using(map_id)
where type = 'bin' and m.short_name like '%1992%' and m.short_name like '%EXPEN%';
EOQ
}

sub editforms_html {
  my ($dbh,$person) = @_;

  return '' unless $person;

  my @person_projects = #do {warn 'THIS IS BOGUS'; @{all_projects()}};
    $person->get_projects_associated_with_person;

  #lookup the name for each of the projects and parse out the chromosome numbers
  @person_projects =
    map {
      my $proj_id = $_;
      my ($chr_name) = $dbh->selectrow_array('select name from sgn_people.sp_project where sp_project_id = ? order by name',undef,$proj_id);
      $chr_name =~ s/\D//g; #remove all non-digits
      #and if nothing's left then it must be the unmapped one
      $chr_name ||= 'unmapped';
      [$proj_id, $chr_name]
    } @person_projects;

  my @ils = il_bin_list($dbh);

  #the values of all these form fields will be set by javascript each
  #time this form is popped up at a given location
  my $clone_id_hidden =  '<input name="clone_id" value="" type="hidden" />';
  my $sel_edit = sub {
    my ($name,@choices) = @_;

    ( qq|<form name="${name}_edit" onsubmit="return false" style="display: inline">|,
      (
       $clone_id_hidden,
       simple_selectbox_html(name     => "val_input",
			     choices  => \@choices,
			     params   => { onchange => "alter_clone('$name',this.form.clone_id.value,{ action: 'set_$name', val: this.value})" },
			    ),
      ),
      '</form>',
    )
  };
  my $cb_edit = sub {
    my ($name,$checked) = @_;
    $checked = $checked ? 'checked="checked"' : '';
    ( qq|<form name="${name}_edit" onsubmit="return false" style="display: inline">|,
      (
       $clone_id_hidden,
       qq|<input id="cb_$name" type="checkbox" name="val_input" onclick="alter_clone('$name',this.form.clone_id.value,{ action: 'set_$name', val: this.checked ? 1 : 0})"$checked/>|,
      ),
      '</form>',
    )
  };
  my $t_edit = sub {
    no warnings 'uninitialized';
    my ($name,$size,$text) = @_;
    ( qq|<form name="${name}_edit" onsubmit="alter_clone('$name',this.clone_id.value,{action: 'set_$name', val: this.val_input.value}); return false" style="display: inline">|,
      (
       $clone_id_hidden,
       qq|<input id="text_$name" type="text" value="$urlencode{$text}" size="$size" maxlength="200" name="val_input" />|,
      ),
      '</form>',
    )
  };
  return join '', map {my $s = $_; chomp $s; "$s\n"}
    (
      '<div id="editor_corral" style="position: absolute; left: -800px;">',
      (
       $sel_edit->('seq_proj',['','none'],@person_projects),
       $sel_edit->('seq_status','none','not_sequenced','in_progress','complete'),
       $sel_edit->('gb_status','none',map {"htgs$_"} 1..3),
       $sel_edit->('il_proj',['','none'],grep {my $id = $_->[0]; str_in($id,map $_->[0],@person_projects)} @{CXGN::People::Project->distinct_country_projects($dbh)}),
       $sel_edit->('il_chr',['','none'],1..12),
       $sel_edit->('il_bin',['','none'],@ils),
       $t_edit  ->('il_notes',15),
       $cb_edit ->('ver_int_read'),
       $cb_edit ->('ver_bac_end'),
      ),
     '</div>',
    );
}

sub metadata {
  our $metadata ||= CXGN::Metadata->new(); # metadata object
}

sub bac_status_log {
    my $dbh = shift;
  our $bac_status_log ||= CXGN::People::BACStatusLog->new($dbh); # bac ... status ... object
}

