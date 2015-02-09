
=head1 NAME

SGN::Controller::AJAX::Trial - a REST controller class to provide the
backend for adding trials and viewing trials

=head1 DESCRIPTION

Creating, viewing and deleting trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

Deletion by Lukas

=cut

package SGN::Controller::AJAX::Trial;

use Moose;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);
use DateTime;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use List::MoreUtils qw /any /;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use JSON -support_by_pp;
use SGN::View::Trial qw/design_layout_view design_info_view/;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;
use CXGN::UploadFile;
use CXGN::Trial::ParseUpload;
use CXGN::List::Transform;

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

sub get_trial_layout : Path('/ajax/trial/layout') : ActionClass('REST') { }

sub get_trial_layout_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $project;
  print STDERR "\n\ntrial layout controller\n";
  my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, project => $project} );

  #my $trial_id = $c->req->parm('trial_id');
  # my $project = $schema->resultset('Project::Project')->find(
  # 							     {
  # 							      id => $trial_id,
  # 							     }
  # 							    );
}


sub generate_experimental_design : Path('/ajax/trial/generate_experimental_design') : ActionClass('REST') { }

sub generate_experimental_design_POST : Args(0) {
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
#       my $data = $self->transform_stock_list($c, \@raw_stock_names);
#    if (exists($data->{missing}) && ref($data->{missing}) && @{$data->{missing}} >0) { 
#	$c->stash->{rest} = { error => "Some stocks were not found. Please edit the list and try again." };
#	return;
#    }
#    if ($data->{transform} && @{$data->{transform}}>0) { 
#	@stock_names = @{$data->{transform}};
#    }
  }
  my @control_names;
  if ($c->req->param('control_list')) {
    @control_names = @{_parse_list_from_json($c->req->param('control_list'))};
  }

  my $design_type =  $c->req->param('design_type');
  my $rep_count =  $c->req->param('rep_count');
  my $block_number =  $c->req->param('block_number');

  my $row_number = $c->req->param('row_number');
  my $block_row_number=$c->req->param('row_number_per_block');
  my $block_col_number=$c->req->param('col_number_per_block');
  my $col_number =$c->req->param('col_number'); 

  my $block_size =  $c->req->param('block_size');
  my $max_block_size =  $c->req->param('max_block_size');
  my $plot_prefix =  $c->req->param('plot_prefix');
  my $start_number =  $c->req->param('start_number');
  my $increment =  $c->req->param('increment');
  my $trial_location = $c->req->param('trial_location');
  my $trial_name = $c->req->param('project_name');
  #my $trial_name = "Trial $trial_location $year"; #need to add something to make unique in case of multiple trials in location per year?



   print STDERR join "\n",$design_type;
   print STDERR "\n";
   
   print STDERR join "\n",$block_number;
   print STDERR "\n";

   print STDERR join "\n",$row_number;
   print STDERR "\n";



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
    $c->stash->{rest} = { error => "Trial location not found" };
    return;
  }

  # my $trial_create = CXGN::Trial::TrialCreate->new(chado_schema => $schema);
  # $trial_create->set_trial_year($c->req->param('year'));
  # $trial_create->set_trial_location($c->req->param('trial_location'));
  # if ($trial_create->trial_name_already_exists()) {
  #   $c->stash->{rest} = {error => "Trial name \"".$trial_create->get_trial_name()."\" already exists" };
  #   return;
  # }

  $trial_design->set_trial_name($trial_name);

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
    #$trial_design->set_number_of_blocks(8);
  }
  if($row_number){
      $trial_design->set_number_of_rows($row_number);
      #$trial_design->set_number_of_rows(9);
  }
 if($block_row_number){
      $trial_design->set_block_row_numbers($block_row_number);
      #$trial_design->set_number_of_rows(9);
  }
 if($block_col_number){
      $trial_design->set_block_col_numbers($block_col_number);
      #$trial_design->set_number_of_rows(9);
  }
 if($col_number){
      $trial_design->set_number_of_cols($col_number);
      #$trial_design->set_number_of_rows(9);
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

sub save_experimental_design_POST : Args(0) {
  my ($self, $c) = @_;
  #my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $dbh = $c->dbc->dbh;

  print STDERR "Saving trial... :-)\n";

  #my $trial_create = new CXGN::Trial::TrialCreate(chado_schema => $schema);
  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
    return;
  }
  my $user_id = $c->user()->get_object()->get_sp_person_id();

  my $user_name = $c->user()->get_object()->get_username();

  print STDERR "\nUserName: $user_name\n\n";
  my $error;

  my $design = _parse_design_from_json($c->req->param('design_json'));

  my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $chado_schema,
	   phenome_schema => $phenome_schema,
	   dbh => $dbh,
	   user_name => $user_name,
	   design => $design,
	   program => $c->req->param('breeding_program_name'),
	   trial_year => $c->req->param('year'),
	   trial_description => $c->req->param('project_description'),
	   trial_location => $c->req->param('trial_location'),
	   trial_name => $c->req->param('project_name'),
	   design_type => $c->req->param('design_type'),
	  });

  #$trial_create->set_user($c->user()->id());
  #$trial_create->set_trial_year($c->req->param('year'));
  #$trial_create->set_trial_location($c->req->param('trial_location'));
  #$trial_create->set_trial_description($c->req->param('project_description'));
  #$trial_create->set_design_type($c->req->param('design_type'));
  #$trial_create->set_breeding_program_id($c->req->param('breeding_program_name'));
  #$trial_create->set_design(_parse_design_from_json($c->req->param('design_json')));
  #$trial_create->set_stock_list(_parse_list_from_json($c->req->param('stock_list')));
  # if ($c->req->param('control_list')) {
  #   $trial_create->set_control_list(_parse_list_from_json($c->req->param('control_list')));
  # }
  if ($trial_create->trial_name_already_exists()) {
    $c->stash->{rest} = {error => "Trial name \"".$trial_create->get_trial_name()."\" already exists" };
    return;
  }

  try {
    $trial_create->save_trial();
  } catch {
    $c->stash->{rest} = {error => "Error saving trial in the database $_"};
    print STDERR "ERROR SAVING TRIAL!\n";
    $error = 1;
  };
  if ($error) {return;}
  print STDERR "Trial saved successfully\n";
  $c->stash->{rest} = {success => "1",};
  return;
}

