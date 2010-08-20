use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      modesel
				      columnar_table_html
				      simple_selectbox_html
				      info_table_html
				    );
use CXGN::Tools::List qw/distinct str_in/;

my $page = CXGN::Page->new('Clone IL Mapping Assignments','Robert Buels');
$page->jsan_use(qw/MochiKit.Base MochiKit.Async MochiKit.Iter MochiKit.DOM MochiKit.Style/);

$page->header(('Clone IL Mapping Assignments') x 2);

my ($curr_proj) = $page->get_encoded_arguments('p');
$curr_proj ||= 1;

# map project IDs to country names
my @projmap = qw/dummy USA Korea China UK India Netherlands France Japan Spain USA USA Italy/;

# map project IDs to modesel button indexes
my @indexmap = (     0,  0,    1,    2, 3,    4,          5,     6,    7,    8,  0,  0,    9);

print modesel([ map { [ "?p=$_" => $projmap[$_] ] } 1..9,12 ],
	      $indexmap[$curr_proj],
	     );

#look up all the il assignments for this project
my $dbh = CXGN::DB::Connection->new;
my $clone_name_sql = CXGN::Genomic::Clone->
  clone_name_sql('l.shortname',
		 'c.platenum',
		 'c.wellrow',
		 'c.wellcol',
		);
my $bacs = $dbh->selectall_arrayref(<<EOQ,undef,$curr_proj);
select	cl.clone_id,
        $clone_name_sql,
	cl.sp_project_id,
        ill.individual_id,
        i.name
from sgn_people.sp_project_il_mapping_clone_log cl
join genomic.clone c using(clone_id)
join genomic.library l using(library_id)
left join sgn_people.sp_clone_il_mapping_segment_log ill on cl.clone_id=ill.clone_id and ill.is_current = true
left join phenome.individual i using(individual_id)
where cl.sp_project_id = ?
  and cl.is_current = true
order by $clone_name_sql
EOQ

#if logged in, add edit controls
my $person = do {
  if(my $person_id = CXGN::Login->new($dbh)->has_session) {
    CXGN::People::Person->new($dbh, $person_id);
  }
};

my $can_edit = $person                                                #< person is logged in
  && str_in($person->get_user_type,qw/sequencer curator/)             #< and is the right user type
  && str_in($curr_proj,$person->get_projects_associated_with_person); #< and has edit rights on this project

my @data = map {
  my ($clone_id,$clone_name,$project_id,$il_id,$il_name) = @$_;
  [
   #link to clone info page
   qq|<a href="/maps/physical/clone_info.pl?id=$clone_id">$clone_name</a>|,

   #the project name
   qq|<span id="proj_name_$clone_id">$projmap[$project_id]</span><span id="proj_id_$clone_id" style="display: none">$project_id</span>|,

   #the IL line
   qq|<span id="il_name_$clone_id">|.($il_name || '-').qq|</span><span style="display: none" id="il_id_$clone_id">$il_id</span>|,

   $can_edit ? edit_controls_html($clone_id,$il_id) : (),
  ]
} @$bacs;

my @headings = ('BAC', 'Project', 'IL Bin', $can_edit ? 'Edit' : ());

print columnar_table_html( headings     => \@headings,
			   data         => \@data,
			   __border     => 1,
			   __align      => 'lccr',
			   __tableattrs => 'align="center" width="60%" summary="" cellspacing="0"',
			 );

print editform_html($dbh,$person,$curr_proj);

