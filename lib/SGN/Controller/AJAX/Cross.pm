
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
use CXGN::Pedigree::AddPopulations;
use CXGN::Pedigree::ParseUpload;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use CXGN::Cross;
use JSON;
use Tie::UrlEncoder; our(%urlencode);
use LWP::UserAgent;
use HTML::Entities;

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
  my $breeding_program_id = $c->req->param('cross_upload_breeding_program');
  my $location = $c->req->param('cross_upload_location');
  my $upload = $c->req->upload('crosses_upload_file');
  my $prefix = $c->req->param('upload_prefix');
  my $suffix = $c->req->param('upload_suffix');
  my $folder_name = $c->req->param('upload_folder_name');
  my $folder_id = $c->req->param('upload_folder_id');
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

  if ($folder_name) {
    my $folder = CXGN::Trial::Folder->create({
      bcs_schema => $chado_schema,
	    parent_folder_id => '',
	    name => $folder_name,
	    breeding_program_id => $breeding_program_id,
        folder_for_crosses => 1
    });
    $folder_id = $folder->folder_id();
  }

  my $breeding_program = $chado_schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
  my $program = $breeding_program->name();
  #print STDERR "Breeding program name = $program\n";

  $user_id = $c->user()->get_object()->get_sp_person_id();

  $owner_name = $c->user()->get_object()->get_username();

  my $uploader = CXGN::UploadFile->new({
    tempfile => $upload_tempfile,
    subdirectory => $subdirectory,
    archive_path => $c->config->{archive_path},
    archive_filename => $upload_original_name,
    timestamp => $timestamp,
    user_id => $user_id,
    user_role => $c->user()->roles
  });

  ## Store uploaded temporary file in archive
  $archived_filename_with_path = $uploader->archive();
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
  #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

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
     parent_folder_id => $folder_id
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
  if ($parsed_data->{number_of_progeny}) {
  my %progeny_hash = %{$parsed_data->{number_of_progeny}};
  foreach my $cross_name_key (keys %progeny_hash){
    my $progeny_number = $progeny_hash{$cross_name_key};
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
}

  #add additional cross info to crosses
  my $cv_id = $chado_schema->resultset('Cv::Cv')->search({name => 'nd_experiment_property', })->first()->cv_id();
  my $cross_property_rs = $chado_schema->resultset('Cv::Cvterm')->search({ cv_id => $cv_id, });
  while (my $cross_property_row = $cross_property_rs->next) {
    my $info_type = $cross_property_row->name;
    if ($parsed_data->{$info_type}) {
    print STDERR "Handling info type $info_type\n";
    my %info_hash = %{$parsed_data->{$info_type}};
    foreach my $cross_name_key (keys %info_hash) {
      my $value = $info_hash{$cross_name_key};
      my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name_key, info_type => $info_type, value => $value, } );
      $cross_add_info->add_info();
    }
  }
  }

  $c->stash->{rest} = {success => "1",};
}


sub add_cross : Local : ActionClass('REST') { }

