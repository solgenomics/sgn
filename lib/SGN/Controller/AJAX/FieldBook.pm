
=head1 NAME

SGN::Controller::AJAX::FieldBook - a REST controller class to provide the
backend for field book operations

=head1 DESCRIPTION

Creating and viewing trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::FieldBook;

use Moose;
use List::MoreUtils qw /any /;
use Scalar::Util qw(looks_like_number);
use DateTime;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use JSON -support_by_pp;
use Spreadsheet::WriteExcel;
use SGN::View::Trial qw/design_layout_view design_info_view/;
use CXGN::Trial::TrialLayout;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::UploadFile;
use CXGN::Fieldbook::TraitInfo;
use CXGN::Fieldbook::DownloadTrial;
use SGN::Model::Cvterm;

#use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub create_fieldbook_from_trial : Path('/ajax/fieldbook/create') : ActionClass('REST') { }

sub create_fieldbook_from_trial_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
  my $data_level = $c->req->param('data_level') || 'plots';
  my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
  my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');

  chomp($trial_id);
  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to create a field book" };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to create a field book." };
    return;
  }
  if (!$trial_id) {
    $c->stash->{rest} = {error =>  "No trial ID supplied." };
    return;
  }
  my $trial = $schema->resultset('Project::Project')->find({project_id => $trial_id});
  if (!$trial) {
    $c->stash->{rest} = {error =>  "Trial does not exist with id $trial_id." };
    return;
  }
    if ($data_level eq 'plants') {
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        if (!$trial->has_plant_entries()){
            $c->stash->{rest} = {error =>  "Trial does not have plant entries. You must first create plant entries." };
            return;
        }
    }

  my $dir = $c->tempfiles_subdir('/other');
  my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');

    my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
        bcs_schema => $schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        trial_id => $trial_id,
        tempfile => $tempfile,
        archive_path => $c->config->{archive_path},
        user_id => $c->user()->get_object()->get_sp_person_id(),
        user_name => $c->user()->get_object()->get_username(),
        data_level => $data_level,
    });

    my $create_fieldbook_return = $create_fieldbook->download();

    $c->stash->{rest} = {
        error_string => $create_fieldbook_return->{'error_messages'},
        success => 1,
        result => $create_fieldbook_return->{'result'},
        file => $create_fieldbook_return->{'file'},
    };
}

sub create_trait_file_for_field_book : Path('/ajax/fieldbook/traitfile/create') : ActionClass('REST') { }

sub create_trait_file_for_field_book_POST : Args(0) {
  my ($self, $c) = @_;

  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to create a field book" };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to create a field book." };
    return;
  }

  my @trait_list;
  my $trait_file_name = $c->req->param('trait_file_name');
  my $user_id = $c->user()->get_object()->get_sp_person_id();
  my $user_name = $c->user()->get_object()->get_username();
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $subdirectory_name = "tablet_trait_files";
  my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$trait_file_name.".trt");
  my $archive_path = $c->config->{archive_path};
  my $file_destination =  catfile($archive_path, $archived_file_name);
  my $dbh = $c->dbc->dbh();
  my @trait_ids = @{_parse_list_from_json($c->req->param('trait_ids'))};

  if ($c->req->param('trait_list')) {
    @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
  }

  if (!-d $archive_path) {
    mkdir $archive_path;
  }

  if (! -d catfile($archive_path, $user_id)) {
    mkdir (catfile($archive_path, $user_id));
  }

  if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
    mkdir (catfile($archive_path, $user_id, $subdirectory_name));
  }

  open FILE, ">$file_destination" or die $!;
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  print FILE "trait,format,defaultValue,minimum,maximum,details,categories,isVisible,realPosition\n";
  my $order = 0;

  foreach my $term (@trait_list) {

      my ($trait_name, $full_cvterm_accession) = split (/\|/, $term);
      my ( $db_name , $accession ) = split (/:/ , $full_cvterm_accession);

      $accession =~ s/\s+$//;
      $accession =~ s/^\s+//;
      $db_name =~ s/\s+$//;
      $db_name =~ s/^\s+//;

      print STDERR "traitname: $term | accession: $accession \n";

      my $cvterm = CXGN::Chado::Cvterm->new( $dbh, $trait_ids[$order] );
      my $synonym = $cvterm->get_uppercase_synonym();
      my $name = $synonym || $trait_name;
      $order++;

      #get trait info

      my $trait_info_lookup = CXGN::Fieldbook::TraitInfo
	  ->new({
	      chado_schema    => $chado_schema,
	      db_name         => $db_name,
	      trait_accession => $accession,
		});
      my $trait_info_string = $trait_info_lookup->get_trait_info($trait_name);

      #return error if not $trait_info_string;
      #print line with trait info
      #print FILE "$trait_name:$db_name:$accession,text,,,,,,TRUE,$order\n";
      print FILE "\"$name\t\t\t|$db_name:$accession\",$trait_info_string,\"TRUE\",\"$order\"\n";
  }

  close FILE;

  open(my $F, "<", $file_destination) || die "Can't open file ";
  binmode $F;
  my $md5 = Digest::MD5->new();
  $md5->addfile($F);
  close($F);

  my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

  my $md_row = $metadata_schema->resultset("MdMetadata")->create({
								  create_person_id => $user_id,
								 });
  $md_row->insert();

  my $file_row = $metadata_schema->resultset("MdFiles")->create({
								     basename => basename($file_destination),
								     dirname => dirname($file_destination),
								     filetype => 'tablet trait file',
								     md5checksum => $md5->hexdigest(),
								     metadata_id => $md_row->metadata_id(),
								    });
  $file_row->insert();

  my $id = $file_row->file_id();

  $c->stash->{rest} = {success => "1", file_id => $id, };

}


sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}


1;
