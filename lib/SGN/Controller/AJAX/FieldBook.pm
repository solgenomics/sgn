
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
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::UploadFile;
use CXGN::Fieldbook::TraitInfo;
use CXGN::Fieldbook::DownloadTrial;
use SGN::Model::Cvterm;
use CXGN::List;
use CXGN::List::Validate;
use CXGN::List::Transform;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub create_fieldbook_from_trial : Path('/ajax/fieldbook/create') : ActionClass('REST') { }

sub create_fieldbook_from_trial_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
  my $data_level = $c->req->param('data_level') || 'plots';
  my $treatment_project_ids = $c->req->param('treatment_project_id') ? [$c->req->param('treatment_project_id')] : [];
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
    if ($data_level eq 'subplots' || $data_level eq 'plants_subplots') {
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        if (!$trial->has_subplot_entries()) {
            $c->stash->{rest} = {error =>  "Trial does not have subplot entries." };
            return;
        }
    }

    my $trial_stock_type;
    if (!defined($c->req->param('trial_stock_type'))) {
        $trial_stock_type = 'accession';
    } else {
        $trial_stock_type = $c->req->param('trial_stock_type');
    }

    my $original_selected_columns = $c->req->param('selected_columns') ? decode_json $c->req->param('selected_columns') : {};

    my %modified_columns = %{$original_selected_columns};
    if (exists $modified_columns{'family_name'}) {
        delete $modified_columns{'family_name'};
        $modified_columns{'accession_name'} = 1;
    }
    if (exists $modified_columns{'cross_unique_id'}) {
        delete $modified_columns{'cross_unique_id'};
        $modified_columns{'accession_name'} = 1;
    }
    my $selected_columns = \%modified_columns;

#    print STDERR "ORIGINAL SELECTED COLUMNS =".Dumper($original_selected_columns)."\n";
#    print STDERR "MODIFIED COLUMNS =".Dumper(\%modified_columns)."\n";
    my $include_measured = $c->req->param('include_measured') || '';
    my $all_stats = $c->req->param('all_stats') || '';
    my $use_synonyms = $c->req->param('use_synonyms') || '';
    my $selected_trait_list_id = $c->req->param('trait_list');
    my @selected_traits;
    if ($selected_trait_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $selected_trait_list_id });
        my @trait_list = @{$list->elements()};
        my $validator = CXGN::List::Validate->new();
        my @absent_traits = @{$validator->validate($schema, 'traits', \@trait_list)->{'missing'}};
        if (scalar(@absent_traits)>0){
            $c->stash->{rest} = {error =>  "Trait list is not valid because of these terms: ".join ',',@absent_traits };
            $c->detach();
        }
        my $lt = CXGN::List::Transform->new();
        @selected_traits = @{$lt->transform($schema, "traits_2_trait_ids", \@trait_list)->{transform}};
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
        treatment_project_ids => $treatment_project_ids,
        selected_columns => $selected_columns,
        include_measured => $include_measured,
        all_stats => $all_stats,
        use_synonyms => $use_synonyms,
        selected_trait_ids => \@selected_traits,
        trial_stock_type => $trial_stock_type,
    });

    my $create_fieldbook_return = $create_fieldbook->download();
    my $error;
    if ($create_fieldbook_return->{'error_messages'}){
        $error = join ',', @{$create_fieldbook_return->{'error_messages'}};
    }

    $c->stash->{rest} = {
        error_string => $error,
        success => 1,
        result => $create_fieldbook_return->{'result'},
        file => $create_fieldbook_return->{'file'},
        file_id => $create_fieldbook_return->{'file_id'},
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
  my $include_notes = $c->req->param('include_notes');
  my $user_id = $c->user()->get_object()->get_sp_person_id();
  my $user_name = $c->user()->get_object()->get_username();
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $subdirectory_name = "tablet_trait_files";
  my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$trait_file_name.".trt");
  my $archive_path = $c->config->{archive_path};
  my $file_destination =  catfile($archive_path, $archived_file_name);
  my $dbh = $c->dbc->dbh();
  my @trait_ids;

  if ($c->req->param('selected_listed')) {
    @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
    @trait_ids = @{_parse_list_from_json($c->req->param('trait_ids'))};
  } else {
    @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
    @trait_ids = $c->req->param('trait_ids');
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
  print STDERR Dumper($file_destination);
  open(my $FILE, "> :encoding(UTF-8)", $file_destination) or die $!;
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  print $FILE "trait,format,defaultValue,minimum,maximum,details,categories,isVisible,realPosition\n";
  my $order = 0;

  foreach my $term (@trait_list) {
      #print STDERR "term is $term\n";
      my @parts = split (/\|/ , $term);
      my ($db_name, $accession) = split ":", pop @parts;
      my $trait_name = join ("|", @parts);
      #print STDERR "trait name is $trait_name, full cvterm accession is $full_cvterm_accession\n";
      #my ( $db_name , $accession ) = split (/:/ , $full_cvterm_accession);

      $accession =~ s/\s+$//;
      $accession =~ s/^\s+//;
      $db_name =~ s/\s+$//;
      $db_name =~ s/^\s+//;

      my $cvterm = CXGN::Chado::Cvterm->new( $dbh, $trait_ids[$order] );
      my $synonym = $cvterm->get_uppercase_synonym();
      my $name = $synonym || $trait_name; # use uppercase synonym if defined, otherwise use full trait name
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
      #print STDERR " Adding line \"$name\t\t\t|$db_name:$accession\",$trait_info_string,\"TRUE\",\"$order\" to trait file\n";
      print $FILE "\"$name\t\t\t|$db_name:$accession\",$trait_info_string,\"TRUE\",\"$order\"\n";
  }

  if ($include_notes eq 'true') {
      $order++;
      #print STDERR " Adding notes line \"notes\",\"text\",\"\",\"\",\"\",\"Additional observations for future reference\",\"\",\"TRUE\",\"$order\"\n";
      print $FILE "\"notes\",\"text\",\"\",\"\",\"\",\"Additional observations for future reference\",\"\",\"TRUE\",\"$order\"\n";
  }

  close $FILE;

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
      #my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
     my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}


1;
