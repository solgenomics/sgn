package SGN::Controller::AJAX::TrialMetadata;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;
use CXGN::Trial;
use Math::Round::Var;
use List::MoreUtils qw(uniq);
use CXGN::Trial::FieldMap;
use JSON;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Cross;

use CXGN::Phenotypes::TrialPhenotype;
use CXGN::Login;
use CXGN::UploadFile;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use File::Basename qw | basename dirname|;
use List::MoreUtils ':all';
use Try::Tiny;
use CXGN::BreederSearch;
use CXGN::Page::FormattingHelpers qw / html_optional_show /;
use SGN::Image;

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


sub trial : Chained('/') PathPart('ajax/breeders/trial') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{schema} =  $bcs_schema;
    $c->stash->{trial} = CXGN::Trial->new({
        bcs_schema => $bcs_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        trial_id => $trial_id
    });

    if (!$c->stash->{trial}) {
	$c->stash->{rest} = { error => "The specified trial with id $trial_id does not exist" };
	return;
    }

    try {
        my %param = ( schema => $bcs_schema, trial_id => $trial_id );
        if ($c->stash->{trial}->get_design_type() eq 'genotyping_plate'){
            $param{experiment_type} = 'genotyping_layout';
        } else {
            $param{experiment_type} = 'field_layout';
        }
        $c->stash->{trial_layout} = CXGN::Trial::TrialLayout->new(\%param);
    }
    catch {
        print STDERR "Trial Layout for $trial_id does not exist. @_\n";
    }

}

=head2 delete_trial_by_file
 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:
=cut

sub delete_trial_data : Local() ActionClass('REST');

sub delete_trial_data_GET : Chained('trial') PathPart('delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $datatype = shift;

    if ($self->privileges_denied($c)) {
	$c->stash->{rest} = { error => "You have insufficient access privileges to delete trial data." };
	return;
    }

    my $error = "";

    if ($datatype eq 'phenotypes') {
	$error = $c->stash->{trial}->delete_phenotype_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error .= $c->stash->{trial}->delete_phenotype_data();
    }

    elsif ($datatype eq 'layout') {
        $error = $c->stash->{trial}->delete_metadata();
        $error = $c->stash->{trial}->delete_field_layout();

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');
    }
    elsif ($datatype eq 'entry') {
	$error = $c->stash->{trial}->delete_project_entry();
    }
    else {
	$c->stash->{rest} = { error => "unknown delete action for $datatype" };
	return;
    }
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }
    $c->stash->{rest} = { message => "Successfully deleted trial data.", success => 1 };
}

sub trial_phenotypes_fully_uploaded : Chained('trial') PathPart('phenotypes_fully_uploaded') Args(0) ActionClass('REST') {};

sub trial_phenotypes_fully_uploaded_GET   {
    my $self = shift;
    my $c = shift;
    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { phenotypes_fully_uploaded => $trial->get_phenotypes_fully_uploaded() };
}

sub trial_phenotypes_fully_uploaded_POST  {
    my $self = shift;
    my $c = shift;
    my $value = $c->req->param("phenotypes_fully_uploaded");
    my $trial = $c->stash->{trial};
    eval {
        $trial->set_phenotypes_fully_uploaded($value);
    };
    if ($@) {
        $c->stash->{rest} = { error => "An error occurred setting phenotypes_fully_uploaded: $@" };
    }
    else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub trial_details : Chained('trial') PathPart('details') Args(0) ActionClass('REST') {};

sub trial_details_GET   {
    my $self = shift;
    my $c = shift;

    my $trial = $c->stash->{trial};

    $c->stash->{rest} = { details => $trial->get_details() };

}

sub trial_details_POST  {
    my $self = shift;
    my $c = shift;

    my @categories = $c->req->param("categories[]");

    my $details = {};
    foreach my $category (@categories) {
      $details->{$category} = $c->req->param("details[$category]");
    }

    if (!%{$details}) {
      $c->stash->{rest} = { error => "No values were edited, so no changes could be made for this trial's details." };
      return;
    }
    else {
    print STDERR "Here are the deets: " . Dumper($details) . "\n";
    }

    #check privileges
    print STDERR " curator status = ".$c->user()->check_roles('curator')." and submitter status = ".$c->user()->check_roles('submitter')."\n";
    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
      $c->stash->{rest} = { error => 'You do not have the required privileges to edit trial details, trial details can only be edited by accounts with submitter or curator privileges' };
      return;
    }

    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $c->stash->{schema} });
    my $program_ref = $program_object->get_breeding_programs_by_trial($trial_id);

    my $program_array = @$program_ref[0];
    my $breeding_program_name = @$program_array[1];
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    print STDERR "my user roles = @user_roles and trial breeding program = $breeding_program_name \n";

    if (!exists($has_roles{$breeding_program_name})) {
      $c->stash->{rest} = { error => "You need to be associated with breeding program $breeding_program_name to change the details of this trial." };
      return;
    }

    # set each new detail that is defined
    eval {
      if ($details->{name}) { $trial->set_name($details->{name}); }
      if ($details->{breeding_program}) { $trial->set_breeding_program($details->{breeding_program}); }
      if ($details->{location}) { $trial->set_location($details->{location}); }
      if ($details->{year}) { $trial->set_year($details->{year}); }
      if ($details->{type}) { $trial->set_project_type($details->{type}); }
      if ($details->{planting_date}) {
        if ($details->{planting_date} eq 'remove') { $trial->remove_planting_date($trial->get_planting_date()); }
        else { $trial->set_planting_date($details->{planting_date}); }
      }
      if ($details->{harvest_date}) {
        if ($details->{harvest_date} eq 'remove') { $trial->remove_harvest_date($trial->get_harvest_date()); }
        else { $trial->set_harvest_date($details->{harvest_date}); }
      }
      if ($details->{description}) { $trial->set_description($details->{description}); }
    };

    if ($@) {
	    $c->stash->{rest} = { error => "An error occurred setting the new trial details: $@" };
    }
    else {
	    $c->stash->{rest} = { success => 1 };
    }
}

