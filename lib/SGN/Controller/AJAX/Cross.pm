
=head1 NAME

SGN::Controller::AJAX::Cross - a REST controller class to provide the
functions for adding crosses

=head1 DESCRIPTION

Add a new cross or upload a file containing crosses to add

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>
Titima Tantikanjana <tt15@cornell.edu>

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
use List::MoreUtils 'none';
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::UploadFile;
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddProgeny;
use CXGN::Pedigree::AddProgeniesExistingAccessions;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Pedigree::AddFamilyNames;
use CXGN::Pedigree::AddPopulations;
use CXGN::Pedigree::AddCrossTransaction;
use CXGN::Pedigree::ParseUpload;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::StockLookup;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use CXGN::Cross;
use JSON;
use Tie::UrlEncoder; our(%urlencode);
use LWP::UserAgent;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use Sort::Key::Natural qw(natsort);


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub upload_cross_file : Path('/ajax/cross/upload_crosses_file') : ActionClass('REST') { }

sub upload_cross_file_POST : Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $manage_page_crossing_experiment_id = $c->req->param('upload_crosses_crossing_experiment_id');
    my $experiment_page_crossing_experiment_id = $c->req->param('experiment_id');
    my $crossing_trial_id;
    if ($manage_page_crossing_experiment_id) {
        $crossing_trial_id = $manage_page_crossing_experiment_id;
    } elsif ($experiment_page_crossing_experiment_id) {
        $crossing_trial_id = $experiment_page_crossing_experiment_id;
    }
    my $crosses_upload = $c->req->upload('upload_crosses_file');

    my $upload;
    my $upload_type;

    if ($crosses_upload) {
        $upload = $crosses_upload;
        $upload_type = 'CrossesGeneric';
    }

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

    #if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
    if ($c->stash->{access}->denied( $user_id, "write", "crosses")) { 
        $c->stash->{rest} = {error => 'You do not have the privileges to upload crosses' };
        $c->detach();
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

    my $cross_additional_info_string = $c->config->{cross_additional_info};
    my @additional_info = split ',', $cross_additional_info_string;
    my $cross_additional_info = \@additional_info;

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, cross_additional_info => $cross_additional_info);
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
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}, missing_plots => $parse_errors->{'missing_plots'}, missing_accessions_or_crosses => $parse_errors->{'missing_accessions_or_crosses'}};
        $c->detach();
    }

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($archived_filename_with_path);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_filename_with_path),
        dirname => dirname($archived_filename_with_path),
        filetype => 'crosses',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });
    my $file_id = $file_row->file_id();

    my $cross_add = CXGN::Pedigree::AddCrosses->new({
        chado_schema => $chado_schema,
        phenome_schema => $phenome_schema,
        metadata_schema => $metadata_schema,
        dbh => $dbh,
        crossing_trial_id => $crossing_trial_id,
        crosses =>  $parsed_data->{crosses},
        user_id => $user_id,
        file_id => $file_id
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

    if ($parsed_data->{'additional_info'}) {
        my %cross_additional_info = %{$parsed_data->{additional_info}};
        foreach my $cross_name (keys %cross_additional_info) {
            my %info_hash = %{$cross_additional_info{$cross_name}};
            foreach my $info_type (keys %info_hash) {
                my $value = $info_hash{$info_type};
                my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
                    chado_schema => $chado_schema,
                    cross_name => $cross_name,
                    key => $info_type,
                    value => $value,
                    data_type => 'cross_additional_info'
                });

               $cross_add_info->add_info();

               if (!$cross_add_info->add_info()){
                   $c->stash->{rest} = {error_string => "Error saving info",};
                   return;
               }

            }
        }
    }

    $c->stash->{rest} = {success => "1",};
}


sub add_cross : Local : ActionClass('REST') { }