sub add_cross_POST :Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    my $cross_type = $c->req->param('cross_type');
    my $breeding_program_id = $c->req->param('breeding_program_id');
    my $folder_name = $c->req->param('folder_name');
    my $folder_id = $c->req->param('folder_id');
    my $folder;

    if ($folder_name && !$folder_id) {
      eval {
        $folder = CXGN::Trial::Folder->create({
          bcs_schema => $chado_schema,
          parent_folder_id => '',
          name => $folder_name,
          breeding_program_id => $breeding_program_id,
          folder_for_crosses =>1
        });
      };

      if ($@) {
        $c->stash->{rest} = {error => $@ };
        return;
      }

      $folder_id = $folder->folder_id();
    }

    my $breeding_program = $chado_schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
    my $program = $breeding_program->name();

    if (!$c->user()) {
  print STDERR "User not logged in... not adding a cross.\n";
  $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
  return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
  print STDERR "User does not have sufficient privileges.\n";
  $c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
  return;
    }

    if ($cross_type eq "polycross") {
      print STDERR "Handling a polycross\n";
        my @maternal_parents = split (',', $c->req->param('maternal_parents'));
        print STDERR "Maternal parents array:" . @maternal_parents . "\n Maternal parents with ref:" . \@maternal_parents . "\n Maternal parents with dumper:". Dumper(@maternal_parents) . "\n";
        my $paternal = $cross_name . '_parents';
        my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $chado_schema, name => $paternal, members =>  \@maternal_parents} );
        $population_add->add_population();
        $cross_type = 'open';
        print STDERR "Scalar maternatal paretns:" . scalar @maternal_parents;
        for (my $i = 0; $i < scalar @maternal_parents; $i++) {
          my $maternal = $maternal_parents[$i];
          my $polycross_name = $cross_name . '_' . $maternal . '_polycross';
          print STDERR "First polycross to add is $polycross_name with amternal $maternal and paternal $paternal\n";
          my $success = $self->add_individual_cross($c, $chado_schema, $polycross_name, $cross_type, $program, $maternal, $paternal, $folder_id);
          if (!$success) {
            return;
          }
          print STDERR "polycross addition  $polycross_name worked successfully\n";
        }
      }
      elsif ($cross_type eq "reciprocal") {
        $cross_type = 'biparental';
        my @maternal_parents = split (',', $c->req->param('maternal_parents'));
        for (my $i = 0; $i < scalar @maternal_parents; $i++) {
          my $maternal = $maternal_parents[$i];
          for (my $j = 0; $j < scalar @maternal_parents; $j++) {
            my $paternal = $maternal_parents[$j];
            if ($maternal eq $paternal) {
              next;
            }
            my $reciprocal_cross_name = $cross_name . '_' . $maternal . 'x' . $paternal . '_reciprocalcross';
            my $success = $self->add_individual_cross($c, $chado_schema, $reciprocal_cross_name, $cross_type, $program, $maternal, $paternal, $folder_id);
            if (!$success) {
              return;
            }
          }
        }
      }
      elsif ($cross_type eq "multicross") {
        $cross_type = 'biparental';
        my @maternal_parents = split (',', $c->req->param('maternal_parents'));
        my @paternal_parents = split (',', $c->req->param('paternal_parents'));
        for (my $i = 0; $i < scalar @maternal_parents; $i++) {
            my $maternal = $maternal_parents[$i];
            my $paternal = $paternal_parents[$i];
            my $multicross_name = $cross_name . '_' . $maternal . 'x' . $paternal . '_multicross';
            my $success = $self->add_individual_cross($c, $chado_schema, $multicross_name, $cross_type, $program, $maternal, $paternal, $folder_id);
            if (!$success) {
              return;
            }
        }
      }
      else {
        my $maternal = $c->req->param('maternal');
        my $paternal = $c->req->param('paternal');
        my $success = $self->add_individual_cross($c, $chado_schema, $cross_name, $cross_type, $program, $maternal, $paternal, $folder_id);
        if (!$success) {
          return;
        }
      }
    $c->stash->{rest} = {success => "1",};
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

    my $cross_obj = CXGN::Cross->new({bcs_schema=>$schema, cross_stock_id=>$cross_id});
    my ($maternal_parent, $paternal_parent, $progeny) = $cross_obj->get_cross_relationships();

    $c->stash->{rest} = {
        maternal_parent => $maternal_parent,
        paternal_parent => $paternal_parent,
        progeny => $progeny,
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

    #print STDERR Dumper($props);
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

    if ($type =~ m/^number/ || $type =~ m/^days/) { $type = 'number';}
    if ($type =~ m/^date/) { $type = 'date';}

    my %suggested_values = (
  cross_name => '.*',
	cross_type =>  { 'biparental'=>1, 'self'=>1, 'open'=>1, 'bulk'=>1, 'bulk_self'=>1, 'bulk_open'=>1, 'doubled_haploid'=>1 },
	number => '\d+',
	date => '\d{4}\\/\d{2}\\/\d{2}',
	);

    my %example_values = (
	date => '2014/03/29',
  number => 20,
  cross_type => 'biparental',
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
	    $c->stash->{rest} = { error => 'The provided value is not in a valid format. Format example: "'.$example_values{$type}.'"' };
	    return;
	}
    }
    $c->stash->{rest} = { success => 1 };
}

sub cross_property_save :Path('/cross/property/save') Args(1) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to add properties." };
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
    my $type_row = $schema->resultset("Cv::Cvterm")->find( { 'me.name' => $type, 'cv.name' => 'nd_experiment_property' }, { join => { 'cv'}});
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

    #print STDERR Dumper(\@progeny_names);

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

sub get_crosses_with_folders : Path('/ajax/breeders/get_crosses_with_folders') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema  } );

    my $projects = $p->get_breeding_programs();

    my $html = "";
    my $folder_obj = CXGN::Trial::Folder->new( { bcs_schema => $schema, folder_id => @$projects[0]->[0] });

    print STDERR "Starting get crosses at time ".localtime()."\n";
    foreach my $project (@$projects) {
        my %project = ( "id" => $project->[0], "name" => $project->[1]);
        $html .= $folder_obj->get_jstree_html(\%project, $schema, 'breeding_program', 'cross');
    }
    print STDERR "Finished get crosses at time ".localtime()."\n";

    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_crosses_jstree_html.txt";

    my $OUTFILE;
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } $html or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $c->stash->{rest} = { status => 1 };
}

sub get_crosses_with_folders_cached : Path('/ajax/breeders/get_crosses_with_folders_cached') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    my $filename = $dir."/entire_crosses_jstree_html.txt";
    my $html = '';
    open(my $fh, '<', $filename) or die "cannot open file $filename";
    {
        local $/;
        $html = <$fh>;
    }
    close($fh);

    #print STDERR $html;
    $c->stash->{rest} = { html => $html };
}