sub traits_assayed : Chained('trial') PathPart('traits_assayed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $stock_type = $c->req->param('stock_type');

    my @traits_assayed  = $c->stash->{trial}->get_traits_assayed($stock_type);
    $c->stash->{rest} = { traits_assayed => \@traits_assayed };
}

sub trait_phenotypes : Chained('trial') PathPart('trait_phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    #get userinfo from db
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user = $c->user();
    if (! $c->user) {
      $c->stash->{rest} = {
        status => "not logged in"
      };
      return;
    }
    my $display = $c->req->param('display');
    my $trait = $c->req->param('trait');
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=> $schema,
        search_type => "Native",
        data_level => $display,
        trait_list=> [$trait],
        trial_list => [$c->stash->{trial_id}]
    );
    my @data = $phenotypes_search->get_phenotype_matrix();
    $c->stash->{rest} = {
      status => "success",
      data => \@data
   };
}

sub phenotype_summary : Chained('trial') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->stash->{schema};
    my $round = Math::Round::Var->new(0.01);
    my $dbh = $c->dbc->dbh();
    my $trial_id = $c->stash->{trial_id};
    my $display = $c->req->param('display');
    my $select_clause_additional = '';
    my $group_by_additional = '';
    my $order_by_additional = '';
    my $stock_type_id;
    my $rel_type_id;
    my $total_complete_number;
    if ($display eq 'plots') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plots = $c->stash->{trial}->get_plots();
        $total_complete_number = scalar (@$plots);
    }
    if ($display eq 'plants') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $plants = $c->stash->{trial}->get_plants();
        $total_complete_number = scalar (@$plants);
    }
    if ($display eq 'subplots') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();
        my $subplots = $c->stash->{trial}->get_subplots();
        $total_complete_number = scalar (@$subplots);
    }
    my $stocks_per_accession;
    if ($display eq 'plots_accession') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
        $select_clause_additional = ', accession.uniquename, accession.stock_id';
        $group_by_additional = ', accession.stock_id, accession.uniquename';
        $stocks_per_accession = $c->stash->{trial}->get_plots_per_accession();
        $order_by_additional = ' ,accession.uniquename DESC';
    }
    if ($display eq 'plants_accession') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        $select_clause_additional = ', accession.uniquename, accession.stock_id';
        $group_by_additional = ', accession.stock_id, accession.uniquename';
        $stocks_per_accession = $c->stash->{trial}->get_plants_per_accession();
        $order_by_additional = ' ,accession.uniquename DESC';
    }
    my $accesion_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990')
        $select_clause_additional
        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE project_id=?
            AND phenotype.value~?
            AND stock_relationship.type_id=?
            AND plot.type_id=?
            AND accession.type_id=?
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id $group_by_additional
        ORDER BY cvterm.name ASC
        $order_by_additional;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($c->stash->{trial_id}, $numeric_regex, $rel_type_id, $stock_type_id, $accesion_type_id);

    my @phenotype_data;

    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id) = $h->fetchrow_array()) {

        my $cv = 0;
        if ($stddev && $average != 0) {
            $cv = ($stddev /  $average) * 100;
            $cv = $round->round($cv) . '%';
        }
        if ($average) { $average = $round->round($average); }
        if ($min) { $min = $round->round($min); }
        if ($max) { $max = $round->round($max); }
        if ($stddev) { $stddev = $round->round($stddev); }

        my @return_array;
        if ($stock_name && $stock_id) {
            $total_complete_number = scalar (@{$stocks_per_accession->{$stock_id}});
            push @return_array, qq{<a href="/stock/$stock_id/view">$stock_name</a>};
        }
        my $percent_missing = '';
        if ($total_complete_number){
            $percent_missing = 100 - sprintf("%.2f", ($count/$total_complete_number)*100)."%";
        }

        push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count, $percent_missing, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} );
        push @phenotype_data, \@return_array;
    }

    $c->stash->{rest} = { data => \@phenotype_data };
}

sub trait_histogram : Chained('trial') PathPart('trait_histogram') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    my $stock_type = $c->req->param('stock_type') || 'plot';

    my @data = $c->stash->{trial}->get_phenotypes_for_trait($trait_id, $stock_type);

    $c->stash->{rest} = { data => \@data };
}

sub get_trial_folder :Chained('trial') PathPart('folder') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $project_parent = $c->stash->{trial}->get_folder();

    $c->stash->{rest} = { folder => [ $project_parent->project_id(), $project_parent->name() ] };

}

sub get_trial_location :Chained('trial') PathPart('location') Args(0) {
    my $self = shift;
    my $c = shift;
    my $location = $c->stash->{trial}->get_location;
    $c->stash->{rest} = { location => $location };
}

sub trial_accessions : Chained('trial') PathPart('accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_accessions();

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_tissue_sources : Chained('trial') PathPart('tissue_sources') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });
    my $data = $trial->get_tissue_sources();
    #print STDERR Dumper $data;
    $c->stash->{rest} = { tissue_sources => $data };
}

sub trial_seedlots : Chained('trial') PathPart('seedlots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_seedlots();

    $c->stash->{rest} = { seedlots => \@data };
}