sub add_cross_POST :Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $cross_name = $c->req->param('cross_name');
    my $cross_type = $c->req->param('cross_type');
    my $crossing_trial_id = $c->req->param('crossing_trial_id');
    my $female_plot_plant_id = $c->req->param('female_plot_plant');
    my $male_plot_plant_id = $c->req->param('male_plot_plant');
    my $cross_combination = $c->req->param('cross_combination');
    $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end.

    my $user_id;
    if (!$c->user()) {
        print STDERR "User not logged in... not adding a cross.\n";
        $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        print STDERR "User does not have sufficient privileges.\n";
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
        return;
    } else {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    if ($cross_type eq "polycross") {
        print STDERR "Handling a polycross\n";
        my @maternal_parents = split (',', $c->req->param('maternal_parents'));
        print STDERR "Maternal parents array:" . @maternal_parents . "\n Maternal parents with ref:" . \@maternal_parents . "\n Maternal parents with dumper:". Dumper(@maternal_parents) . "\n";
        my $paternal = $cross_name . '_population';
        my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $chado_schema, phenome_schema => $phenome_schema, user_id => $user_id, name => $paternal, members =>  \@maternal_parents} );
        $population_add->add_population();
        $cross_type = 'polycross';
        print STDERR "Scalar maternatal paretns:" . scalar @maternal_parents;
        for (my $i = 0; $i < scalar @maternal_parents; $i++) {
            my $maternal = $maternal_parents[$i];
            my $polycross_name = $cross_name . '_' . $maternal;
            print STDERR "First polycross to add is $polycross_name with amternal $maternal and paternal $paternal\n";
            my $success = $self->add_individual_cross($c, $chado_schema, $polycross_name, $cross_type, $crossing_trial_id, $female_plot_plant_id, $male_plot_plant_id, $maternal, $paternal);
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
                my $success = $self->add_individual_cross($c, $chado_schema, $reciprocal_cross_name, $cross_type, $crossing_trial_id, $female_plot_plant_id, $male_plot_plant_id, $maternal, $paternal);
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
            my $success = $self->add_individual_cross($c, $chado_schema, $multicross_name, $cross_type, $crossing_trial_id, $female_plot_plant_id, $male_plot_plant_id, $maternal, $paternal);
            if (!$success) {
                return;
            }
        }
    }
    else {
        my $maternal = $c->req->param('maternal');
        my $paternal = $c->req->param('paternal');
        my $success = $self->add_individual_cross($c, $chado_schema, $cross_name, $cross_type, $crossing_trial_id, $female_plot_plant_id, $male_plot_plant_id, $maternal, $paternal, $cross_combination);
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

    my $cross_obj = CXGN::Cross->new({schema=>$schema, cross_stock_id=>$cross_id});
    my ($maternal_parent, $paternal_parent, $progeny) = $cross_obj->get_cross_relationships();

    $c->stash->{rest} = {
        maternal_parent => $maternal_parent,
        paternal_parent => $paternal_parent,
        progeny => $progeny,
    };
}


sub get_membership :Path('/ajax/cross/membership') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross = $schema->resultset("Stock::Stock")->find( { stock_id => $cross_id });

    if ($cross && $cross->type()->name() ne "cross") {
	    $c->stash->{rest} = { error => 'This entry is not of type cross and cannot be displayed using this page.' };
	    return;
    }

    my $cross_obj = CXGN::Cross->new({schema=>$schema, cross_stock_id=>$cross_id});
    my $result = $cross_obj->get_membership();
    my @membership_info;

    foreach my $r (@$result){
        my ($crossing_experiment_id, $crossing_experiment_name, $description, $family_id, $family_name) =@$r;
        push @membership_info, [qq{<a href="/breeders/trial/$crossing_experiment_id">$crossing_experiment_name</a>}, $description, qq{<a href = "/family/$family_id/">$family_name</a>}];
    }

    $c->stash->{rest} = { data => \@membership_info };

}


