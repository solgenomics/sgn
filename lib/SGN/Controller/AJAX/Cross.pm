
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
use Time::HiRes qw(time);
use POSIX qw(strftime);
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
use CXGN::Pedigree::AddCrossingtrial;
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
use URI::Encode qw(uri_encode uri_decode);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub upload_cross_file : Path('/ajax/cross/upload_crosses_file') : ActionClass('REST') { }

sub upload_cross_file_POST : Args(0) {
  my ($self, $c) = @_;
  #print STDERR Dumper $c->req->params();
  my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $dbh = $c->dbc->dbh;
  my $crossing_trial_id = $c->req->param('cross_upload_crossing_trial');
  my $location = $c->req->param('cross_upload_location');
  my $upload = $c->req->upload('crosses_upload_file');
  my $prefix = $c->req->param('upload_prefix');
  my $suffix = $c->req->param('upload_suffix');
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
  my $user_role;
  my $user_id;
  my $user_name;
  my $owner_name;
  my $upload_file_type = "crosses excel";#get from form when more options are added
  my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload crosses!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload crosses!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

  my $uploader = CXGN::UploadFile->new({
    tempfile => $upload_tempfile,
    subdirectory => $subdirectory,
    archive_path => $c->config->{archive_path},
    archive_filename => $upload_original_name,
    timestamp => $timestamp,
    user_id => $user_id,
    user_role => $user_role

  });

  ## Store uploaded temporary file in arhive
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

    my $cross_properties_json = $c->config->{cross_properties};
    my @properties = split ',', $cross_properties_json;
    my $cross_properties = \@properties;

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, cross_properties => $cross_properties);
    $parser->load_plugin('CrossesExcelFormat');
    $parsed_data = $parser->parse();
    #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}, missing_plots => $parse_errors->{'missing_plots'}};
        $c->detach();
    }

  my $cross_add = CXGN::Pedigree::AddCrosses
    ->new({
	   chado_schema => $chado_schema,
	   phenome_schema => $phenome_schema,
	   metadata_schema => $metadata_schema,
	   dbh => $dbh,
	   location => $location,
     crossing_trial_id => $crossing_trial_id,
	   crosses =>  $parsed_data->{crosses},
	   owner_name => $user_name
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

    while (my $info_type = shift (@properties)){
        if ($parsed_data->{$info_type}) {
        print STDERR "Handling info type $info_type\n";
            my %info_hash = %{$parsed_data->{$info_type}};
            foreach my $cross_name_key (keys %info_hash) {
                my $value = $info_hash{$cross_name_key};
                my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name_key, key => $info_type, value => $value, } );
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
    my $crossing_trial_id = $c->req->param('crossing_trial_id');
    my $female_plot_id = $c->req->param('female_plot');
    my $male_plot_id = $c->req->param('male_plot');
    #print STDERR "Female Plot=".Dumper($female_plot)."\n";

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
          my $success = $self->add_individual_cross($c, $chado_schema, $polycross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal, $paternal);
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
                my $success = $self->add_individual_cross($c, $chado_schema, $reciprocal_cross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal, $paternal);
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
            my $success = $self->add_individual_cross($c, $chado_schema, $multicross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal, $paternal);
            if (!$success) {
              return;
            }
        }
    }
    else {
        my $maternal = $c->req->param('maternal');
        my $paternal = $c->req->param('paternal');
        my $success = $self->add_individual_cross($c, $chado_schema, $cross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal, $paternal);
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

sub get_cross_parents :Path('/ajax/cross/accession_plot_parents') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $female_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $female_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_plot_of', 'stock_relationship')->cvterm_id();
    my $male_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $male_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_plot_of', 'stock_relationship')->cvterm_id();

    my $q ="SELECT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename, stock3.stock_id, stock3.uniquename, stock4.stock_id, stock4.uniquename, stock_relationship1.value FROM stock
        JOIN stock_relationship AS stock_relationship1 ON (stock.stock_id = stock_relationship1.object_id) and stock_relationship1.type_id = ?
        JOIN stock AS stock1 ON (stock_relationship1.subject_id = stock1.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS stock2 on (stock_relationship2.subject_id = stock2.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship3 ON (stock.stock_id = stock_relationship3.object_id) and stock_relationship3.type_id = ?
        LEFT JOIN stock AS stock3 ON (stock_relationship3.subject_id = stock3.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship4 ON (stock.stock_id = stock_relationship4.object_id) AND stock_relationship4.type_id = ?
        LEFT JOIN stock AS stock4 ON (stock_relationship4.subject_id =stock4.stock_id) WHERE stock.stock_id = ?";


    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_accession_cvterm, $female_plot_cvterm, $male_accession_cvterm, $male_plot_cvterm, $cross_id);

    my @cross_parents = ();
    while(my ($female_accession_id, $female_accession_name, $female_plot_id, $female_plot_name, $male_accession_id, $male_accession_name, $male_plot_id, $male_plot_name, $cross_type) = $h->fetchrow_array()){
        push @cross_parents, [ $cross_type,
            qq{<a href="/stock/$female_accession_id/view">$female_accession_name</a>},
            qq{<a href="/stock/$male_accession_id/view">$male_accession_name</a>},
            qq{<a href="/stock/$female_plot_id/view">$female_plot_name</a>},
            qq{<a href="/stock/$male_plot_id/view">$male_plot_name</a>}];
    }

    $c->stash->{rest} = {data => \@cross_parents}

}



sub get_cross_properties :Path('/ajax/cross/properties') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $cross_info_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_metadata_json', 'stock_property')->cvterm_id();
    my $cross_json_string = $schema->resultset("Stock::Stockprop")->find({stock_id => $cross_id, type_id => $cross_info_cvterm})->value();

#    print STDERR Dumper($cross_json_string);

    my $cross_props_hash ={};
    $cross_props_hash = decode_json $cross_json_string;

#    print STDERR Dumper($cross_props_hash);

    my $cross_properties = $c->config->{cross_properties};
    my @column_order = split ',',$cross_properties;
    my @props;
    my @row;
    foreach my $key (@column_order){
        push @row, $cross_props_hash->{$key};
    }

    push @props,\@row;
    $c->stash->{rest} = {data => \@props};

}


 sub save_property_check :Path('/cross/property/check') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $type = $c->req->param("type");
    my $value = $c->req->param("value");


    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if ($type =~ m/Number/ || $type =~ m/Days/) { $type = 'number';}
    if ($type =~ m/Date/) { $type = 'date';}

    my %suggested_values = (
#  cross_name => '.*',
#	cross_type =>  { 'biparental'=>1, 'self'=>1, 'open'=>1, 'bulk'=>1, 'bulk_self'=>1, 'bulk_open'=>1, 'doubled_haploid'=>1 },
	      number => '\d+',
	      date => '\d{4}\\/\d{2}\\/\d{2}',
	  );

    my %example_values = (
	      date => '2014/03/29',
        number => 20,
#  cross_type => 'biparental',
#	cross_name => 'nextgen_cross',
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
    my $type = $c->req->param("type");
    my $value = $c->req->param("value");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $schema->resultset("Stock::Stock")->find({stock_id => $cross_id})->uniquename();

    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
        chado_schema => $schema,
        cross_name => $cross_name,
        key => $type,
        value => $value
    });
    $cross_add_info->add_info();

    if (!$cross_add_info->add_info()){
        $c->stash->{rest} = {error_string => "Error saving info",};
        return;
    }

    $c->stash->{rest} = { success => 1};
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

sub add_individual_cross {
  my $self = shift;
  my $c = shift;
  my $chado_schema = shift;
  my $cross_name = shift;
  my $cross_type = shift;
  my $crossing_trial_id = shift;
  my $female_plot_id = shift;
  my $female_plot;
  my $male_plot_id = shift;
  my $male_plot;
  my $maternal = shift;
  my $paternal = shift;

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
  my $tag_number = $c->req->param('tag_number');
  my $pollination_date = $c->req->param('pollination_date');
  my $number_of_bags = $c->req->param('bag_number');
  my $number_of_flowers = $c->req->param('flower_number');
  my $number_of_fruits = $c->req->param('fruit_number');
  my $number_of_seeds = $c->req->param('seed_number');
  my $visible_to_role = $c->req->param('visible_to_role');

  #print STDERR Dumper "Adding Cross... Maternal: $maternal Paternal: $paternal Cross Type: $cross_type Number of Flowers: $number_of_flowers";

    if ($female_plot_id){
        my $female_plot_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $female_plot_id});
        $female_plot = $female_plot_rs->name();
    }

    if ($male_plot_id){
        my $male_plot_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $male_plot_id});
        $male_plot = $male_plot_rs->name();
    }


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
  if (! $chado_schema->resultset("Stock::Stock")->find({uniquename=>$maternal,})){
    $c->stash->{rest} = {error =>  "Female parent does not exist." };
    return 0;
  }

  if ($paternal) {
    if (! $chado_schema->resultset("Stock::Stock")->find({uniquename=>$paternal,})){
$c->stash->{rest} = {error =>  "Male parent does not exist." };
return 0;
    }
  }

  #check that cross name does not already exist
  if ($chado_schema->resultset("Stock::Stock")->find({uniquename=>$cross_name})){
    $c->stash->{rest} = {error =>  "cross name already exists." };
    return 0;
  }

  #check that progeny do not already exist
  if ($chado_schema->resultset("Stock::Stock")->find({uniquename=>$cross_name.$prefix.'001'.$suffix,})){
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

    if ($female_plot) {
        my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_plot);
        $cross_to_add->set_female_plot($female_plot_individual);
    }

    if ($male_plot) {
        my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_plot);
        $cross_to_add->set_male_plot($male_plot_individual);
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
  crossing_trial_id => $crossing_trial_id,
  crosses =>  \@array_of_pedigree_objects,
  owner_name => $owner_name,
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

    my @cross_props = (
        ['Pollination Date',$pollination_date],
        ['Number of Flowers',$number_of_flowers],
        ['Number of Fruits',$number_of_fruits],
        ['Number of Seeds',$number_of_seeds]
    );

    foreach (@cross_props){
        if ($_->[1]){
            my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
                chado_schema => $chado_schema,
                cross_name => $cross_name,
                key => $_->[0],
                value => $_->[1]
            });
        $cross_add_info->add_info();
        }
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
    #print STDERR Dumper $data;

    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $location = $t->get_location();
    my $location_name = $location->[1];
    #if ($location_name ne 'Arusha'){
    #    $c->stash->{rest} = { error => "Cross wishlist currently limited to trials in the location(s): Arusha. This is because currently there is only the ODK form for Arusha. In the future there will be others." };
    #    $c->detach();
    #}

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

    my $trial = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout' });
    my $design_layout = $trial->get_design();
    #print STDERR Dumper $design_layout;

    my %block_plot_hash;
    print STDERR "NUM PLOTS:".scalar(keys %$design_layout);
    while ( my ($key,$value) = each %$design_layout){
        $block_plot_hash{$value->{block_number}}->{$value->{plot_number}} = $value;
    }
    #print STDERR Dumper \%block_plot_hash;

    my $cross_wishlist_plot_select_html = '<h1>Select Female <!--and Male -->Plots For Each Desired Cross Below:</h1>';

    foreach my $female_accession_name (sort keys %ordered_data){
        my $decoded_female_accession_name = uri_decode($female_accession_name);
        my $num_seen = 0;
        my $current_males = $ordered_data{$female_accession_name};
        my $current_males_string = join ',', @$current_males;
        my $encoded_males_string = uri_encode($current_males_string);
        $cross_wishlist_plot_select_html .= '<div class="well" id="cross_wishlist_plot_'.$female_accession_name.'_tab" ><h2>Female: '.$decoded_female_accession_name.' Males: '.$current_males_string.'</h2><h3><!--Select All Male Plots <input type="checkbox" name="cross_wishlist_plot_select_all_male" id="cross_wishlist_plot_select_all_male_'.$female_accession_name.'" data-female_accession_name="'.$female_accession_name.'" />   -->Select All Female Plots <input type="checkbox" id="cross_wishlist_plot_select_all_female_'.$female_accession_name.'" name="cross_wishlist_plot_select_all_female" data-female_accession_name="'.$female_accession_name.'" /></h3><table class="table table-bordered table-hover"><thead>';

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
                #if ($female_accession_name eq $accession_name && exists($current_males{$accession_name})){
                #    $cross_wishlist_plot_select_html .= '<td><span class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross:';
                #    my $count = 1;
                #    foreach (@{$ordered_data{$value->{accession_name}}}){
                #        $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                #        $count ++;
                #    }
                #    $cross_wishlist_plot_select_html .= '">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" /><br/><span class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" /></td>';
                #    $num_seen++;
                #}
                if ($decoded_female_accession_name eq $accession_name){
                    $cross_wishlist_plot_select_html .= '<td class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross: '.$current_males_string;
                    #my $count = 1;
                    #foreach (@{$ordered_data{$value->{accession_name}}}){
                    #    $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                    #    $count ++;
                    #}
                    $cross_wishlist_plot_select_html .= '">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" data-female_accession_name="'.$female_accession_name.'" data-male_genotypes_string="'.$encoded_males_string.'" /></td>';
                    $num_seen++;
                }
                #elsif (exists($current_males{$accession_name})){
                #    $cross_wishlist_plot_select_html .= '<td class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" data-female_accession_name="'.$female_accession_name.'" /></td>';
                #    $num_seen++;
                #}
                else {
                    $cross_wishlist_plot_select_html .= '<td title="Not Chosen. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</td>';
                    $num_seen++;
                }
            }
            $cross_wishlist_plot_select_html .= '</tr>'
        }
        $cross_wishlist_plot_select_html .= '</tbody></table></div>';

        #$cross_wishlist_plot_select_html .= '<script>jQuery(document).on("change", "#cross_wishlist_plot_select_all_male_'.$female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_male_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});jQuery(document).on("change", "#cross_wishlist_plot_select_all_female_'.$female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});</script>';
        $cross_wishlist_plot_select_html .= '<script>jQuery(document).on("change", "input[name=\"cross_wishlist_plot_select_all_female\"]", function(){var female_accession = jQuery(this).data("female_accession_name");if(jQuery(this).is(":checked")){jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}else{jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", false);}});}});</script>';

        print STDERR "NUM PLOTS SEEN: $num_seen\n";
    }

    $c->stash->{rest}->{data} = $cross_wishlist_plot_select_html;
}