sub add_individual_cross {
  my $self = shift;
  my $c = shift;
  my $chado_schema = shift;
  my $cross_name = shift;
  my $cross_type = shift;
  my $program = shift;
  my $maternal = shift;
  my $paternal = shift;
  my $folder_id = shift;
  my $owner_name = $c->user()->get_object()->get_username();
  my @progeny_names;
  my $progeny_increment = 1;
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $dbh = $c->dbc->dbh;
  my $location = $c->req->param('location');
  my $prefix = $c->req->param('prefix');
  my $suffix = $c->req->param('suffix');
  my $progeny_number = $c->req->param('progeny_number');
  my $number_of_flowers = $c->req->param('number_of_flowers');
  my $number_of_fruits = $c->req->param('number_of_fruits');
  my $number_of_seeds = $c->req->param('number_of_seeds');
  my $visible_to_role = $c->req->param('visible_to_role');

  print STDERR "Adding Cross... Maternal: $maternal Paternal: $paternal Cross Type: $cross_type\n";

  #check that progeny number is an integer less than maximum allowed
  my $maximum_progeny_number = 999; #higher numbers break cross name convention
  if ($progeny_number) {
    if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number) or ($progeny_number < 1)) {
$c->stash->{rest} = {error =>  "progeny number exceeds the maximum of $maximum_progeny_number or is invalid." };
return 0;
    }
  }

  #check that maternal name is not blank
  if ($maternal eq "") {
    $c->stash->{rest} = {error =>  "Female parent name cannot be blank." };
    return 0;
  }

  #if required, check that paternal parent name is not blank;
  if ($paternal eq "" && ($cross_type ne "open") && ($cross_type ne "bulk_open")) {
    $c->stash->{rest} = {error =>  "Male parent name cannot be blank." };
    return 0;
  }

  #check that parents exist in the database
  if (! $chado_schema->resultset("Stock::Stock")->find({name=>$maternal,})){
    $c->stash->{rest} = {error =>  "Female parent does not exist." };
    return 0;
  }

  if ($paternal) {
    if (! $chado_schema->resultset("Stock::Stock")->find({name=>$paternal,})){
$c->stash->{rest} = {error =>  "Male parent does not exist." };
return 0;
    }
  }

  #check that cross name does not already exist
  if ($chado_schema->resultset("Stock::Stock")->find({name=>$cross_name})){
    $c->stash->{rest} = {error =>  "cross name already exists." };
    return 0;
  }

  #check that progeny do not already exist
  if ($chado_schema->resultset("Stock::Stock")->find({name=>$cross_name.$prefix.'001'.$suffix,})){
    $c->stash->{rest} = {error =>  "progeny already exist." };
    return 0;
  }

  #objects to store cross information
  my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type);
  my $female_individual = Bio::GeneticRelationships::Individual->new(name => $maternal);
  $cross_to_add->set_female_parent($female_individual);

  if ($paternal) {
    my $male_individual = Bio::GeneticRelationships::Individual->new(name => $paternal);
    $cross_to_add->set_male_parent($male_individual);
  }


  $cross_to_add->set_cross_type($cross_type);
  $cross_to_add->set_name($cross_name);

  eval {
#create array of pedigree objects to add, in this case just one pedigree
my @array_of_pedigree_objects = ($cross_to_add);
my $cross_add = CXGN::Pedigree::AddCrosses
    ->new({
  chado_schema => $chado_schema,
  phenome_schema => $phenome_schema,
  dbh => $dbh,
  location => $location,
  program => $program,
  crosses =>  \@array_of_pedigree_objects,
  owner_name => $owner_name,
  parent_folder_id => $folder_id
    });


#add the crosses
$cross_add->add_crosses();
  };
  if ($@) {
$c->stash->{rest} = { error => "Error creating the cross: $@" };
return 0;
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
    my $progeny_add = CXGN::Pedigree::AddProgeny
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

if ($number_of_fruits) {
    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name} );
    $cross_add_info->set_number_of_fruits($number_of_fruits);
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
return 0;
  }
return 1;

}

sub create_cross_wishlist : Path('/ajax/cross/create_cross_wishlist') : ActionClass('REST') { }