sub verify_stock_list : Path('/ajax/trial/verify_stock_list') : ActionClass('REST') { }

sub verify_stock_list_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my @stock_names;
  my $error;
  my %errors;
  my $error_alert;
  if ($c->req->param('stock_list')) {
    @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
    #my $data = $self->transform_stock_list($c, \@raw_stock_names);
    #if (exists($data->{missing}) && ref($data->{missing}) && @{$data->{missing}} >0) { 
#	$c->stash->{rest} = { error => "Some stocks were not found. Please edit the list and try again." };
#	return;
 #   }
  #  if ($data->{transform} && @{$data->{transform}}>0) { 
#	@stock_names = @{$data->{transform}};
 #   }
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
    return \@array_of_list_items;
  }
  else {
    return;
  }
}

sub _parse_design_from_json {
  my $design_json = shift;
  my $json = new JSON;
  if ($design_json) {
    my $decoded_json = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);
    #my $decoded_json = decode_json($design_json);
    my %design = %{$decoded_json};
    return \%design;
  }
  else {
    return;
  }
}

###################################################################################

sub upload_trial_file : Path('/ajax/trial/upload_trial_file') : ActionClass('REST') { }

sub upload_trial_file_POST : Args(0) {
  my ($self, $c) = @_;
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $dbh = $c->dbc->dbh;
  my $program = $c->req->param('trial_upload_breeding_program');
  my $trial_location = $c->req->param('trial_upload_location');
  my $trial_name = $c->req->param('trial_upload_name');
  my $trial_year = $c->req->param('trial_upload_year');
  my $trial_description = $c->req->param('trial_upload_description');
  my $trial_design_method = $c->req->param('trial_upload_design_method');
  my $upload = $c->req->upload('trial_uploaded_file');
  my $uploader = CXGN::UploadFile->new();
  my $parser;
  my $parsed_data;
  my $upload_original_name = $upload->filename();
  my $upload_tempfile = $upload->tempname;
  my $subdirectory = "trial_upload";
  my $archived_filename_with_path;
  my $md5;
  my $validate_file;
  my $parsed_file;
  my $parse_errors;
  my %parsed_data;
  my %upload_metadata;
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $user_id;
  my $user_name;
  my $error;

  if (!$c->user()) { 
    print STDERR "User not logged in... not adding a crosses.\n";
    $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
    return;
  }

  $user_id = $c->user()->get_object()->get_sp_person_id();

  $user_name = $c->user()->get_object()->get_username();

  ## Store uploaded temporary file in archive
  $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
  $md5 = $uploader->get_md5($archived_filename_with_path);
  if (!$archived_filename_with_path) {
      $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
      return;
  }
  unlink $upload_tempfile;

  $upload_metadata{'archived_file'} = $archived_filename_with_path;
  $upload_metadata{'archived_file_type'}="trial upload file";
  $upload_metadata{'user_id'}=$user_id;
  $upload_metadata{'date'}="$timestamp";

  #parse uploaded file with appropriate plugin
  $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
  $parser->load_plugin('TrialExcelFormat');
  $parsed_data = $parser->parse();

  if (!$parsed_data) {
    my $return_error = '';

    if (! $parser->has_parse_errors() ){
      $return_error = "Could not get parsing errors";
      $c->stash->{rest} = {error_string => $return_error,};
    }

    else {
      $parse_errors = $parser->get_parse_errors();
      foreach my $error_string (@{$parse_errors}){
	$return_error=$return_error.$error_string."<br>";
      }
    }

    $c->stash->{rest} = {error_string => $return_error,};
    return;
  }


  my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $chado_schema,
	   phenome_schema => $phenome_schema,
	   dbh => $dbh,
	   trial_year => $trial_year,
	   trial_description => $trial_description,
	   trial_location => $trial_location,
	   trial_name => $trial_name,
	   user_name => $user_name, #not implemented
	   design_type => $trial_design_method,
	   design => $parsed_data,
	   program => $program,
	   upload_trial_file => $upload,
	  });

