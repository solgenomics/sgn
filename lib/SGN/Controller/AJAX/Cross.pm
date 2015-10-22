
=head1 NAME

SGN::Controller::AJAX::Cross - a REST controller class to provide the
functions for adding crosses

=head1 DESCRIPTION

Add a new cross or upload a file containing crosses to add

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>

=cut

package SGN::Controller::AJAX::Cross;

use Moose;
use Try::Tiny;
use DateTime;
use Data::Dumper;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use List::MoreUtils qw /any /;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::UploadFile;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddProgeny;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Pedigree::ParseUpload;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub upload_cross_file : Path('/ajax/cross/upload_crosses_file') : ActionClass('REST') { }

sub upload_cross_file_POST : Args(0) {
  my ($self, $c) = @_;
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $dbh = $c->dbc->dbh;
  my $program = $c->req->param('cross_upload_breeding_program');
  my $location = $c->req->param('cross_upload_location');
  my $upload = $c->req->upload('crosses_upload_file');
  my $prefix = $c->req->param('upload_prefix');
  my $suffix = $c->req->param('upload_suffix');
  my $uploader = CXGN::UploadFile->new();
  my $parser;
  my $parsed_data;
  my $upload_original_name = $upload->filename();
  my $upload_tempfile = $upload->tempname;
  my $subdirectory = "cross_upload";
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
  my $owner_name;
  my $upload_file_type = "crosses excel";#get from form when more options are added

  if (!$c->user()) { 
    print STDERR "User not logged in... not adding a crosses.\n";
    $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
    return;
  }
  $user_id = $c->user()->get_object()->get_sp_person_id();

  $owner_name = $c->user()->get_object()->get_username();

  ## Store uploaded temporary file in archive
  $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
  $md5 = $uploader->get_md5($archived_filename_with_path);
  if (!$archived_filename_with_path) {
      $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
      return;
  }
  unlink $upload_tempfile;

  $upload_metadata{'archived_file'} = $archived_filename_with_path;
  $upload_metadata{'archived_file_type'}="cross upload file";
  $upload_metadata{'user_id'}=$user_id;
  $upload_metadata{'date'}="$timestamp";

  #parse uploaded file with appropriate plugin
  $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
  $parser->load_plugin('CrossesExcelFormat');
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

  my $cross_add = CXGN::Pedigree::AddCrosses
    ->new({
	   chado_schema => $chado_schema,
	   phenome_schema => $phenome_schema,
	   metadata_schema => $metadata_schema,
	   dbh => $dbh,
	   location => $location,
	   program => $program,
	   crosses =>  $parsed_data->{crosses},
	   owner_name => $owner_name,
	  });

  #validate the crosses
  if (!$cross_add->validate_crosses()){
    $c->stash->{rest} = {error_string => "Error validating crosses",};
    return;
  }

  #add the crosses
  if (!$cross_add->add_crosses()){
    $c->stash->{rest} = {error_string => "Error adding crosses",};
    return;
  }

  #add the progeny
  foreach my $cross_name_key (keys %{$parsed_data->{progeny}}){
    my $progeny_number = $parsed_data->{progeny}->{$cross_name_key};
    my $progeny_increment = 1;
    my @progeny_names;

    #create array of progeny names to add for this cross
    while ($progeny_increment < $progeny_number + 1) {
      $progeny_increment = sprintf "%03d", $progeny_increment;
      my $stock_name = $cross_name_key.$prefix.$progeny_increment.$suffix;
      push @progeny_names, $stock_name;
      $progeny_increment++;
    }

    #add array of progeny to the cross
    my $progeny_add = CXGN::Pedigree::AddProgeny
      ->new({
	     chado_schema => $chado_schema,
	     phenome_schema => $phenome_schema,
	     dbh => $dbh,
	     cross_name => $cross_name_key,
	     progeny_names => \@progeny_names,
	     owner_name => $owner_name,
	    });
    if (!$progeny_add->add_progeny()){
      $c->stash->{rest} = {error_string => "Error adding progeny",};
      #should delete crosses and other progeny if add progeny fails?
      return;
    }
  }

  #add the number of flowers to crosses
  foreach my $cross_name_key (keys %{$parsed_data->{flowers}}) {
    my $number_of_flowers = $parsed_data->{flowers}->{$cross_name_key};
    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name_key} );
    $cross_add_info->set_number_of_flowers($number_of_flowers);
    $cross_add_info->add_info();
  }

  #add the number of seeds to crosses
  foreach my $cross_name_key (keys %{$parsed_data->{seeds}}) {
    my $number_of_seeds = $parsed_data->{seeds}->{$cross_name_key};
    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name_key} );
    $cross_add_info->set_number_of_seeds($number_of_seeds);
    $cross_add_info->add_info();
  }

  $c->stash->{rest} = {success => "1",};
}