sub get_cross_parents :Path('/ajax/cross/accession_plot_plant_parents') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $cross = $schema->resultset("Stock::Stock")->find( { stock_id => $cross_id });

    if ($cross && $cross->type()->name() ne "cross") {
	    $c->stash->{rest} = { error => 'This entry is not of type cross and cannot be displayed using this page.' };
	    return;
    }

    my $cross_obj = CXGN::Cross->new({schema=>$schema, cross_stock_id=>$cross_id});
    my $result = $cross_obj->cross_parents();
    my @cross_parent_info;

    foreach my $r (@$result){
        my ($female_accession_id, $female_accession_name, $female_plot_id, $female_plot_name, $female_plant_id, $female_plant_name, $male_accession_id, $male_accession_name, $male_plot_id, $male_plot_name, $male_plant_id, $male_plant_name, $cross_type, $cross_combination, $female_ploidy, $male_ploidy) = @$r;
        push @cross_parent_info, [$cross_combination, $cross_type,
            qq{<a href="/stock/$female_accession_id/view">$female_accession_name</a>},
            $female_ploidy,
            qq{<a href="/stock/$male_accession_id/view">$male_accession_name</a>},
            $male_ploidy,
            qq{<a href="/stock/$female_plot_id/view">$female_plot_name</a>},
            qq{<a href="/stock/$male_plot_id/view">$male_plot_name</a>},
            qq{<a href="/stock/$female_plant_id/view">$female_plant_name</a>},
            qq{<a href="/stock/$male_plant_id/view">$male_plant_name</a>}];
    }

    $c->stash->{rest} = {data => \@cross_parent_info}

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