#  try {
    $trial_create->save_trial();
 # } catch {
#    $c->stash->{rest} = {error => "Error saving trial in the database $_"};
#    $error = 1;
#  };
  if ($error) {return;}
  $c->stash->{rest} = {success => "1",};
  return;

}




###################################################################################
##remove this soon.  using above instead
sub upload_trial_layout :  Path('/trial/upload_trial_layout') : ActionClass('REST') { }

sub upload_trial_layout_POST : Args(0) {
  my ($self, $c) = @_;
  my @contents;
  my $error = 0;
  my $upload = $c->req->upload('trial_upload_file');
  my $header_line;
  my @header_contents;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  if (!$c->user()) {  #user must be logged in
    $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
    $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
    return;
  }
  if (!$upload) { #upload file required
    $c->stash->{rest} = {error => "File upload failed: no file name received"};
    return;
  }
  try { #get file contents
    @contents = split /\n/, $upload->slurp;
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    $error = 1;
  };
  if ($error) {return;}
  if (@contents < 2) { #upload file must contain at least one line of data plus a header
    $c->stash->{rest} = {error => "File upload failed: contains less than two lines"};
    return;
  }
  $header_line = shift(@contents);
  @header_contents = split /\t/, $header_line;
  try { #verify header contents
  _verify_trial_layout_header(\@header_contents);
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    $error = 1;
  };
  if ($error) {return;}

  #verify location
  if (! $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$c->req->param('add_project_location'),})){
    $c->stash->{rest} = {error => "File upload failed: location not found"};
    return;
  }

  try { #verify contents of file
  _verify_trial_layout_contents($self, $c, \@contents);
  } catch {
    my %error_hash = %{$_};
    #my $error_string = Dumper(%error_hash);
    my $error_string = _formatted_string_from_error_hash(\%error_hash);
    $c->stash->{rest} = {error => "File upload failed: missing or invalid content (see details that follow..)", error_string => "$error_string"};
    $error = 1;
  };
  if ($error) {return;}

  try { #add file contents to the database
    _add_trial_layout_to_database($self,$c,\@contents);
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
  };

  if ($error) {
    return;
  } else {
     $c->stash->{rest} = {success => "1"};
  }
}