sub add_cross : Local : ActionClass('REST') { }

sub add_cross_POST :Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $cross_name = $c->req->param('cross_name');
    my $cross_type = $c->req->param('cross_type');
    my $program = $c->req->param('program');
    my $location = $c->req->param('location');
    my $maternal = $c->req->param('maternal_parent');
    my $paternal = $c->req->param('paternal_parent');
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $number_of_flowers = $c->req->param('number_of_flowers');
    my $number_of_seeds = $c->req->param('number_of_seeds');
    my $visible_to_role = $c->req->param('visible_to_role');
    my $cross_add;
    my $progeny_add;
    my @progeny_names;
    my @array_of_pedigree_objects;
    my $progeny_increment = 1;
    my $paternal_parent_not_required;
    my $number_of_flowers_cvterm;
    my $number_of_seeds_cvterm;
    my $owner_name;

    if ($cross_type eq "open" || $cross_type eq "bulk_open") {
      $paternal_parent_not_required = 1;
    }

    print STDERR "Adding Cross... Maternal: $maternal Paternal: $paternal Cross Type: $cross_type\n";

    if (!$c->user()) { 
	print STDERR "User not logged in... not adding a cross.\n";
	$c->stash->{rest} = {error => "You need to be logged in to add a cross." };
	return;
    }

    $owner_name = $c->user()->get_object()->get_username();

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	print STDERR "User does not have sufficient privileges.\n";
	$c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
	return;
    }

    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 999; #higher numbers break cross name convention
    if ($progeny_number) {
      if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number) or ($progeny_number < 1)) {
	$c->stash->{rest} = {error =>  "progeny number exceeds the maximum of $maximum_progeny_number or is invalid." };
	return;
      }
    }

    #check that maternal name is not blank
    if ($maternal eq "") {
      $c->stash->{rest} = {error =>  "maternal parent name cannot be blank." };
      return;
    }

    #if required, check that paternal parent name is not blank;
    if ($paternal eq "" && !$paternal_parent_not_required) {
      $c->stash->{rest} = {error =>  "paternal parent name cannot be blank." };
      return;
    }

    #check that parents exist in the database
    if (! $chado_schema->resultset("Stock::Stock")->find({name=>$maternal,})){
      $c->stash->{rest} = {error =>  "maternal parent does not exist." };
      return;
    }

    if (!$paternal_parent_not_required) {
      if (! $chado_schema->resultset("Stock::Stock")->find({name=>$paternal,})){
	$c->stash->{rest} = {error =>  "paternal parent does not exist." };
	return;
      }
    }

    #check that cross name does not already exist
    if ($chado_schema->resultset("Stock::Stock")->find({name=>$cross_name})){
      $c->stash->{rest} = {error =>  "cross name already exists." };
      return;
    }

    #check that progeny do not already exist
    if ($chado_schema->resultset("Stock::Stock")->find({name=>$cross_name.$prefix.'001'.$suffix,})){
      $c->stash->{rest} = {error =>  "progeny already exist." };
      return;
    }

    #objects to store cross information
    my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type);
    my $female_individual = Bio::GeneticRelationships::Individual->new(name => $maternal);
    $cross_to_add->set_female_parent($female_individual);

    if (!$paternal_parent_not_required){
      my $male_individual = Bio::GeneticRelationships::Individual->new(name => $paternal);
      $cross_to_add->set_male_parent($male_individual);
    }

    
    $cross_to_add->set_cross_type($cross_type);
    $cross_to_add->set_name($cross_name);

    eval { 
	#create array of pedigree objects to add, in this case just one pedigree
	@array_of_pedigree_objects = ($cross_to_add);
	$cross_add = CXGN::Pedigree::AddCrosses
	    ->new({
		chado_schema => $chado_schema,
		phenome_schema => $phenome_schema,
		#metadata_schema => $metadata_schema,
		dbh => $dbh,
		location => $location,
		program => $program,
		crosses =>  \@array_of_pedigree_objects,
		owner_name => $owner_name,
		  });
	
	
	#add the crosses
	$cross_add->add_crosses();
    };
    if ($@) { 
	$c->stash->{rest} = { error => "Error creating the cross: $@" };
	return;
    }
    
    eval {
	#create progeny if specified
	if ($progeny_number) {
	    
	    #create array of progeny names to add for this cross
	    while ($progeny_increment < $progeny_number + 1) {
		$progeny_increment = sprintf "%03d", $progeny_increment;
		my $stock_name = $cross_name.$prefix.$progeny_increment.$suffix;
		push @progeny_names, $stock_name;
		$progeny_increment++;
	    }
	    
	    #add array of progeny to the cross
	    $progeny_add = CXGN::Pedigree::AddProgeny
		->new({
		    chado_schema => $chado_schema,
		    phenome_schema => $phenome_schema,
		    dbh => $dbh,
		    cross_name => $cross_name,
		    progeny_names => \@progeny_names,
		    owner_name => $owner_name,
		      });
	    $progeny_add->add_progeny();
	    
	}
	
	#add number of flowers as an experimentprop if specified
	if ($number_of_flowers) {
	    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name} );
	    $cross_add_info->set_number_of_flowers($number_of_flowers);
	    $cross_add_info->add_info();
	}
	
	#add number of seeds as an experimentprop if specified
	if ($number_of_seeds) {
	    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name} );
	    $cross_add_info->set_number_of_seeds($number_of_seeds);
	    $cross_add_info->add_info();
	}
	
    };
    if ($@) {
	$c->stash->{rest} = { error => "An error occurred: $@"};
	return;
    }

    $c->stash->{rest} = { error => '', };
  }