sub create_cross_wishlist_submit : Path('/ajax/cross/create_cross_wishlist_submit') : ActionClass('REST') { }

sub create_cross_wishlist_submit_POST : Args(0) {
    my ($self, $c) = @_;

    if (!$c->user){
        $c->stash->{rest}->{error} = "You must be logged in to actually create a cross wishlist.";
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $site_name = $c->config->{project_name};

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    #print STDERR Dumper $c->req->params();
    my $data = decode_json $c->req->param('crosses');
    my $trial_id = $c->req->param('trial_id');
    my $ona_form_id = $c->req->param('form_id');
    my $ona_form_name = $c->req->param('form_name');
    my $selected_plot_ids = decode_json $c->req->param('selected_plot_ids');
    my $test_ona_form_name = $c->config->{odk_crossing_data_test_form_name};
    my $separate_crosswishlist_by_location = $c->config->{odk_crossing_data_separate_wishlist_by_location};

    #For test ona forms, the cross wishlists are combined irrespective of location. On non-test forms, the cross wishlists are separated by location
    my $is_test_form;
    if ($ona_form_name eq $test_ona_form_name){
        $is_test_form = 1;
    }
    #print STDERR Dumper $data;
    #print STDERR Dumper $selected_plot_ids;

    my %individual_cross_plot_ids;
    foreach (@$selected_plot_ids){
        if (exists($_->{female_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{female_plot_ids}}, $_->{female_plot_id};
        }
        if (exists($_->{male_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{male_plot_ids}}, $_->{male_plot_id};
        }
        if (exists($_->{male_genotypes_string})){
            my $male_genotypes_string = $_->{male_genotypes_string};
            my @male_genotypes = split ',', $male_genotypes_string;
            foreach my $g (@male_genotypes){
                $individual_cross_plot_ids{$_->{cross_female_accession_name}}->{male_genotypes}->{uri_decode($g)}++;
            }
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
    my $planting_date = $trial->get_planting_date() || " ";
    my $trial_year = $trial->get_year();

    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout' });
    my $design_layout = $trial_layout->get_design();
    #print STDERR Dumper $design_layout;

    my $file_type;
    if ($is_test_form){
        $file_type = 'cross_wishlist_test_'.$ona_form_id;
    } elsif ($separate_crosswishlist_by_location){
        $file_type = 'cross_wishlist_'.$location_name.'_'.$ona_form_id;
    } else {
        $file_type = 'cross_wishlist_'.$ona_form_id;
    }
    my $previously_saved_metadata_id;
    my $previous_wishlist_md_file = $metadata_schema->resultset("MdFiles")->find({filetype=> $file_type});
    my @previous_file_lines;
    my %previous_file_lookup;
    my $old_header_row;
    my @old_header_row_array;
    if ($previous_wishlist_md_file){
        my $previous_file_path = $previous_wishlist_md_file->dirname."/".$previous_wishlist_md_file->basename;
        print STDERR "Previous cross_wishlist $previous_file_path\n";
        open(my $fh, '<', $previous_file_path)
            or die "Could not open file '$previous_file_path' $!";
        $old_header_row = <$fh>;
        @old_header_row_array = split ',', $old_header_row;
        while ( my $row = <$fh> ){
            chomp $row;
            push @previous_file_lines, $row;
            my @previous_file_line_contents = split ',', $row;
            my $previous_female_plot_id = $previous_file_line_contents[0];
            $previous_female_plot_id =~ s/"//g;
            $previous_file_lookup{$previous_female_plot_id} = \@previous_file_line_contents;
        }
        $previously_saved_metadata_id = $previous_wishlist_md_file->comment;
        $previous_wishlist_md_file->delete;
    }
    #print STDERR Dumper \@previous_file_lines;

    my $germplasm_info_file_type;
    if ($is_test_form){
        $germplasm_info_file_type = 'cross_wishlist_germplasm_info_test_'.$ona_form_id;
    } elsif ($separate_crosswishlist_by_location){
        $germplasm_info_file_type = 'cross_wishlist_germplasm_info_'.$location_name.'_'.$ona_form_id;
    } else {
        $germplasm_info_file_type = 'cross_wishlist_germplasm_info_'.$ona_form_id;
    }

    my $previously_saved_germplasm_info_metadata_id;
    my $previous_germplasm_info_md_file = $metadata_schema->resultset("MdFiles")->find({filetype=> $germplasm_info_file_type});
    my @previous_germplasm_info_lines;
    my %seen_info_plots;
    if ($previous_germplasm_info_md_file){
        my $previous_file_path = $previous_germplasm_info_md_file->dirname."/".$previous_germplasm_info_md_file->basename;
        print STDERR "PREVIOUS germplasm_info $previous_file_path\n";
        open(my $fh, '<', $previous_file_path)
            or die "Could not open file '$previous_file_path' $!";
        my $header_row = <$fh>;
        while ( my $row = <$fh> ){
            chomp $row;
            push @previous_germplasm_info_lines, $row;
            my @previous_file_line_contents = split ',', $row;
            my $previous_plot_id = $previous_file_line_contents[1];
            $previous_plot_id =~ s/"//g;
            $seen_info_plots{$previous_plot_id}++;
        }
        $previously_saved_germplasm_info_metadata_id = $previous_germplasm_info_md_file->comment;
        $previous_germplasm_info_md_file->delete;
    }

    my $plot_info_file_header = '"PlotName","PlotID","PlotBlockNumber","PlotNumber","PlotRepNumber","PlotRowNumber","PlotColNumber","PlotTier","PlotIsAControl","PlotSourceSeedlotName","PlotSourceSeedlotTransactionOperator","PlotSourceSeedlotNumSeedPerPlot","TrialYear","TrialName","TrialID","LocationName","LocationID","PlantingDate","AccessionName","AccessionID","AccessionNameAndPlotNumber","AccessionSynonyms","AccessionPedigree","AccessionGenus","AccessionSpecies","AccessionVariety","AccessionDonors","AccessionCountryOfOrigin","AccessionState","AccessionInstituteCode","AccessionInstituteName","AccessionBiologicalStatusOfAccessionCode","AccessionNotes","AccessionNumber","AccessionPUI","AccessionSeedSource","AccessionTypeOfGermplasmStorageCode","AccessionAcquisitionDate","AccessionOrganization","AccessionPopulationName","AccessionProgenyAccessionNames","PlotImageFileNames","AccessionImageFileNames","CrossWishlistTimestamp","CrossWishlistCreatedByUsername"';
    my @plot_info_lines;

    my %plot_id_hash;
    while ( my ($key,$value) = each %$design_layout){
        my $plot_id = $value->{plot_id};
        $plot_id_hash{$plot_id} = $value;

        if (!exists($seen_info_plots{$plot_id})){
            my $plot_name = $value->{plot_name};
            my $plot_id = $value->{plot_id};
            my $accession_name = $value->{accession_name};
            my $accession_id = $value->{accession_id};
            my $plot_number = $value->{plot_number};
            my $block_number = $value->{block_number} || '';
            my $rep_number = $value->{rep_number} || '';
            my $row_number = $value->{row_number} || '';
            my $col_number = $value->{col_number} || '';
            my $is_a_control = $value->{is_a_control} || '';
            my $tier = $row_number && $col_number ? $row_number."/".$col_number : '';
            my $seedlot_name = $value->{seedlot_name} || '';
            my $seedlot_transaction_operator = $value->{seed_transaction_operator} || '';
            my $seedlot_num_seed_per_plot = $value->{num_seed_per_plot} || '';
            my $accession_stock = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$accession_id});
            my $synonyms = join(',',@{$accession_stock->synonyms()});
            my $pedigree = $accession_stock->get_pedigree_string("Parents");
            my $genus = $accession_stock->get_genus;
            my $species = $accession_stock->get_species;
            my $variety = $accession_stock->variety;
            my $donors = encode_json($accession_stock->donors);
            my $countryoforigin = $accession_stock->countryOfOriginCode;
            my $state = $accession_stock->state;
            my $institute_code = $accession_stock->state;
            my $institute_name = $accession_stock->instituteName;
            my $bio = $accession_stock->biologicalStatusOfAccessionCode;
            my $notes = $accession_stock->notes;
            my $accession_number = $accession_stock->accessionNumber;
            my $pui = $accession_stock->germplasmPUI;
            my $seedsource = $accession_stock->germplasmSeedSource;
            my $storage_code = $accession_stock->typeOfGermplasmStorageCode;
            my $acquisition_date = $accession_stock->acquisitionDate;
            my $organization = $accession_stock->organization_name;
            my $population = $accession_stock->population_name || '';
            my $stock_descendant_hash = $accession_stock->get_descendant_hash();
            my $descendants = $stock_descendant_hash->{descendants};
            my @descendents_array;
            while (my($k,$v) = each %$descendants){
                push @descendents_array, $v->{name};
            }
            my $descendents_string = join ',', @descendents_array;
            my $t = time;
            my $entry_timestamp = strftime '%F %T', localtime $t;
            $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
            push @plot_info_lines, '"'.$plot_name.'","'.$plot_id.'","'.$block_number.'","'.$plot_number.'","'.$rep_number.'","'.$row_number.'","'.$col_number.'","'.$tier.'","'.$is_a_control.'","'.$seedlot_name.'","'.$seedlot_transaction_operator.'","'.$seedlot_num_seed_per_plot.'","'.$trial_year.'","'.$trial_name.'","'.$trial_id.'","'.$location_name.'","'.$location_id.'","'.$planting_date.'","'.$accession_name.'","'.$accession_id.'","'.$accession_name.'_'.$plot_number.'","'.$synonyms.'","'.$pedigree.'","'.$genus.'","'.$species.'","'.$variety.'","'.$donors.'","'.$countryoforigin.'","'.$state.'","'.$institute_code.'","'.$institute_name.'","'.$bio.'","'.$notes.'","'.$accession_number.'","'.$pui.'","'.$seedsource.'","'.$storage_code.'","'.$acquisition_date.'","'.$organization.'","'.$population.'","'.$descendents_string.'","NA","NA","'.$entry_timestamp.'","'.$user_name.'"';
            $seen_info_plots{$plot_id}++;
        }
    }

    my $header = '"FemalePlotID","FemalePlotName","FemaleAccessionName","FemaleAccessionId","FemalePlotNumber","FemaleAccessionNameAndPlotNumber","FemaleBlockNumber","FemaleRepNumber","Timestamp","CrossWishlistCreatedByUsername","NumberMales"';
    my @lines;
    my $max_male_num = 0;
    foreach my $female_id (keys %individual_cross_plot_ids){
        my $male_ids = $ordered_data{$female_id};
        my $female_plot_ids = $individual_cross_plot_ids{$female_id}->{female_plot_ids};
        #my $male_plot_ids = $individual_cross_plot_ids{$female_id}->{male_plot_ids};
        #my %allowed_male_plot_ids = map {$_=>1} @$male_plot_ids;
        my %allowed_male_genotypes = %{$individual_cross_plot_ids{$female_id}->{male_genotypes}};
        #print STDERR Dumper $female_plots;
        #print STDERR Dumper $male_ids;
        foreach my $female_plot_id (@$female_plot_ids){
            my $num_males = 0;
            if ($previous_file_lookup{$female_plot_id}){
                $num_males = $previous_file_lookup{$female_plot_id}->[10];
                $num_males =~ s/"//g;
                my %seen_males_ids;
                foreach my $i (11..scalar(@{$previous_file_lookup{$female_plot_id}})-1){
                    my $previous_male_id = $previous_file_lookup{$female_plot_id}->[$i];
                    $previous_male_id =~ s/"//g;
                    $seen_males_ids{$previous_male_id}++;
                }
                foreach my $male_id (@$male_ids){
                    if (!$seen_males_ids{$male_id}){
                        push @{$previous_file_lookup{$female_plot_id}}, '"'.$male_id.'"';
                        $num_males++;
                    }
                }
                $previous_file_lookup{$female_plot_id}->[10] = '"'.$num_males.'"';
            } else {
                my $female = $plot_id_hash{$female_plot_id};
                $num_males = 0;
                my $plot_name = $female->{plot_name};
                my $plot_id = $female->{plot_id};
                my $accession_name = $female->{accession_name};
                my $accession_id = $female->{accession_id};
                my $plot_number = $female->{plot_number};
                my $block_number = $female->{block_number} || '';
                my $rep_number = $female->{rep_number} || '';
                my $t = time;
                my $entry_timestamp = strftime '%F %T', localtime $t;
                $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
                my $line = '"'.$plot_id.'","'.$plot_name.'","'.$accession_name.'","'.$accession_id.'","'.$plot_number.'","'.$accession_name.'_'.$plot_number.'","'.$block_number.'","'.$rep_number.'","'.$entry_timestamp.'","'.$user_name.'","';

                my @male_segments;
                foreach my $male_id (@$male_ids){
                    push @male_segments, ',"'.$male_id.'"';
                    $num_males++;
                }
                $line .= $num_males.'"';
                foreach (@male_segments){
                    $line .= $_;
                }
                push @lines, $line;
            }
            if ($num_males > $max_male_num){
                $max_male_num = $num_males;
            }
        }
    }
    for (1 .. $max_male_num){
        $header .= ',"MaleAccessionName'.$_.'"';
    }

    my %priority_order_hash;
    foreach (@$data){
        push @{$priority_order_hash{$_->{priority}}}, [$_->{female_id}, $_->{male_id}];
    }
    my @new_header_row = split ',', $header;
    #print STDERR Dumper \%priority_order_hash;
    #print STDERR Dumper \@lines;
    #print STDERR Dumper \@plot_info_lines;

    if (scalar(@old_header_row_array)>scalar(@new_header_row)){
        chomp $old_header_row;
        $header = $old_header_row;
    }

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
                print $F1 uri_decode($_->[0])."\t".$_->[1]."\t".$p."\n";
            }
        }
    close($F1);
    print STDERR Dumper $file_path1;
    #print STDERR Dumper $uri1;
    my $urlencoded_filename1 = $urlencode{$uri1};
    #print STDERR Dumper $urlencoded_filename1;
    #$c->stash->{rest}->{filename} = $urlencoded_filename1;

    my ($file_path2, $uri2) = $c->tempfile( TEMPLATE => "download/cross_wishlist_XXXXX");
    $file_path2 .= '.csv';
    $uri2 .= '.csv';
    open(my $F, ">", $file_path2) || die "Can't open file ".$file_path2;
        print $F $header."\n";
        foreach (values %previous_file_lookup){
            my $line_string = join ',', @$_;
            print $F $line_string."\n";
        }
        foreach (@lines){
            print $F $_."\n";
        }
    close($F);
    print STDERR Dumper $file_path2;
    #print STDERR Dumper $uri2;
    my $urlencoded_filename2 = $urlencode{$uri2};
    #print STDERR Dumper $urlencoded_filename2;
    #$c->stash->{rest}->{filename} = $urlencoded_filename2;

    my $archive_name;
    if ($is_test_form){
        $archive_name = 'cross_wishlist_test.csv';
    } elsif ($separate_crosswishlist_by_location){
        $archive_name = 'cross_wishlist_'.$location_name.'.csv';
    } else {
        $archive_name = 'cross_wishlist_'.$site_name.'.csv';
    }

    my $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path2,
       subdirectory => 'cross_wishlist_'.$site_name.'_'.$ona_form_id,
       archive_path => $c->config->{archive_path},
       archive_filename => $archive_name,
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user()->roles,
    });
    my $uploaded_file = $uploader->archive();
    my $md5 = $uploader->get_md5($uploaded_file);

    my ($file_path3, $uri3) = $c->tempfile( TEMPLATE => "download/cross_wishlist_accession_info_XXXXX");
    $file_path3 .= '.csv';
    $uri3 .= '.csv';
    open(my $F3, ">", $file_path3) || die "Can't open file ".$file_path3;
        print $F3 $plot_info_file_header."\n";
        foreach (@previous_germplasm_info_lines){
            print $F3 $_."\n";
        }
        foreach (@plot_info_lines){
            print $F3 $_."\n";
        }
    close($F3);
    print STDERR Dumper $file_path3;
    #print STDERR Dumper $uri3;
    my $urlencoded_filename3 = $urlencode{$uri3};
    #print STDERR Dumper $urlencoded_filename3;
    #$c->stash->{rest}->{filename} = $urlencoded_filename3;

    my $germplasm_info_archive_name;
    if ($is_test_form){
        $germplasm_info_archive_name = 'germplasm_info_test.csv';
    } elsif ($separate_crosswishlist_by_location){
        $germplasm_info_archive_name = 'germplasm_info_'.$location_name.'.csv';
    } else {
        $germplasm_info_archive_name = 'germplasm_info_'.$site_name.'.csv';
    }

    $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path3,
       subdirectory => 'cross_wishlist_'.$site_name.'_'.$ona_form_id,
       archive_path => $c->config->{archive_path},
       archive_filename => $germplasm_info_archive_name,
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user()->roles,
    });
    my $germplasm_info_uploaded_file = $uploader->archive();
    my $germplasm_info_md5 = $uploader->get_md5($germplasm_info_uploaded_file);

    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    my $odk_crossing_data_service_url = $c->config->{odk_crossing_data_service_url};

    my $ua = LWP::UserAgent->new;
    $ua->credentials( 'api.ona.io:443', 'DJANGO', $c->config->{odk_crossing_data_service_username}, $c->config->{odk_crossing_data_service_password} );
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
            "xform"=>$ona_form_id,
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
            "xform"=>$ona_form_id,
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