sub create_cross_wishlist_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    #print STDERR Dumper $c->req->params();
    my $data = decode_json $c->req->param('crosses');
    my $trial_id = $c->req->param('trial_id');

    my %selected_cross_hash;
    my %selected_females;
    my %selected_males;
    foreach (@$data){
        push @{$selected_cross_hash{$_->{female_id}}->{$_->{priority}}}, $_->{male_id};
        $selected_females{$_->{female_id}}++;
        $selected_males{$_->{male_id}}++;
    }
    #print STDERR Dumper \%selected_cross_hash;

    my %ordered_data;
    foreach my $female_id (keys %selected_cross_hash){
        foreach my $priority (sort keys %{$selected_cross_hash{$female_id}}){
            my $males = $selected_cross_hash{$female_id}->{$priority};
            foreach my $male_id (@$males){
                push @{$ordered_data{$female_id}}, $male_id;
            }
        }
    }
    #print STDERR Dumper \%ordered_data;

    my $trial = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id });
    my $design_layout = $trial->get_design();
    #print STDERR Dumper $design_layout;

    my %accession_plot_hash;
    my %block_plot_hash;
    print STDERR "NUM PLOTS:".scalar(keys %$design_layout);
    while ( my ($key,$value) = each %$design_layout){
        push @{$accession_plot_hash{$value->{accession_name}}}, $value;
        $block_plot_hash{$value->{block_number}}->{$value->{plot_number}} = $value;
    }
    #print STDERR Dumper \%accession_plot_hash;
    #print STDERR Dumper \%block_plot_hash;

    my $cross_wishlist_plot_select_html = '<h1>Select Female and Male Plots For Each Desired Cross Below:</h1>';

    foreach my $female_accession_name (sort keys %ordered_data){
        my $num_seen = 0;
        my $current_males = $ordered_data{$female_accession_name};
        my $current_males_string = join ',', @$current_males;
        my $encoded_female_accession_name = encode_entities($female_accession_name);
        $cross_wishlist_plot_select_html .= '<div class="well" id="cross_wishlist_plot_'.$female_accession_name.'_tab" ><h2>Female: '.$female_accession_name.' Males: '.$current_males_string.'</h2><h3>Select All Male Plots <input type="checkbox" id="cross_wishlist_plot_select_all_male_'.$encoded_female_accession_name.'" data-female_accession_name="'.$female_accession_name.'" />   Select All Female Plots <input type="checkbox" id="cross_wishlist_plot_select_all_female_'.$encoded_female_accession_name.'" data-female_accession_name="'.$female_accession_name.'" /></h3><table class="table table-bordered table-hover"><thead>';

        $cross_wishlist_plot_select_html .= "</thead><tbody>";
        my %current_males = map{$_=>1} @$current_males;
        foreach my $block_number (sort { $a <=> $b } keys %block_plot_hash){
            $cross_wishlist_plot_select_html .= "<tr><td><b>Block $block_number</b></td>";
            my $plot_number_obj = $block_plot_hash{$block_number};
            my @plot_numbers = sort { $a <=> $b } keys %$plot_number_obj;
            for (0 .. scalar(@plot_numbers)-1){
                my $plot_number = $plot_numbers[$_];
                my $value = $plot_number_obj->{$plot_number};
                my $accession_name = $value->{accession_name};
                if ($female_accession_name eq $accession_name && exists($current_males{$accession_name})){
                    $cross_wishlist_plot_select_html .= '<td><span class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross:';
                    my $count = 1;
                    foreach (@{$ordered_data{$value->{accession_name}}}){
                        $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                        $count ++;
                    }
                    $cross_wishlist_plot_select_html .= '">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" /><br/><span class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" /></td>';
                    $num_seen++;
                }
                elsif ($female_accession_name eq $accession_name){
                    $cross_wishlist_plot_select_html .= '<td class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross:';
                    my $count = 1;
                    foreach (@{$ordered_data{$value->{accession_name}}}){
                        $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                        $count ++;
                    }
                    $cross_wishlist_plot_select_html .= '">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" data-female_accession_name="'.$female_accession_name.'" /></td>';
                    $num_seen++;
                }
                elsif (exists($current_males{$accession_name})){
                    $cross_wishlist_plot_select_html .= '<td class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" data-female_accession_name="'.$female_accession_name.'" /></td>';
                    $num_seen++;
                }
                else {
                    $cross_wishlist_plot_select_html .= '<td title="Not Chosen. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</td>';
                    $num_seen++;
                }
            }
            $cross_wishlist_plot_select_html .= '</tr>'
        }
        $cross_wishlist_plot_select_html .= '</tbody></table></div>';

        $cross_wishlist_plot_select_html .= '<script>jQuery(document).on("change", "#cross_wishlist_plot_select_all_male_'.$encoded_female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_male_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});jQuery(document).on("change", "#cross_wishlist_plot_select_all_female_'.$encoded_female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});</script>';

        print STDERR "NUM PLOTS SEEN: $num_seen\n";
    }

    $c->stash->{rest}->{data} = $cross_wishlist_plot_select_html;
}

sub create_cross_wishlist_submit : Path('/ajax/cross/create_cross_wishlist_submit') : ActionClass('REST') { }

