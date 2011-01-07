use strict;
use warnings;

use JSON; #< used for encoding our return data as JSON, for use by the
          #< client javascript

use Data::Dumper;

use CXGN::Metadata; #< bac project associations are in the metadatadatabase

use CXGN::Scrap::AjaxPage;
use CXGN::People;
use CXGN::People::BACStatusLog;
use CXGN::Login;

use CXGN::Tools::List qw/str_in/;
use CXGN::Page::FormattingHelpers qw/info_table_html columnar_table_html/;

use CXGN::Genomic::Clone;
use CXGN::Cview::MapOverviews::ProjectStats;

use CatalystX::GlobalContext '$c';

our $page = CXGN::Scrap::AjaxPage->new('text/html');
our $dbh = CXGN::DB::Connection->new();

$page->send_http_header;

my %ops = (
	    set_ver_int_read   => sub { set_val_flag('int_read') },
	    set_ver_bac_end    => sub { set_val_flag('bac_end') },
	    qclonehtml         => \&query_bac_infotable,
	    qclonejson         => \&query_bac_json,
	    qcloneperl         => \&query_bac_perl,
	  );

my ($opname) = $page->get_encoded_arguments('action');
no strict 'refs'; #< using symbolic refs for sub names
$opname =~ /[^a-z_]/ and die "invalid op name '$opname'";
$ops{$opname} ||= \&{"$opname"};
$ops{$opname} or die 'unknown operation';
print $ops{$opname}->();
exit;

######## END OF MAIN SCRIPT

######## OPERATIONS SUBS #############

sub set_il_proj {
  my $person = get_valid_person();
  my $clone = clone();

  my ($id) = $page->get_encoded_arguments('val');
  if($id && $id ne 'none') {
    $id += 0; #< enforce numeric
    str_in($id,$person->get_projects_associated_with_person)
      or die 'you do not have permission to make that assignment';
  } else {
    $id = undef;
  }

  $clone->il_mapping_project_id($id,$person->get_sp_person_id);
  return query_bac_json($clone);
}

sub set_il_bin {
  my ($argname,$funcname) = @_;

  my $person = get_valid_person();
  my $clone = clone();

  my ($id) = $page->get_encoded_arguments('val');
  if($id && $id ne 'none') {
    $id += 0;
  } else {
    $id = undef;
  }

  $clone->il_mapping_data({bin_id =>$id},$person->get_sp_person_id);
  return query_bac_json($clone);
}

sub set_il_chr {
  my ($argname,$funcname) = @_;

  my $person = get_valid_person();
  my $clone = clone();

  my ($chr) = $page->get_encoded_arguments('val');
  if($chr && $chr >0) {
    $chr += 0;
  } else {
    $chr = undef;
  }

  $clone->il_mapping_data({chr =>$chr},$person->get_sp_person_id);
  return query_bac_json($clone);
}

sub set_il_notes {
  my ($argname,$funcname) = @_;

  my $person = get_valid_person();
  my $clone = clone();

  my ($notes) = $page->get_encoded_arguments('val');
  $notes ||= undef;

  $clone->il_mapping_data({notes => $notes},$person->get_sp_person_id);
  return query_bac_json($clone);
}




sub set_seq_proj {
  my $clone = clone();
  my $person = get_valid_person();
  my ($proj_id) = $page->get_encoded_arguments('val');

  unless($proj_id) {
    $proj_id = undef;
  } else {
    $proj_id += 0; #< enforce numeric
    $person->is_person_associated_with_project($proj_id)
      or die "not authorized to assign a clone to that project\n";
  }
  my $current_proj = metadata()->get_project_associated_with_bac($clone->clone_id);

  !$current_proj or $person->is_person_associated_with_project($current_proj)
    or die "not authorized to take a bac away from that chromosome project\n";

  metadata()->attribute_bac_to_project($clone->clone_id,$proj_id);
  return query_bac_json($clone);
}

