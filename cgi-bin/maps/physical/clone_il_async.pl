use strict;
use warnings;

use JSON; #< used for encoding our return data as JSON, for use by the
          #< client javascript

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::People;
use CXGN::Login;

use CXGN::Tools::List qw/str_in/;
use CXGN::Page::FormattingHelpers qw/ info_table_html /;

use CXGN::Genomic::Clone;

use CatalystX::GlobalContext '$c';

my %ops = ( assign     => \&assign_to_project,
	    localize   => \&report_mapping_bin,
#	    qprojjson  => \&query_proj_json,
	    qclonehtml => \&query_bac_infotable,
	    qclonejson => \&query_bac_json
	  );

my $opname = $c->req->param('action');
#die "got opname $opname\n";
$ops{$opname} or die 'unknown operation';
print $ops{$opname}->();

exit;

######## OPERATIONS SUBS #############

sub assign_to_project {
  my $person = get_valid_person();
  my $clone = clone();

  my $id = $c->req->param('proj');
  if($id eq 'none') {
    $id = undef;
  } else {
    $id += 0; #< enforce numeric
    str_in($id,$person->get_projects_associated_with_person)
      or die 'you do not have permission to make that assignment';
  }

  clone()->il_mapping_project_id($id,$person->get_sp_person_id);
  return query_bac_json();
}

sub report_mapping_bin {
  my ($argname,$funcname) = @_;

  my $person = get_valid_person();
  my $clone = clone();

  my $id = $c->req->param('il_indiv');
  if($id eq 'none') {
    $id = undef;
  } else {
    $id += 0; #< enforce numeric
  }

  clone()->il_mapping_individual_id($id,$person->get_sp_person_id);
  return query_bac_json();
}

sub query_bac {
  my ($clone) = @_;
  $clone ||= clone();
  my @projnames = (undef,qw/USA Korea China UK India Netherlands France Japan Spain USA USA Italy/);
  my $proj_id = $clone->il_mapping_project_id;
  my $proj_name = $proj_id ? ($projnames[$proj_id] || $proj_id) : 'none'; #< change the project ID to the project name

  my $il_id = $clone->il_mapping_individual_id;
  my ($il_name) = do {
    if($il_id) {
      $clone->db_Main->selectrow_array(<<EOQ,undef,$il_id);
select name
from phenome.individual
where individual_id=?
EOQ
    }
  };

  $il_name ||= 'not yet reported';
  return ($proj_name,$il_name,$proj_id,$il_id);

}

sub query_bac_infotable {
  my ($proj_name,$il_name) = query_bac(@_);
  return info_table_html( __multicol => 2,
			  __border => 0,
			  'Assigned to project' => $proj_name,
			  'Mapped to IL segment' => $il_name,
			);
}

sub query_bac_json {
  my ($proj_name,$il_name,$proj_id,$il_id) = query_bac(@_);
  return objToJson({ proj_name => $proj_name,
		     proj_id => $proj_id,
		     il_name => $il_name,
		     il_id => $il_id,
		   });
}

# sub query_proj_json {
#   my ($proj_id) = $page->get_encoded_arguments('p');

#   my $dbh = CXGN::DB::Connection->new;
#   my $bacs = $dbh->selectall_arrayref(<<EOQ,undef,$proj_id);
# select cl.clone_id,
#        ( select name
#          from sgn_people.sp_clone_il_mapping_segment_log
#          join phenome.individual using(individual_id)
#          where clone_id = cl.clone_id
#                and is_current = true
#        )
# from sgn_people.sp_project_il_mapping_clone_log cl
# where cl.sp_project_id = ?
#   and cl.is_current = true
# EOQ

#   my @ret = map {
#     my ($clone_id,$il_name) = @$_;
#     [ $clone_id,
#       'bogus name',
#       $il_name,
#     ]
# #     my $clone = CXGN::Genomic::Clone->retrieve($clone_id);
# #     [
# #      '<a href="/maps/physical/clone_info.pl?id=$clone_id">'
# #      .($clone->clone_name_with_chromosome || $clone->clone_name)
# #      .'</a>',
# #      $il_name,
# #     ]
#   } @$bacs;

#   return objToJson(\@ret);
# }

############ UTILITY SUBS #############

sub clone {
  my $id = $c->req->param('id');
  $id += 0;
  my $c = CXGN::Genomic::Clone->retrieve($id)
    or die 'could not retrieve clone from id';
  return $c;
}

sub get_valid_person {
  my $dbh = CXGN::DB::Connection->new();
  my $person_id = CXGN::Login->new($dbh)->has_session
    or die 'you must log in to access this page';
  my $person = CXGN::People::Person->new($dbh, $person_id);

 str_in($person->get_user_type,qw/sequencer curator/)
    or die 'you do not have permission to make that assignment';

  return $person;
}