sub trial_used_seedlots_upload : Chained('trial') PathPart('upload_used_seedlots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $upload = $c->req->upload('trial_upload_used_seedlot_file');
    my $subdirectory = "trial_used_seedlot_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialUsedSeedlotsXLS');
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_seedlots => $parse_errors->{'missing_seedlots'}, missing_plots => $parse_errors->{'missing_plots'}};
        $c->detach();
    }

    my $upload_used_seedlots_txn = sub {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_stock_id});

            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor(1);
            $transaction->from_stock([$val->{seedlot_stock_id}, $val->{seedlot_name}]);
            $transaction->to_stock([$val->{plot_stock_id}, $val->{plot_name}]);
            $transaction->amount($val->{amount});
            $transaction->weight_gram($val->{weight_gram});
            $transaction->timestamp($timestamp);
            $transaction->description($val->{description});
            $transaction->operator($user_name);
            $transaction->store();

            $sl->set_current_count_property();
            $sl->set_current_weight_property();
        }
        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_used_seedlots_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial used seedlots. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants : Chained('trial') PathPart('upload_plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $upload = $c->req->upload('trial_upload_plants_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_per_plot_inherit_treatments');
    my $plants_per_plot = $c->req->param('upload_plants_per_plot_number');

    my $subdirectory = "trial_plants_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialPlantsXLS');
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_plots => $parse_errors->{'missing_plots'}};
        $c->detach();
    }

    my $upload_plants_txn = sub {
        my %plot_plant_hash;
        while (my ($key, $val) = each(%$parsed_data)){
            $plot_plant_hash{$val->{plot_stock_id}}->{plot_name} = $val->{plot_name};
            push @{$plot_plant_hash{$val->{plot_stock_id}}->{plant_names}}, $val->{plant_name};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $c->stash->{trial_id} });
        $t->save_plant_entries(\%plot_plant_hash, $plants_per_plot, $inherits_plot_treatments);

        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_plants_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial plants. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

    $c->stash->{rest} = { success => 1 };
}

sub trial_plot_gps_upload : Chained('trial') PathPart('upload_plot_gps') Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    #Check that trial has a location set
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $nd_geolocation_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search(
        {'nd_experiments.type_id'=>$field_experiment_cvterm_id, 'project.project_id'=>$c->stash->{trial_id}},
        { 'join' => { 'nd_experiments' => {'nd_experiment_projects'=>'project'} } }
    );
    my $nd_geolocation = $nd_geolocation_rs->first;
    if (!$nd_geolocation){
        $c->stash->{rest} = {error=>'This trial has no location set!'};
        $c->detach();
    }

    my $upload = $c->req->upload('trial_upload_plot_gps_file');
    my $subdirectory = "trial_plot_gps_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialPlotGPSCoordinatesXLS');
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_plots => $parse_errors->{'missing_plots'}};
        $c->detach();
    }

    my $stock_geo_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property');

    my $upload_plot_gps_txn = sub {
        my %plot_stock_ids_hash;
        while (my ($key, $val) = each(%$parsed_data)){
            $plot_stock_ids_hash{$val->{plot_stock_id}} = $val;
        }
        my @plot_stock_ids = keys %plot_stock_ids_hash;
        my $plots_rs = $schema->resultset("Stock::Stock")->search({stock_id => {-in=>\@plot_stock_ids}});
        while (my $plot=$plots_rs->next){
            my $coords = $plot_stock_ids_hash{$plot->stock_id};
            my $geo_json = {
                "type"=> "Feature",
                "geometry"=> {
                    "type"=> "Polygon",
                    "coordinates"=> [
                        [
                            [$coords->{WGS84_bottom_left_x}, $coords->{WGS84_bottom_left_y}],
                            [$coords->{WGS84_bottom_right_x}, $coords->{WGS84_bottom_right_y}],
                            [$coords->{WGS84_top_right_x}, $coords->{WGS84_top_right_y}],
                            [$coords->{WGS84_top_left_x}, $coords->{WGS84_top_left_y}],
                            [$coords->{WGS84_bottom_left_x}, $coords->{WGS84_bottom_left_y}],
                        ]
                    ]
                },
                "properties"=> {
                    "format"=> "WGS84",
                }
            };
            my $geno_json_string = encode_json $geo_json;
            #print STDERR $geno_json_string."\n";
            my $previous_plot_gps_rs = $schema->resultset("Stock::Stockprop")->search({stock_id=>$plot->stock_id, type_id=>$stock_geo_json_cvterm->cvterm_id});
            $previous_plot_gps_rs->delete_all();
            $plot->create_stockprops({$stock_geo_json_cvterm->name() => $geno_json_string});
        }
        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_plot_gps_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial plot GPS coordinates. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

    $c->stash->{rest} = { success => 1 };
}

sub trial_additional_file_upload : Chained('trial') PathPart('upload_additional_file') Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload additional trials to a file!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload additional files to a trial!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $upload = $c->req->upload('trial_upload_additional_file');
    my $subdirectory = "trial_additional_file_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $md5checksum = $md5->hexdigest();

    my $result = $c->stash->{trial}->add_additional_uploaded_file($user_id, $archived_filename_with_path, $md5checksum);
    if ($result->{error}){
        $c->stash->{rest} = {error=>$result->{error}};
        $c->detach();
    }
    $c->stash->{rest} = { success => 1, file_id => $result->{file_id} };
}

sub get_trial_additional_file_uploaded : Chained('trial') PathPart('get_uploaded_additional_file') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to see uploaded additional files!'};
        $c->detach();
    }

    my $files = $c->stash->{trial}->get_additional_uploaded_files();
    $c->stash->{rest} = {success=>1, files=>$files};
}

sub trial_controls : Chained('trial') PathPart('controls') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls();

    $c->stash->{rest} = { accessions => \@data };
}

sub controls_by_plot : Chained('trial') PathPart('controls_by_plot') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my @plot_ids = $c->req->param('plot_ids[]');

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls_by_plot(\@plot_ids);

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_plots : Chained('trial') PathPart('plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};

    my @data = $trial->get_plots();

    $c->stash->{rest} = { plots => \@data };
}

