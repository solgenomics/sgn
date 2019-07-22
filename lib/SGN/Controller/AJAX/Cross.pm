
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
use CXGN::Pedigree::AddFamilyNames;
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
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $crossing_trial_id = $c->req->param('cross_upload_crossing_trial');
    my $crosses_simple_upload = $c->req->upload('xls_crosses_simple_file');
    my $crosses_plots_upload = $c->req->upload('xls_crosses_plots_file');
    my $crosses_plants_upload = $c->req->upload('xls_crosses_plants_file');
    my $upload;
    my $upload_type;
    if ($crosses_plots_upload) {
        $upload = $crosses_plots_upload;
        $upload_type = 'CrossesExcelFormat';
        }
    if ($crosses_plants_upload) {
            $upload = $crosses_plants_upload;
            $upload_type = 'CrossesExcelFormat';
            }

    if ($crosses_simple_upload) {
        $upload = $crosses_simple_upload;
        $upload_type = 'CrossesSimpleExcel';
    }

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
    $parser->load_plugin($upload_type);
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

    my $cross_add = CXGN::Pedigree::AddCrosses->new({
        chado_schema => $chado_schema,
        phenome_schema => $phenome_schema,
        metadata_schema => $metadata_schema,
        dbh => $dbh,
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

        foreach my $cross_name_key (keys %progeny_hash) {
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
            my $progeny_add = CXGN::Pedigree::AddProgeny->new ({
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
    my $cross_combination = $c->req->param('cross_combination');
    $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end.

    print STDERR "CROSS COMBINATION=".Dumper($cross_combination)."\n";

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
        my $success = $self->add_individual_cross($c, $chado_schema, $cross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal, $paternal, $cross_combination);
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

sub get_cross_parents :Path('/ajax/cross/accession_plot_plant_parents') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $female_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $female_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_plot_of', 'stock_relationship')->cvterm_id();
    my $male_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $male_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_plot_of', 'stock_relationship')->cvterm_id();
    my $female_plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_plant_of', 'stock_relationship')->cvterm_id();
    my $male_plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_plant_of', 'stock_relationship')->cvterm_id();

    my $q ="SELECT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename, stock3.stock_id, stock3.uniquename, stock4.stock_id, stock4.uniquename, stock5.stock_id, stock5.uniquename, stock6.stock_id, stock6.uniquename, stock_relationship1.value FROM stock
        JOIN stock_relationship AS stock_relationship1 ON (stock.stock_id = stock_relationship1.object_id) and stock_relationship1.type_id = ?
        JOIN stock AS stock1 ON (stock_relationship1.subject_id = stock1.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS stock2 on (stock_relationship2.subject_id = stock2.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship3 ON (stock.stock_id = stock_relationship3.object_id) and stock_relationship3.type_id = ?
        LEFT JOIN stock AS stock3 ON (stock_relationship3.subject_id = stock3.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship4 ON (stock.stock_id = stock_relationship4.object_id) AND stock_relationship4.type_id = ?
        LEFT JOIN stock AS stock4 ON (stock_relationship4.subject_id =stock4.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship5 ON (stock.stock_id = stock_relationship5.object_id) AND stock_relationship5.type_id = ?
        LEFT JOIN stock AS stock5 ON (stock_relationship5.subject_id =stock5.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship6 ON (stock.stock_id = stock_relationship6.object_id) AND stock_relationship6.type_id = ?
        LEFT JOIN stock AS stock6 ON (stock_relationship6.subject_id =stock6.stock_id)

         WHERE stock.stock_id = ?";


    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_accession_cvterm, $female_plot_cvterm, $female_plant_cvterm, $male_accession_cvterm, $male_plot_cvterm, $male_plant_cvterm, $cross_id);

    my @cross_parents = ();
    while(my ($female_accession_id, $female_accession_name, $female_plot_id, $female_plot_name, $female_plant_id, $female_plant_name, $male_accession_id, $male_accession_name, $male_plot_id, $male_plot_name, $male_plant_id, $male_plant_name, $cross_type) = $h->fetchrow_array()){
        push @cross_parents, [ $cross_type,
            qq{<a href="/stock/$female_accession_id/view">$female_accession_name</a>},
            qq{<a href="/stock/$male_accession_id/view">$male_accession_name</a>},
            qq{<a href="/stock/$female_plot_id/view">$female_plot_name</a>},
            qq{<a href="/stock/$male_plot_id/view">$male_plot_name</a>},
            qq{<a href="/stock/$female_plant_id/view">$female_plant_name</a>},
            qq{<a href="/stock/$male_plant_id/view">$male_plant_name</a>}];
    }

    $c->stash->{rest} = {data => \@cross_parents}

}



sub get_cross_properties :Path('/ajax/cross/properties') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $cross_info_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_metadata_json', 'stock_property')->cvterm_id();
    my $cross_info = $schema->resultset("Stock::Stockprop")->find({stock_id => $cross_id, type_id => $cross_info_cvterm});

    my $cross_json_string;
    if($cross_info){
        $cross_json_string = $cross_info->value();
    }

    my $cross_props_hash ={};
    if($cross_json_string){
        $cross_props_hash = decode_json $cross_json_string;
    }

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
    my $cross_combination = shift;

    my $owner_name = $c->user()->get_object()->get_username();
    my @progeny_names;
    my $progeny_increment = 1;
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');

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
    my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type, cross_combination => $cross_combination,);
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
    $cross_to_add->set_cross_combination($cross_combination);

    eval {
        #create array of pedigree objects to add, in this case just one pedigree
        my @array_of_pedigree_objects = ($cross_to_add);
        my $cross_add = CXGN::Pedigree::AddCrosses
        ->new({
            chado_schema => $chado_schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
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
    };

    if ($@) {
        $c->stash->{rest} = { error => "An error occurred: $@"};
        return 0;
    }
    return 1;

}


sub add_crossingtrial : Path('/ajax/cross/add_crossingtrial') : ActionClass('REST') {}

sub add_crossingtrial_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    print STDERR Dumper $c->req->params();
    my $crossingtrial_name = $c->req->param('crossingtrial_name');
    my $breeding_program_name = $c->req->param('crossingtrial_program_name');
    my $location = $c->req->param('crossingtrial_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');

    my $breeding_program_id = $schema->resultset('Project::Project')->find({ name => $breeding_program_name })->project_id();

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


sub upload_family_names : Path('/ajax/cross/upload_family_names') : ActionClass('REST'){ }

sub upload_family_names_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('family_name_upload_file');
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
            $c->stash->{rest} = {error=>'You must be logged in to upload family names!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload family names!'};
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
    $parser->load_plugin('FamilyNameExcel');
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
        my %family_name_hash = %{$parsed_data};
        foreach my $cross_name(keys %family_name_hash){
            my $family_name = $family_name_hash{$cross_name};

            my $family_name_add = CXGN::Pedigree::AddFamilyNames->new({
                chado_schema => $chado_schema,
                phenome_schema => $phenome_schema,
                dbh => $dbh,
                cross_name => $cross_name,
                family_name => $family_name,
                owner_name => $user_name,
            });

            $family_name_add->add_family_name();

            if (!$family_name_add->add_family_name()){
                $c->stash->{rest} = {error_string => "Error adding family name",};
                return;
            }
        }
    }

    $c->stash->{rest} = {success => "1",};
}



###
1;#
###