sub _add_trial_layout_to_database {
  my $self = shift;
  my $c = shift;
  my $contents_ref = shift;
  my @contents = @{$contents_ref};
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $year = $c->req->param('add_project_year');
  my $location = $c->req->param('add_project_location');
  my $project_name = $c->req->param('add_project_name');
  my $project_description = $c->req->param('add_project_description');
  my $plot_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
		   name   => 'plot',
		   cv     => 'stock type',
		   db     => 'null',
		   dbxref => 'plot',
		  });
  my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")
    ->find_or_create({
		      description => $location, #add this as an option
		     });
  my $organism = $schema->resultset("Organism::Organism")
    ->find_or_create({
		      genus   => 'Manihot',
		      species => 'Manihot esculenta',
		     });

  #this is wrong
  my $plot_exp_cvterm = $schema->resultset('Cv::Cvterm')
    ->create_with({
		   name   => 'plot experiment',
		   cv     => 'experiment type',
		   db     => 'null',
		   dbxref => 'plot experiment',
		  });

  #create project
  my $project = $schema->resultset('Project::Project')
    ->find_or_create({
		      name => $project_name,
		      description => $location,
		     }
		    );

  my $projectprop_year = $project->create_projectprops( { 'project year' => $year,}, {autocreate=>1});
  my $organism_id = $organism->organism_id();

  foreach my $content_line (@contents) {
    my @line_contents = split /\t/, $content_line;
    my $plot_name = $line_contents[0];
    my $block_number = $line_contents[1];
    my $rep_number = $line_contents[2];
    my $stock_name = $line_contents[3];
    my $stock;
    my $stock_rs = $schema->resultset("Stock::Stock")
      ->search({
		-or => [
			'lower(me.uniquename)' => { like => lc($stock_name) },
			-and => [
				 'lower(type.name)'       => { like => '%synonym%' },
				 'lower(stockprops.value)' => { like => lc($stock_name) },
				],
		       ],
	       },
	       {
		join => { 'stockprops' => 'type'} ,
		distinct => 1
	       }
	      );
    if ($stock_rs->count >1 ) {
      die ("multiple stocks found matching $stock_name");
    } elsif ($stock_rs->count == 1) {
      $stock = $stock_rs->first;
    } else {
      die ("no stocks found matching $stock_name");
    }
    my $unique_plot_name = 
      $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;
    my $plot = $schema->resultset("Stock::Stock")
      ->find_or_create({
			organism_id => $stock->organism_id(),
			name       => $unique_plot_name,
			uniquename => $unique_plot_name,
			type_id => $plot_cvterm->cvterm_id,
		       });
    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
      ->create({
                nd_geolocation_id => $geolocation->nd_geolocation_id(),
                type_id => $plot_exp_cvterm->cvterm_id(),
	       });
    #link to the project
    $experiment
      ->find_or_create_related('nd_experiment_projects',{
							 project_id => $project->project_id()
							});
    #link the experiment to the stock
    $experiment
      ->find_or_create_related('nd_experiment_stocks' ,{
							stock_id => $plot->stock_id(),
							type_id  =>  $plot_exp_cvterm->cvterm_id(),
						       });
    }
}