sub get_cross_relationships :Path('/cross/ajax/relationships') :Args(1) { 
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross = $schema->resultset("Stock::Stock")->find( { stock_id => $cross_id });

    if ($cross && $cross->type()->name() ne "cross") { 
	$c->stash->{rest} = { error => 'This entry is not of type cross and cannot be displayed using this page.' };
	return;
    }

    my $crs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $cross_id } );

    my $maternal_parent = "";
    my $paternal_parent = "";
    my @progeny = ();

    foreach my $child ($crs->all()) { 
	if ($child->type->name() eq "female_parent") { 
	    $maternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
	}
	if ($child->type->name() eq "male_parent") { 
	    $paternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
	}
	if ($child->type->name() eq "member_of") { 
	    push @progeny, [ $child->subject->name, $child->subject->stock_id() ];
	}	
    }

    $c->stash->{rest} = { maternal_parent => $maternal_parent,
			  paternal_parent => $paternal_parent,
			  progeny => \@progeny,
    };
}


sub get_cross_properties :Path('/cross/ajax/properties') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my $rs = $schema->resultset("NaturalDiversity::NdExperimentprop")->search( { 'nd_experiment_stocks.stock_id' => $cross_id }, { join => { 'nd_experiment' =>  'nd_experiment_stocks' }});

    my $props = {};

    print STDERR "PROPS LEN ".$rs->count()."\n";

    while (my $prop = $rs->next()) { 
	push @{$props->{$prop->type->name()}}, [ $prop->get_column('value'), $prop->get_column('nd_experimentprop_id') ];
    }

    print STDERR Dumper($props);
    $c->stash->{rest} = { props => $props };


}