sub trial_has_subplots : Chained('trial') PathPart('has_subplots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_subplots => $trial->has_subplot_entries(), trial_name => $trial->get_name };
}

sub trial_subplots : Chained('trial') PathPart('subplots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};

    my @data = $trial->get_subplots();

    $c->stash->{rest} = { subplots => \@data };
}

sub trial_has_plants : Chained('trial') PathPart('has_plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_plants => $trial->has_plant_entries(), trial_name => $trial->get_name };
}

sub trial_plants : Chained('trial') PathPart('plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};

    my @data = $trial->get_plants();

    $c->stash->{rest} = { plants => \@data };
}

sub trial_has_tissue_samples : Chained('trial') PathPart('has_tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_tissue_samples => $trial->has_tissue_sample_entries(), trial_name => $trial->get_name };
}

sub trial_tissue_samples : Chained('trial') PathPart('tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};

    my $data = $trial->get_tissue_samples();

    $c->stash->{rest} = { trial_tissue_samples => $data };
}

sub trial_treatments : Chained('trial') PathPart('treatments') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = $c->stash->{trial};

    my $data = $trial->get_treatments();

    $c->stash->{rest} = { treatments => $data };
}

sub trial_add_treatment : Chained('trial') PathPart('add_treatment') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = {error => "You must be logged in to add a treatment"};
        $c->detach();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};
    my $design = decode_json $c->req->param('design');
    my $new_treatment_has_plant_entries = $c->req->param('has_plant_entries');
    my $new_treatment_has_subplot_entries = $c->req->param('has_subplot_entries');
    my $new_treatment_has_tissue_entries = $c->req->param('has_tissue_sample_entries');

    my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
		bcs_schema => $schema,
		trial_id => $trial_id,
        trial_name => $trial->get_name(),
		nd_geolocation_id => $trial->get_location()->[0],
		design_type => $trial->get_design_type(),
		design => $design,
        new_treatment_has_plant_entries => $new_treatment_has_plant_entries,
        new_treatment_has_subplot_entries => $new_treatment_has_subplot_entries,
        new_treatment_has_tissue_sample_entries => $new_treatment_has_subplot_entries,
        operator => $c->user()->get_object()->get_username()
	});
    my $error = $trial_design_store->store();
    if ($error){
        $c->stash->{rest} = {error => "Treatment not added: ".$error};
    } else {
        $c->stash->{rest} = {success => 1};
    }
}

sub trial_layout : Chained('trial') PathPart('layout') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout = $c->stash->{trial_layout};

    my $design = $layout->get_design();
    $c->stash->{rest} = {design => $design};
}

sub trial_design : Chained('trial') PathPart('design') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout = $c->stash->{trial_layout};

    my $design = $layout->get_design();
    my $design_type = $layout->get_design_type();
    my $plot_dimensions = $layout->get_plot_dimensions();

    my $plot_length = $plot_dimensions->[0] ? $plot_dimensions->[0] : '';
    my $plot_width = $plot_dimensions->[1] ? $plot_dimensions->[1] : '';
    my $plants_per_plot = $plot_dimensions->[2] ? $plot_dimensions->[2] : '';

    my $block_numbers = $layout->get_block_numbers();
    my $number_of_blocks = '';
    if ($block_numbers) {
        $number_of_blocks = scalar(@{$block_numbers});
    }

    my $replicate_numbers = $layout->get_replicate_numbers();
    my $number_of_replicates = '';
    if ($replicate_numbers) {
        $number_of_replicates = scalar(@{$replicate_numbers});
    }

    my $plot_names = $layout->get_plot_names();
    my $number_of_plots = '';
    if ($plot_names){
        $number_of_plots = scalar(@{$plot_names});
    }

    $c->stash->{rest} = {
        design_type => $design_type,
        num_blocks => $number_of_blocks,
        num_reps => $number_of_replicates,
        plot_length => $plot_length,
        plot_width => $plot_width,
        plants_per_plot => $plants_per_plot,
        total_number_plots => $number_of_plots,
        design => $design
    };
}

sub get_spatial_layout : Chained('trial') PathPart('coords') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $fieldmap = CXGN::Trial::FieldMap->new({
      bcs_schema => $schema,
      trial_id => $c->stash->{trial_id},
    });
    my $return = $fieldmap->display_fieldmap();

    $c->stash->{rest} = $return;
}

sub retrieve_trial_info :  Path('/ajax/breeders/trial_phenotyping_info') : ActionClass('REST') { }
sub retrieve_trial_info_POST : Args(0) {
#sub retrieve_trial_info : chained('trial') Pathpart("trial_phenotyping_info") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_id = $c->req->param('trial_id');
    my $layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout'});
  	my $design = $layout-> get_design();
    #print STDERR Dumper($design);

    my @layout_info;
  	foreach my $plot_number (keys %{$design}) {
  		push @layout_info, {
        plot_id => $design->{$plot_number}->{plot_id},
  		plot_number => $plot_number,
  		row_number => $design->{$plot_number}->{row_number},
  		col_number => $design->{$plot_number}->{col_number},
  		block_number=> $design->{$plot_number}-> {block_number},
  		rep_number =>  $design->{$plot_number}-> {rep_number},
  		plot_name => $design->{$plot_number}-> {plot_name},
  		accession_name => $design->{$plot_number}-> {accession_name},
  		plant_names => $design->{$plot_number}-> {plant_names},
  		};
        @layout_info = sort { $a->{plot_number} <=> $b->{plot_number} } @layout_info;
  	}

    #print STDERR Dumper(@layout_info);
    $c->stash->{rest} = {trial_info => \@layout_info};
    #$c->stash->{layout_info} = \@layout_info;
}