sub _verify_trial_layout_header {
  my $header_content_ref = shift;
  my @header_contents = @{$header_content_ref};
  if ($header_contents[0] ne 'plot_name' ||
      $header_contents[1] ne 'block_number' ||
      $header_contents[2] ne 'rep_number' ||
      $header_contents[3] ne 'stock_name') {
    die ("Wrong column names in header\n");
  }
  if (@header_contents != 4) {
    die ("Wrong number of columns in header\n");
  }
  return;
}

sub _verify_trial_layout_contents {
  my $self = shift;
  my $c = shift;
  my $contents_ref = shift;
  my @contents = @{$contents_ref};
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $year = $c->req->param('add_project_year');
  my $location = $c->req->param('add_project_location');
  my $project_name = $c->req->param('add_project_name');
  my $line_number = 1;
  my %error_hash;
  my %plot_name_errors;
  my %block_number_errors;
  my %rep_number_errors;
  my %stock_name_errors;
  my %column_number_errors;
  foreach my $content_line (@contents) {
    my @line_contents = split /\t/, $content_line;
    if (@line_contents != 4) {
      my $column_count = scalar(@line_contents);
      $column_number_errors{$line_number} = "Line $line_number: wrong number of columns, expected 4, found $column_count";
      $line_number++;
      next;
    }
    my $plot_name = $line_contents[0];
    my $block_number = $line_contents[1];
    my $rep_number = $line_contents[2];
    my $stock_name = $line_contents[3];
    if (!$stock_name) {
      $stock_name_errors{$line_number} = "Line $line_number: stock name is missing";
    } else {
      #make sure stock name exists and returns a unique result
      my $stock_rs = $schema->resultset("Stock::Stock")
	->search({
		  -or => [
			  'lower(me.uniquename)' => { like => lc($stock_name) },
			  -and => [
				   'lower(type.name)'       => { like => '%synonym%' },
				   'lower(stockprops.value)' => { like => lc($stock_name) },
				  ],
			 ],
		 },
		 {
		  join => { 'stockprops' => 'type'} ,
		  distinct => 1
		 }
		);
      if ($stock_rs->count >1 ) {
	my $error_string = "Line $line_number:  multiple accessions found for stock name $stock_name (";
	while ( my $st = $stock_rs->next) {
	  my $error_string .= $st->uniquename.",";
	}
	$stock_name_errors{$line_number} = $error_string;
      } elsif ($stock_rs->count == 1) {
      } else {
	$stock_name_errors{$line_number} = "Line $line_number: stock name $stock_name not found";
      }
    }

    if (!$plot_name) {
      $plot_name_errors{$line_number} = "Line $line_number: plot name is missing";
    } else {
      my $unique_plot_name = $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;
      if ($schema->resultset("Stock::Stock")->find({uniquename=>$unique_plot_name,})) {
	$plot_name_errors{$line_number} = "Line $line_number: plot name $unique_plot_name is not unique";
      }
    }

    #check for valid block number
    if (!$block_number) {
      $block_number_errors{$line_number} = "Line $line_number: block number is missing";
    } else {
      if (!($block_number =~ /^\d+?$/)) {
	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is not an integer";
      } elsif ($block_number < 1 || $block_number > 1000000) {
	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is out of range";
      }
    }

    #check for valid rep number
    if (!$rep_number) {
      $rep_number_errors{$line_number} = "Line $line_number: rep number is missing";
    } else {
      if (!($rep_number =~ /^\d+?$/)) {
	$rep_number_errors{$line_number} = "Line $line_number: rep number $rep_number is not an integer";
      } elsif ($rep_number < 1 || $rep_number > 1000000) {
	$rep_number_errors{$line_number} = "Line $line_number: rep number $block_number is out of range";
      }
    }
    $line_number++;
  }

  if (%plot_name_errors) {$error_hash{'plot_name_errors'}=\%plot_name_errors;}
  if (%block_number_errors) {$error_hash{'block_number_errors'}=\%block_number_errors;}
  if (%rep_number_errors) {$error_hash{'rep_number_errors'}=\%rep_number_errors;}
  if (%stock_name_errors) {$error_hash{'stock_name_errors'}=\%stock_name_errors;}
  if (%column_number_errors) {$error_hash{'column_number_errors'}=\%column_number_errors;}
  if (%error_hash) {
    die (\%error_hash);
  }
  return;
}

