
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
use Try::Tiny;
use Scalar::Util qw(looks_like_number);
use File::Slurp;
use Data::Dumper;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use JSON -support_by_pp;
use SGN::View::Trial qw/design_layout_view design_info_view/;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::Trial::TrialLayout;
use Spreadsheet::WriteExcel;
use Digest::MD5;
use File::Basename qw | basename dirname|;
use DateTime;
use File::Spec::Functions;
use File::Copy;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);

sub create_fieldbook_from_trial : Path('/ajax/fieldbook/create') : ActionClass('REST') { }

sub create_fieldbook_from_trial_GET : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
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
  my $dir = $c->tempfiles_subdir('/other');
  my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
  my $wb = Spreadsheet::WriteExcel->new($tempfile);
  if (!$wb) {
    $c->stash->{rest} = {error =>  "Could not create file" };
    return;
  }
  my $ws = $wb->add_worksheet();
  my $trial_layout;
  print STDERR "\n\nTrial id: ($trial_id)\n\n"; 
  try {
    $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
  };
  if (!$trial_layout) {
    $c->stash->{rest} = {error =>  "Trial does not have a valid field design" };
    return;
  }
  my $trial_name =  $trial_layout->get_trial_name();
  $ws->write(0, 0, 'plot_id');
  $ws->write(0, 1, 'range');
  $ws->write(0, 2, 'plot');
  $ws->write(0, 3, 'rep');
  $ws->write(0, 4, 'accession');
  $ws->write(0, 5, 'is_a_control');

  my %design = %{$trial_layout->get_design()};
  my $row_num = 1;
  foreach my $key (sort { $a <=> $b} keys %design) {
    my %design_info = %{$design{$key}};
    $ws->write($row_num,0,$design_info{'plot_name'});
    $ws->write($row_num,1,$design_info{'block_number'});
    $ws->write($row_num,2,$design_info{'plot_number'});
    $ws->write($row_num,3,$design_info{'rep_number'});
    $ws->write($row_num,4,$design_info{'accession_name'});
    $ws->write($row_num,5,$design_info{'is_a_control'});
    $row_num++;
  }
  $wb->close();

  my $user_id = $c->user()->get_object()->get_sp_person_id();
  open(my $F, "<", $tempfile) || die "Can't open file ".$self->filename();
  binmode $F;
  my $md5 = Digest::MD5->new();
  $md5->addfile($F);
  close($F);

  my $project = $trial_layout->get_project;

  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $user_name = $c->user()->get_object()->get_username();
  my $user_string = $user_name.'_'.$user_id;
  my $subdirectory_name = "tablet_field_layout";
  my $archived_file_name = catfile($user_string, $subdirectory_name,$timestamp."_".$project->name.".xls");
  my $archive_path = $c->config->{archive_path};
  my $file_destination =  catfile($archive_path, $archived_file_name);

  if (!-d $archive_path) {
    mkdir $archive_path;
  }

  if (! -d catfile($archive_path, $user_string)) { 
      mkdir (catfile($archive_path, $user_string));
  }

  if (! -d catfile($archive_path, $user_string,$subdirectory_name)) { 
      mkdir (catfile($archive_path, $user_string, $subdirectory_name));
  }



  my $md_row = $metadata_schema->resultset("MdMetadata")->create({
								  create_person_id => $user_id,
								 });
  $md_row->insert();
  my $file_row = $metadata_schema->resultset("MdFiles")->create({
								     basename => basename($file_destination),
								     dirname => dirname($file_destination),
								     filetype => 'tablet field layout xls',
								     md5checksum => $md5->digest(),
								     metadata_id => $md_row->metadata_id(),
								    });
  $file_row->insert();

  my $field_layout_cvterm = $schema->resultset('Cv::Cvterm')
    ->create_with({
		   name   => 'field layout',
		   cv     => 'experiment type',
		   db     => 'null',
		   dbxref => 'field layout',
		  });


  my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->find({
									       'nd_experiment_projects.project_id' => $project->project_id,
									       type_id => $field_layout_cvterm->cvterm_id(),
									      },
									      {
									       join => 'nd_experiment_projects',
									      });


  my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
										    nd_experiment_id => $experiment->nd_experiment_id(),
										    file_id => $file_row->file_id(),
										   });

  $experiment_files->insert();


  move($tempfile,$file_destination);
  unlink $tempfile;

  $c->stash->{rest} = {
		       success => "1",
		       result => $file_row->file_id,
		       file => "$file_destination",
		      };
####put all of the above in a sub

}

sub create_trait_file_for_field_book : Path('/ajax/fieldbook/traitfile/create') : ActionClass('REST') { }

sub create_trait_file_for_field_book_POST : Args(0) {
  my ($self, $c) = @_;
  my @trait_list;
  print STDERR "\n\n\n creating trait file\n\n";
  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to create a field book" };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to create a field book." };
    return;
  }


  if ($c->req->param('trait_list')) {
    @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
  }
  my $trait_file_name='testing';


  my $user_id = $c->user()->get_object()->get_sp_person_id();
  my $user_name = $c->user()->get_object()->get_username();
  my $user_string = $user_name.'_'.$user_id;
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $subdirectory_name = "tablet_trait_files";
  my $archived_file_name = catfile($user_string, $subdirectory_name,$timestamp."_".$trait_file_name.".trt");
  my $archive_path = $c->config->{archive_path};
  my $file_destination =  catfile($archive_path, $archived_file_name);


  if (!-d $archive_path) {
    mkdir $archive_path;
  }

  if (! -d catfile($archive_path, $user_string)) { 
      mkdir (catfile($archive_path, $user_string));
  }

  if (! -d catfile($archive_path, $user_string,$subdirectory_name)) { 
      mkdir (catfile($archive_path, $user_string, $subdirectory_name));
  }


  open FILE, ">$file_destination" or die $!;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  print FILE "trait,format,defaultValue,minimum,maximum,details,categories,isVisible,realPosition\n";
  my $order = 1;
  foreach my $trait (@trait_list) {
    #my $trait_desctiption = $schema;
    my ($db_name, $accession) = split (/:/, $trait);
    my $db = $schema->resultset("General::Db")->search(
						       {
							'me.name' => $db_name, } );

    print STDERR " ** store: found db $db_name , accession = $accession \n";
    if ($db) {
      my $dbxref = $db->search_related("dbxrefs", { accession => $accession, });
      if ($dbxref) {
	my $cvterm = $dbxref->search_related("cvterm")->single;
	my $trait_name = $cvterm->name;
	print FILE "$trait,text,,,,$trait_name,,TRUE,$order\n";
      }
    }
    $order++;
    print STDERR "trait: $trait\n\n"
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
								     md5checksum => $md5->digest(),
								     metadata_id => $md_row->metadata_id(),
								    });
  $file_row->insert();






  $c->stash->{rest} = {
		       success => "1",
		      };
}


sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    my @list;
    foreach my $list_item_array_ref (@array_of_list_items) {
      my @list_item_array = @{$list_item_array_ref};
      push (@list,$list_item_array[1]);
    }
    return \@list;
  }
  else {
    return;
  }
}



1;