sub get_cross_tissue_culture_summary :Path('/ajax/cross/tissue_culture_summary') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross_samples_obj = CXGN::Cross->new({schema=>$schema, cross_stock_id=>$cross_id});
    my $cross_sample_data  = $cross_samples_obj->get_cross_tissue_culture_samples();

    my $embryo_ids = $cross_sample_data->{'Embryo IDs'};
    my $subculture_ids = $cross_sample_data->{'Subculture IDs'};
    my $rooting_ids = $cross_sample_data->{'Rooting IDs'};
    my $weaning1_ids = $cross_sample_data->{'Weaning1 IDs'};
    my $weaning2_ids = $cross_sample_data->{'Weaning2 IDs'};
    my $screenhouse_ids = $cross_sample_data->{'Screenhouse IDs'};
    my $hardening_ids = $cross_sample_data->{'Hardening IDs'};
    my $openfield_ids = $cross_sample_data->{'Openfield IDs'};

    my @embryo_ids_array;
    my @subculture_ids_array;
    my @rooting_ids_array;
    my @weaning1_ids_array;
    my @weaning2_ids_array;
    my @screenhouse_ids_array;
    my @hardening_ids_array;
    my @openfield_ids_array;

    if (defined $embryo_ids) {
        @embryo_ids_array = @$embryo_ids;
    }

    if (defined $subculture_ids) {
        @subculture_ids_array = @$subculture_ids;
    }

    if (defined $rooting_ids) {
        @rooting_ids_array = @$rooting_ids;
    }

    if (defined $weaning1_ids) {
        @weaning1_ids_array = @$weaning1_ids;
    }

    if (defined $weaning2_ids) {
        @weaning2_ids_array = @$weaning2_ids;
    }

    if (defined $screenhouse_ids) {
        @screenhouse_ids_array = @$screenhouse_ids;
    }

    if (defined $hardening_ids) {
        @hardening_ids_array = @$hardening_ids;
    }

    if (defined $openfield_ids) {
        @openfield_ids_array = @$openfield_ids;
    }

    my @all_rows;
    my @each_row;
    my $checkmark = qq{<img src="/img/checkmark_green.jpg"/>};
    my $x_mark = qq{<img src="/img/x_mark_red.jpg"/>};
    my @sorted_embryo_ids = natsort @embryo_ids_array;

    foreach my $embryo_id (@sorted_embryo_ids) {

        if ($embryo_id) {
            push @each_row, $embryo_id;
        }

        if ($embryo_id ~~ @subculture_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @rooting_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @weaning1_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @weaning2_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @screenhouse_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @hardening_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        if ($embryo_id ~~ @openfield_ids_array) {
            push @each_row, $checkmark;
        } else {
            push @each_row, $x_mark;
        }

        push @all_rows, [@each_row];
        @each_row =();
    }
#    print STDERR "SORTED EMBRYO IDS =".Dumper(\@sorted_embryo_ids)."\n";
    $c->stash->{rest} = { data => \@all_rows };
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
    my $data_type = $c->req->param("data_type");
#    print STDERR "DATA TYPE =".Dumper($data_type)."\n";
#    print STDERR "TYPE =".Dumper($type)."\n";
#    print STDERR "VALUE =".Dumper($value)."\n";

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $schema->resultset("Stock::Stock")->find({stock_id => $cross_id})->uniquename();

    my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
        chado_schema => $schema,
        cross_name => $cross_name,
        key => $type,
        value => $value,
        data_type => $data_type
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


#my $new_cross = CXGN::Cross->new({ schema=>schema });
#$new_cross->female_parent($fjfj);
#$new_cross->male_parent(kdkjf);
#$new_cross->location(kjlsdlkjdfskj);
#...type
#...cross_name
#...plots...
#$new_cross->store();

sub add_individual_cross {
    my $self = shift;
    my $c = shift;
    my $chado_schema = shift;
    my $cross_name = shift;
    my $cross_type = shift;
    my $crossing_trial_id = shift;
    my $female_plot_plant_id = shift;
    my $female_plot;
    my $female_plant;
    my $male_plot_plant_id = shift;
    my $male_plot;
    my $male_plant;
    my $maternal = shift;
    my $paternal = shift;
    my $cross_combination = shift;

    my $owner_name = $c->user()->get_object()->get_username();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my @progeny_names;
    my $progeny_increment = 1;
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');

    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();


    if ($female_plot_plant_id){
        my $female_plot_plant_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $female_plot_plant_id});
        my $female_type = $female_plot_plant_rs->type_id();
        if ($female_type == $plot_cvterm_id) {
            $female_plot = $female_plot_plant_rs->name();
        } elsif ($female_type == $plant_cvterm_id) {
            $female_plant = $female_plot_plant_rs->name();
        }
    }

    if ($male_plot_plant_id){
        my $male_plot_plant_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $male_plot_plant_id});
        my $male_type = $male_plot_plant_rs->type_id();
        if ($male_type == $plot_cvterm_id) {
            $male_plot = $male_plot_plant_rs->name();
        } elsif ($male_type == $plant_cvterm_id) {
            $male_plant = $male_plot_plant_rs->name();
        }
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
        $c->stash->{rest} = {error =>  "Cross Unique ID already exists." };
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

    if ($female_plant) {
        my $female_plant_individual = Bio::GeneticRelationships::Individual->new(name => $female_plant);
        $cross_to_add->set_female_plant($female_plant_individual);
    }

    if ($male_plant) {
        my $male_plant_individual = Bio::GeneticRelationships::Individual->new(name => $male_plant);
        $cross_to_add->set_male_plant($male_plant_individual);
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
            user_id => $user_id,
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
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $crossingtrial_name = $c->req->param('crossingtrial_name');
    my $breeding_program_id = $c->req->param('crossingtrial_program_id');
    my $program_name = $schema->resultset('Project::Project')->find({project_id => $breeding_program_id})->name();
    my $location = $c->req->param('crossingtrial_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');

    if (!$c->user()){
        print STDERR "User not logged in... not adding a crossing experiment.\n";
        $c->stash->{rest} = {error => "You need to be logged in to add a crossing experiment."};
        return;
    }

    my @user_roles = $c->user->roles();
    my $check_roles = CXGN::People::Roles->new({ people_schema => $people_schema});
    my $invalid_roles = $check_roles->check_sp_roles(\@user_roles, $program_name);
    if ($invalid_roles->{'invalid_role'}) {
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a crossing experiment." };
        return;
    } elsif ($invalid_roles->{'invalid_program'}) {
        $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $program_name to add new crossing experiment." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
    $geolocation_lookup->set_location_name($location);
    if(!$geolocation_lookup->get_geolocation()){
        $c->stash->{rest}={error => "Location not found"};
        return;
    }

    my $error;
    eval{
        my $add_crossingtrial = CXGN::Pedigree::AddCrossingtrial->new({
            chado_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $year,
            project_description => $project_description,
            crossingtrial_name => $crossingtrial_name,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
            owner_id => $user_id
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
    my $upload = $c->req->upload('progenies_new_upload_file');
    my $upload_type = 'ProgeniesExcel';
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

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload progenies'};
        $c->detach();
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

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
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
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    #add the progeny
    my %progeny_hash = %{$parsed_data};
    my @all_crosses = keys %progeny_hash;
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

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($archived_filename_with_path);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_filename_with_path),
        dirname => dirname($archived_filename_with_path),
        filetype => 'cross_progenies',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });

    my $file_id = $file_row->file_id();
#    print STDERR "FILE ID =".Dumper($file_id)."\n";
    foreach my $cross_name (@all_crosses) {
        my $cross_experiment_type = CXGN::Cross->new({schema => $chado_schema, cross_name => $cross_name});
        my $experiment_id = $cross_experiment_type->get_nd_experiment_id_with_type_cross_experiment();
#        print STDERR "ND EXPERIMENT ID =".Dumper($experiment_id)."\n";
        my $nd_experiment_file = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $experiment_id,
            file_id => $file_id,
        });
    }

    $c->stash->{rest} = {success => "1",};

}