sub create_cross_wishlist_submit_POST : Args(0) {
    my ($self, $c) = @_;
    my $time = DateTime->now();

    if (!$c->user){
        $c->stash->{rest}->{error} = "You must be logged in to actually create a cross wishlist.";
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $timestamp = $time->ymd()."_".$time->hms();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    #print STDERR Dumper $c->req->params();
    my $data = decode_json $c->req->param('crosses');
    my $trial_id = $c->req->param('trial_id');
    my $selected_plot_ids = decode_json $c->req->param('selected_plot_ids');

    my %individual_cross_plot_ids;
    foreach (@$selected_plot_ids){
        if (exists($_->{female_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{female_plot_ids}}, $_->{female_plot_id};
        }
        if (exists($_->{male_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{male_plot_ids}}, $_->{male_plot_id};
        }
    }
    #print STDERR Dumper \%individual_cross_plot_ids;

    my %selected_cross_hash;
    my %selected_females;
    my %selected_males;
    foreach (@$data){
        push @{$selected_cross_hash{$_->{female_id}}->{$_->{priority}}}, $_->{male_id};
    }
    #print STDERR Dumper \%selected_cross_hash;

    my %ordered_data;
    foreach my $female_id (keys %selected_cross_hash){
        foreach my $priority (sort keys %{$selected_cross_hash{$female_id}}){
            my $males = $selected_cross_hash{$female_id}->{$priority};
            foreach my $male_id (@$males){
                push @{$ordered_data{$female_id}}, $male_id;
            }
        }
    }
    #print STDERR Dumper \%ordered_data;

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $location = $trial->get_location();
    my $location_name = $location->[1];
    my $location_id = $location->[0];
    my $trial_name = $trial->get_name();
    my $planting_date = $trial->get_planting_date();

    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id });
    my $design_layout = $trial_layout->get_design();
    #print STDERR Dumper $design_layout;

    my %accession_plot_hash;
    my %plot_id_hash;
    while ( my ($key,$value) = each %$design_layout){
        push @{$accession_plot_hash{$value->{accession_name}}}, $value;
        $plot_id_hash{$value->{plot_id}} = $value;
    }
    #print STDERR Dumper \%accession_plot_hash;

    my $plot_info_file_header = '"PlotName","PlotID","TrialName","TrialID","LocationName","LocationID","PlantingDate","AccessionName","AccessionID","AccessionSynonyms","Pedigree","Genus","Species","Variety","Donors","CountryOfOrigin","State","InstituteCode","InstituteName","BiologicalStatusOfAccessionCode","Notes","AccessionNumber","PUI","SeedSource","TypeOfGermplasmStorageCode","AcquisitionDate","Organization","PopulationName","ProgenyAccessionNames","PlotImageFileNames","AccessionImageFileNames"';
    my @plot_info_lines;
    push @plot_info_lines, $plot_info_file_header;

    my $header = '"FemalePlotID","FemalePlotName","FemaleAccessionName","FemaleAccessionId","FemalePlotNumber","FemaleBlockNumber","FemaleRepNumber","NumberMales"';
    my @lines;
    my $max_male_num = 0;
    my %seen_info_plots;
    foreach my $female_id (keys %individual_cross_plot_ids){
        my $male_ids = $ordered_data{$female_id};
        my $female_plot_ids = $individual_cross_plot_ids{$female_id}->{female_plot_ids};
        my $male_plot_ids = $individual_cross_plot_ids{$female_id}->{male_plot_ids};
        my %allowed_male_plot_ids = map {$_=>1} @$male_plot_ids;
        #print STDERR Dumper $female_plots;
        #print STDERR Dumper $male_ids;
        foreach my $female_plot_id (@$female_plot_ids){
            my $female = $plot_id_hash{$female_plot_id};
            my $num_males = 0;
            my $line = '"'.$female->{plot_id}.'","'.$female->{plot_name}.'","'.$female->{accession_name}.'","'.$female->{accession_id}.'","'.$female->{plot_number}.'","'.$female->{block_number}.'","'.$female->{rep_number}.'","';

            if (!exists($seen_info_plots{$female->{plot_id}})){
                my $female_accession_stock = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$female->{accession_id}});
                push @plot_info_lines, '"'.$female->{plot_name}.'","'.$female->{plot_id}.'","'.$trial_name.'","'.$trial_id.'","'.$location_name.'","'.$location_id.'","'.$planting_date.'","'.$female->{accession_name}.'","'.$female->{accession_id}.'","'.join(',',@{$female_accession_stock->synonyms()}).'","'.$female_accession_stock->get_pedigree_string.'","'.$female_accession_stock->get_genus.'","'.$female_accession_stock->get_species.'","'.$female_accession_stock->variety.'","'.encode_json($female_accession_stock->donors).'","'.$female_accession_stock->countryOfOriginCode.'","'.$female_accession_stock->state.'","'.$female_accession_stock->instituteCode.'","'.$female_accession_stock->instituteName.'","'.$female_accession_stock->biologicalStatusOfAccessionCode.'","'.$female_accession_stock->notes.'","'.$female_accession_stock->accessionNumber.'","'.$female_accession_stock->germplasmPUI.'","'.$female_accession_stock->germplasmSeedSource.'","'.$female_accession_stock->typeOfGermplasmStorageCode.'","'.$female_accession_stock->acquisitionDate.'","'.$female_accession_stock->organization_name.'","'.$female_accession_stock->population_name.'","NA","NA","NA"';
                $seen_info_plots{$female->{plot_id}}++;
            }

            my @male_segments;
            foreach my $male_id (@$male_ids){
                my $male_plots = $accession_plot_hash{$male_id};
                foreach my $male (@$male_plots){
                    if (exists($allowed_male_plot_ids{$male->{plot_id}})){
                        push @male_segments, ',"'.$male->{plot_id}.'","'.$male->{plot_name}.'","'.$male->{accession_name}.'","'.$male->{accession_id}.'","'.$male->{plot_number}.'","'.$male->{block_number}.'","'.$male->{rep_number}.'"';

                        if (!exists($seen_info_plots{$male->{plot_id}})){
                            my $male_accession_stock = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$male->{accession_id}});
                            push @plot_info_lines, '"'.$male->{plot_name}.'","'.$male->{plot_id}.'","'.$trial_name.'","'.$trial_id.'","'.$location_name.'","'.$location_id.'","'.$planting_date.'","'.$male->{accession_name}.'","'.$male->{accession_id}.'","'.join(',',@{$male_accession_stock->synonyms()}).'","'.$male_accession_stock->get_pedigree_string.'","'.$male_accession_stock->get_genus.'","'.$male_accession_stock->get_species.'","'.$male_accession_stock->variety.'","'.encode_json($male_accession_stock->donors).'","'.$male_accession_stock->countryOfOriginCode.'","'.$male_accession_stock->state.'","'.$male_accession_stock->instituteCode.'","'.$male_accession_stock->instituteName.'","'.$male_accession_stock->biologicalStatusOfAccessionCode.'","'.$male_accession_stock->notes.'","'.$male_accession_stock->accessionNumber.'","'.$male_accession_stock->germplasmPUI.'","'.$male_accession_stock->germplasmSeedSource.'","'.$male_accession_stock->typeOfGermplasmStorageCode.'","'.$male_accession_stock->acquisitionDate.'","'.$male_accession_stock->organization_name.'","'.$male_accession_stock->population_name.'","NA","NA","NA"';
                            $seen_info_plots{$male->{plot_id}}++;
                        }

                        $num_males++;
                    }
                }
            }
            $line .= $num_males.'"';
            foreach (@male_segments){
                $line .= $_;
            }
            $line .= "\n";
            push @lines, $line;
            if ($num_males > $max_male_num){
                $max_male_num = $num_males;
            }
        }
    }
    for (1 .. $max_male_num){
        $header .= ',"MalePlotID'.$_.'","MalePlotName'.$_.'","MaleAccessionName'.$_.'","MaleAccessionID'.$_.'","MalePlotNumber'.$_.'","MaleBlockNumber'.$_.'","MaleRepNumber'.$_.'"';
    }

    my %priority_order_hash;
    foreach (@$data){
        push @{$priority_order_hash{$_->{priority}}}, [$_->{female_id}, $_->{male_id}];
    }
    #print STDERR Dumper \%priority_order_hash;

    my $dir = $c->tempfiles_subdir('download');
    my ($file_path1, $uri1) = $c->tempfile( TEMPLATE => 'download/cross_wishlist_downloadXXXXX');
    $file_path1 .= '.tsv';
    $uri1 .= '.tsv';
    my @header1 = ('Female Accession', 'Male Accession', 'Priority');
    open(my $F1, ">", $file_path1) || die "Can't open file ".$file_path1;
        print $F1 join "\t", @header1;
        print $F1 "\n";
        foreach my $p (keys %priority_order_hash){
            my $entries = $priority_order_hash{$p};
            foreach (@$entries){
                print $F1 $_->[0]."\t".$_->[1]."\t".$p."\n";
            }
        }
    close($F1);
    #print STDERR Dumper $file_path1;
    #print STDERR Dumper $uri1;
    my $urlencoded_filename1 = $urlencode{$uri1};
    #print STDERR Dumper $urlencoded_filename1;
    #$c->stash->{rest}->{filename} = $urlencoded_filename1;


    my ($file_path2, $uri2) = $c->tempfile( TEMPLATE => "download/cross_wishlist_XXXXX");
    $file_path2 .= '.csv';
    $uri2 .= '.csv';
    open(my $F, ">", $file_path2) || die "Can't open file ".$file_path2;
        print $F $header;
        print $F "\n";
        foreach (@lines){
            print $F $_;
        }
    close($F);
    #print STDERR Dumper $file_path2;
    #print STDERR Dumper $uri2;
    my $urlencoded_filename2 = $urlencode{$uri2};
    #print STDERR Dumper $urlencoded_filename2;
    #$c->stash->{rest}->{filename} = $urlencoded_filename2;

    my $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path2,
       subdirectory => 'cross_wishlist',
       archive_path => $c->config->{archive_path},
       archive_filename => 'cross_wishlist_'.$location_name.'.csv',
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user()->roles,
    });
    my $uploaded_file = $uploader->archive();
    my $md5 = $uploader->get_md5($uploaded_file);

    my $file_type = 'cross_wishlist_'.$location_name;
    my $previously_saved_metadata_id;
    my $previous_wishlist_md_file = $metadata_schema->resultset("MdFiles")->find({filetype=> $file_type});
    if ($previous_wishlist_md_file){
        $previously_saved_metadata_id = $previous_wishlist_md_file->comment;
        $previous_wishlist_md_file->delete;
    }

    my ($file_path3, $uri3) = $c->tempfile( TEMPLATE => "download/cross_wishlist_accession_info_XXXXX");
    $file_path3 .= '.csv';
    $uri3 .= '.csv';
    open(my $F3, ">", $file_path3) || die "Can't open file ".$file_path3;
        foreach (@plot_info_lines){
            print $F3 $_."\n";
        }
    close($F3);
    #print STDERR Dumper $file_path3;
    #print STDERR Dumper $uri3;
    my $urlencoded_filename3 = $urlencode{$uri3};
    #print STDERR Dumper $urlencoded_filename3;
    #$c->stash->{rest}->{filename} = $urlencoded_filename3;

    $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path3,
       subdirectory => 'cross_wishlist',
       archive_path => $c->config->{archive_path},
       archive_filename => 'germplasm_info_'.$location_name.'.csv',
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user()->roles,
    });
    my $germplasm_info_uploaded_file = $uploader->archive();
    my $germplasm_info_md5 = $uploader->get_md5($germplasm_info_uploaded_file);

    my $germplasm_info_file_type = 'cross_wishlist_germplasm_info_'.$location_name;
    my $previously_saved_germplasm_info_metadata_id;
    my $previous_germplasm_info_md_file = $metadata_schema->resultset("MdFiles")->find({filetype=> $germplasm_info_file_type});
    if ($previous_germplasm_info_md_file){
        $previously_saved_germplasm_info_metadata_id = $previous_germplasm_info_md_file->comment;
        $previous_germplasm_info_md_file->delete;
    }

    my $ua = LWP::UserAgent->new;
    $ua->credentials( 'api.ona.io:443', 'DJANGO', $c->config->{ona_username}, $c->config->{ona_password} );
    my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");

    my $server_endpoint = "https://api.ona.io/api/v1/metadata";

    if ($previously_saved_metadata_id){
        my $delete_resp = $ua->delete(
            $server_endpoint."/$previously_saved_metadata_id"
        );
        if ($delete_resp->is_success) {
            print STDERR "Deleted metadata file $previously_saved_metadata_id\n";
        }
        else {
            print STDERR "ERROR: Did not delete metadata file\n";
            #print STDERR Dumper $delete_resp;
        }
    }
    if ($previously_saved_germplasm_info_metadata_id){
        my $delete_resp = $ua->delete(
            $server_endpoint."/$previously_saved_germplasm_info_metadata_id"
        );
        if ($delete_resp->is_success) {
            print STDERR "Deleted metadata file $previously_saved_germplasm_info_metadata_id\n";
        }
        else {
            print STDERR "ERROR: Did not delete metadata file\n";
            #print STDERR Dumper $delete_resp;
        }
    }


    my $resp = $ua->post(
        $server_endpoint,
        Content_Type => 'form-data',
        Content => [
            data_file => [ $uploaded_file, $uploaded_file, Content_Type => 'text/plain', ],
            "xform"=>"215418",
            "data_type"=>"media",
            "data_value"=>$uploaded_file
        ]
    );

    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $message_hash = decode_json $message;
        #print STDERR Dumper $message_hash;
        if ($message_hash->{id}){

            my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
            $md_row->insert();
            my $file_row = $metadata_schema->resultset("MdFiles")
                ->create({
                    basename => basename($uploaded_file),
                    dirname => dirname($uploaded_file),
                    filetype => $file_type,
                    md5checksum => $md5->hexdigest(),
                    metadata_id => $md_row->metadata_id(),
                    comment => $message_hash->{id}
                });
            $file_row->insert();

            $c->stash->{rest}->{success} = 'The cross wishlist is now ready to be used on the ODK tablet application. Files uploaded to ONA here: <a href="'.$message_hash->{media_url}.'">'.$message_hash->{data_value}.'</a> with <a href="'.$message_hash->{url}.'">metadata entry</a>.';
        } else {
            $c->stash->{rest}->{error} = 'The cross wishlist was not posted to ONA. Please try again.';
        }
    } else {
        #print STDERR Dumper $resp;
        $c->stash->{rest}->{error} = "There was an error submitting cross wishlist to ONA. Please try again.";
    }

    my $germplasm_info_resp = $ua->post(
        $server_endpoint,
        Content_Type => 'form-data',
        Content => [
            data_file => [ $germplasm_info_uploaded_file, $germplasm_info_uploaded_file, Content_Type => 'text/plain', ],
            "xform"=>"215418",
            "data_type"=>"media",
            "data_value"=>$germplasm_info_uploaded_file
        ]
    );

    if ($germplasm_info_resp->is_success) {
        my $message = $germplasm_info_resp->decoded_content;
        my $message_hash = decode_json $message;
        #print STDERR Dumper $message_hash;
        if ($message_hash->{id}){

            my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
            $md_row->insert();
            my $file_row = $metadata_schema->resultset("MdFiles")
                ->create({
                    basename => basename($germplasm_info_uploaded_file),
                    dirname => dirname($germplasm_info_uploaded_file),
                    filetype => $germplasm_info_file_type,
                    md5checksum => $germplasm_info_md5->hexdigest(),
                    metadata_id => $md_row->metadata_id(),
                    comment => $message_hash->{id}
                });
            $file_row->insert();

            $c->stash->{rest}->{success} .= 'The germplasm info file is now ready to be used on the ODK tablet application. Files uploaded to ONA here: <a href="'.$message_hash->{media_url}.'">'.$message_hash->{data_value}.'</a> with <a href="'.$message_hash->{url}.'">metadata entry</a>.';
        } else {
            $c->stash->{rest}->{error} .= 'The germplasm info file was not posted to ONA. Please try again.';
        }
    } else {
        #print STDERR Dumper $germplasm_info_resp;
        $c->stash->{rest}->{error} .= "There was an error submitting germplasm info file to ONA. Please try again.";
    }

}