sub save_property_check :Path('/cross/property/check') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $type = $c->req->param("type");
    my $value = $c->req->param("value");


    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $type_row = $schema->resultset('Cv::Cvterm')->find( { name => $type } );
    
    if (! $type_row) { 
	$c->stash->{rest} = { error => "The type '$type' does not exist in the database" };
	return;
    }
    
    my $type_id = $type_row->cvterm_id();

    my %suggested_values = (
	cross_type =>  { 'biparental'=>1, 'self'=>1, 'open pollinated'=>1, 'bulk'=>1, 'bulk selfed'=>1, 'bulk and open pollinated'=>1, 'doubled haplotype'=>1 },
	number_of_flowers => '\d+',
	number_of_seeds => '\d+',
	date => '\d{4}\\/\d{2}\\/\d{2}',
	time => '\d+\:\d+',
	operator => '.*',
	cross_name => '.*',
	);

    my %example_values = ( 
	date => '2014/03/29',
	time => '10:00',
	number_of_flowers => 23,
	number_of_seeds => 42,
	operator => 'Alfonso',
	cross_name => 'nextgen_cross',
	);

    if (ref($suggested_values{$type})) { 
	if (!exists($suggested_values{$type}->{$value})) { # don't make this case insensitive!
	    $c->stash->{rest} =  { message => 'The provided value is not in the suggested list of terms. This could affect downstream data processing.' };
	    return;
	}
    }
    else { 
	if ($value !~ m/^$suggested_values{$type}$/) { 
	    $c->stash->{rest} = { error => 'The provided value is not of the correct type. Format example: "'.$example_values{$type}.'"' };
	    return;
	}
    }
    $c->stash->{rest} = { success => 1 };
}

sub cross_property_save :Path('/cross/property/save') Args(1) { 
    my $self = shift;
    my $c = shift;
    
    if (!$c->user()) { 
	$c->stash->{rest} = { error => "You must be logged in add properties." };
	return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) { 
	$c->stash->{rest} = { error => "You do not have sufficient privileges to add properties." };
	return;
    }

    my $cross_id = $c->req->param("cross_id");
    my $type  = $c->req->param("type");
    my $value    = $c->req->param("value");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $exp_id = $schema->resultset("NaturalDiversity::NdExperiment")->search( { 'nd_experiment_stocks.stock_id' => $cross_id }, { join => 'nd_experiment_stocks' })->first()->get_column('nd_experiment_id');
    
    my $type_id;
    my $type_row = $schema->resultset("Cv::Cvterm")->find( { 'me.name' => $type, 'cv.name' => 'local' }, { join => { 'cv'}});
    if ($type_row) { 
	$type_id = $type_row->cvterm_id();
    }
    else { 
	$c->stash->{rest} = { error => "The type $type does not exist in the database." };
	return;
    }
    
    my $rs = $schema->resultset("NaturalDiversity::NdExperimentprop")->search( { 'nd_experiment_stocks.stock_id' => $cross_id, 'me.type_id' => $type_id }, { join => { 'nd_experiment' => { 'nd_experiment_stocks' }}});

    my $row = $rs->first();
    if (!$row) { 
	$row = $schema->resultset("NaturalDiversity::NdExperimentprop")->create( { 'nd_experiment_stocks.stock_id' => $cross_id, 'me.type_id' => $type_id, 'me.value'=>$value, 'me.nd_experiment_id' => $exp_id }, { join => {'nd_experiment' => {'nd_experiment_stocks' }}});
	$row->insert();
    }
    else { 
	
	$row->set_column( 'value' => $value );
	$row->update();
    }
    
    $c->stash->{rest} = { success => 1 };
}


sub add_more_progeny :Path('/cross/progeny/add') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    if (!$c->user()) { 
	$c->stash->{rest} = { error => "You must be logged in add progeny." };
	return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) { 
	$c->stash->{rest} = { error => "You do not have sufficient privileges to add progeny." };
	return;
    }
    
    my $basename = $c->req->param("basename");
    my $start_number = $c->req->param("start_number");
    my $progeny_count = $c->req->param("progeny_count");
    my $cross_name = $c->req->param("cross_name");

    my @progeny_names = ();
    foreach my $n (1..$progeny_count) { 
	push @progeny_names, $basename. (sprintf "%03d", $n + $start_number -1);
    }

    print STDERR Dumper(\@progeny_names);

    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;

    my $owner_name = $c->user()->get_object()->get_username();
    
    my $progeny_add = CXGN::Pedigree::AddProgeny
	->new({
	    chado_schema => $chado_schema,
	    phenome_schema => $phenome_schema,
	    dbh => $dbh,
	    cross_name => $cross_name,
	    progeny_names => \@progeny_names,
	    owner_name => $owner_name,
	      });
    if (!$progeny_add->add_progeny()){
      $c->stash->{rest} = {error_string => "Error adding progeny. Please change the input parameters and try again.",};
      #should delete crosses and other progeny if add progeny fails?
      return;
    }

    $c->stash->{rest} = { success => 1};
    
}



###
1;#
###