sub trial_completion_layout_section : Chained('trial') PathPart('trial_completion_layout_section') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $c->stash->{trial_id}, experiment_type => 'field_layout', verify_layout=>1, verify_physical_map=>1});
    my $trial_errors = $trial_layout->generate_and_cache_layout();
    my $has_layout_check = $trial_errors->{errors}->{layout_errors} || $trial_errors->{error} ? 0 : 1;
    my $has_physical_map_check = $trial_errors->{errors}->{physical_map_errors} || $trial_errors->{error} ? 0 : 1;
    my $has_seedlots = $trial_errors->{errors}->{seedlot_errors} || $trial_errors->{error} ? 0 : 1;
    my $error_string = $trial_errors->{error} ? $trial_errors->{error} : '';
    my $layout_error_string = $trial_errors->{errors}->{layout_errors} ? join ', ', @{$trial_errors->{errors}->{layout_errors}} : '';
    my $map_error_string = $trial_errors->{errors}->{physical_map_errors} ? join ', ', @{$trial_errors->{errors}->{physical_map_errors}} : '';
    my $seedlot_error_string = $trial_errors->{errors}->{seedlot_errors} ? join ', ', @{$trial_errors->{errors}->{seedlot_errors}} : '';

    $c->stash->{rest} = {
        has_layout => $has_layout_check,
        layout_errors => $error_string." ".$layout_error_string,
        has_physical_map => $has_physical_map_check,
        physical_map_errors => $error_string." ".$map_error_string,
        has_seedlots => $has_seedlots,
        seedlot_errors => $error_string." ".$seedlot_error_string
    };
}

sub trial_completion_phenotype_section : Chained('trial') PathPart('trial_completion_phenotype_section') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $phenotyping_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $has_phenotype_check = $schema->resultset('Phenotype::Phenotype')->search({'stock.type_id'=> [$plot_type_id, $plant_type_id], 'nd_experiment.type_id'=>$phenotyping_experiment_type_id, 'me.value' => { '!=' => ''}, 'project.project_id'=>$c->stash->{trial_id}}, {join=>{'nd_experiment_phenotypes'=>{'nd_experiment'=>[{'nd_experiment_stocks'=>'stock' }, {'nd_experiment_projects'=>'project'}] } }, rows=>1 });
    my $has_phenotypes = $has_phenotype_check->first ? 1 : 0;

    $c->stash->{rest} = {has_phenotypes => $has_phenotypes};
}

sub delete_field_coord : Path('/ajax/phenotype/delete_field_coords') Args(0) {
  my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');

  my $schema = $c->dbic_schema('Bio::Chado::Schema');

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to update this map." };
    return;
  }

  my $fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
  });
  my $delete_return_error = $fieldmap->delete_fieldmap();
  if ($delete_return_error) {
    $c->stash->{rest} = { error => $delete_return_error };
    return;
  }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');
    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout' });
    $trial_layout->generate_and_cache_layout();

    $c->stash->{rest} = {success => 1};
}

sub replace_trial_accession : Chained('trial') PathPart('replace_accession') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $old_accession_id = $c->req->param('old_accession_id');
  my $new_accession = $c->req->param('new_accession');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_accession){
    $c->stash->{rest} = { error => "Provide new accession name." };
    return;
  }

  my $replace_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    old_accession_id => $old_accession_id,
    new_accession => $new_accession,
  });

  my $return_error = $replace_accession_fieldmap->update_fieldmap_precheck();
     if ($return_error) {
       $c->stash->{rest} = { error => $return_error };
       return;
     }

  my $replace_return_error = $replace_accession_fieldmap->replace_trial_accession_fieldMap();
  if ($replace_return_error) {
    $c->stash->{rest} = { error => $replace_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $old_accession = $c->req->param('old_accession');
  my $new_accession = $c->req->param('new_accession');
  my $old_plot_id = $c->req->param('old_plot_id');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_accession){
    $c->stash->{rest} = { error => "Provide new accession name." };
    return;
  }

  my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    new_accession => $new_accession,
    old_accession => $old_accession,
    old_plot_id => $old_plot_id,

  });

  my $return_error = $replace_plot_accession_fieldmap->update_fieldmap_precheck();
     if ($return_error) {
       $c->stash->{rest} = { error => $return_error };
       return;
     }

  print "Calling Replace Function...............\n";
  my $replace_return_error = $replace_plot_accession_fieldmap->replace_plot_accession_fieldMap();
  if ($replace_return_error) {
    $c->stash->{rest} = { error => $replace_return_error };
    return;
  }

  print "OldAccession: $old_accession, NewAcc: $new_accession, OldPlotId: $old_plot_id\n";
  $c->stash->{rest} = { success => 1};
}

sub substitute_accession : Chained('trial') PathPart('substitute_accession') Args(0) {
  my $self = shift;
	my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $trial_id = $c->stash->{trial_id};
  my $plot_1_info = $c->req->param('plot_1_info');
  my $plot_2_info = $c->req->param('plot_2_info');

  my ($plot_1_id, $accession_1) = split /,/, $plot_1_info;
  my ($plot_2_id, $accession_2) = split /,/, $plot_2_info;

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to update this map." };
    return;
  }

  if ($plot_1_id == $plot_2_id){
    $c->stash->{rest} = { error => "Choose a different plot/accession in 'select Accession 2' to perform this operation." };
    return;
  }

  my @controls;
  my @ids;

  my $fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    first_plot_selected => $plot_1_id,
    second_plot_selected => $plot_2_id,
    first_accession_selected => $accession_1,
    second_accession_selected => $accession_2,
  });

  my $return_error = $fieldmap->update_fieldmap_precheck();
  if ($return_error) {
    $c->stash->{rest} = { error => $return_error };
    return;
  }

  my $return_check_error = $fieldmap->substitute_accession_precheck();
  if ($return_check_error) {
    $c->stash->{rest} = { error => $return_check_error };
    return;
  }

  my $update_return_error = $fieldmap->substitute_accession_fieldmap();
  if ($update_return_error) {
    $c->stash->{rest} = { error => $update_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub create_plant_subplots : Chained('trial') PathPart('create_plant_entries') Args(0) {
    my $self = shift;
    my $c = shift;
    my $plants_per_plot = $c->req->param("plants_per_plot") || 8;
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $plants_with_treatments;
    if($inherits_plot_treatments eq '1'){
        $plants_with_treatments = 1;
    }

    if (my $error = $self->privileges_denied($c)) {
	$c->stash->{rest} = { error => $error };
	return;
    }

    if (!$plants_per_plot || $plants_per_plot > 50) {
	$c->stash->{rest} = { error => "Plants per plot number is required and must be smaller than 50." };
	return;
    }

    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $c->stash->{trial_id} });

    if ($t->create_plant_entities($plants_per_plot, $plants_with_treatments)) {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

        $c->stash->{rest} = {success => 1};
        return;
    } else {
        $c->stash->{rest} = { error => "Error creating plant entries in controller." };
    	return;
    }

}