sub set_seq_status {
  my $clone = clone();
  my $person = get_valid_person();
  my ($stat) = $page->get_encoded_arguments('val');

  my $current_proj = metadata()->get_project_associated_with_bac($clone->clone_id);

  $person->is_person_associated_with_project($current_proj)
    or die "not authorized to change seq status for that bac\n";

  bac_status_log()->change_status( bac => $clone->clone_id,
				   person => $person->get_sp_person_id,
				   seq_status => $stat,
				 );
  return query_bac_json($clone);
}

sub set_gb_status {
  my $clone = clone();
  my $person = get_valid_person();
  my ($stat) = $page->get_encoded_arguments('val');

  my $current_proj = metadata()->get_project_associated_with_bac($clone->clone_id);

  $person->is_person_associated_with_project($current_proj)
    or die "not authorized to change genbank status for that bac\n";

  bac_status_log()->change_status( bac => $clone->clone_id,
				   person => $person->get_sp_person_id,
				   genbank_status => $stat,
				 );
  return query_bac_json($clone);
}

sub set_val_flag {
  my ($flagname) = @_;
  my $clone = clone();
  my $person = get_valid_person();

  my ($stat) = $page->get_encoded_arguments('val');

  $clone->verification_flags(person => $person, $flagname => $stat ? 1 : 0);
  return query_bac_json($clone);
}

sub query_bac_infotable {
  my $clone = shift() || clone();
  my $info = $clone->reg_info_hashref;
  return info_table_html( __multicol => 2,
			  __border => 0,
			  'Assigned to project' => $info->{il_proj}{disp},
			  'Mapped to IL segment' => $info->{il_bin}{disp},
			);
}

sub query_bac_json {
  my $clone = shift() || clone();
  return to_json( $clone->reg_info_hashref );
}

sub query_bac_perl {
  my $clone = shift() || clone();
  local $Data::Dumper::Terse = 1;
  return Dumper $clone->reg_info_hashref;
}

sub project_stats_img_html {

  # force re-calculation of the image/stats
  my $map_overview = CXGN::Cview::MapOverviews::ProjectStats->new(
      { force => 1,
        dbh => $dbh,
        basepath => $c->get_conf('basepath'),
        tempfiles_subdir => $c->tempfiles_subdir('cview'),
        progress_data => bac_status_log()->bac_by_bac_progress_statistics,
      },
     );
  $map_overview->render_map();
  my $map_overview_html = $map_overview->get_image_html();

  # also generate a smaller version of the image that is
  # used on the homepage.
  #
  $map_overview->create_mini_overview;

  return $map_overview_html;
}


############ UTILITY SUBS #############
# these subs are used by the main operations subs above

sub clone {

  #did we get a clone_id argument?  if so, lookup from that
  my ($id) = $page->get_encoded_arguments('clone_id');
  $id += 0;
  if($id) { 
    my $c = CXGN::Genomic::Clone->retrieve($id)
      or die 'could not retrieve clone from id';
    return $c;
  }

  my ($name) = $page->get_encoded_arguments('clone_name');
  #otherwise, did we get a clone_name arg? if so, lookup from that
  if($name) {
    my $c = CXGN::Genomic::Clone->retrieve_from_clone_name($name)
      or die 'could not retrieve clone from name';
    return $c;
  }

  die 'must provide either clone ID (clone_id argument) or clone name (clone_name argument)';
}

sub get_valid_person {
  my $person_id = CXGN::Login->new($dbh)->has_session
    or die 'you must log in to access this page';
  my $person = CXGN::People::Person->new($dbh, $person_id);

  str_in($person->get_user_type,qw/sequencer curator/)
    or die 'you do not have permission to make that assignment';

  return $person;
}

sub metadata {
  our $metadata ||= CXGN::Metadata->new(); # metadata object
}

sub bac_status_log {
    our $bac_status_log ||= CXGN::People::BACStatusLog->new($dbh); # bac ... status ... object
}