sub add_crossingtrial_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    print STDERR Dumper $c->req->params();
    my $crossingtrial_name = $c->req->param('crossingtrial_name');
    my $breeding_program_id = $c->req->param('crossingtrial_program_id');
    my $location = $c->req->param('crossingtrial_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');
    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
    $geolocation_lookup->set_location_name($location);
    if(!$geolocation_lookup->get_geolocation()){
        $c->stash->{rest}={error => "Location not found"};
        return;
    }

    if (!$c->user()){
        print STDERR "User not logged in... not adding a crossingtrial.\n";
        $c->stash->{rest} = {error => "You need to be logged in to add a crossingtrial."};
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        print STDERR "User does not have sufficient privileges.\n";
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a crossingtrial." };
        return;
    }

    my $error;
    eval{
        my $add_crossingtrial = CXGN::Pedigree::AddCrossingtrial->new({
            chado_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $c->req->param('year'),
            project_description => $c->req->param('project_description'),
            crossingtrial_name => $crossingtrial_name,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id()
        });
        my $store_return = $add_crossingtrial->save_crossingtrial();
        if ($store_return->{error}){
            $error = $store_return->{error};
        }
    };

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };

    if ($error){
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {success => 1};
    }
}


sub upload_progenies : Path('/ajax/cross/upload_progenies') : ActionClass('REST'){ }