sub list_cross_wishlists : Path('/ajax/cross/list_cross_wishlists') : ActionClass('REST') { }

sub list_cross_wishlists_GET : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $q = "SELECT file_id, basename, dirname, filetype, comment, m.create_date, m.create_person_id, p.first_name, p.last_name FROM metadata.md_files JOIN metadata.md_metadata as m USING(metadata_id) JOIN sgn_people.sp_person as p ON(p.sp_person_id=m.create_person_id) WHERE filetype ilike 'cross_wishlist_%';";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @files;
    while(my ($file_id, $basename, $dirname, $filetype, $comment, $create_date, $sp_person_id, $first_name, $last_name) = $h->fetchrow_array()){
        push @files, [$file_id, $basename, $dirname, $filetype, $comment, $create_date, $sp_person_id, $first_name, $last_name];
    }
    #print STDERR Dumper \@files;
    $c->stash->{rest} = {"success" => 1, "files"=>\@files};
}


sub add_crossingtrial : Path('/ajax/cross/add_crossingtrial') : ActionClass('REST') {}

sub add_crossingtrial_POST :Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $crossingtrial_name = $c->req->param('crossingtrial_name');
    my $breeding_program_id = $c->req->param('breeding_program_id');
    my $location = $c->req->param('location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');
    my $folder_name = $c->req->param('folder_name');
    my $folder_id = $c->req->param('folder_id');
    my $folder;

    if ($folder_name && !$folder_id) {
      eval {
        $folder = CXGN::Trial::Folder->create({
          bcs_schema => $schema,
          parent_folder_id => '',
          name => $folder_name,
          breeding_program_id => $breeding_program_id,
          folder_for_crosses =>1
        });
      };

      if ($@) {
        $c->stash->{rest} = {error => $@ };
        return;
      }

      $folder_id = $folder->folder_id();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
    my $program = $breeding_program->name();

    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
    $geolocation_lookup->set_location_name($location);
    if(!$geolocation_lookup->get_location()){
        $c->stash->{rest}={error => "Location not found"};
        return;
    }

    my $existing_crossingtrial = $schema->resultset("Project::Project")->find({name => $crossingtrial_name});
    if ($existing_crossingtrial){
        $c->stash->{rest} = {error => "That crossing trial name already exists in the database. Please select another name."};
        return;
    }

    if($folder_name){
        my $folder = CXGN::Trial::Folder->create({
          bcs_schema => $schema,
          parent_folder_id => '',
          name => $folder_name,
          breeding_program_id  => $breeding_program_id,
          folder_for_crosses => 1
        });
        $folder_id = $folder->folder_id();
    }

    if (!$c->user()) {
  print STDERR "User not logged in... not adding a crossingtrial.\n";
  $c->stash->{rest} = {error => "You need to be logged in to add a crossingtrial." };
  return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
  print STDERR "User does not have sufficient privileges.\n";
  $c->stash->{rest} = {error =>  "you have insufficient privileges to add a crossingtrial." };
  return;
    }

    my $add_crossingtrial = CXGN::Pedigree::AddCrossingtrial->new({
        chado_schema => $schema,
        dbh => $dbh,
        program => $breeding_program,
        year => $c->req->param('year'),
        project_description => $c->req->param('project_description'),
        location => $location,
        crossingtrial_name => $crossingtrial_name
    });

    if (!$add_crossingtrial) {
          return;
        }
    $c->stash->{rest} = {success => "1",};
  }


###
1;#
###