sub _formatted_string_from_error_hash {
  my $error_hash_ref = shift;
  my %error_hash = %{$error_hash_ref};
  my $error_string ;
  if ($error_hash{column_number_errors}) {
    $error_string .= "<b>Column number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{column_number_errors}})."<br><br>";
  }
  if ($error_hash{stock_name_errors}) {
    $error_string .= "<b>Stock name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{stock_name_errors}})."<br><br>";
  }
  if ($error_hash{'plot_name_errors'}) {
    $error_string .= "<b>Plot name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'plot_name_errors'}})."<br><br>";
  }
  if ($error_hash{'block_number_errors'}) {
    $error_string .= "<b>Block number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'block_number_errors'}})."<br><br>";
  }
  if ($error_hash{'rep_number_errors'}) {
    $error_string .= "<b>Rep number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'rep_number_errors'}})."<br><br>";
  }
  return $error_string;
}

sub _formatted_string_from_error_hash_by_type {
  my $error_hash_ref = shift;
  my %error_hash = %{$error_hash_ref};
  my $error_string;
  foreach my $key (sort { $a <=> $b} keys %error_hash) {
    $error_string .= $error_hash{$key} . "<br>";
  }
  return $error_string;
}


=head2 delete_trial_by_file

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_trial_by_file : Path('/breeders/trial/delete/file') Args(1) { 
    my $self = shift;
    my $c = shift;
    
    my $file_id = shift;
    
    if (!$c->user()) { 
	$c->stash->{rest} = { error => 'You must be logged in to delete a trial' };
	return;
    }

    if (! ($c->user->check_roles('curator') || $c->user->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to delete a trial.' };
    }

    my $del = CXGN::BreedersToolbox::Delete->new( 
	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
	phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
	);
	
    if ($del->delete_experiments_by_file($c->user->get_object()->get_sp_person_id(), $file_id)) { 
	$c->stash->{rest} = { success => 1 };
    }
    else { 
	$c->stash->{rest} = { error => "The trial information could not be removed from the database." };
    }    
}


=head2 delete_trial_by_trial_id

 Usage:
 Desc:         Deletes plots associated with a phenotyping experiment
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_trial_by_trial_id : Path('/breeders/trial/delete/id') Args(1) { 
    my $self = shift;
    my $c = shift;

    my $trial_id = shift;

    print STDERR "DELETING trial $trial_id\n";

    if (!$c->user()) { 
	$c->stash->{rest} = { error => 'You must be logged in to delete a trial' };
	return;
    }
    
    my $user_id = $c->user->get_object()->get_sp_person_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $breeding_program_rs = $schema->resultset("Cv::Cvterm")->search( { name => "breeding_program" });

    my $breeding_program_id = $breeding_program_rs->first()->cvterm_id();

    my $breeding_program_name = $breeding_program_rs->first()->name();

    my $trial_organization_id = $schema->resultset("Project::Projectprop")->search( 
	{ 
	    project_id => $trial_id, 
	    type_id=>$breeding_program_id 
	});

    if (! ($c->user->check_roles('curator') || ( $c->user->check_roles('submitter') && $c->roles($breeding_program_name) ))) { 
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to delete a trial.' };
    }
    
#    my $del = CXGN::BreedersToolbox::Delete->new( 
#	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
#	phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
#	);

    my $t = CXGN::Trial->new( { trial_id=> $trial_id, bcs_schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $hash = $t->delete_experiments($user_id, $trial_id);

    $c->stash->{rest} = $hash;
}


=head2 delete_phenotype_data_by_trial_id

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_phenotype_data_by_trial_id : Path('/breeders/trial/phenotype/delete/id') Args(1) { 
    my $self = shift;
    my $c = shift;

    my $trial_id = shift;

    print STDERR "DELETING phenotypes of trial $trial_id\n";

    if (!$c->user()) { 
	$c->stash->{rest} = { error => 'You must be logged in to delete a trial' };
	return;
    }
    
    my $user_id = $c->user->get_object()->get_sp_person_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $breeding_program_rs = $schema->resultset("Cv::Cvterm")->search( { name => "breeding_program" });

    my $breeding_program_id = $breeding_program_rs->first()->cvterm_id();

    my $breeding_program_name = $breeding_program_rs->first()->name();

    my $trial_organization_id = $schema->resultset("Project::Projectprop")->search( 
	{ 
	    project_id => $trial_id, 
	    type_id=>$breeding_program_id 
	});

    if (! ($c->user->check_roles('curator') || ( $c->user->check_roles('submitter') && $c->roles($breeding_program_name) ))) { 
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to delete a trial.' };
    }
    
    my $t = CXGN::Trial->new( { trial_id => $trial_id, bcs_schema => $c->dbic_schema("Bio::Chado::Schema") });
    
    my $error = $t->delete_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));

    print STDERR "ERROR DELETING METADATA: $error\n";
    my $error = $t->delete_phenotype_data($trial_id);

    print STDERR "ERROR DELETING PHENOTYPES: $error\n";
    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} = { success => "1" };
    }
}