sub create_tissue_samples : Chained('trial') PathPart('create_tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tissues_per_plant = $c->req->param("tissue_samples_per_plant") || 3;
    my $tissue_names = decode_json $c->req->param("tissue_samples_names");
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $tissues_with_treatments;
    if($inherits_plot_treatments eq '1'){
        $tissues_with_treatments = 1;
    }

    if (my $error = $self->privileges_denied($c)) {
        $c->stash->{rest} = { error => $error };
        $c->detach;
    }

    if (!$c->stash->{trial}->has_plant_entries){
        $c->stash->{rest} = { error => "Trial must have plant entries before you can add tissue samples entries. Plant entries are added from the trial detail page." };
        $c->detach;
    }

    if (!$tissue_names || scalar(@$tissue_names) < 1){
        $c->stash->{rest} = { error => "You must provide tissue name(s) for your samples" };
        $c->detach;
    }

    if (!$tissues_per_plant || $tissues_per_plant > 50) {
        $c->stash->{rest} = { error => "Tissues per plant is required and must be smaller than 50." };
        $c->detach;
    }

    my $t = CXGN::Trial->new({ bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $c->stash->{trial_id} });

    if ($t->create_tissue_samples($tissue_names, $inherits_plot_treatments)) {
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

        $c->stash->{rest} = {success => 1};
        $c->detach;;
    } else {
        $c->stash->{rest} = { error => "Error creating tissues samples in controller." };
        $c->detach;;
    }

}

sub privileges_denied {
    my $self = shift;
    my $c = shift;

    my $trial_id = $c->stash->{trial_id};

    if (! $c->user) { return "Login required for modifying trial."; }
    my $user_id = $c->user->get_object->get_sp_person_id();

    if ($c->user->check_roles('curator')) {
	     return 0;
    }

    my $breeding_programs = $c->stash->{trial}->get_breeding_programs();

    if ( ($c->user->check_roles('submitter')) && ( $c->user->check_roles($breeding_programs->[0]->[1]))) {
	return 0;
    }
    return "You have insufficient privileges to modify or delete this trial.";
}

# loading field coordinates

sub upload_trial_coordinates : Path('/ajax/breeders/trial/coordsupload') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
    	print STDERR "User not logged in... not uploading coordinates.\n";
    	$c->stash->{rest} = {error => "You need to be logged in to upload coordinates." };
    	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    	$c->stash->{rest} = {error =>  "You have insufficient privileges to add coordinates." };
    	return;
    }

    my $time = DateTime->now();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'trial_coords_upload';
    my $upload = $c->req->upload('trial_coordinates_uploaded_file');
    my $trial_id = $c->req->param('trial_coordinates_upload_trial_id');
    my $upload_tempfile  = $upload->tempname;
    my $upload_original_name  = $upload->filename();
    my $md5;
    my %upload_metadata;

    # Store uploaded temporary file in archive
    print STDERR "TEMP FILE: $upload_tempfile\n";
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $c->user()->roles
    });
    my $archived_filename_with_path = $uploader->archive();

    if (!$archived_filename_with_path) {
    	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
    	return;
    }

    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;

    my $error_string = '';
   # open file and remove return of line
    open(my $F, "<", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $header = <$F>;
    while (<$F>) {
    	chomp;
    	$_ =~ s/\r//g;
    	my ($plot,$row,$col) = split /\t/ ;
    	my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $plot });
    	if ($rs->count()== 1) {
      	my $r =  $rs->first();
      	print STDERR "The plots $plot was found.\n Loading row $row col $col\n";
      	$r->create_stockprops({row_number => $row, col_number => $col}, {autocreate => 1});
      }
      else {
      	print STDERR "WARNING! $plot was not found in the database.\n";
        $error_string .= "WARNING! $plot was not found in the database.";
      }
    }

    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id, experiment_type => 'field_layout' });
    $trial_layout->generate_and_cache_layout();

    if ($error_string){
        $c->stash->{rest} = {error_string => $error_string};
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop');

    $c->stash->{rest} = {success => 1};
}

sub crosses_in_trial : Chained('trial') PathPart('crosses_in_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({bcs_schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_crosses_in_trial();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_type, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name) =@$r;
        push @crosses, [qq{<a href = "/cross/$cross_id">$cross_name</a>},
        qq{<a href = "/stock/$female_parent_id/view">$female_parent_name</a>},
        qq{<a href = "/stock/$male_parent_id/view">$male_parent_name</a>}, $cross_type,
        qq{<a href = "/stock/$female_plot_id/view">$female_plot_name</a>},
        qq{<a href = "/stock/$male_plot_id/view">$male_plot_name</a>}];
    }

    $c->stash->{rest} = { data => \@crosses };
}