sub validate_upload_existing_progenies : Path('/ajax/cross/validate_upload_existing_progenies') : ActionClass('REST'){ }

sub validate_upload_existing_progenies_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('progenies_exist_upload_file');
    my $upload_type = 'ValidateExistingProgeniesExcel';
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
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload progenies!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload progenies'};
        $c->detach();
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

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();
    #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

        my $return_error = '';
        my $existing_pedigree = '';
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }

            foreach my $each_pedigree (@{$parse_errors->{'existing_pedigrees'}}){
                $existing_pedigree .= $each_pedigree."<br>";
            }

        }
        $c->stash->{rest} = {error_string => $return_error, existing_pedigrees => $existing_pedigree, archived_file_name => $archived_filename_with_path, user_id => $user_id};
}


sub store_upload_existing_progenies : Path('/ajax/cross/store_upload_existing_progenies') Args(0) {
    my $self = shift;
    my $c = shift;
    my $archived_filename_with_path = $c->req->param('archived_file_name');
    my $user_id = $c->req->param('user_id');
#    print STDERR "ARCHIVED FILE NAME =".Dumper($archived_filename_with_path)."\n";
#    print STDERR "USER ID =".Dumper($user_id)."\n";
    my $overwrite_pedigrees = $c->req->param('overwrite_pedigrees') ne 'false' ? $c->req->param('overwrite_pedigrees') : 0;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;

    my $upload_type = 'StoreExistingProgeniesExcel';
    my @all_crosses;

    my $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin($upload_type);
    my $parsed_data = $parser->parse();
    if ($parsed_data){
        my %progeny_hash = %{$parsed_data};
        @all_crosses = keys %progeny_hash;
        foreach my $cross_name_key (keys %progeny_hash){
            my $progenies_ref = $progeny_hash{$cross_name_key};
            my @progenies = @{$progenies_ref};
            my $adding_progenies = CXGN::Pedigree::AddProgeniesExistingAccessions->new({
                chado_schema => $chado_schema,
                cross_name => $cross_name_key,
                progeny_names => \@progenies,
            });

            my $return = $adding_progenies->add_progenies_existing_accessions($overwrite_pedigrees);
            my $error;
            if (!$return){
                $error = "The progenies were not stored";
            }

            if ($return->{error}){
                $error = $return->{error};
            }

            if ($error){
                $c->stash->{rest} = { error => $error };
                return;
            }
        }
    }

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($archived_filename_with_path);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_filename_with_path),
        dirname => dirname($archived_filename_with_path),
        filetype => 'cross_progenies',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });

    my $file_id = $file_row->file_id();
#    print STDERR "FILE ID =".Dumper($file_id)."\n";
    foreach my $cross_name (@all_crosses) {
        my $cross_experiment_type = CXGN::Cross->new({schema => $chado_schema, cross_name => $cross_name});
        my $experiment_id = $cross_experiment_type->get_nd_experiment_id_with_type_cross_experiment();
#        print STDERR "ND EXPERIMENT ID =".Dumper($experiment_id)."\n";
        my $nd_experiment_file = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $experiment_id,
            file_id => $file_id,
        });
    }

    $c->stash->{rest} = { success => 1 };
}

sub upload_info : Path('/ajax/cross/upload_info') : ActionClass('REST'){ }