#now here are the JS functions to do the updating
print <<EOJS;
<script language="JavaScript" type="text/javascript">

  var TR = MochiKit.DOM.TR;
  var TD = MochiKit.DOM.TD;
  var A = MochiKit.DOM.A;
  var map = MochiKit.Base.map;
  var partial = MochiKit.Base.partial;
  var TABLE = MochiKit.DOM.TABLE;
  var THEAD = MochiKit.DOM.THEAD;

  var set_row_content = function(row,req) {
    var data = MochiKit.Async.evalJSONRequest(req);

    row.proj_name.innerHTML = data.il_proj.disp;
    row.proj_id.innerHTML   = data.il_proj.val;
    row.il_name.innerHTML   = data.il_bin.disp;
    row.il_id.innerHTML     = data.il_bin.val;

    check_editor_enable();
  };

  var set_row_error = function(row) {
    row.proj_name.innerHTML = 'error';
    row.il_name.innerHTML = 'error';
  }

  //get the three span elements in the relevant table row
  var get_row_elements = function(clone_id) {
    var row = { proj_name:  document.getElementById('proj_name_'+clone_id),
                proj_id:    document.getElementById('proj_id_'+clone_id),
                il_name:    document.getElementById('il_name_'+clone_id),
                il_id:      document.getElementById('il_id_'+clone_id),
                editbutton: document.getElementById('editbutton_'+clone_id),
                posdiv:     document.getElementById('posdiv_'+clone_id)
              };
    row.disabled = (row.proj_id.innerHTML == 'disabled') || (row.il_id.innerHTML == 'disabled');
    return row;
  };

  var edform = document.clone_il_editor_form;
  var edtable = document.getElementById('clone_il_editor_table');

  //set the editor either enabled or disabled,
  //depending on which clone it's currently
  //editing
  var check_editor_enable = function() {

    var clone_id = edform.clone_id.value;

    if(!clone_id) return;

    var row = get_row_elements(clone_id);

    if(row.disabled) {
      edform.il.disabled = true;
      edform.proj.disabled = true;
    } else {
      edform.il.disabled = false;
      edform.proj.disabled = false;
    }
  };

  //do a POST XHR to alter the clone in the database,
  //also update its display fields
  var alter_clone = function(clone_id,type,newvalue) {
    var row = get_row_elements(clone_id);

    var postcontent = type == 'proj' ? { clone_id: clone_id, action: 'set_il_proj', val:     newvalue }
                                     : { clone_id: clone_id, action: 'set_il_bin',  val: newvalue };

    var xhr_opt =
      {  headers:     [["Content-type","application/x-www-form-urlencoded"]],
         method:      'POST',
         sendContent: MochiKit.Base.queryString(postcontent)
      };

    row.proj_name.innerHTML =
      row.il_name.innerHTML =
        '<div style="background: red; color: white; font-weight:bold; border: 2px outset gray;">wait</span>';
    row.proj_id.innerHTML = row.il_id.innerHTML = 'disabled';

    check_editor_enable();

    var res = MochiKit.Async.doXHR('clone_async.pl',xhr_opt);
    res.addCallbacks(partial(set_row_content,row),
                     partial(set_row_error,row)
                    );
  };

  var last_active_edit_button;

  //pop up the edit form at the given button
  var edit_row = function(clone_id) {
    var row = get_row_elements(clone_id);

    row.editbutton.blur();
    edform.clone_id.value = clone_id;

    edform.il.value = row.il_id.innerHTML || 'none';
    edform.proj.value = row.proj_id.innerHTML;

    edtable.style.display = 'block';

    MochiKit.DOM.removeElement(edform);
    MochiKit.DOM.appendChildNodes(row.posdiv,edform);
    var divdims = MochiKit.Style.getElementDimensions(row.posdiv);
    MochiKit.Style.setElementPosition(edtable,{x: divdims.w-4, y: 0});

    check_editor_enable();

    if(last_active_edit_button) {
      MochiKit.Style.setStyle(last_active_edit_button,{background: 'none', fontWeight: 'normal', color: 'black'});
    }
    last_active_edit_button = row.editbutton;
    MochiKit.Style.setStyle(row.editbutton,{background: '#666', fontWeight: 'bold', color: 'white' });
  };

</script>
EOJS

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

sub edit_controls_html {
  my ($clone_id,$il_id) = @_;
  $il_id ||= 'null';
  return qq|<div style="position: relative; padding: 0" id="posdiv_$clone_id"><button id="editbutton_$clone_id" value="edit" style="background: none; border: 1px solid black;" onclick="edit_row($clone_id)">edit</button></div>|;
}

sub editform_html {
  my ($dbh,$person,$curr_proj) = @_;

  return '' unless $person;

  my @person_projects = $person->get_projects_associated_with_person;

  #@projmap is a array of [project_id,country name]
  my $c;
  my @projmap = map {
    [++$c,$_]
  } qw/USA Korea China UK India Netherlands France Japan Spain USA USA Italy/;
  @projmap[9,10] = ($projmap[0]) x 2;

  my @ils = il_bin_list($dbh);

  #the values of all these form fields will be set by javascript each
  #time this form is popped up at a given location
  return join '',
    (
     '<form name="clone_il_editor_form">',
     qq|<input name="clone_id" value="" type="hidden"/>|,
     '<table id="clone_il_editor_table" style="display: none; position: absolute; background: #bbbbff; border: 1px solid black; z-index: 3"><tr><td><b>Project</b></td><td>',
     simple_selectbox_html(name     => "proj",
			   choices  => [['','none'],
					distinct map {$projmap[$_-1]} @person_projects
				       ],
			   params   => { onchange => "alter_clone(this.form.clone_id.value,'proj',this.value)" },
			   selected => $curr_proj,
			  ),
     '</td></tr><tr><td><b>IL</b></td><td>',
     simple_selectbox_html(name    => "il",
			   choices => [['','none'],
				       @ils,
				      ],
			   params  => { onchange => "alter_clone(this.form.clone_id.value,'il',this.value)" },
			  ),
     '</td></tr></table></form>',
    );
}