sub cross_properties_trial : Chained('trial') PathPart('cross_properties_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({bcs_schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_cross_properties_trial();

    my $cross_properties = $c->config->{cross_properties};
    my @column_order = split ',', $cross_properties;

    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_props_hash) =@$r;

        my @row = ( qq{<a href = "/cross/$cross_id">$cross_name</a>} );
        foreach my $key (@column_order){
          push @row, $cross_props_hash->{$key};
        }

        push @crosses, \@row;
    }

    $c->stash->{rest} = { data => \@crosses };
}

sub cross_progenies_trial : Chained('trial') PathPart('cross_progenies_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({bcs_schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_cross_progenies_trial();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $progeny_number) =@$r;
        push @crosses, [qq{<a href = "/cross/$cross_id">$cross_name</a>}, $progeny_number];
    }

    $c->stash->{rest} = { data => \@crosses };
}


sub phenotype_heatmap : Chained('trial') PathPart('heatmap') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->req->param("selected");

    # my $phenotypes_heatmap = CXGN::Phenotypes::TrialPhenotype->new({
    # 	bcs_schema=>$schema,
    # 	trial_id=>$trial_id,
    #     trait_id=>$trait_id
    # });
    # my $phenotype = $phenotypes_heatmap->get_trial_phenotypes_heatmap();

    my @items = map {@{$_}[0]} @{$c->stash->{trial}->get_plots()};
    #print STDERR Dumper(\@items);
    my @trait_ids = ($trait_id);
    
    my $layout = $c->stash->{trial_layout};
    my $design_type = $layout->get_design_type();

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        "MaterializedView",
        {
            bcs_schema=> $schema,
            data_level=> 'plot',
            trait_list=> \@trait_ids,
            plot_list=>  \@items,
            include_row_and_column_numbers=> 1
        }
    );
    my $data = $phenotypes_search->search();
    my (@col_No, @row_No, @pheno_val, @plot_Name, @stock_Name, @plot_No, @block_No, @rep_No, @msg, $result, @phenoID);
    foreach my $d (@$data) {
        my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $rep, $block_number, $plot_number, $row_number, $col_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $timestamp_value, $synonyms, $design, $stock_type_name, $phenotype_id, $full_count) = @$d;
        if (!$row_number && !$col_number){
			if ($block_number && $design_type ne 'splitplot'){
				$row_number = $block_number;
			}elsif ($rep && !$block_number && $design_type ne 'splitplot'){
				$row_number = $rep;
			}elsif ($design_type eq 'splitplot'){
                $row_number = $rep;
            }
		}

        my $plot_popUp = $plot_name."\nplot_No:".$plot_number."\nblock_No:".$block_number."\nrep_No:".$rep."\nstock:".$stock_name."\nvalue:".$value;
        push @$result,  {plotname => $plot_name, stock => $stock_name, plotn => $plot_number, blkn=>$block_number, rep=>$rep, row=>$row_number, col=>$col_number, pheno=>$value, plot_msg=>$plot_popUp, pheno_id=>$phenotype_id} ;
		if ($col_number){
            push @col_No, $col_number;
        }
		push @row_No, $row_number;
		push @pheno_val, $value;
		push @plot_Name, $plot_name;
		push @stock_Name, $stock_name;
		push @plot_No, $plot_number;
		push @block_No, $block_number;
		push @rep_No, $rep;
        push @phenoID, $phenotype_id;
    }

    my $false_coord;
	if (!$col_No[0]){
        @col_No = ();
        $false_coord = 'false_coord';
		my @row_instances = uniq @row_No;
		my %unique_row_counts;
		$unique_row_counts{$_}++ for @row_No;
        my @col_number2;
        for my $key (keys %unique_row_counts){
            push @col_number2, (1..$unique_row_counts{$key});
        }
        for (my $i=0; $i < scalar(@$result); $i++){
            @$result[$i]->{'col'} = $col_number2[$i];
            push @col_No, $col_number2[$i];
        }
	}

    my ($min_col, $max_col) = minmax @col_No;
	my ($min_row, $max_row) = minmax @row_No;
	my (@unique_col,@unique_row);
	for my $x (1..$max_col){
		push @unique_col, $x;
	}
	for my $y (1..$max_row){
		push @unique_row, $y;
	}

    my $trial = CXGN::Trial->new({
		bcs_schema => $schema,
		trial_id => $trial_id
	});
	my $data_check = $trial->get_controls();
	my @control_name;
	foreach my $cntrl (@{$data_check}) {
		push @control_name, $cntrl->{'accession_name'};
	}
    #print STDERR Dumper($result);
    $c->stash->{rest} = { #phenotypes => $phenotype,
                            col => \@col_No,
                            row => \@row_No,
                            pheno => \@pheno_val,
                            plotName => \@plot_Name,
                            stock => \@stock_Name,
                            plot => \@plot_No,
                            block => \@block_No,
                            rep => \@rep_No,
                            result => $result,
                            plot_msg => \@msg,
                            col_max => $max_col,
                            row_max => $max_row,
                            unique_col => \@unique_col,
                            unique_row => \@unique_row,
                            false_coord => $false_coord,
                            phenoID => \@phenoID,
                            controls => \@control_name
                        };
}