sub upload_info_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $cross_info_upload = $c->req->upload('crossinfo_upload_file');
    my $additional_info_upload = $c->req->upload('additional_info_upload_file');
    my $upload;
    my $upload_type;
    my $data_type;

    if ($cross_info_upload) {
        $upload = $cross_info_upload;
        $upload_type = 'CrossInfoExcel';
        $data_type = 'crossing_metadata_json';
    }
    if ($additional_info_upload) {
        $upload = $additional_info_upload;
        $upload_type = 'AdditionalInfoExcel';
        $data_type = 'cross_additional_info';
    }
#    print STDERR "INFO UPLOAD =".Dumper($cross_info_upload)."\n";
#    print STDERR "ADDITIONAL INFO UPLOAD =".Dumper($additional_info_upload)."\n";
#    print STDERR "DATA TYPE =".Dumper($data_type)."\n";

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
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
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
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload cross info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload cross info'};
        $c->detach();
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

    my $cross_properties_string = $c->config->{cross_properties};
    my @properties = split ',', $cross_properties_string;
    my $cross_properties = \@properties;

    my $cross_additional_info_string = $c->config->{cross_additional_info};
    my @additional_info = split ',', $cross_additional_info_string;
    my $cross_additional_info = \@additional_info;

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, cross_properties => $cross_properties, cross_additional_info => $cross_additional_info);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();
#    print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

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

    my @all_crosses;
    if ($parsed_data) {
        my %cross_info = %{$parsed_data};
        @all_crosses = keys %cross_info;
        foreach my $cross_name (keys %cross_info) {
            my %info_hash = %{$cross_info{$cross_name}};
            foreach my $info_type (keys %info_hash) {
                my $value = $info_hash{$info_type};
                my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({
                    chado_schema => $chado_schema,
                    cross_name => $cross_name,
                    key => $info_type,
                    value => $value,
                    data_type => $data_type
                });

               $cross_add_info->add_info();

               if (!$cross_add_info->add_info()){
                   $c->stash->{rest} = {error_string => "Error saving info",};
                   return;
               }
            }
        }
    }

#    print STDERR "FILE =".Dumper($archived_filename_with_path)."\n";
    my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($archived_filename_with_path);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_filename_with_path),
        dirname => dirname($archived_filename_with_path),
        filetype => 'cross_info',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });

    my $file_id = $file_row->file_id();
#    print STDERR "FILE ID =".Dumper($file_id)."\n";
    foreach my $cross_name (@all_crosses) {
        my $cross_experiment_type = CXGN::Cross->new({schema => $chado_schema, cross_name => $cross_name});
        my $experiment_id = $cross_experiment_type->get_nd_experiment_id_with_type_cross_experiment();
#        print STDERR "ND EXPERIMENT ID =".Dumper($experiment_id)."\n";
        my $nd_experiment_file = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $experiment_id,
            file_id => $file_id,
        });
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
    my $same_parents_upload = $c->req->upload('same_parents_file');
    my $reciprocal_parents_upload = $c->req->upload('reciprocal_parents_file');

    my $upload_original_name;
    my $upload_tempfile;
    my $family_type;

    if ($same_parents_upload) {
        $upload_original_name = $same_parents_upload->filename();
        $upload_tempfile = $same_parents_upload->tempname;
        $family_type = 'same_parents';
    }

    if ($reciprocal_parents_upload) {
        $upload_original_name = $reciprocal_parents_upload->filename();
        $upload_tempfile = $reciprocal_parents_upload->tempname;
        $family_type = 'reciprocal_parents';
    }

    my $parser;
    my $parsed_data;
    my $subdirectory = "cross_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
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

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload family names'};
        $c->detach();
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

    #add family name and associate with cross
    my @all_crosses;
    if ($parsed_data){
        my %family_name_hash = %{$parsed_data};
        @all_crosses = keys %family_name_hash;
        foreach my $cross_name(keys %family_name_hash){
            my $family_name = $family_name_hash{$cross_name};

            my $family_name_add = CXGN::Pedigree::AddFamilyNames->new({
                chado_schema => $chado_schema,
                phenome_schema => $phenome_schema,
                dbh => $dbh,
                cross_name => $cross_name,
                family_name => $family_name,
                owner_name => $user_name,
                family_type => $family_type
            });

            my $return = $family_name_add->add_family_name();
            my $error;
            if (!$return){
                $error = "Error adding family name";
            }
            if ($return->{error}){
                $error = $return->{error};
            }
            if ($error){
                $c->stash->{rest} = {error_string => $error };
                $c->detach();
            }
        }
    }