=head2 delete_trial_layout_by_trial_id

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_trial_layout_by_trial_id : Path('/breeders/trial/layout/delete/id') Args(1) { 
    my $self = shift;
    my $c = shift;

    my $trial_id = shift;

    print STDERR "DELETING trial layout $trial_id\n";

    if (!$c->user()) { 
	$c->stash->{rest} = { error => 'You must be logged in to delete a trial layout' };
	return;
    }
    
    my $user_id = $c->user->get_object()->get_sp_person_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $breeding_program_rs = $schema->resultset("Cv::Cvterm")->search( { name => "breeding_program" });

    my $breeding_program_id = $breeding_program_rs->first()->cvterm_id();

    my $breeding_program_name = $breeding_program_rs->first()->name();

    my $trial_organization_id = $schema->resultset("Project::Projectprop")->search( 
	{ 
	    project_id => $trial_id, 
	    type_id=>$breeding_program_id 
	});

    if (! ($c->user->check_roles('curator') || ( $c->user->check_roles('submitter') && $c->roles($breeding_program_name) ))) { 
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to delete a trial.' };
    }
    
    #my $del = CXGN::BreedersToolbox::Delete->new( 
#	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
#	phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
#	);

    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });
    #my $error =  $del->delete_field_layout_by_trial($trial_id);

    my $error = $t->delete_field_layout();
    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    $c->stash->{rest} = { success => 1 };

}

sub get_trial_description : Path('/ajax/breeders/trial/description/get') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    
    my $trial = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });
    
    print STDERR "TRIAL: ".$trial->get_description()."\n";

    $c->stash->{rest} = { description => $trial->get_description() };
   
}

sub save_trial_description : Path('/ajax/breeders/trial/description/save') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $description = $c->req->param("description");
    
    my $trial = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $breeding_program = $p->get_breeding_programs_by_trial($trial_id);

    if (! ($c->user() &&  ($c->user->check_roles("curator") || $c->user->check_roles($breeding_program)))) { 
	$c->stash->{rest} = { error => "You need to be logged in with sufficient privileges to change the description of a trial." };
	return;
    }
    
    $trial->set_description($description);

    $c->stash->{rest} = { success => 1 };
}

# sub get_trial_type :Path('/ajax/breeders/trial/type') Args(1) { 
#     my $self = shift;
#     my $c = shift;
#     my $trial_id = shift;

#     my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id } );

#     $c->stash->{rest} = { type => $t->get_project_type() };

# }
    




1;