sub get_suppress_plot_phenotype : Chained('trial') PathPart('suppress_phenotype') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $plot_name = $c->req->param('plot_name');
  my $plot_pheno_value = $c->req->param('phenotype_value');
  my $trait_id = $c->req->param('trait_id');
  my $phenotype_id = $c->req->param('phenotype_id');
  my $trial_id = $c->stash->{trial_id};
  my $trial = $c->stash->{trial};
  my $user_name = $c->user()->get_object()->get_username();
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to suppress this phenotype." };
    return;
  }

  my $suppress_return_error = $trial->suppress_plot_phenotype($trait_id, $plot_name, $plot_pheno_value, $phenotype_id, $user_name, $timestamp);
  if ($suppress_return_error) {
    $c->stash->{rest} = { error => $suppress_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub delete_single_assayed_trait : Chained('trial') PathPart('delete_single_trait') Args(0) {
    my $self = shift;
    my $c = shift;
    my $pheno_ids = $c->req->param('pheno_id');
    my $trait_ids = $c->req->param('traits_id');
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $trial = $c->stash->{trial};

    if (!$c->user()) {
    	print STDERR "User not logged in... not deleting trait.\n";
    	$c->stash->{rest} = {error => "You need to be logged in to delete trait." };
    	return;
    }

    if ($self->privileges_denied($c)) {
      $c->stash->{rest} = { error => "You have insufficient access privileges to delete assayed trait for this trial." };
      return;
    }

    my $delete_trait_return_error;
    if ($pheno_ids){
            my $phenotypes_ids = JSON::decode_json($pheno_ids);
         $delete_trait_return_error = $trial->delete_assayed_trait($phenotypes_ids, [] );
    }
    if ($trait_ids){
        my $traits_ids = JSON::decode_json($trait_ids);
         $delete_trait_return_error = $trial->delete_assayed_trait([], $traits_ids );
    }

    if ($delete_trait_return_error) {
      $c->stash->{rest} = { error => $delete_trait_return_error };
      return;
    }

    $c->stash->{rest} = { success => 1};
}

sub retrieve_plot_image : Chained('trial') PathPart('retrieve_plot_images') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $image_ids =  decode_json $c->req->param('image_ids');
  my $plot_name = $c->req->param('plot_name');
  my $plot_id = $c->req->param('plot_id');
  my $trial_id = $c->stash->{trial_id};
  my $stockref;
  my $image_objects;
  my $dbh = $c->dbc->dbh;
  $stockref->{dbh} = $dbh;
  $stockref->{image_ids} =  $image_ids || [] ;
  my $images = $stockref->{image_ids};
  $dbh = $stockref->{dbh};

  #print STDERR Dumper($stockref);
  print "$plot_name and $plot_id and $image_ids\n";
  
  my $image_html     = "";
  my $m_image_html   = "";
  my $count;
  my @more_is; 

  if ($images && !$image_objects) {
    my @image_object_list = map { SGN::Image->new( $dbh , $_ ) }  @$images ;
    $image_objects = \@image_object_list;
  }

  if ($image_objects)  { # don't display anything for empty list of images
    $image_html .= qq|<table cellpadding="5">|;
    foreach my $image_ob (@$image_objects) {
      $count++;
      my $image_id = $image_ob->get_image_id;
      my $image_name = $image_ob->get_name();
      my $image_description = $image_ob->get_description();
      my $image_img  = $image_ob->get_image_url("medium");
      my $small_image = $image_ob->get_image_url("thumbnail");
      my $image_page  = "/image/view/$image_id";
      
      my $colorbox = 
        qq|<a href="$image_img"  class="stock_image_group" rel="gallery-figures"><img src="$small_image" alt="$image_description" onclick="close_view_plot_image_dialog()"/></a> |;
      my $fhtml =
        qq|<tr><td width=120>|
          . $colorbox
            . $image_name
              . "</td><td>"
                . $image_description
                  . "</td></tr>";
      if ( $count < 3 ) { $image_html .= $fhtml; }
      else {
        push @more_is, $fhtml;
      }    #more than 3 figures- show these in a hidden div
        }
    $image_html .= "</table>";  #close the table tag or the first 3 figures

    $image_html .= "<script> jQuery(document).ready(function() { jQuery('a.stock_image_group').colorbox(); }); </script>\n";

  }
  $m_image_html .=
    "<table cellpadding=5>";  #open table tag for the hidden figures #4 and on
  my $more = scalar(@more_is);
  foreach (@more_is) { $m_image_html .= $_; }

  $m_image_html .= "</table>";    #close tabletag for the hidden figures

  if (@more_is) {    #html_optional_show if there are more than 3 figures
    $image_html .= html_optional_show(
  				    "Images",
  				    "<b>See $more more images...</b>",
  				    qq| $m_image_html |,
  				    0, #< do not show by default
  				    'abstract_optional_show', #< don't use the default button-like style
  				   );
  }
 
  $c->stash->{rest} = { image_html => $image_html};
}

sub field_trial_from_field_trial : Chained('trial') PathPart('field_trial_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $source_field_trials_for_this_trial = $c->stash->{trial}->get_field_trials_source_field_trials();
    my $field_trials_sourced_from_this_trial = $c->stash->{trial}->get_field_trials_sourced_from_field_trials();

    $c->stash->{rest} = {success => 1, source_field_trials => $source_field_trials_for_this_trial, field_trials_sourced => $field_trials_sourced_from_this_trial};
}

sub genotyping_trial_from_field_trial : Chained('trial') PathPart('genotyping_trial_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $genotyping_trials_from_field_trial = $c->stash->{trial}->get_genotyping_trials_from_field_trial();
    my $field_trials_source_of_genotyping_trial = $c->stash->{trial}->get_field_trials_source_of_genotyping_trial();

    $c->stash->{rest} = {success => 1, genotyping_trials_from_field_trial => $genotyping_trials_from_field_trial, field_trials_source_of_genotyping_trial => $field_trials_source_of_genotyping_trial};
}

sub crossing_trial_from_field_trial : Chained('trial') PathPart('crossing_trial_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $crossing_trials_from_field_trial = $c->stash->{trial}->get_crossing_trials_from_field_trial();
    my $field_trials_source_of_crossing_trial = $c->stash->{trial}->get_field_trials_source_of_crossing_trial();

    $c->stash->{rest} = {success => 1, crossing_trials_from_field_trial => $crossing_trials_from_field_trial, field_trials_source_of_crossing_trial => $field_trials_source_of_crossing_trial};
}

1;