#    print STDERR "FILE =".Dumper($archived_filename_with_path)."\n";
    my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($archived_filename_with_path);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_filename_with_path),
        dirname => dirname($archived_filename_with_path),
        filetype => 'families',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });

    my $file_id = $file_row->file_id();
#    print STDERR "FILE ID =".Dumper($file_id)."\n";
    foreach my $cross_name (@all_crosses) {
        my $cross_experiment_type = CXGN::Cross->new({schema => $chado_schema, cross_name => $cross_name});
        my $experiment_id = $cross_experiment_type->get_nd_experiment_id_with_type_cross_experiment();
#        print STDERR "ND EXPERIMENT ID =".Dumper($experiment_id)."\n";
        my $nd_experiment_file = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $experiment_id,
            file_id => $file_id,
        });
    }

    $c->stash->{rest} = {success => "1",};
}


sub delete_cross : Path('/ajax/cross/delete') : ActionClass('REST'){ }

sub delete_cross_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to delete crosses" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete crosses. Please contact us." };
        $c->detach();
    }

    my $cross_stock_id = $c->req->param("cross_id");

    my $cross = CXGN::Cross->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'), cross_stock_id => $cross_stock_id });

    if (!$cross->cross_stock_id()) {
	$c->stash->{rest} = { error => "No such cross exists. Cannot delete." };
	return;
    }

    my $error = $cross->delete();

    print STDERR "ERROR = $error\n";

    if ($error) {
	$c->stash->{rest} = { error => "An error occurred attempting to delete a cross. ($@)" };
	return;
    }

    $c->stash->{rest} = { success => 1 };
}


sub get_cross_transactions :Path('/ajax/cross/transactions') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $cross_transaction_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_transaction_json', 'stock_property')->cvterm_id();
    my $cross_transactions = $schema->resultset("Stock::Stockprop")->find({stock_id => $cross_id, type_id => $cross_transaction_cvterm});

    my $cross_transaction_string;
    my %cross_transaction_hash;
    my @all_transactions;

    if($cross_transactions){
        $cross_transaction_string = $cross_transactions->value();
        my $cross_transaction_ref = decode_json $cross_transaction_string;
        %cross_transaction_hash = %{$cross_transaction_ref};
        foreach my $transaction_key (sort keys %cross_transaction_hash) {
            my $operator = $cross_transaction_hash{$transaction_key}{'Operator'};
            my $timestamp = $cross_transaction_hash{$transaction_key}{'Timestamp'};
            my $number_of_flowers = $cross_transaction_hash{$transaction_key}{'Number of Flowers'};
            my $number_of_fruits = $cross_transaction_hash{$transaction_key}{'Number of Fruits'};
            my $number_of_seeds = $cross_transaction_hash{$transaction_key}{'Number of Seeds'};
            push @all_transactions, [$transaction_key, $operator, $timestamp, $number_of_flowers, $number_of_fruits, $number_of_seeds];
        }
    }

    $c->stash->{rest} = {data => \@all_transactions};

}


sub get_cross_additional_info :Path('/ajax/cross/additional_info') Args(1) {
    my $self = shift;
    my $c = shift;
    my $cross_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross_additional_info_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_additional_info', 'stock_property')->cvterm_id();
    my $cross_additional_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $cross_id, type_id => $cross_additional_info_cvterm});

    my $cross_info_json_string;
    if($cross_additional_info_rs){
        $cross_info_json_string = $cross_additional_info_rs->value();
    }

    my $cross_info_hash ={};
    if($cross_info_json_string){
        $cross_info_hash = decode_json $cross_info_json_string;
    }

    my $cross_additional_info = $c->config->{cross_additional_info};
    my @column_order = split ',',$cross_additional_info;
    my @props;
    my @row;
    foreach my $key (@column_order){
        push @row, $cross_info_hash->{$key};
    }

    push @props,\@row;
    $c->stash->{rest} = {data => \@props};

}


###
1;#
###