sub upload_progenies_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('progenies_upload_file');
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
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
#   my $upload_file_type = "crosses excel";#get from form when more options are added
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload progenies!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload progenies!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

    ## Store uploaded temporary file in arhive
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
    $parser->load_plugin('ProgeniesExcel');
    $parsed_data = $parser->parse();
    #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_crosses => $parse_errors->{'missing_crosses'} };
        $c->detach();
    }

    #add the progeny
    if ($parsed_data){
        my %progeny_hash = %{$parsed_data};
        foreach my $cross_name_key (keys %progeny_hash){
            my $progenies_ref = $progeny_hash{$cross_name_key};
            my @progenies = @{$progenies_ref};

            my $progeny_add = CXGN::Pedigree::AddProgeny->new({
                chado_schema => $chado_schema,
                phenome_schema => $phenome_schema,
                dbh => $dbh,
                cross_name => $cross_name_key,
                progeny_names => \@progenies,
                owner_name => $user_name,
            });
            if (!$progeny_add->add_progeny()){
                $c->stash->{rest} = {error_string => "Error adding progeny",};
                return;
            }
        }
    }

    $c->stash->{rest} = {success => "1",};
}

sub upload_info : Path('/ajax/cross/upload_info') : ActionClass('REST'){ }

sub upload_info_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('crossinfo_upload_file');
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
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload cross info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload cross info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

    ## Store uploaded temporary file in arhive
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

    my $cross_properties_json = $c->config->{cross_properties};
    my @properties = split ',', $cross_properties_json;
    my $cross_properties = \@properties;

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, cross_properties => $cross_properties);
    $parser->load_plugin('CrossInfoExcel');
    $parsed_data = $parser->parse();
    #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_crosses => $parse_errors->{'missing_crosses'} };
        $c->detach();
    }

    while (my $info_type = shift (@properties)){
        if ($parsed_data->{$info_type}) {
            print STDERR "Handling info type $info_type\n";
            my %info_hash = %{$parsed_data->{$info_type}};
            foreach my $cross_name_key (keys %info_hash){
                my $value = $info_hash{$cross_name_key};
                my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
                    chado_schema => $chado_schema,
                    cross_name => $cross_name_key,
                    key => $info_type,
                    value => $value,
                });
                $cross_add_info->add_info();
            }
        }
    }

    $c->stash->{rest} = {success => "1",};
}


###
1;#
###
