
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

  print FILE "trait,format,defaultValue,minimum,maximum,details,categories,isVisible,realPosition\n";
  my $order = 1;
  foreach my $trait (@trait_list) {
    print FILE "$trait,text,,,,,,TRUE,$order\n";
    $order++;
    print STERR "trait: $trait\n\n"
  }


  close FILE;

  $c->stash->{rest} = {
		       success => "1",
		      };
}




sub generate_experimental_design : Path('/ajax/trial/generate_experimental_design') : ActionClass('REST') { }

sub generate_experimental_design_GET : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_design = CXGN::Trial::TrialDesign->new();
  my %design;
  my %design_info;
  my $error;
  my $project_name = $c->req->param('project_name');
  my $project_description = $c->req->param('project_description');
  my $year = $c->req->param('year');
  my @stock_names;
  my $design_layout_view_html;
  my $design_info_view_html;
  if ($c->req->param('stock_list')) {
    @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
  }
  my @control_names;
  if ($c->req->param('control_list')) {
    @control_names = @{_parse_list_from_json($c->req->param('control_list'))};
  }
  my $design_type =  $c->req->param('design_type');
  my $rep_count =  $c->req->param('rep_count');
  my $block_number =  $c->req->param('block_number');
  my $block_size =  $c->req->param('block_size');
  my $max_block_size =  $c->req->param('max_block_size');
  my $plot_prefix =  $c->req->param('plot_prefix');
  my $start_number =  $c->req->param('start_number');
  my $increment =  $c->req->param('increment');
  my $trial_location = $c->req->param('trial_location');
  #my $trial_name = "Trial $trial_location $year"; #need to add something to make unique in case of multiple trials in location per year?

  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
    return;
  }

  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
    $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
    return;
  }

  my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $schema);
  $geolocation_lookup->set_location_name($c->req->param('trial_location'));
  if (!$geolocation_lookup->get_geolocation()){
    $c->stash->{rest} = {error => "Trial location not found"};
    return;
  }

  my $trial_name;
  my $trial_create = CXGN::Trial::TrialCreate->new(schema => $schema);
  $trial_create->set_trial_year($c->req->param('year'));
  $trial_create->set_trial_location($c->req->param('trial_location'));
  if ($trial_create->trial_name_already_exists()) {
    $c->stash->{rest} = {error => "Trial name \"".$trial_create->get_trial_name()."\" already exists" };
    return;
  }

  if (@stock_names) {
    $trial_design->set_stock_list(\@stock_names);
    $design_info{'number_of_stocks'} = scalar(@stock_names);
  } else {
    $c->stash->{rest} = {error => "No list of stocks supplied." };
    return;
  }
  if (@control_names) {
    $trial_design->set_control_list(\@control_names);
    $design_info{'number_of_controls'} = scalar(@control_names);
  }
  if ($start_number) {
    $trial_design->set_plot_start_number($start_number);
  } else {
    $trial_design->set_plot_start_number(1);
  }
  if ($increment) {
    $trial_design->set_plot_number_increment($increment);
  } else {
    $trial_design->set_plot_number_increment(1);
  }
  if ($plot_prefix) {
    $trial_design->set_plot_name_prefix($plot_prefix);
  }
  if ($rep_count) {
    $trial_design->set_number_of_reps($rep_count);
  }
  if ($block_number) {
    $trial_design->set_number_of_blocks($block_number);
  }
  if ($block_size) {
    $trial_design->set_block_size($block_size);
  }
  if ($max_block_size) {
    $trial_design->set_maximum_block_size($max_block_size);
  }
  if ($design_type) {
    $trial_design->set_design_type($design_type);
    $design_info{'design_type'} = $design_type;
  } else {
    $c->stash->{rest} = {error => "No design type supplied." };
    return;
  }
  if (!$trial_design->has_design_type()) {
    $c->stash->{rest} = {error => "Design type not supported." };
    return;
  }
  try {
    $trial_design->calculate_design();
  } catch {
    $c->stash->{rest} = {error => "Could not calculate design: $_"};
    $error=1;
  };
  if ($error) {return;}
  if ($trial_design->get_design()) {
    %design = %{$trial_design->get_design()};
  } else {
    $c->stash->{rest} = {error => "Could not generate design" };
    return;
  }
  $design_layout_view_html = design_layout_view(\%design, \%design_info);
  $design_info_view_html = design_info_view(\%design, \%design_info);
  my $design_json = encode_json(\%design);
  $c->stash->{rest} = {
		       success => "1",
		       design_layout_view_html => $design_layout_view_html,
		       design_info_view_html => $design_info_view_html,
		       design_json => $design_json,
		      };
}

sub save_experimental_design : Path('/ajax/trial/save_experimental_design') : ActionClass('REST') { }

sub save_experimental_design_GET : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_create = new CXGN::Trial::TrialCreate(schema => $schema);
  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
    return;
  }
  my $error;

  $trial_create->set_user($c->user()->id());
  $trial_create->set_trial_year($c->req->param('year'));
  $trial_create->set_trial_location($c->req->param('trial_location'));
  $trial_create->set_trial_description($c->req->param('project_description'));
  $trial_create->set_design_type($c->req->param('design_type'));
  $trial_create->set_design(_parse_design_from_json($c->req->param('design_json')));
  $trial_create->set_stock_list(_parse_list_from_json($c->req->param('stock_list')));
  if ($c->req->param('control_list')) {
    $trial_create->set_control_list(_parse_list_from_json($c->req->param('control_list')));
  }
  if ($trial_create->trial_name_already_exists()) {
    $c->stash->{rest} = {error => "Trial name \"".$trial_create->get_trial_name()."\" already exists" };
    return;
  }

  try {
    $trial_create->save_trial();
  } catch {
    $c->stash->{rest} = {error => "Error saving trial in the database $_"};
    $error = 1;
  };
  if ($error) {return;}
  $c->stash->{rest} = {success => "1",};
  return;
}

sub verify_stock_list : Path('/ajax/trial/verify_stock_list') : ActionClass('REST') { }

sub verify_stock_list_GET : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my @stock_names;
  my $error;
  my %errors;
  my $error_alert;
  if ($c->req->param('stock_list')) {
    @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
  }
  if (!@stock_names) {
    $c->stash->{rest} = {error => "No stock names supplied"};
    return;
  }
  foreach my $stock_name (@stock_names) {

    my $stock;
    my $number_of_stocks_found;
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $stock_lookup->set_stock_name($stock_name);
    $stock = $stock_lookup->get_stock();
    $number_of_stocks_found = $stock_lookup->get_matching_stock_count();
    if ($number_of_stocks_found > 1) {
      $errors{$stock_name} = "Multiple stocks found matching $stock_name\n";
    }
    if (!$number_of_stocks_found) {
      $errors{$stock_name} = "No stocks found matching $stock_name\n";
    }
  }
  if (%errors) {
    foreach my $key (keys %errors) {
      $error_alert .= "Stock $key: ".$errors{$key}."\n";
    }
    $c->stash->{rest} = {error => $error_alert};
  } else {
    $c->stash->{rest} = {
		       success => "1",
		      };
  }
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
