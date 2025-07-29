package SGN::Controller::AJAX::TrialMetadata;

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use CXGN::Trial;
use CXGN::Trial::TrialLookup;
use CXGN::Trial::Search;
use Math::Round::Var;
use File::Temp 'tempfile';
use Text::CSV;
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
use File::Slurp qw | read_file |;
use List::MoreUtils qw | :all !before !after |;
use Try::Tiny;
use CXGN::BreederSearch;
use CXGN::Page::FormattingHelpers qw / html_optional_show /;
use SGN::Image;
use CXGN::Trial::TrialLayoutDownload;
use CXGN::Genotype::DownloadFactory;
use POSIX qw | !qsort !bsearch |;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use Statistics::Descriptive::Full;
use CXGN::TrialStatus;
use CXGN::BreedersToolbox::SoilData;
use CXGN::Genotype::GenotypingProject;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    print STDERR "This is sp_person_id from trial detail edit: $sp_person_id \n";
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);

    my $people_schema = $c->dbic_schema('CXGN::People::Schema');

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{schema} =  $bcs_schema;
    $c->stash->{trial} = CXGN::Trial->new({
        bcs_schema => $bcs_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        people_schema => $people_schema,
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
	# print STDERR "Trial Layout: ".Dumper($c->stash->{trial_layout})."\n";
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

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);

    if ($self->privileges_denied($c)) {
        $c->stash->{rest} = { error => "You have insufficient access privileges to delete trial data." };
        return;
    }

    my $error = "";

    if ($datatype eq 'phenotypes') {
        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

        $error = $c->stash->{trial}->delete_phenotype_metadata($metadata_schema, $phenome_schema);
        $error .= $c->stash->{trial}->delete_phenotype_data($c->config->{basepath}, $c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, $temp_file_nd_experiment_id);
    }

    elsif ($datatype eq 'layout') {

        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $drone_image_check_q = "SELECT count(subject_project_id) FROM project_relationship WHERE object_project_id = ? AND type_id = ?;";
        my $drone_image_check_h = $schema->storage->dbh()->prepare($drone_image_check_q);;
        $drone_image_check_h->execute($c->stash->{trial_id}, $project_relationship_type_id);
        my ($drone_run_count) = $drone_image_check_h->fetchrow_array();

        if ($drone_run_count > 0) {
            $c->stash->{rest} = { error => "Please delete the imaging events belonging to this field trial first!" };
            return;
        }

        $error = $c->stash->{trial}->delete_metadata();
        $error .= $c->stash->{trial}->delete_field_layout();
        $error .= $c->stash->{trial}->delete_project_entry();

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});
    }
    elsif ($datatype eq 'entry') {
        $error = $c->stash->{trial}->delete_project_entry();
    }
    elsif ($datatype eq 'crossing_experiment') {
        $error = $c->stash->{trial}->delete_empty_crossing_experiment();
    }
    elsif ($datatype eq 'genotyping_project') {
        $error = $c->stash->{trial}->delete_empty_genotyping_project();
    }
    elsif ($datatype eq 'transformation_project') {
        $error = $c->stash->{trial}->delete_empty_transformation_project();
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

sub trial_details_GET{
    my $self = shift;
    my $c = shift;

    my $trial = $c->stash->{trial};
    my $planting_date = $trial->get_planting_date();
    my $transplanting_date = $trial->get_transplanting_date();
    my $harvest_date = $trial->get_harvest_date();
    my $get_location_noaa_station_id = $trial->get_location_noaa_station_id();

    $c->stash->{rest} = {
        details => {
            planting_date => $planting_date,
            transplanting_date => $transplanting_date,
            harvest_date => $harvest_date,
            location_noaa_station_id => $get_location_noaa_station_id
        }
    };

}

sub trial_details_POST  {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

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

    # policy: curators can change without breeding program association
    # submitters can change if they are associated with the breeding program
    # users cannot change

    if (! ( (exists($has_roles{$breeding_program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {

#    if (!exists($has_roles{$breeding_program_name})) {
      $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $breeding_program_name to change the details of this trial." };
      return;
    }

    # set each new detail that is defined
    #print STDERR Dumper $details;

    my $dbh = $trial->bcs_schema->storage->dbh;

    my $logged_in_user_q = "select * from logged_in_user";
    my $logged_in_user_h = $dbh -> prepare($logged_in_user_q);
    $logged_in_user_h->execute();
    my $logged_in_user_arr = $logged_in_user_h->fetchall_arrayref();
    print STDERR "logged in user TrialMetadata.pm BEFORE EVAL: ".Dumper($logged_in_user_arr)."\n";


    my $error = $trial->update_metadata($details);
    if ($error) {
        $c->stash->{rest} = { error => $error };
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
    my $start_date = $c->req->param('start_date');
    my $end_date = $c->req->param('end_date');
    my $include_dateless_items = $c->req->param('include_dateless_items');

    # print STDERR "trait_phenotypes START DATE $start_date; and the END DATE $end_date\n";

    #get userinfo from db
    my $user = $c->user();
    if (! $c->user) {
      $c->stash->{rest} = {
        status => "not logged in"
      };
      return;
    }
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $display = $c->req->param('display');
    my $trait = $c->req->param('trait');

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
    my $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_of', 'stock_relationship')->cvterm_id();

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=> $schema,
        search_type => "Native",
        data_level => $display,
        trait_list=> [$trait],
        trial_list => [$c->stash->{trial_id}],
	    start_date => $start_date,
	    end_date => $end_date,
	    include_dateless_items => $include_dateless_items,
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
    my $trial_stock_type = $c->req->param('trial_stock_type');
    my $start_date = $c->req->param('start_date');
    my $end_date = $c->req->param('end_date');
    my $include_dateless_items = $c->req->param('include_dateless_items');
    my $select_clause_additional = '';
    my $group_by_additional = '';
    my $order_by_additional = '';
    my $stock_type_id;
    my $rel_type_id;
    my $total_complete_number;
    # print STDERR "trial phenotypes: START DATE: $start_date. END DATE: $end_date, INLCUDE DATELESS $include_dateless_items, DIPLAY = $display\n";
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
    if ($display eq 'tissue_samples') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
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
    if ($display eq 'tissue_samples_accession') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
        $select_clause_additional = ', accession.uniquename, accession.stock_id';
        $group_by_additional = ', accession.stock_id, accession.uniquename';
        $stocks_per_accession = $c->stash->{trial}->get_plants_per_accession();
        $order_by_additional = ' ,accession.uniquename DESC';
    }

    if ($display eq 'analysis_instance') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_of', 'stock_relationship')->cvterm_id();
    }

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $trial_stock_type_id;

    if ($trial_stock_type eq 'family_name') {
        $trial_stock_type_id = $family_name_type_id;
    } elsif ($trial_stock_type eq 'cross') {
        $trial_stock_type_id = $cross_type_id;
    }
    else {
        $trial_stock_type_id = $accession_type_id;
        if ($display eq 'analysis_instance') {
            my $analysis_stock_type = $self->get_analysis_instance_stock_type($c, $trial_id);
            if ($analysis_stock_type eq 'analysis_result') {
                my $analysis_result_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_result', 'stock_type')->cvterm_id();
                $trial_stock_type_id = $analysis_result_type_id;
            }
        }
    }

    my $date_params = "";
    my @date_placeholders = ();
    my $datelessq = "";

    if ($include_dateless_items) {
	$datelessq = " ( collect_date IS NULL) ";
    }
    if ($start_date && $end_date) {
	$start_date =~ s/(.*)[ T]+.*$/$1/g;
	$end_date =~ s/(.*)[ T]+.*$/$1/g;

	# print STDERR "START DATE $start_date  END DATE: $end_date\n";
	if ($datelessq) {
	    $date_params = " AND ( $datelessq OR ( collect_date::date >= ? and collect_date::date <= ?)) ";
	}
	else { 
	    $date_params = " AND ( collect_date::date >= ? and collect_date::date <= ?) ";
	}
	@date_placeholders = ($start_date, $end_date);
    }

    # print STDERR "date params : $date_params\n";

    my $q1 = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
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
            $date_params
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id $group_by_additional
        ORDER BY cvterm.name ASC
    $order_by_additional ";
        
    my $h1 = $dbh->prepare($q1);
    
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
    
    # print STDERR "TRIAL ID = ".$c->stash->{trial_id}." REGEX: $numeric_regex REL_TYPE_ID $rel_type_id STOCK TYPE ID $stock_type_id DATE PLACE HOLDERS: ".join(", ", @date_placeholders)."\n";
    
    $h1->execute($c->stash->{trial_id}, $numeric_regex, $rel_type_id, $stock_type_id, $trial_stock_type_id, @date_placeholders);

    my @phenotype_data;
    my @numeric_trait_ids;

    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id) = $h1->fetchrow_array()) {
	
	push @numeric_trait_ids, $trait_id;
	
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
        if ($total_complete_number > $count){
            $percent_missing = sprintf("%.2f", 100 -(($count/$total_complete_number)*100))."%";
        } else {
            $percent_missing = "0%";
        }

        push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count, $percent_missing, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} );
        push @phenotype_data, \@return_array;
    }

    # get data from the non-numeric trait ids
    #

    # prevent sql statement from failing if there are no numeric traits
    #
    my $exclude_numeric_trait_ids = "";
    if (@numeric_trait_ids) {
	$exclude_numeric_trait_ids = " AND cvterm.cvterm_id NOT IN (".join(",", @numeric_trait_ids).")";
    }

    # print STDERR "run the non-numeric query\n";
    my $q = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value)
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
            AND stock_relationship.type_id=?
            AND plot.type_id=?
            AND accession.type_id=?
            $date_params
	     	$exclude_numeric_trait_ids
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id $group_by_additional
        ORDER BY cvterm.name ASC
        $order_by_additional ";

        # print STDERR "QUERY = $q\n";
    
    my $h = $dbh->prepare($q);
    
    $h->execute($c->stash->{trial_id}, $rel_type_id, $stock_type_id, $trial_stock_type_id, @date_placeholders);

    while (my ($trait, $trait_id, $count, $stock_name, $stock_id) = $h->fetchrow_array()) {
	my @return_array;
	push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, "NA", "NA", "NA", "NA", "NA", $count, "NA", qq{<span class="glyphicon glyphicon-stats"></span></a>} );
        push @phenotype_data, \@return_array;
    }
    
    $c->stash->{rest} = { data => \@phenotype_data };
}

sub trait_histogram : Chained('trial') PathPart('trait_histogram') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    my $stock_type = $c->req->param('stock_type') || 'plot';
    my $start_date = $c->req->param('start_date');
    my $end_date = $c->req->param('end_date');

    my @data = $c->stash->{trial}->get_phenotypes_for_trait($trait_id, $stock_type, $start_date, $end_date);

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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_accessions();

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_stocks : Chained('trial') PathPart('stocks') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my $stocks = $trial->get_accessions();

    $c->stash->{rest} = { data => $stocks };
}

sub trial_tissue_sources : Chained('trial') PathPart('tissue_sources') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });
    my $data = $trial->get_tissue_sources();
    #print STDERR Dumper $data;
    $c->stash->{rest} = { tissue_sources => $data };
}

sub trial_seedlots : Chained('trial') PathPart('seedlots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

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

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plants info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plants info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
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
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_plant_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
            push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_names}}, $_->{plant_name};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_entries(\%plot_plant_hash, $plants_per_plot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants_subplot : Chained('trial') PathPart('upload_plants_subplot') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plants info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plants info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_plants_subplot_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_per_subplot_inherit_treatments');
    my $plants_per_subplot = $c->req->param('upload_plants_per_subplot_number');

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
    $parser->load_plugin('TrialPlantsSubplotXLS');
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
        $c->stash->{rest} = {error_string => $return_error, missing_subplots => $parse_errors->{'missing_subplots'}};
        $c->detach();
    }

    my $upload_plants_txn = sub {
        my %subplot_plant_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $subplot_plant_hash{$_->{subplot_stock_id}}->{subplot_name} = $_->{subplot_name};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
            push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_names}}, $_->{plant_name};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_subplot_entries(\%subplot_plant_hash, $plants_per_subplot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_subplots : Chained('trial') PathPart('upload_subplots') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplots info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplots info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_subplots_file');
    my $inherits_plot_treatments = $c->req->param('upload_subplots_per_plot_inherit_treatments');
    my $subplots_per_plot = $c->req->param('upload_subplots_per_plot_number');

    my $subdirectory = "trial_subplots_upload";
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
    $parser->load_plugin('TrialSubplotsXLS');
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

    my $upload_subplots_txn = sub {
        my %plot_subplot_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_subplot_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            push @{$plot_subplot_hash{$_->{plot_stock_id}}->{subplot_names}}, $_->{subplot_name};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_subplot_entries(\%plot_subplot_hash, $subplots_per_plot, $inherits_plot_treatments, $user_id);

        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_subplots_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial subplots. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants_with_index_number : Chained('trial') PathPart('upload_plants_with_plant_index_number') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_plants_with_index_number_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_with_index_number_inherit_treatments');
    my $plants_per_plot = $c->req->param('upload_plants_with_index_number_per_plot_number');

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
    $parser->load_plugin('TrialPlantsWithPlantNumberXLS');
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
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_plant_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_names}}, $_->{plant_name};
            push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_index_numbers}}, $_->{plant_index_number};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_entries(\%plot_plant_hash, $plants_per_plot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants_subplot_with_index_number : Chained('trial') PathPart('upload_plants_subplot_with_plant_index_number') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_plants_subplot_with_index_number_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_subplot_with_index_number_inherit_treatments');
    my $plants_per_subplot = $c->req->param('upload_plants_subplot_with_index_number_per_subplot_number');

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
    $parser->load_plugin('TrialPlantsSubplotWithPlantNumberXLS');
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
        $c->stash->{rest} = {error_string => $return_error, missing_subplots => $parse_errors->{'missing_subplots'}};
        $c->detach();
    }

    my $upload_plants_txn = sub {
        my %subplot_plant_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $subplot_plant_hash{$_->{subplot_stock_id}}->{subplot_name} = $_->{subplot_name};
            push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_names}}, $_->{plant_name};
            push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_index_numbers}}, $_->{plant_index_number};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_subplot_entries(\%subplot_plant_hash, $plants_per_subplot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_subplots_with_index_number : Chained('trial') PathPart('upload_subplots_with_subplot_index_number') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_subplots_with_index_number_file');
    my $inherits_plot_treatments = $c->req->param('upload_subplots_with_index_number_inherit_treatments');
    my $subplots_per_plot = $c->req->param('upload_subplots_with_index_number_per_plot_number');

    my $subdirectory = "trial_subplots_upload";
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
    $parser->load_plugin('TrialSubplotsWithSubplotNumberXLS');
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

    my $upload_subplots_txn = sub {
        my %plot_subplot_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_subplot_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            push @{$plot_subplot_hash{$_->{plot_stock_id}}->{subplot_names}}, $_->{subplot_name};
            push @{$plot_subplot_hash{$_->{plot_stock_id}}->{subplot_index_numbers}}, $_->{subplot_index_number};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_subplot_entries(\%plot_subplot_hash, $subplots_per_plot, $inherits_plot_treatments, $user_id);

        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_subplots_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial subplots. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants_with_number_of_plants : Chained('trial') PathPart('upload_plants_with_number_of_plants') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_plants_with_number_of_plants_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_with_num_plants_inherit_treatments');
    my $plants_per_plot = $c->req->param('upload_plants_with_num_plants_per_plot_number');

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
    $parser->load_plugin('TrialPlantsWithNumberOfPlantsXLS');
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
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_plant_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_names}}, $_->{plant_name};
            push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_index_numbers}}, $_->{plant_index_number};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_entries(\%plot_plant_hash, $plants_per_plot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_plants_subplot_with_number_of_plants : Chained('trial') PathPart('upload_plants_subplot_with_number_of_plants') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this plant info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_plants_subplot_with_number_of_plants_file');
    my $inherits_plot_treatments = $c->req->param('upload_plants_subplot_with_num_plants_inherit_treatments');
    my $plants_per_subplot = $c->req->param('upload_plants_subplot_with_num_plants_per_subplot_number');

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
    $parser->load_plugin('TrialPlantsSubplotWithNumberOfPlantsXLS');
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
        $c->stash->{rest} = {error_string => $return_error, missing_subplots => $parse_errors->{'missing_subplots'}};
        $c->detach();
    }

    my $upload_plants_txn = sub {
        my %subplot_plant_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $subplot_plant_hash{$_->{subplot_stock_id}}->{subplot_name} = $_->{subplot_name};
            push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_names}}, $_->{plant_name};
            push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_index_numbers}}, $_->{plant_index_number};
            if ($_->{row_num} && $_->{col_num}) {
                push @{$subplot_plant_hash{$_->{subplot_stock_id}}->{plant_coords}}, $_->{row_num}.",".$_->{col_num};
            }
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_plant_subplot_entries(\%subplot_plant_hash, $plants_per_subplot, $inherits_plot_treatments, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_upload_subplots_with_number_of_subplots : Chained('trial') PathPart('upload_subplots_with_number_of_subplots') Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this subplot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $upload = $c->req->upload('trial_upload_subplots_with_number_of_subplots_file');
    my $inherits_plot_treatments = $c->req->param('upload_subplots_with_num_subplots_inherit_treatments');
    my $subplots_per_plot = $c->req->param('upload_subplots_with_num_subplots_per_plot_number');

    my $subdirectory = "trial_subplots_upload";
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
    $parser->load_plugin('TrialSubplotsWithNumberOfSubplotsXLS');
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

    my $upload_subplots_txn = sub {
        my %plot_subplot_hash;
        my $parsed_entries = $parsed_data->{data};
        foreach (@$parsed_entries){
            $plot_subplot_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
            push @{$plot_subplot_hash{$_->{plot_stock_id}}->{subplot_names}}, $_->{subplot_name};
            push @{$plot_subplot_hash{$_->{plot_stock_id}}->{subplot_index_numbers}}, $_->{subplot_index_number};
        }
        my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });
        $t->save_subplot_entries(\%plot_subplot_hash, $subplots_per_plot, $inherits_plot_treatments, $user_id);

        my $layout = $c->stash->{trial_layout};
        $layout->generate_and_cache_layout();
    };
    eval {
        $schema->txn_do($upload_subplots_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload trial subplots. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

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

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub trial_change_plot_accessions_upload : Chained('trial') PathPart('change_plot_accessions_using_file') Args(1) {
    my $self = shift;
    my $c = shift;
    my $override = shift;
    my $trial_id = $c->stash->{trial_id};
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
        return;
    }


    my $upload = $c->req->upload('trial_design_change_accessions_file');
    my $subdirectory = "trial_change_plot_accessions_upload";
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
        user_id => $c->user->get_object->get_sp_person_id(),
        user_role => ($c->user->get_roles)[0]
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, trial_id => $trial_id);
    $parser->load_plugin('TrialChangePlotAccessionsCSV');
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
        $c->stash->{rest} = {error => $return_error};
        return;
    }

    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();

    my $replace_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    });

    my $return_error = $replace_accession_fieldmap->update_fieldmap_precheck();
    if ($c->user()->check_roles("curator") and $return_error) {
        if ($override eq "check") {
            $c->stash->{rest} = { warning => "curator warning" };
            return;
        }
    } elsif ($return_error){
        $c->stash->{rest} = { error => $return_error };
        return;
    }

    my $upload_change_plot_accessions_txn = sub {
        my @stock_names;
        print STDERR Dumper $parsed_data;
        while (my ($key, $val) = each(%$parsed_data)){
            my $plot_name = $val->{plot_name};
            my $accession_name = $val->{accession_name};
            my $new_plot_name = $val->{new_plot_name};
            push @stock_names, $plot_name;
            push @stock_names, $accession_name;
        }
        my %stock_id_map;
        my $stock_rs = $schema->resultset("Stock::Stock")->search({
            uniquename => {'-in' => \@stock_names}
        });
        while (my $r = $stock_rs->next()){
            $stock_id_map{$r->uniquename} = $r->stock_id;
        }
        print STDERR Dumper \%stock_id_map;
        while (my ($key, $val) = each(%$parsed_data)){
            my $plot_id = $stock_id_map{$val->{plot_name}};
            my $accession_id = $stock_id_map{$val->{accession_name}};
            my $plot_name = $val->{plot_name};
            my $new_plot_name = $val->{new_plot_name};

            my $replace_accession_error = $replace_accession_fieldmap->replace_plot_accession_fieldMap($plot_id, $accession_id, $plot_of_type_id);
            if ($replace_accession_error) {
                $c->stash->{rest} = { error => $replace_accession_error};
                return;
            }

            if ($new_plot_name) {
                my $replace_plot_name_error = $replace_accession_fieldmap->replace_plot_name_fieldMap($plot_id, $new_plot_name);
                if ($replace_plot_name_error) {
                    $c->stash->{rest} = { error => $replace_plot_name_error};
                    return;
                }
            }
        }
    };
    eval {
        $schema->txn_do($upload_change_plot_accessions_txn);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to change plot accessions. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

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

sub obsolete_trial_additional_file_uploaded :Chained('trial') PathPart('obsolete_uploaded_additional_file') Args(1) {
    my $self = shift;
    my $c = shift;
    my $file_id = shift;

    if (!$c->user) {
	$c->stash->{rest} = { error => "You must be logged in to obsolete additional files!" };
	$c->detach();
    }

    my $user_id = $c->user->get_object()->get_sp_person_id();

    my @roles = $c->user->roles();
    my $result = $c->stash->{trial}->obsolete_additional_uploaded_file($file_id, $user_id, $roles[0]);

    if (exists($result->{errors})) {
	$c->stash->{rest} = { error => $result->{errors} };
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }

}


sub trial_controls : Chained('trial') PathPart('controls') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls();

    $c->stash->{rest} = { accessions => \@data };
}

sub controls_by_plot : Chained('trial') PathPart('controls_by_plot') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my @plot_ids = $c->req->param('plot_ids[]');

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls_by_plot(\@plot_ids);

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_plots : Chained('trial') PathPart('plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};

    my @data = $trial->get_plots();
#    print STDERR "PLOTS =".Dumper(\@data)."\n";

    $c->stash->{rest} = { plots => \@data };
}

sub trial_has_data_levels : Chained('trial') PathPart('has_data_levels') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = {
        has_plants => $trial->has_plant_entries(),
        has_subplots => $trial->has_subplot_entries(),
        has_tissue_samples => $trial->has_tissue_sample_entries(),
        trial_name => $trial->get_name
    };
}

sub trial_has_subplots : Chained('trial') PathPart('has_subplots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_subplots => $trial->has_subplot_entries(), trial_name => $trial->get_name };
}

sub trial_subplots : Chained('trial') PathPart('subplots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};

    my @data = $trial->get_subplots();

    $c->stash->{rest} = { subplots => \@data };
}

sub trial_has_plants : Chained('trial') PathPart('has_plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_plants => $trial->has_plant_entries(), trial_name => $trial->get_name };
}

sub trial_plants : Chained('trial') PathPart('plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};

    my @data = $trial->get_plants();

    $c->stash->{rest} = { plants => \@data };
}

sub trial_has_tissue_samples : Chained('trial') PathPart('has_tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { has_tissue_samples => $trial->has_tissue_sample_entries(), trial_name => $trial->get_name };
}

sub trial_tissue_samples : Chained('trial') PathPart('tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};

    my $data = $trial->get_tissue_samples();

    $c->stash->{rest} = { trial_tissue_samples => $data };
}

sub trial_phenotype_metadata : Chained('trial') PathPart('phenotype_metadata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $trial = $c->stash->{trial};
    my $data = $trial->get_phenotype_metadata();

    $c->stash->{rest} = { data => $data };
}

sub trial_treatments : Chained('trial') PathPart('treatments') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial = $c->stash->{trial};

    # my $data = $trial->get_treatments
    my $data = $trial->get_treatment_projects();

    $c->stash->{rest} = { treatments => $data };
}

sub trial_add_treatment : Chained('trial') PathPart('add_treatment') Args(0) { #TODO REFACTOR
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = {error => "You must be logged in to add a treatment"};
        $c->detach();
    }

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};
    my $design = decode_json $c->req->param('design');
    my $new_treatment_has_plant_entries = $c->req->param('has_plant_entries');
    my $new_treatment_has_subplot_entries = $c->req->param('has_subplot_entries');
    my $new_treatment_has_tissue_entries = $c->req->param('has_tissue_sample_entries');
    my $new_treatment_year = $c->req->param('treatment_year');
    my $new_treatment_date = $c->req->param('treatment_date');
    my $new_treatment_type = $c->req->param('treatment_type');

    my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
		bcs_schema => $schema,
		trial_id => $trial_id,
        trial_name => $trial->get_name(),
		nd_geolocation_id => $trial->get_location()->[0],
		design_type => $trial->get_design_type(),
		design => $design,
        new_treatment_has_plant_entries => $new_treatment_has_plant_entries,
        new_treatment_has_subplot_entries => $new_treatment_has_subplot_entries,
        new_treatment_has_tissue_sample_entries => $new_treatment_has_tissue_entries,
        new_treatment_date => $new_treatment_date,
        new_treatment_year => $new_treatment_year,
        new_treatment_type => $new_treatment_type,
        operator => $c->user()->get_object()->get_username()
	});
    my $error = $trial_design_store->store();
    if ($error){
        $c->stash->{rest} = {error => "Treatment not added: ".$error};
    } else {
        $c->stash->{rest} = {success => 1};
    }
}

sub trial_remove_treatment : Chained('trial') PathPart('remove_treatment') Args(0) { #TODO REFACTOR
    my $self = shift;
    my $c = shift;
    my $treatment_id = $c->req->param('treatment_id');

    if (!($c->user()->check_roles('curator'))) {
        $c->stash->{rest} = { error => 'You do not have the privileges to remove a treatment from this trial.'};
        return;
    }
    my $trial = $c->stash->{trial};
    my $trial_id = $c->stash->{trial_id};

    my $result;
    eval {
        $result = $trial->remove_treatment($treatment_id);
    };
    if ($@) {
        $c->stash->{rest} = { error => "An error occurred while removing the treatment: $@" };
        return;
    }
    if ($result->{error}) {
        $c->stash->{rest} = { error => $result->{error} };
        return;
    }

    $c->stash->{rest} = { success => 1, message => "Treatment removed from trial." };
}

sub trial_layout : Chained('trial') PathPart('layout') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $layout = $c->stash->{trial_layout};

    my $design = $layout->get_design();
    $c->stash->{rest} = {design => $design};
}

sub trial_layout_table : Chained('trial') PathPart('layout_table') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $selected_cols = $c->req->param('selected_columns') ? decode_json $c->req->param('selected_columns') : {"plot_name"=>1,"plot_number"=>1,"block_number"=>1,"accession_name"=>1,"is_a_control"=>1,"rep_number"=>1,"row_number"=>1,"col_number"=>1,"plot_geo_json"=>1};

    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $schema,
        trial_id => $c->stash->{trial_id},
        data_level => 'plots',
        #treatment_project_ids => [1,2],
        selected_columns => $selected_cols,
        include_measured => "false"
    });
    my $output = $trial_layout_download->get_layout_output();

    print STDERR "\nDone getting layout output CXGN::Trial::TrialLayoutDownload..\n";

    $c->stash->{rest} = $output;
}

sub trial_design : Chained('trial') PathPart('design') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $layout = $c->stash->{trial_layout};

    my $design = $layout->get_design();
    my $design_type = $layout->get_design_type();

    my $plot_length = '';
    my $plot_width = '';
    my $subplots_per_plot = '';
    my $plants_per_plot = '';
    my $number_of_blocks = '';
    if ($design_type ne 'genotyping_plate') {
        my $plot_dimensions = $layout->get_plot_dimensions();
        $plot_length = $plot_dimensions->[0] ? $plot_dimensions->[0] : '';
        $plot_width = $plot_dimensions->[1] ? $plot_dimensions->[1] : '';
        $plants_per_plot = $plot_dimensions->[2] ? $plot_dimensions->[2] : '';
        $subplots_per_plot = $plot_dimensions->[3] ? $plot_dimensions->[3] : '';

        my $block_numbers = $layout->get_block_numbers();
        if ($block_numbers) {
            $number_of_blocks = scalar(@{$block_numbers});
        }
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
        subplots_per_plot => $subplots_per_plot,
        plants_per_plot => $plants_per_plot,
        total_number_plots => $number_of_plots,
        design => $design
    };
}

sub get_spatial_layout : Chained('trial') PathPart('coords') Args(0) {

    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $cxgn_project_type = $c->stash->{trial}->get_cxgn_project_type();

    my $fieldmap = CXGN::Trial::FieldMap->new({
      bcs_schema => $schema,
      trial_id => $c->stash->{trial_id},
      experiment_type => $cxgn_project_type->{experiment_type}
    });
    my $return = $fieldmap->display_fieldmap();

    $c->stash->{rest} = $return;
}

sub retrieve_trial_info :  Path('/ajax/breeders/trial_phenotyping_info') : ActionClass('REST') { }
sub retrieve_trial_info_POST : Args(0) {
#sub retrieve_trial_info : chained('trial') Pathpart("trial_phenotyping_info") Args(0) {
    my $self =shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $experiment_type = $c->req->param('experiment_type') || 'field_layout';

    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $c->stash->{trial_id}, experiment_type => $experiment_type, verify_layout=>1, verify_physical_map=>1});
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

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

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);

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
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});
    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout' });
    $trial_layout->generate_and_cache_layout();

    $c->stash->{rest} = {success => 1};
}

sub replace_trial_stock : Chained('trial') PathPart('replace_stock') Args(0) {
  my $self = shift;
  my $c = shift;
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
  my $old_stock_id = $c->req->param('old_stock_id');
  my $new_stock = $c->req->param('new_stock');
  my $trial_stock_type = $c->req->param('trial_stock_type');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_stock){
    $c->stash->{rest} = { error => "Provide new stock name." };
    return;
  }

  my $replace_stock_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    trial_stock_type => $trial_stock_type,

  });

  my $return_error = $replace_stock_fieldmap->update_fieldmap_precheck();
     if ($return_error) {
       $c->stash->{rest} = { error => $return_error };
       return;
     }

  my $replace_return_error = $replace_stock_fieldmap->replace_trial_stock_fieldMap($new_stock, $old_stock_id);
  if ($replace_return_error) {
    $c->stash->{rest} = { error => $replace_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub refresh_cache : Chained('trial') PathPart('refresh_cache') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->stash->{trial_id};
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);

    my $refresh_fieldmap_cache = CXGN::Trial::FieldMap->new({
        trial_id => $trial_id,
        bcs_schema => $schema,
    });

    $refresh_fieldmap_cache->_regenerate_trial_layout_cache();
    $c->stash->{rest} = { success => 1};
}

sub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
    my $old_accession = $c->req->param('old_accession');
    my $new_accession = $c->req->param('new_accession');
    my $plot_id = $c->req->param('old_plot_id');
    my $old_plot_name = $c->req->param('old_plot_name');
    my $new_plot_name = $c->req->param('new_plot_name');
    my $override = $c->req->param('override');
    my $trial_id = $c->stash->{trial_id};

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to change a plot accession!'};
        return;
    }

    if ($self->privileges_denied($c)) {
        $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
    }

    if (!$new_accession) {
        $c->stash->{rest} = { error => "Provide new accession name." };
    return;
    }

    my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({
        trial_id => $trial_id,
        bcs_schema => $schema,
    });

    my $return_error = $replace_plot_accession_fieldmap->update_fieldmap_precheck();

    if ($c->user()->check_roles("curator") and $return_error) {
        if ($override eq "check") {
            $c->stash->{rest} = { warning => "curator warning" };
            return;
        }
    } elsif ($return_error) {
        $c->stash->{rest} = { error => $return_error};
        return;
    }


    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $accession_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $new_accession
    });
    $accession_rs = $accession_rs->next();
    my $new_accession_id = $accession_rs->stock_id;
    my $old_accession_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $old_accession
    });
    $old_accession_rs = $old_accession_rs->next();
    my $old_accession_id = $old_accession_rs->stock_id;

    print "Calling Replace Function...............\n";
    my $replace_return_error = $replace_plot_accession_fieldmap->replace_plot_accession_fieldMap($plot_id, $old_accession_id, $new_accession_id, $plot_of_type_id);
    if ($replace_return_error) {
        $c->stash->{rest} = { error => $replace_return_error };
        return;
    }

    if ($new_plot_name) {
        my $replace_plot_name_return_error = $replace_plot_accession_fieldmap->replace_plot_name_fieldMap($plot_id, $old_plot_name, $new_plot_name);
        if ($replace_plot_name_return_error) {
            $c->stash->{rest} = { error => $replace_plot_name_return_error };
            return;
        }
    }
    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});

    print "OldAccession: $old_accession, NewAcc: $new_accession, OldPlotName: $old_plot_name, NewPlotName: $new_plot_name OldPlotId: $plot_id\n";
    $c->stash->{rest} = { success => 1};
}

sub accession_exists : Chained('trial') PathPart('accession_exists') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
    my $accession_name = $c->req->param('accession_name');
    my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $accession_name });
    if (!$rs->first()) {
        $c->stash->{rest} = { error => "Error: $accession_name is not a valid accession in the database." };
        return;
    }
    my $accession_id = $rs->first()->stock_id();
    $c->stash->{rest} = { success => $accession_id};
}

sub check_curator_privileges : Chained('trial') PathPart('check_curator_privileges') Args(0) {
    my $self = shift;
    my $c = shift;

    if ($c->user()->check_roles("curator")) {
        $c->stash->{rest} = { success => 1};
    } else {
        $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    }

}

sub replace_well_accession : Chained('trial') PathPart('replace_well_accessions') Args(0) {
  my $self = shift;
  my $c = shift;
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
  my $old_accession = $c->req->param('old_accession');
  my $new_accession = $c->req->param('new_accession');
  my $old_plot_id = $c->req->param('old_plot_id');
  my $old_plot_name = $c->req->param('old_plot_name');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_accession){
    $c->stash->{rest} = { error => "Provide new accession name." };
    return;
  }
  my $cxgn_project_type = $c->stash->{trial}->get_cxgn_project_type();

  my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    new_accession => $new_accession,
    old_accession => $old_accession,
    old_plot_id => $old_plot_id,
    old_plot_name => $old_plot_name,
    experiment_type => $cxgn_project_type->{experiment_type}
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

  print "OldAccession: $old_accession, NewAcc: $new_accession, OldWellId: $old_plot_id\n";
  $c->stash->{rest} = { success => 1};
}

sub substitute_stock : Chained('trial') PathPart('substitute_stock') Args(0) {
  my $self = shift;
  my $c = shift;
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
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
    $c->stash->{rest} = { error => "Choose a different plot/stock in 'select plot 2' to perform this operation." };
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

sub create_plant_plot_entries : Chained('trial') PathPart('create_plant_entries') Args(0) {
    my $self = shift;
    my $c = shift;
    my $plant_owner = $c->user->get_object->get_sp_person_id;
    my $plant_owner_username = $c->user->get_object->get_username;
    my $plants_per_plot = $c->req->param("plants_per_plot") || 8;
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $include_plant_coordinates = $c->req->param('include_plant_coordinates');
    my $num_rows = $c->req->param('rows_per_plot');
    my $num_cols = $c->req->param('cols_per_plot');
    my $plants_with_treatments;
    if($inherits_plot_treatments eq '1'){
        $plants_with_treatments = 1;
    }

    if (my $error = $self->privileges_denied($c)) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    if (!$plants_per_plot || $plants_per_plot > 500) {
        $c->stash->{rest} = { error => "Plants per plot number is required and must be smaller than 500." };
        return;
    }

    my $user_id = $c->user->get_object->get_sp_person_id();
    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });

    my @plant_entity_params = ($plants_per_plot, $plants_with_treatments, $user_id, $plant_owner_username);

    if ($include_plant_coordinates) {

        if (!$num_rows || !$num_cols || $num_rows * $num_cols == 0) {
            $c->stash->{rest} = { error => "To include plant coordinate data, rows and columns must be specified." };
            return;
        }

        if ($num_rows * $num_cols < $plants_per_plot) {
            $c->stash->{rest} = { error => "You cannot have more plants than available spaces. Decrease plants per plot or increase rows or columns." };
            return;
        }

        push @plant_entity_params, $num_rows;
        push @plant_entity_params, $num_cols;
    }

    if ($t->create_plant_entities(@plant_entity_params)) {
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});


        $c->stash->{rest} = {success => 1};
        return;
    } else {
        $c->stash->{rest} = { error => "Error creating plant entries in controller." };
    	return;
    }

}

sub create_plant_subplot_entries : Chained('trial') PathPart('create_plant_subplot_entries') Args(0) {
    my $self = shift;
    my $c = shift;
    my $plant_owner = $c->user->get_object->get_sp_person_id;
    my $plant_owner_username = $c->user->get_object->get_username;
    my $plants_per_subplot = $c->req->param("plants_per_subplot") || 8;
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $include_plant_coordinates = $c->req->param('include_plant_coordinates');
    my $num_rows = $c->req->param('rows_per_plot');
    my $num_cols = $c->req->param('cols_per_plot');
    my $plants_with_treatments;
    if($inherits_plot_treatments eq '1'){
        $plants_with_treatments = 1;
    }

    if (my $error = $self->privileges_denied($c)) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    if (!$plants_per_subplot || $plants_per_subplot > 500) {
        $c->stash->{rest} = { error => "Plants per subplot number is required and must be smaller than 500." };
        return;
    }

    my $user_id = $c->user->get_object->get_sp_person_id();
    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });

    my @subplot_plant_entity_params = ($plants_per_subplot, $plants_with_treatments, $user_id, $plant_owner_username);

    if ($include_plant_coordinates) {

        if (!$num_rows || !$num_cols || $num_rows * $num_cols == 0) {
            $c->stash->{rest} = { error => "To include plant coordinate data, rows and columns must be specified." };
            return;
        }

        if ($num_rows * $num_cols < $plants_per_subplot) {
            $c->stash->{rest} = { error => "You cannot have more plants than available spaces. Decrease plants per subplot or increase rows or columns." };
            return;
        }

        push @subplot_plant_entity_params, $num_rows;
        push @subplot_plant_entity_params, $num_cols;
    }

    if ($t->create_plant_subplot_entities(@subplot_plant_entity_params)) {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {success => 1};
        return;
    } else {
        $c->stash->{rest} = { error => "Error creating plant entries for subplots in controller." };
    	return;
    }

}

sub create_subplot_entries : Chained('trial') PathPart('create_subplot_entries') Args(0) {
    my $self = shift;
    my $c = shift;
    my $subplot_owner = $c->user->get_object->get_sp_person_id;
    my $subplot_owner_username = $c->user->get_object->get_username;
    my $subplots_per_plot = $c->req->param("subplots_per_plot") || 4;
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $subplots_with_treatments;
    if($inherits_plot_treatments eq '1'){
        $subplots_with_treatments = 1;
    }

    if (my $error = $self->privileges_denied($c)) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    if (!$subplots_per_plot || $subplots_per_plot > 500) {
        $c->stash->{rest} = { error => "Subplots per plot number is required and must be smaller than 500." };
        return;
    }

    my $user_id = $c->user->get_object->get_sp_person_id();
    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });

    if ($t->create_subplot_entities($subplots_per_plot, $subplots_with_treatments, $user_id)) {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {success => 1};
        return;
    } else {
        $c->stash->{rest} = { error => "Error creating subplot entries in controller." };
    	return;
    }

}

sub create_tissue_samples : Chained('trial') PathPart('create_tissue_samples') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tissue_sample_owner = $c->user->get_object->get_sp_person_id;
    my $tissue_owner_username = $c->user->get_object->get_username;
    my $tissues_per_plant = $c->req->param("tissue_samples_per_plant") || 3;
    my $tissue_names = decode_json $c->req->param("tissue_samples_names");
    my $inherits_plot_treatments = $c->req->param("inherits_plot_treatments");
    my $use_tissue_numbers = $c->req->param("use_tissue_numbers");
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

    my $user_id = $c->user->get_object->get_sp_person_id();
    my $t = CXGN::Trial->new({ bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $c->stash->{trial_id} });

    if ($t->create_tissue_samples($tissue_names, $inherits_plot_treatments, $use_tissue_numbers, $user_id)) {
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {success => 1};
        $c->detach;;
    } else {
        $c->stash->{rest} = { error => "Error creating tissues samples in controller." };
        $c->detach;;
    }

}

sub get_management_regime : Chained('trial') PathPart('get_management_regime') Args(0) { #TODO
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
}

sub edit_management_factor_details : Chained('trial') PathPart('edit_management_factor_details') Args(0) { #TODO REFACTOR
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $management_factor_schedule = $c->req->param("schedule");
    my $management_factor_description = $c->req->param("description");
    my $management_factor_type = $c->req->param("type");
    my $action = $c->req->param("action");

    if (my $error = $self->privileges_denied($c)) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    if (!$management_factor_schedule) {
        $c->stash->{rest} = { error => 'No schedule given!' };
        return;
    }

    if (!$management_factor_description) {
        $c->stash->{rest} = { error => 'No description given!' };
        return;
    }
    if (!$management_factor_type) {
        $c->stash->{rest} = { error => 'No type given!' };
        return;
    }
    if (!$action) {
        $c->stash->{rest} = { error => 'Server error! Somebody tried sending bad data.' };
        return;
    }

    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    if ($action eq "add") {
        # same as below but adding a new json key
    } elsif ($action eq "remove") {
        # get the management regime and remove the part that needs to be removed, set resulting management regime
    }

    $c->stash->{rest} = { success => 1 };
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
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload plot coordinates (row and column number)!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload plot coordinates (row and column number)!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to add coordinates (row and column numbers)." };
        $c->detach();
    }

    my $time = DateTime->now();
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
        user_role => $user_role
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
    open(my $F, "< :encoding(UTF-8)", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $header = <$F>;
    while (<$F>) {
    	chomp;
    	$_ =~ s/\r//g;
    	my ($plot,$row,$col) = split /\t/ ;
    	my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $plot });
    	if ($rs->count()== 1) {
      	my $r =  $rs->first();
      	print STDERR "The plots $plot was found.\n Loading row $row col $col\n";
      	$r->create_stockprops({row_number => $row, col_number => $col});
      }
      else {
      	print STDERR "WARNING! $plot was not found in the database.\n";
        $error_string .= "WARNING! $plot was not found in the database.";
      }
    }

    if ($error_string){
        $c->stash->{rest} = {error_string => $error_string};
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});
    my $trial_layout = CXGN::Trial::TrialLayout->new({ schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id), trial_id => $trial_id, experiment_type => 'field_layout' });
    $trial_layout->generate_and_cache_layout();

    $c->stash->{rest} = {success => 1};
}

sub crosses_in_crossingtrial : Chained('trial') PathPart('crosses_in_crossingtrial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_crosses_in_crossing_experiment();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name) =@$r;
        push @crosses, {
            cross_id => $cross_id,
            cross_name => $cross_name,
        };
    }

    $c->stash->{rest} = { data => \@crosses };
}

sub crosses_and_details_in_trial : Chained('trial') PathPart('crosses_and_details_in_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_crosses_and_details_in_crossingtrial();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_combination, $cross_type, $female_parent_id, $female_parent_name, $female_ploidy, $male_parent_id, $male_parent_name, $male_ploidy, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name) =@$r;
        push @crosses, {
            cross_id => $cross_id,
            cross_name => $cross_name,
            cross_combination => $cross_combination,
            cross_type => $cross_type,
            female_parent_id => $female_parent_id,
            female_parent_name => $female_parent_name,
            female_ploidy_level => $female_ploidy,
            male_parent_id => $male_parent_id,
            male_parent_name => $male_parent_name,
            male_ploidy_level => $male_ploidy,
            female_plot_id => $female_plot_id,
            female_plot_name => $female_plot_name,
            male_plot_id => $male_plot_id,
            male_plot_name => $male_plot_name,
            female_plant_id => $female_plant_id,
            female_plant_name => $female_plant_name,
            male_plant_id => $male_plant_id,
            male_plant_name => $male_plant_name
        };
    }

    $c->stash->{rest} = { data => \@crosses };
}

sub cross_properties_trial : Chained('trial') PathPart('cross_properties_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_cross_properties_trial();

    my $cross_properties = $c->config->{cross_properties};
    my @column_order = split ',', $cross_properties;

    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_combination, $cross_props_hash) =@$r;

        my @row = ( qq{<a href = "/cross/$cross_id">$cross_name</a>}, $cross_combination );
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_cross_progenies_trial();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_combination, $family_id, $family_name, $progeny_number) =@$r;
        push @crosses, [qq{<a href = "/cross/$cross_id">$cross_name</a>}, $cross_combination, $progeny_number, qq{<a href = "/family/$family_id/">$family_name</a>}];
    }

    $c->stash->{rest} = { data => \@crosses };
}


sub seedlots_from_crossingtrial : Chained('trial') PathPart('seedlots_from_crossingtrial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_seedlots_from_crossingtrial();
    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $seedlot_id, $seedlot_name) =@$r;
        push @crosses, {
            cross_id => $cross_id,
            cross_name => $cross_name,
            seedlot_id => $seedlot_id,
            seedlot_name => $seedlot_name
        };
    }

    $c->stash->{rest} = { data => \@crosses };

}


sub get_crosses : Chained('trial') PathPart('get_crosses') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_crosses_in_crossing_experiment();
    my @data = @$result;
#    print STDERR "CROSSES =".Dumper(\@data)."\n";

    $c->stash->{rest} = { crosses => \@data };
}


sub get_female_accessions : Chained('trial') PathPart('get_female_accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_female_accessions_in_crossing_experiment();
    my @data = @$result;
#    print STDERR "FEMALE ACCESSIONS =".Dumper(\@data)."\n";

    $c->stash->{rest} = { female_accessions => \@data };
}


sub get_male_accessions : Chained('trial') PathPart('get_male_accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_male_accessions_in_crossing_experiment();
    my @data = @$result;

    $c->stash->{rest} = { male_accessions => \@data };
}


sub get_female_plots : Chained('trial') PathPart('get_female_plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_female_plots_in_crossing_experiment();
    my @data = @$result;

    $c->stash->{rest} = { female_plots => \@data };
}


sub get_male_plots : Chained('trial') PathPart('get_male_plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_male_plots_in_crossing_experiment();
    my @data = @$result;

    $c->stash->{rest} = { male_plots => \@data };
}


sub get_female_plants : Chained('trial') PathPart('get_female_plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_female_plants_in_crossing_experiment();
    my @data = @$result;
#    print STDERR "FEMALE PLANTS =".Dumper(\@data)."\n";

    $c->stash->{rest} = { female_plants => \@data };
}


sub get_male_plants : Chained('trial') PathPart('get_male_plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_male_plants_in_crossing_experiment();
    my @data = @$result;

    $c->stash->{rest} = { male_plants => \@data };
}


sub delete_all_crosses_in_crossingtrial : Chained('trial') PathPart('delete_all_crosses_in_crossingtrial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to delete crosses" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete crosses. Please contact us." };
        $c->detach();
    }

    my $trial = CXGN::Cross->new({schema => $schema, trial_id => $trial_id});

    my $result = $trial->get_crosses_in_crossing_experiment();

    foreach my $r (@$result){
        my ($cross_stock_id, $cross_name) =@$r;
        my $cross = CXGN::Cross->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id), cross_stock_id => $cross_stock_id });
        my $error = $cross->delete();
        print STDERR "ERROR = $error\n";

        if ($error) {
            $c->stash->{rest} = { error => "An error occurred attempting to delete a cross. ($@)" };
            return;
        }
    }

    $c->stash->{rest} = { success => 1 };
}


sub cross_additional_info_trial : Chained('trial') PathPart('cross_additional_info_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id});
    my $result = $trial->get_cross_additional_info_trial();
#    print STDERR "ADDITIONAL INFO =".Dumper($result)."\n";

    my $cross_additional_info_string = $c->config->{cross_additional_info};
    my @column_order = split ',', $cross_additional_info_string;

    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_combination, $cross_additional_info_hash) =@$r;

        my @row = ( qq{<a href = "/cross/$cross_id">$cross_name</a>}, $cross_combination );
        foreach my $key (@column_order){
          push @row, $cross_additional_info_hash->{$key};
        }

        push @crosses, \@row;
    }

    $c->stash->{rest} = { data => \@crosses };
}


sub downloaded_intercross_file_metadata : Chained('trial') PathPart('downloaded_intercross_file_metadata') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $crosses = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id, file_type => 'intercross_download'});
    my $result = $crosses->get_intercross_file_metadata();

    $c->stash->{rest} = { data => $result };
}


sub uploaded_intercross_file_metadata : Chained('trial') PathPart('uploaded_intercross_file_metadata') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $trial_id = $c->stash->{trial_id};
    my $crosses = CXGN::Cross->new({ schema => $schema, trial_id => $trial_id, file_type => 'intercross_upload'});
    my $result = $crosses->get_intercross_file_metadata();

    $c->stash->{rest} = { data => $result };
}


sub phenotype_heatmap : Chained('trial') PathPart('heatmap') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->req->param("selected");

    my @items = map {@{$_}[0]} @{$c->stash->{trial}->get_plots()};
    #print STDERR Dumper(\@items);
    my @trait_ids = ($trait_id);

    my $layout = $c->stash->{trial_layout};
    my $design_type = $layout->get_design_type();

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        "Native",
        {
            bcs_schema=> $schema,
            data_level=> 'plot',
            trait_list=> \@trait_ids,
            plot_list=>  \@items,
        }
    );
    my $data = $phenotypes_search->search();
    my (@col_No, @row_No, @pheno_val, @plot_Name, @stock_Name, @plot_No, @block_No, @rep_No, @msg, $result, @phenoID);
    foreach my $d (@$data) {
        my $stock_id = $d->{accession_stock_id};
        my $stock_name = $d->{accession_uniquename};
        my $value = $d->{phenotype_value};
        my $plot_id = $d->{obsunit_stock_id};
        my $plot_name = $d->{obsunit_uniquename};
        my $rep = $d->{rep};
        my $block_number = $d->{block};
        my $plot_number = $d->{plot_number};
        my $row_number = $d->{row_number};
        my $col_number = $d->{col_number};
        my $design = $d->{design};
        my $phenotype_id = $d->{phenotype_id};
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
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
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
    my $pheno_ids = $c->req->param('pheno_id') ? JSON::decode_json($c->req->param('pheno_id')) : [];
    my $trait_ids = $c->req->param('traits_id') ? JSON::decode_json($c->req->param('traits_id')) : [];
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
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

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');
    my $delete_trait_return_error = $trial->delete_assayed_trait($c->config->{basepath}, $c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, $temp_file_nd_experiment_id, $pheno_ids, $trait_ids);

    if ($delete_trait_return_error) {
        $c->stash->{rest} = { error => $delete_trait_return_error };
    } else {
        $c->stash->{rest} = { success => 1};
    }
}

sub retrieve_plot_image : Chained('trial') PathPart('retrieve_plot_images') Args(0) {
  my $self = shift;
  my $c = shift;
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $source_field_trials_for_this_trial = $c->stash->{trial}->get_field_trials_source_field_trials();
    my $field_trials_sourced_from_this_trial = $c->stash->{trial}->get_field_trials_sourced_from_field_trials();

    $c->stash->{rest} = {success => 1, source_field_trials => $source_field_trials_for_this_trial, field_trials_sourced => $field_trials_sourced_from_this_trial};
}

sub genotyping_trial_from_field_trial : Chained('trial') PathPart('genotyping_trial_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $genotyping_trials_from_field_trial = $c->stash->{trial}->get_genotyping_trials_from_field_trial();
    my $field_trials_source_of_genotyping_trial = $c->stash->{trial}->get_field_trials_source_of_genotyping_trial();

    $c->stash->{rest} = {success => 1, genotyping_trials_from_field_trial => $genotyping_trials_from_field_trial, field_trials_source_of_genotyping_trial => $field_trials_source_of_genotyping_trial};
}

sub delete_genotyping_plate_from_field_trial_linkage : Chained('trial') PathPart('delete_genotyping_plate_from_field_trial_linkage') Args(1) {
    my $self = shift;
    my $c = shift;
    my $field_trial_id = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!$c->user) {
        $c->stash->{rest} = { error => "You must be logged in to remove genotyping plate and field trial linkage!" };
        $c->detach();
    }

    my @roles = $c->user->roles();
    my $result = $c->stash->{trial}->delete_genotyping_plate_from_field_trial_linkage($field_trial_id, $roles[0]);

    if (exists($result->{errors})) {
        $c->stash->{rest} = { error => $result->{errors} };
    }
    else {
        $c->stash->{rest} = { success => 1 };
    }

}

sub crossing_trial_from_field_trial : Chained('trial') PathPart('crossing_trial_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $crossing_trials_from_field_trial = $c->stash->{trial}->get_crossing_trials_from_field_trial();
    my $field_trials_source_of_crossing_trial = $c->stash->{trial}->get_field_trials_source_of_crossing_trial();

    $c->stash->{rest} = {success => 1, crossing_trials_from_field_trial => $crossing_trials_from_field_trial, field_trials_source_of_crossing_trial => $field_trials_source_of_crossing_trial};
}

sub field_trial_sources_of_parents : Chained('trial') PathPart('field_trial_sources_of_parents') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $field_trials_source_of_crossing_trial = $c->stash->{trial}->get_field_trial_sources_of_crossing_experiment();
    my @source_trials;
    if ($field_trials_source_of_crossing_trial) {
        foreach my $trial (@$field_trials_source_of_crossing_trial) {
            push @source_trials, [qq{<a href="/breeders/trial/$trial->[0]">$trial->[1]</a>}];
        }
    }
    $c->stash->{rest} = { data => \@source_trials };
}

sub field_trials_for_evaluating_crosses : Chained('trial') PathPart('field_trials_for_evaluating_crosses') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $field_trials_for_evaluating_crosses = $c->stash->{trial}->get_field_trials_for_evaluating_crosses();
    my @field_trials;
    if ($field_trials_for_evaluating_crosses) {
        foreach my $trial (@$field_trials_for_evaluating_crosses) {
            push @field_trials, [qq{<a href="/breeders/trial/$trial->[0]">$trial->[1]</a>}];
        }
    }
    $c->stash->{rest} = { data => \@field_trials };
}

sub crossing_experiments_from_field_trial : Chained('trial') PathPart('crossing_experiments_from_field_trial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $crossing_experiments_from_field_trial = $c->stash->{trial}->get_crossing_experiments_from_field_trial();
    my @crossing_experiments;
    if ($crossing_experiments_from_field_trial) {
        foreach my $crossing_experiment (@$crossing_experiments_from_field_trial) {
            push @crossing_experiments, [qq{<a href="/breeders/trial/$crossing_experiment->[0]">$crossing_experiment->[1]</a>}];
        }
    }
    $c->stash->{rest} = { data => \@crossing_experiments };
}

sub trial_correlate_traits : Chained('trial') PathPart('correlate_traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $obsunit_level = $c->req->param('observation_unit_level');
    my $correlation_type = $c->req->param('correlation_type');

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>$obsunit_level,
            trait_list=>$trait_ids,
            trial_list=>[$c->stash->{trial_id}],
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %phenotype_data;
    my %trait_hash;
    my %seen_obsunit_ids;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_stock_id};
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            $phenotype_data{$obsunit_id}->{$_->{trait_id}} = $_->{value};
            $trait_hash{$_->{trait_id}} = $_->{trait_name};
        }
        $seen_obsunit_ids{$obsunit_id}++;
    }
    my @sorted_obs_units = sort keys %seen_obsunit_ids;

    my $header_string = join ',', @$trait_ids;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_trial_correlation";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_fh, $stats_out_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
        print $F $header_string."\n";
        foreach my $s (@sorted_obs_units) {
            my @line = ();
            foreach my $t (@$trait_ids) {
                my $val = $phenotype_data{$s}->{$t};
                if (!$val && $val != 0) {
                    $val = 'NA';
                }
                push @line, $val;
            }
            my $line_string = join ',', @line;
            print $F "$line_string\n";
        }
    close($F);

    my $cmd = 'R -e "library(data.table);
    mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
    res <- cor(mat, method=\''.$correlation_type.'\', use = \'complete.obs\')
    res_rounded <- round(res, 2)
    write.table(res_rounded, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $csv = Text::CSV->new({ sep_char => "\t" });
    my @result;
    open(my $fh, '<', $stats_out_tempfile)
        or die "Could not open file '$stats_out_tempfile' $!";

        print STDERR "Opened $stats_out_tempfile\n";
        my $header = <$fh>;
        my @header_cols;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }

        my @header_trait_names = ("Trait");
        foreach (@header_cols) {
            push @header_trait_names, $trait_hash{$_};
        }
        push @result, \@header_trait_names;

        while (my $row = <$fh>) {
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $trait_id = shift @columns;
            my @line = ($trait_hash{$trait_id});
            push @line, @columns;
            push @result, \@line;
        }
    close($fh);

    $c->stash->{rest} = {success => 1, result => \@result};
}

sub trial_plot_time_series_accessions : Chained('trial') PathPart('plot_time_series_accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $accession_ids = $c->req->param('accession_ids') ne 'null' ? decode_json $c->req->param('accession_ids') : [];
    my $trait_format = $c->req->param('trait_format');
    my $data_level = $c->req->param('data_level');
    my $draw_error_bars = $c->req->param('draw_error_bars');
    my $use_cumulative_phenotype = $c->req->param('use_cumulative_phenotype');

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>$data_level,
            trait_list=>$trait_ids,
            trial_list=>[$c->stash->{trial_id}],
            accession_list=>$accession_ids,
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %trait_ids_hash = map {$_ => 1} @$trait_ids;

    my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$c->stash->{trial_id}});
    my $traits_assayed = $trial->get_traits_assayed($data_level, $trait_format, 'time_ontology');
    my %unique_traits_ids;
    foreach (@$traits_assayed) {
        if (exists($trait_ids_hash{$_->[0]})) {
            $unique_traits_ids{$_->[0]} = $_;
        }
    }
    my %unique_components;
    foreach (values %unique_traits_ids) {
        foreach my $component (@{$_->[2]}) {
            if ($component->{cv_type} && $component->{cv_type} eq 'time_ontology') {
                $unique_components{$_->[0]} = $component->{name};
            }
        }
    }

    my @sorted_times;
    my %sorted_time_hash;
    while( my($trait_id, $time_name) = each %unique_components) {
        my @time_split = split ' ', $time_name;
        my $time_val = $time_split[1] + 0;
        push @sorted_times, $time_val;
        $sorted_time_hash{$time_val} = $trait_id;
    }
    @sorted_times = sort @sorted_times;

    my %cumulative_time_hash;
    while( my($trait_id, $time_name) = each %unique_components) {
        my @time_split = split ' ', $time_name;
        my $time_val = $time_split[1] + 0;
        foreach my $t (@sorted_times) {
            if ($t < $time_val) {
                push @{$cumulative_time_hash{$time_val}}, $sorted_time_hash{$t};
            }
        }
    }

    my %phenotype_data;
    my %trait_hash;
    my %seen_germplasm_names;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_stock_id};
        my $observations = $obs_unit->{observations};
        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
        my $germplasm_uniquename = $obs_unit->{germplasm_uniquename};
        foreach (@$observations){
            push @{$phenotype_data{$germplasm_uniquename}->{$_->{trait_id}}}, $_->{value};
            $trait_hash{$_->{trait_id}} = $_->{trait_name};
        }
        $seen_germplasm_names{$germplasm_uniquename}++;
    }
    my @sorted_germplasm_names = sort keys %seen_germplasm_names;

    my $header_string = 'germplasmName,time,value,sd';

    my $dir = $c->tempfiles_subdir('/trial_analysis_accession_time_series_plot_dir');
    my $pheno_data_tempfile_string = $c->tempfile( TEMPLATE => 'trial_analysis_accession_time_series_plot_dir/datafileXXXX');
    $pheno_data_tempfile_string .= '.csv';
    my $stats_tempfile = $c->config->{basepath}."/".$pheno_data_tempfile_string;

    open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
        print $F $header_string."\n";
        foreach my $s (@sorted_germplasm_names) {
            foreach my $t (@$trait_ids) {
                my $time = $unique_components{$t};
                my @time_split = split ' ', $time;
                my $time_val = $time_split[1];
                my $vals = $phenotype_data{$s}->{$t};
                my $val;
                my $sd;
                if (!$vals || scalar(@$vals) == 0) {
                    $val = 'NA';
                    $sd = 0;
                }
                else {
                    my $stat = Statistics::Descriptive::Full->new();
                    $stat->add_data(@$vals);
                    $sd = $stat->standard_deviation();
                    $val = $stat->mean();
                    if ($use_cumulative_phenotype eq 'Yes') {
                        my $previous_time_trait_ids = $cumulative_time_hash{$time_val};
                        my @previous_vals_avgs = ($val);
                        foreach my $pt (@$previous_time_trait_ids) {
                            my $previous_vals = $phenotype_data{$s}->{$pt};
                            my $previous_stat = Statistics::Descriptive::Full->new();
                            $previous_stat->add_data(@$previous_vals);
                            my $previous_val_avg = $previous_stat->mean();
                            push @previous_vals_avgs, $previous_val_avg;
                        }
                        my $stat_cumulative = Statistics::Descriptive::Full->new();
                        $stat_cumulative->add_data(@previous_vals_avgs);
                        $sd = $stat_cumulative->standard_deviation();
                        $val = sum(@previous_vals_avgs);
                    }
                }
                print $F "$s,$time_val,$val,$sd\n";
            }
        }
    close($F);

    my @set = ('0' ..'9', 'A' .. 'F');
    my @colors;
    for (1..scalar(@sorted_germplasm_names)) {
        my $str = join '' => map $set[rand @set], 1 .. 6;
        push @colors, '#'.$str;
    }
    my $color_string = join '\',\'', @colors;

    my $pheno_figure_tempfile_string = $c->tempfile( TEMPLATE => 'trial_analysis_accession_time_series_plot_dir/figureXXXX');
    $pheno_figure_tempfile_string .= '.png';
    my $pheno_figure_tempfile = $c->config->{basepath}."/".$pheno_figure_tempfile_string;

    my $cmd = 'R -e "library(data.table); library(ggplot2);
    mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
    mat\$time <- as.numeric(as.character(mat\$time));
    options(device=\'png\');
    par();
    sp <- ggplot(mat, aes(x = time, y = value)) +
        geom_line(aes(color = germplasmName), size = 1) +
        scale_fill_manual(values = c(\''.$color_string.'\')) +
        theme_minimal()';
    if ($draw_error_bars eq "Yes") {
        $cmd .= '+ geom_errorbar(aes(ymin=value-sd, ymax=value+sd, color=germplasmName), width=.2, position=position_dodge(0.05));
        ';
    }
    else {
        $cmd .= ';
        ';
    }
    $cmd .= 'sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));';
    if (scalar(@sorted_germplasm_names) > 100) {
        $cmd .= 'sp <- sp + theme(legend.position = \'none\');';
    }
    $cmd .= 'ggsave(\''.$pheno_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
    dev.off();"';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $c->stash->{rest} = {success => 1, figure => $pheno_figure_tempfile_string, data_file => $pheno_data_tempfile_string, cmd => $cmd};
}

sub trial_accessions_rank : Chained('trial') PathPart('accessions_rank') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $trait_weights = decode_json $c->req->param('trait_weights');
    my $accession_ids = $c->req->param('accession_ids') ne 'null' ? decode_json $c->req->param('accession_ids') : [];
    my $trait_format = $c->req->param('trait_format');
    my $data_level = $c->req->param('data_level');

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>$data_level,
            trait_list=>$trait_ids,
            trial_list=>[$c->stash->{trial_id}],
            accession_list=>$accession_ids,
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %trait_weight_map;
    foreach (@$trait_weights) {
        $trait_weight_map{$_->[0]} = $_->[1];
    }
    print STDERR Dumper \%trait_weight_map;

    my %phenotype_data;
    my %trait_hash;
    my %seen_germplasm_names;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_stock_id};
        my $observations = $obs_unit->{observations};
        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
        my $germplasm_uniquename = $obs_unit->{germplasm_uniquename};
        foreach (@$observations){
            push @{$phenotype_data{$germplasm_uniquename}->{$_->{trait_id}}}, $_->{value};
            $trait_hash{$_->{trait_id}} = $_->{trait_name};
        }
        $seen_germplasm_names{$germplasm_uniquename}++;
    }
    my @sorted_germplasm_names = sort keys %seen_germplasm_names;

    my %accession_sum;
    foreach my $s (@sorted_germplasm_names) {
        foreach my $t (@$trait_ids) {
            my $vals = $phenotype_data{$s}->{$t};
            my $average_val = sum(@$vals)/scalar(@$vals);
            my $average_val_weighted = $average_val*$trait_weight_map{$t};
            $accession_sum{$s} += $average_val_weighted;
        }
    }

    my @sorted_accessions = sort { $accession_sum{$b} <=> $accession_sum{$a} } keys(%accession_sum);
    my @sorted_values = @accession_sum{@sorted_accessions};
    my @sorted_rank = (1..scalar(@sorted_accessions));

    $c->stash->{rest} = {success => 1, results => \%accession_sum, sorted_accessions => \@sorted_accessions, sorted_values => \@sorted_values, sorted_ranks => \@sorted_rank};
}

sub trial_genotype_comparison : Chained('trial') PathPart('genotype_comparison') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $trait_weights = decode_json $c->req->param('trait_weights');
    my $accession_ids = $c->req->param('accession_ids') ne 'null' ? decode_json $c->req->param('accession_ids') : [];
    my $trait_format = $c->req->param('trait_format');
    my $nd_protocol_id = $c->req->param('nd_protocol_id');
    my $data_level = $c->req->param('data_level');
    my $genotype_filter_string = $c->req->param('genotype_filter');
    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'yes' ? 1 : 0;

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $user_id);

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>$data_level,
            trait_list=>$trait_ids,
            trial_list=>[$c->stash->{trial_id}],
            accession_list=>$accession_ids,
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %trait_weight_map;
    foreach (@$trait_weights) {
        $trait_weight_map{$_->[0]} = $_->[1];
    }
    # print STDERR Dumper \%trait_weight_map;

    my %phenotype_data;
    my %trait_hash;
    my %seen_germplasm_names;
    my %seen_germplasm_ids;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_stock_id};
        my $observations = $obs_unit->{observations};
        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
        my $germplasm_uniquename = $obs_unit->{germplasm_uniquename};
        foreach (@$observations){
            push @{$phenotype_data{$germplasm_uniquename}->{$_->{trait_id}}}, $_->{value};
            $trait_hash{$_->{trait_id}} = $_->{trait_name};
        }
        $seen_germplasm_names{$germplasm_uniquename} = $germplasm_stock_id;
        $seen_germplasm_ids{$germplasm_stock_id}++;
    }
    my @sorted_germplasm_names = sort keys %seen_germplasm_names;
    my @sorted_germplasm_ids = sort keys %seen_germplasm_ids;

    my %accession_sum;
    foreach my $s (@sorted_germplasm_names) {
        foreach my $t (@$trait_ids) {
            my $vals = $phenotype_data{$s}->{$t};
            my $average_val = sum(@$vals)/scalar(@$vals);
            my $average_val_weighted = $average_val*$trait_weight_map{$t};
            $accession_sum{$s} += $average_val_weighted;
        }
    }

    my @sorted_accessions = sort { $accession_sum{$b} <=> $accession_sum{$a} } keys(%accession_sum);
    my @sorted_values = @accession_sum{@sorted_accessions};
    my $sort_increment = ceil(scalar(@sorted_accessions)/10)+0;
    # print STDERR Dumper $sort_increment;

    my $percentile_inc = $sort_increment/scalar(@sorted_accessions);

    my $acc_counter = 1;
    my $rank_counter = 1;
    my %rank_hash;
    my %rank_lookup;
    my %rank_percentile;
    foreach (@sorted_accessions) {
        print STDERR Dumper $acc_counter;
        if ($acc_counter >= $sort_increment) {
            $rank_counter++;
            $acc_counter = 0;
        }
        my $stock_id = $seen_germplasm_names{$_};
        push @{$rank_hash{$rank_counter}}, $stock_id;
        $rank_lookup{$stock_id} = $rank_counter;
        my $percentile = $rank_counter*$percentile_inc;
        $rank_percentile{$rank_counter} = "Rank ".$rank_counter;
        $acc_counter++;
    }

    my @sorted_rank_groups;
    foreach (@sorted_accessions) {
        my $stock_id = $seen_germplasm_names{$_};
        push @sorted_rank_groups, $rank_lookup{$stock_id};
    }
    my @sorted_ranks = (1..scalar(@sorted_accessions));
    # print STDERR Dumper \%rank_hash;
    # print STDERR Dumper \%rank_lookup;

    my $geno = CXGN::Genotype::DownloadFactory->instantiate(
        'DosageMatrix',    #can be either 'VCF' or 'DosageMatrix'
        {
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            cache_root_dir=>$c->config->{cache_file_path},
            accession_list=>\@sorted_germplasm_ids,
            trial_list=>[$c->stash->{trial_id}],
            protocol_id_list=>[$nd_protocol_id],
            compute_from_parents=>$compute_from_parents,
        }
    );
    my $file_handle = $geno->download(
        $c->config->{cluster_shared_tempdir},
        $c->config->{backend},
        $c->config->{cluster_host},
        $c->config->{'web_cluster_queue'},
        $c->config->{basepath}
    );

    my %genotype_filter;
    if ($genotype_filter_string) {
        my @genos = split ',', $genotype_filter_string;
        %genotype_filter = map {$_ => 1} @genos;
    }

    my %geno_rank_counter;
    my %geno_rank_seen_scores;
    my @marker_names;
    open my $geno_fh, "<&", $file_handle or die "Can't open output file: $!";
        my $header = <$geno_fh>;
        chomp($header);
        # print STDERR Dumper $header;
        my @header = split "\t", $header;
        my $header_dummy = shift @header;

        my $position = 0;
        while (my $row = <$geno_fh>) {
            chomp($row);
            if ($row) {
                # print STDERR Dumper $row;
                my @line = split "\t", $row;
                my $marker_name = shift @line;
                push @marker_names, $marker_name;
                my $counter = 0;
                foreach (@line) {
                    if ( defined $_ && $_ ne '' && $_ ne 'NA') {
                        my $rank = $rank_lookup{$header[$counter]};
                        if (!$genotype_filter_string || exists($genotype_filter{$_})) {
                            $geno_rank_counter{$rank}->{$position}->{$_}++;
                            $geno_rank_seen_scores{$_}++;
                        }
                    }
                    $counter++;
                }
                $position++;
            }
        }
    close($geno_fh);
    # print STDERR Dumper \%geno_rank_counter;
    my @sorted_seen_scores = sort keys %geno_rank_seen_scores;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_trial_genotype_comparision";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $header_string = 'Rank,Genotype,Marker,Count';

    open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
        print $F $header_string."\n";
        while (my ($rank, $pos_o) = each %geno_rank_counter) {
            while (my ($position, $score_o) = each %$pos_o) {
                while (my ($score, $count) = each %$score_o) {
                    print $F $rank_percentile{$rank}.",$score,$position,$count\n";
                }
            }
        }
    close($F);

    my @set = ('0' ..'9', 'A' .. 'F');
    my @colors;
    for (1..scalar(@sorted_seen_scores)) {
        my $str = join '' => map $set[rand @set], 1 .. 6;
        push @colors, '#'.$str;
    }
    my $color_string = join '\',\'', @colors;

    my $dir = $c->tempfiles_subdir('/trial_analysis_genotype_comparision_plot_dir');
    my $pheno_figure_tempfile_string = $c->tempfile( TEMPLATE => 'trial_analysis_genotype_comparision_plot_dir/figureXXXX');
    $pheno_figure_tempfile_string .= '.png';
    my $pheno_figure_tempfile = $c->config->{basepath}."/".$pheno_figure_tempfile_string;

    my $cmd = 'R -e "library(data.table); library(ggplot2);
    mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
    mat\$Marker <- as.numeric(as.character(mat\$Marker));
    mat\$Genotype <- as.character(mat\$Genotype);
    options(device=\'png\');
    par();
    sp <- ggplot(mat, aes(x = Marker, y = Count)) +
        geom_line(aes(color = Genotype), size=0.2) +
        scale_fill_manual(values = c(\''.$color_string.'\')) +
        theme_minimal();
    sp <- sp + facet_grid(Rank ~ .);';
    $cmd .= 'ggsave(\''.$pheno_figure_tempfile.'\', sp, device=\'png\', width=12, height=12, units=\'in\');
    dev.off();"';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $c->stash->{rest} = {success => 1, results => \%accession_sum, sorted_accessions => \@sorted_accessions, sorted_values => \@sorted_values, sorted_ranks => \@sorted_ranks, sorted_rank_groups => \@sorted_rank_groups, figure => $pheno_figure_tempfile_string};
}

sub trial_calculate_numerical_derivative : Chained('trial') PathPart('calculate_numerical_derivative') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $derivative = $c->req->param('derivative');
    my $data_level = $c->req->param('data_level');

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this analysis!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $user_id);

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>$data_level,
            trait_list=>$trait_ids,
            trial_list=>[$c->stash->{trial_id}],
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %phenotype_data;
    my %seen_plot_names;
    my %seen_rows;
    my %seen_cols;
    my %row_col_hash;
    my %rev_row;
    my %rev_col;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_stock_id};
        my $obsunit_name = $obs_unit->{observationunit_uniquename};
        my $observations = $obs_unit->{observations};
        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
        my $germplasm_uniquename = $obs_unit->{germplasm_uniquename};
        my $row = $obs_unit->{obsunit_row_number};
        my $col = $obs_unit->{obsunit_col_number};
        foreach (@$observations){
            $phenotype_data{$obsunit_name}->{$_->{trait_name}} = $_->{value};
        }
        $rev_row{$obsunit_name} = $row;
        $rev_col{$obsunit_name} = $col;
        $row_col_hash{$row}->{$col} = $obsunit_name;
        $seen_plot_names{$obsunit_name}++;
        $seen_rows{$row}++;
        $seen_cols{$col}++;
    }
    my @sorted_plot_names = sort keys %seen_plot_names;
    my @sorted_rows = sort { $a <=> $b } keys %seen_rows;
    my @sorted_cols = sort { $a <=> $b } keys %seen_cols;

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my %trait_id_map;
    foreach my $trait_name (@sorted_trait_names) {
        my $trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
        $trait_id_map{$trait_name} = $trait_cvterm_id;
    }
    my @trait_ids = values %trait_id_map;

    my $analysis_statistical_ontology_term = 'Two-dimension numerical first derivative across rows and columns|SGNSTAT:0000022';
    # my $analysis_statistical_ontology_term = 'Two-dimension numerical second derivative across rows and columns|SGNSTAT:0000023';
    my $stat_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $analysis_statistical_ontology_term)->cvterm_id();

    my $categories = {
        object => [],
        attribute => [$stat_cvterm_id],
        method => [],
        unit => [],
        trait => \@trait_ids,
        tod => [],
        toy => [],
        gen => [],
    };

    my %time_term_map;

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, $categories);
    my $existing_traits = $traits->{existing_traits};
    my $new_traits = $traits->{new_traits};
    # print STDERR Dumper $new_traits;
    # print STDERR Dumper $existing_traits;
    my %new_trait_names;
    foreach (@$new_traits) {
        my $components = $_->[0];
        $new_trait_names{$_->[1]} = join ',', @$components;
    }

    my $onto = CXGN::Onto->new( { schema => $schema } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my %composed_trait_map;
    while (my($trait_name, $trait_id) = each %trait_id_map) {
        my $components = [$trait_id, $stat_cvterm_id];
        my $composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, $components);
        my $composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $composed_cvterm_id, 'extended');
        $composed_trait_map{$trait_name} = $composed_trait_name;
    }
    my @composed_trait_names = values %composed_trait_map;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my %derivative_results;
    no warnings 'uninitialized';
    foreach my $s (@sorted_plot_names) {
        foreach my $t (@sorted_trait_names) {
            my $trait = $composed_trait_map{$t};
            my @derivs;
            my $val = $phenotype_data{$s}->{$t};
            my $row = $rev_row{$s};
            my $col = $rev_col{$s};
            my @values = (
                $phenotype_data{$row_col_hash{$row-1}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col+1}}->{$t},

                $phenotype_data{$row_col_hash{$row-1}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row-1}->{$col+1}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col+1}}->{$t},

                $phenotype_data{$row_col_hash{$row-2}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col+2}}->{$t},

                $phenotype_data{$row_col_hash{$row-2}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row-2}->{$col+2}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col+2}}->{$t},

                $phenotype_data{$row_col_hash{$row-2}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row-2}->{$col+1}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col+1}}->{$t},

                $phenotype_data{$row_col_hash{$row-1}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row-1}->{$col+2}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col+2}}->{$t},

                $phenotype_data{$row_col_hash{$row-3}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row}->{$col+3}}->{$t},

                $phenotype_data{$row_col_hash{$row-3}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row-3}->{$col+3}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col+3}}->{$t},

                $phenotype_data{$row_col_hash{$row-3}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col-1}}->{$t},
                $phenotype_data{$row_col_hash{$row-3}->{$col+1}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col+1}}->{$t},

                $phenotype_data{$row_col_hash{$row-3}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col-2}}->{$t},
                $phenotype_data{$row_col_hash{$row-3}->{$col+2}}->{$t},
                $phenotype_data{$row_col_hash{$row+3}->{$col+2}}->{$t},

                $phenotype_data{$row_col_hash{$row-1}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row-1}->{$col+3}}->{$t},
                $phenotype_data{$row_col_hash{$row+1}->{$col+3}}->{$t},

                $phenotype_data{$row_col_hash{$row-2}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col-3}}->{$t},
                $phenotype_data{$row_col_hash{$row-2}->{$col+3}}->{$t},
                $phenotype_data{$row_col_hash{$row+2}->{$col+3}}->{$t}
            );

            foreach (@values) {
                if (defined($_)) {
                    push @derivs, ($val - $_);
                    push @derivs, ( (($val + $_)/8) - $_);
                    push @derivs, ( (($val + $_)/4) - $_);
                    push @derivs, ( (($val + $_)*3/8) - $_);
                    push @derivs, ( (($val + $_)/2) - $_);
                    push @derivs, ( (($val + $_)*5/8) - $_);
                    push @derivs, ( (($val + $_)*3/4) - $_);
                    push @derivs, ( (($val + $_)*7/8) - $_);
                }
            }
            # print STDERR Dumper \@derivs;
            if (scalar(@derivs) > 0) {
                my $d = sum(@derivs)/scalar(@derivs);
                $derivative_results{$s}->{$trait} = [$d, $timestamp, $user_name, '', ''];
            }
        }
    }
    # print STDERR Dumper \%derivative_results;

    if (scalar(keys %derivative_results) != scalar(@sorted_plot_names)) {
        $c->stash->{rest} = { error => "Not all plots have rows and columns defined! Please make sure row and columns are saved for this field trial!"};
        return;
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my %phenotype_metadata = (
        'archived_file' => 'none',
        'archived_file_type' => 'numerical_derivative_row_and_column_computation',
        'operator' => $user_name,
        'date' => $timestamp
    );

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@sorted_plot_names,
        trait_list=>\@composed_trait_names,
        values_hash=>\%derivative_results,
        has_timestamps=>0,
        overwrite_values=>1,
        ignore_new_values=>0,
        metadata_hash=>\%phenotype_metadata,
        composable_validation_check_name=>$c->config->{composable_validation_check_name},
        allow_repeat_measures=>$c->config->{allow_repeat_measures}
    );
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => 1};
}


#
# TRIAL ENTRY NUMBERS
#

#
# Get an array of entry numbers for the specified trial
# path param: trial id
# return: an array of objects, with the following keys:
#   stock_id = id of the stock
#   stock_name = uniquename of the stock
#   entry_number = entry number for the stock in this trial
#
sub get_entry_numbers : Chained('trial') PathPart('entry_numbers') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $trial = $c->stash->{trial};

    # Get Entry Number map (stock_id -> entry number)
    my $entry_number_map = $trial->get_entry_numbers();
    my @entry_numbers;
    if ( $entry_number_map ) {

        # Parse each stock - get its name
        foreach my $stock_id (keys %$entry_number_map) {
            my $row = $schema->resultset("Stock::Stock")->find({ stock_id => int($stock_id) });
            my $stock_name = $row ? $row->uniquename() : 'STOCK NO LONGER EXISTS!';
            my $entry_number = $entry_number_map->{$stock_id};
            push(@entry_numbers, { stock_id => int($stock_id), stock_name => $stock_name, entry_number => $entry_number });
        }

    }

    # Return the array of entry number info
    $c->stash->{rest} = { entry_numbers => \@entry_numbers };
}

#
# Create an entry number template for the specified trials
# query param: 'trial_ids' = comma separated list of trial ids
# return: 'file' = path to tempfile of excel template
#
sub create_entry_number_template : Path('/ajax/breeders/trial_entry_numbers/create') Args(0) {
    my $self = shift;
    my $c = shift;
    my @trial_ids = split(',', $c->req->param('trial_ids'));
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = "entry_numbers_XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".xlsx";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trial_list => \@trial_ids,
        filename => $tempfile,
        format => 'TrialEntryNumbers'
    });
    my $error = $download->download();

    $c->stash->{rest} = { file => $tempfile };
}

#
# Download an entry number template
# query param: 'file' = path of entry number template tempfile to download
# return: contents of excel file
#
sub download_entry_number_template : Path('/ajax/breeders/trial_entry_numbers/download') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tempfile = $c->req->param('file');

    $c->res->content_type('application/vnd.ms-excel');
    $c->res->header('Content-Disposition', qq[attachment; filename="entry_number_template.xlsx"]);
    my $output = read_file($tempfile);
    $c->res->body($output);
}

#
# Upload an entry number template
# upload params:
#   upload_entry_numbers_file: Excel file to validate and parse
#   ignore_warnings: true to add processed data if warnings exist
# return: validation errors and warnings or success = 1 if entry numbers sucessfully stored
#   filename: original upload file name
#   error: array of error messages
#   warning: array of warning messages
#   missing_accessions: array of stock names not found in the database
#   missing_trials: array of trial names not found in database
#   success: set to `1` if file successfully validated and stored
#
sub upload_entry_number_template : Path('/ajax/breeders/trial_entry_numbers/upload') : ActionClass('REST') { }
sub upload_entry_number_template_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $upload = $c->req->upload('upload_entry_numbers_file');
    my $ignore_warnings = $c->req->param('ignore_warnings') eq 'true';
    my (@errors, %response);

    my $subdirectory = "trial_entry_numbers";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Make sure user is logged in
    if ( !$c->user() ) {
        push(@errors, "You need to be logged in to upload entry numbers.");
        $c->stash->{rest} = { filename => $upload_original_name, error => \@errors };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

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
    if ( !$archived_filename_with_path ) {
        push(@errors, "Could not save file $upload_original_name in archive");
        $c->stash->{rest} = { filename => $upload_original_name, error => \@errors };
        return;
    }
    unlink $upload_tempfile;

    ## Parse the uploaded file
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialEntryNumbers');
    my $parsed_data = $parser->parse();
    my $parse_errors = $parser->get_parse_errors();
    my $parse_warnings = $parser->get_parse_warnings();

    print STDERR "IGNORE WARNINGS: $ignore_warnings\n";

    ## Return with warnings and errors
    if ( $parse_errors || (!$ignore_warnings && $parse_warnings) || !$parsed_data ) {
        if ( !$parse_errors && !$parse_warnings ) {
            push(@errors, "Data could not be parsed");
            $c->stash->{rest} = { filename => $upload_original_name, error => \@errors };
            return;
        }
        $c->stash->{rest} = {
            filename => $upload_original_name,
            error => $parse_errors->{'error_messages'},
            warning => $parse_warnings->{'warning_messages'},
            missing_accessions => $parse_errors->{'missing_accessions'},
            missing_trials => $parse_errors->{'missing_trials'}
        };
        return;
    }

    ## Process the parsed data
    foreach my $trial_id (keys %$parsed_data) {
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
        $trial->set_entry_numbers($parsed_data->{$trial_id});
    }

    $c->stash->{rest} = {
        success => 1,
        filename => $upload_original_name,
        warning => $parse_warnings->{'warning_messages'}
    };
    return;
}

sub delete_entry_numbers :Path('/ajax/breeders/trial_entry_numbers/delete') Args(0) {
    my $self = shift;
    my $c = shift;

    my $trial_id = $c->req->param("trial_id");

    if (! $trial_id) {
	$c->stash->{rest} = { error_string => 'A trial id must be provided to delete the entry numbers.' };
	return;
    }

    if (!$c->user()) {
        $c->stash->{rest} = {error_string => "You must be logged in to update trial status." };
        return;
    }

    if (!$c->user()->check_roles("curator")) {
	$c->stash->{rest} = {error_string => "Your account must have the curator role to delete entry numbers" };
	return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $user_id);
    my $project_entry_number_map_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_entry_number_map', 'project_property')->cvterm_id();


    my $row = $schema->resultset("Project::Projectprop")->find( { type_id => $project_entry_number_map_cvterm_id, project_id => $trial_id });

    eval {
	$row->delete();
    };

    if ($@) {
	$c->stash->{rest} = { error_string => "The following error occurred when trying to delete an entry map: $@\n" };
	return;
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}


sub update_trial_status : Chained('trial') PathPart('update_trial_status') : ActionClass('REST'){ }

sub update_trial_status_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->stash->{trial_id};
    my $trial_status = $c->req->param("trial_status");
    my $user_name = $c->req->param("user_name");
    my $activity_date = $c->req->param("activity_date");

    if (!$c->user()) {
        $c->stash->{rest} = {error_string => "You must be logged in to update trial status." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    my $trial_status_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_status_json', 'project_property')->cvterm_id();
    my $prop = $schema->resultset("Project::Projectprop")->find({project_id => $trial_id, type_id => $trial_status_type_id});
    my $prop_id;
    my %all_activities_hash;
    if ($prop) {
        $prop_id = $prop->projectprop_id();
        my $status_json = $prop->value();
        my $status_hash_ref = decode_json $status_json;
        my $all_activities = $status_hash_ref->{'trial_activities'};
        %all_activities_hash = %{$all_activities};
    }

    $all_activities_hash{$trial_status}{'user_id'} = $user_id;
    $all_activities_hash{$trial_status}{'activity_date'} = $activity_date;

    my $trial_status_obj = CXGN::TrialStatus->new({ bcs_schema => $schema });
    $trial_status_obj->trial_activities(\%all_activities_hash);
    $trial_status_obj->parent_id($trial_id);
    $trial_status_obj->prop_id($prop_id);
    my $project_prop_id = $trial_status_obj->store();

    $c->stash->{rest} = {success => 1 };
    return;

}


sub get_all_trial_activities :Chained('trial') PathPart('all_trial_activities') Args(0){
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};
    my $activities = $c->config->{'trial_activities'};
    my @activity_list = split ',', $activities;

    my $trial_status_obj = CXGN::TrialStatus->new({ bcs_schema => $schema, people_schema => $people_schema, parent_id => $trial_id, activity_list => \@activity_list });
    my $activity_info = $trial_status_obj->get_trial_activities();

    $c->stash->{rest} = { data => $activity_info };
}

sub update_trial_design_type : Chained('trial') PathPart('update_trial_design_type') : ActionClass('REST'){ }

sub update_trial_design_type_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_design_type = $c->req->param("trial_design_type");

    if (!$c->user()) {
        $c->stash->{rest} = {error_string => "You must be logged in to update trial status." };
        return;
    }
    my $user_id;
    my $curator;
    $user_id = $c->user()->get_object()->get_sp_person_id();
    $curator = $c->user()->check_roles('curator') if $user_id;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    if (!$curator == 1) {
        $c->stash->{rest} = {error_string => "You must be curator to change experimental design type." };
        return;
    }

    my $trial = $c->stash->{trial};

    $trial->set_design_type($trial_design_type);

    $c->stash->{rest} = {success => 1 };

    return;

}


#
# GET TRIAL PLOT ORDERS
# Get the ordered plots of one or more trials based on the requested ordering parameters
# Arguments:
#   - trial_ids: array of trial ids
#   - type: plot order file type ('planting', 'harvest', or 'harvestmaster')
#   - order: the order to traverse the plots ('by_col_serpentine', 'by_col_zigzag', 'by_row_serpentine', 'by_row_zigzag')
#   - start: the corner of the trial layout to start the traversal ('bottom_left', 'top_left', 'top_right', 'bottom_right')
#   - top_border: set to true to include a top border
#   - right_border: set to true to include a right border
#   - bottom_border: set to true to include a bottom border
#   - left_border: set to true to include a left border
#   - gaps: set to true to include gaps / missing plots
#   - hm_pltid: property to use as the harvestmaster PLTID (default: 'plot_id')
#   - hm_range: property to use as the harvestmaster range (default: 'row_number')
#   - hm_row: property to use as the harvestmaster row (default: 'col_number')
#
sub get_trial_plot_order : Path('/ajax/breeders/trial_plot_order') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my @trial_ids = split(',', $c->req->param('trial_ids') || '');
    my $type = $c->req->param('type') || 'planting';
    my $order = $c->req->param('order') || 'by_row_zigzag';
    my $start = $c->req->param('start') || 'bottom_left';
    my $top_border = $c->req->param('top_border') || 'false';
    my $right_border = $c->req->param('right_border') || 'false';
    my $bottom_border = $c->req->param('bottom_border') || 'false';
    my $left_border = $c->req->param('left_border') || 'false';
    my $gaps = $c->req->param('gaps') || 'false';
    my $subplots = $c->req->param('subplots') || 'false';
    my $plants = $c->req->param('plants') || 'false';
    my $hm_pltid = $c->req->param('hm_pltid') || 'plot_id';
    my $hm_range = $c->req->param('hm_range') || 'row_number';
    my $hm_row = $c->req->param('hm_row') || 'col_number';
    my $include_subplots_plants = $subplots eq 'true' || $plants eq 'true';

    # Check parameters
    if ( scalar(@trial_ids) eq 0 ) {
        $c->stash->{rest} = { error => "No trial_ids provided!" };
        return;
    }
    if ( $type ne 'planting' && $type ne 'collection' && $type ne 'harvest' && $type ne 'harvestmaster' ) {
        $c->stash->{rest} = { error => "Unrecognized type!" };
        return;
    }
    if ( ( $order !~ /by_col/ && $order !~ /by_row/ ) || ( $order !~ /serpentine/ && $order !~ /zigzag/ ) ) {
        $c->stash->{rest} = { error => "Unrecognized order!" };
        return;
    }
    if ( ( $start !~ /bottom/ && $start !~ /top/ ) || ( $start !~ /left/ && $start !~ /right/ ) ) {
        $c->stash->{rest} = { error => "Unrecognized start!" };
        return;
    }
    my %borders = (
        top => $top_border eq 'true' || 0,
        right => $right_border eq 'true' || 0,
        bottom => $bottom_border eq 'true' || 0,
        left => $left_border eq 'true' || 0
    );

    # Get the sorted plots
    my $results = CXGN::Trial->get_sorted_plots($schema, \@trial_ids, $order, $start, \%borders, $gaps eq 'true' || 0);

    # Return error message, if set
    if ( !defined $results->{error} && !defined $results->{plots} ) {
        $results->{error} = "An unknown error occurred";
    }
    if ( defined $results->{error} ) {
        $c->stash->{rest} = { error => $results->{error} };
        return;
    }

    # Add entry numbers
    foreach my $trial_id (@trial_ids) {
        my $project = CXGN::Project->new({bcs_schema => $schema, trial_id => $trial_id});
        my $entry_numbers = $project->get_entry_numbers();
        my $trial_name = $project->name();
        if ( $entry_numbers ) {
            foreach my $accession_id (keys %$entry_numbers) {
                foreach my $plot (@{$results->{plots}}) {
                    if ( $plot->{trial_name} eq $trial_name && $plot->{accession_id} eq $accession_id ) {
                        $plot->{entry_number} = $entry_numbers->{$accession_id};
                    }
                }
            }
        }
    };

    # Fetch subplots and/or plant entries, if requested
    my %subplots_by_plot;
    my %plants_by_plot;
    if ( $include_subplots_plants ) {
        foreach my $trial_id (@trial_ids) {
            my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });

            # Get subplots for the trial
            if ( $subplots eq 'true' ) {
                my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
                    schema => $schema,
                    trial_id => $trial_id,
                    data_level => 'subplots',
                    selected_columns => {"subplot_name"=>1,"subplot_id"=>1,"plot_name"=>1,"plot_id"=>1},
                });
                my $output = $trial_layout_download->get_layout_output()->{output};

                if ( defined $output ) {
                    foreach (@$output) {
                        my $subplot_name = $_->[0];
                        my $subplot_id = $_->[1];
                        my $plot_name = $_->[2];
                        if ( $plot_name ne 'plot_name' ) {
                            $subplots_by_plot{$plot_name} = [] if !exists $subplots_by_plot{$plot_name};
                            push @{$subplots_by_plot{$plot_name}}, { name => $subplot_name, id => $subplot_id };
                        }
                    }
                }
            }

            # Get plants for the trial
            if ( $plants eq 'true' ) {
                my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
                    schema => $schema,
                    trial_id => $trial_id,
                    data_level => 'plants',
                    selected_columns => {"plant_name"=>1,"plant_id"=>1,"plot_name"=>1,"plot_id"=>1},
                });
                my $output = $trial_layout_download->get_layout_output()->{output};

                if ( defined $output ) {
                    foreach (@$output) {
                        my $plant_name = $_->[0];
                        my $plant_id = $_->[1];
                        my $plot_name = $_->[2];
                        if ( $plot_name ne 'plot_name' ) {
                            $plants_by_plot{$plot_name} = [] if !exists $plants_by_plot{$plot_name};
                            push @{$plants_by_plot{$plot_name}}, { name => $plant_name, id => $plant_id };
                        }
                    }
                }
            }
        }
    }

    # Generate CSV File
    my $filename;
    my @data;
    if ( $type eq 'planting' || $type eq 'collection' || $type eq 'harvest' ) {
        $filename = $type . "_order_" . join("-", @trial_ids) . ".csv";
        my $order_column = $type . "_order";

        # Add CSV headers
        my @headers = ($order_column);
        push(@headers, "observationunit_name") if $include_subplots_plants;
        push(@headers,
            "type",
            "location_name",
            "trial_name",
            "plot_number",
            "plot_name",
            "accession_name",
            "entry_number",
            "seedlot_name",
            "row_number",
            "col_number",
            "rep_number",
            "block_number",
            "is_a_control"
        );
        push(@data, \@headers);

        # Add plot rows
        my $plots = $results->{plots};
        my $order_offset = 0;
        foreach my $plot (@$plots) {

            # Add plots
            if ( $plot->{type} eq 'plot' ) {
                my @d = ($plot->{order}+$order_offset);
                push(@d, $plot->{plot_name}) if $include_subplots_plants;
                push(@d,
                    $plot->{type},
                    "\"$plot->{location_name}\"",
                    $plot->{trial_name},
                    $plot->{plot_number},
                    $plot->{plot_name},
                    $plot->{accession_name},
                    $plot->{entry_number},
                    $plot->{seedlot_name},
                    $plot->{row_number},
                    $plot->{col_number},
                    $plot->{rep_number},
                    $plot->{block_number},
                    $plot->{is_a_control}
                );
                push(@data, \@d);

                # Add additional subplots for the current plot, if found
                if ( $include_subplots_plants && exists $subplots_by_plot{$plot->{plot_name}} ) {
                    foreach my $sp (@{$subplots_by_plot{$plot->{plot_name}}}) {
                        $order_offset++;
                        my @d = ($plot->{order}+$order_offset);
                        push(@d, $sp->{name});
                        push(@d,
                            "subplot",
                            "\"$plot->{location_name}\"",
                            $plot->{trial_name},
                            $plot->{plot_number},
                            $plot->{plot_name},
                            $plot->{accession_name},
                            $plot->{entry_number},
                            $plot->{seedlot_name},
                            $plot->{row_number},
                            $plot->{col_number},
                            $plot->{rep_number},
                            $plot->{block_number},
                            $plot->{is_a_control}
                        );
                        push(@data, \@d);
                    }
                }

                # Add additional plant entries for the current plot, if found
                if ( $include_subplots_plants && exists $plants_by_plot{$plot->{plot_name}} ) {
                    foreach my $p (@{$plants_by_plot{$plot->{plot_name}}}) {
                        $order_offset++;
                        my @d = ($plot->{order}+$order_offset);
                        push(@d, $p->{name});
                        push(@d,
                            "plant",
                            "\"$plot->{location_name}\"",
                            $plot->{trial_name},
                            $plot->{plot_number},
                            $plot->{plot_name},
                            $plot->{accession_name},
                            $plot->{entry_number},
                            $plot->{seedlot_name},
                            $plot->{row_number},
                            $plot->{col_number},
                            $plot->{rep_number},
                            $plot->{block_number},
                            $plot->{is_a_control}
                        );
                        push(@data, \@d);
                    }
                }
            }

            # Add borders, gaps, etc if in the layout
            else {
                my @d = ($plot->{order}+$order_offset);
                push(@d, "") if $include_subplots_plants;
                push(@d,
                    $plot->{type},
                    "", # location
                    "", # trial
                    "", # plot number
                    "", # plot name
                    "", # accession
                    "", # entry number
                    "", # seedlot
                    $plot->{row_number},
                    $plot->{col_number},
                    "", # rep
                    "", # block
                    "", # control
                );
                push(@data, \@d);
            }

        }
    }

    # Generate HarvestMaster File
    elsif ( $type eq 'harvestmaster' ) {
        $filename = "harvestmaster_" . join("-", @trial_ids) . ".csv";

        # Add CSV headers
        my @headers = ("PLTID", "Range", "Row");
        push(@headers, "observationunit_name") if $include_subplots_plants;
        push(@headers, "type", "location_name", "trial_name", "plot_number", "plot_name", "accession_name", "entry_number", "seedlot_name", "rep_number", "block_number", "is_a_control");
        push(@data, \@headers);

        # Add plot rows
        my $plots = $results->{plots};
        foreach my $plot (@$plots) {

            # Add plots
            if ( $plot->{type} eq 'plot' ) {
                my @d = ($plot->{$hm_pltid}, $plot->{$hm_range}, $plot->{$hm_row});
                push(@d, $plot->{plot_name}) if $include_subplots_plants;
                push(@d,
                    $plot->{type},
                    "\"$plot->{location_name}\"",
                    $plot->{trial_name},
                    $plot->{plot_number},
                    $plot->{plot_name},
                    $plot->{accession_name},
                    $plot->{entry_number},
                    $plot->{seedlot_name},
                    $plot->{rep_number},
                    $plot->{block_number},
                    $plot->{is_a_control}
                );
                push(@data, \@d);

                # Add additional subplots for the current plot, if found
                if ( $include_subplots_plants && exists $subplots_by_plot{$plot->{plot_name}} ) {
                    foreach my $sp (@{$subplots_by_plot{$plot->{plot_name}}}) {
                        my $id = $plot->{$hm_pltid};
                        $id = $sp->{id} if $hm_pltid eq 'plot_id';
                        $id = $sp->{name} if $hm_pltid eq 'plot_name';
                        my @d = ($id, $plot->{$hm_range}, $plot->{$hm_row});
                        push(@d, $sp->{name});
                        push(@d,
                            "subplot",
                            "\"$plot->{location_name}\"",
                            $plot->{trial_name},
                            $plot->{plot_number},
                            $plot->{plot_name},
                            $plot->{accession_name},
                            $plot->{entry_number},
                            $plot->{seedlot_name},
                            $plot->{rep_number},
                            $plot->{block_number},
                            $plot->{is_a_control}
                        );
                        push(@data, \@d);
                    }
                }

                # Add additional plant entries for the current plot, if found
                if ( $include_subplots_plants && exists $plants_by_plot{$plot->{plot_name}} ) {
                    foreach my $p (@{$plants_by_plot{$plot->{plot_name}}}) {
                        my $id = $plot->{$hm_pltid};
                        $id = $p->{id} if $hm_pltid eq 'plot_id';
                        $id = $p->{name} if $hm_pltid eq 'plot_name';
                        my @d = ($id, $plot->{$hm_range}, $plot->{$hm_row});
                        push(@d, $p->{name});
                        push(@d,
                            "plant",
                            "\"$plot->{location_name}\"",
                            $plot->{trial_name},
                            $plot->{plot_number},
                            $plot->{plot_name},
                            $plot->{accession_name},
                            $plot->{entry_number},
                            $plot->{seedlot_name},
                            $plot->{rep_number},
                            $plot->{block_number},
                            $plot->{is_a_control}
                        );
                        push(@data, \@d);
                    }
                }

            }

            # Add gaps, borders, etc if in the layout
            else {
                my @d = ($plot->{type}, $plot->{$hm_range}, $plot->{$hm_row});
                push(@d, "") if $include_subplots_plants; # observationunit_name
                push(@d,
                    $plot->{type},
                    "", # location
                    "", # trial
                    "", # plot number
                    "", # plot name
                    "", # accession
                    "", # entry number
                    "", # seedlot
                    "", # rep
                    "", # block
                    "", # control
                );
                push(@data, \@d);
            }
        }
    }

    # Join all lines into CSV format
    my @all_lines = ();
    foreach my $each_line (@data) {
        my $each_line_string = join(",", @$each_line);
        push @all_lines, $each_line_string;
    }
    my $all_lines_string = join("\n", @all_lines);

    # Return the generated file
    $c->res->content_type('text/csv');
    $c->res->headers->push_header("Content-disposition", "attachment; filename=\"$filename\"");
    $c->res->body($all_lines_string);

    return;
}


#
# GET LINKED FIELD TRIALS
# Get additional field trials that share the same physical field (to display together in the plot layout tool)
# A linked trial: shares the same year, the same location, and the location type is 'Field'
# path param: trial id
# return:
#   error: error message
#   trials: list of linked trials
#       trial_id: id of trial
#       trial_name: name of trial
#       ...
#
sub get_linked_field_trials : Chained('trial') PathPart('linked_field_trials') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};
    my $trial_location = $c->stash->{trial}->get_location();
    my $trial_location_id = $trial_location->[0];
    my $trial_year = $c->stash->{trial}->get_year();

    # Check Trial Location: ensure that it is a "field" type location
    my $locations = CXGN::Trial::get_all_locations($schema);
    foreach my $l (@$locations) {
        if ( $l->[0] eq $trial_location_id ) {
            my $location_type = $l->[8];
            if ( $location_type ne "Field" ) {
                $c->stash->{rest} = { error => "The location for this trial is a \"$location_type\" location.  In order to group trials together: they must share the same year, the same location, and the location type must be \"Field\"" };
                return;
            }
        }
    }

    # Get Trials that share the same year and location
    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema => $schema,
        location_id_list => [$trial_location_id],
        year_list => [$trial_year],
        field_trials_only => 1
    });
    my ($data, $total_count) = $trial_search->search();

    # Parse Results
    my @rtn;
    foreach my $t (@$data) {
        push(@rtn, $t);
    }

    # No matches found...
    if ( scalar(@rtn) == 0 ) {
        $c->stash->{rest} = { error => "No linked Trials found.  In order to group trials together: they must share the same year, the same location, and the location type must be \"Field\"" };
        return;
    }

    # Return the matches...
    $c->stash->{rest} = { trials => \@rtn };
    return;
}


sub get_all_soil_data :Chained('trial') PathPart('all_soil_data') Args(0){
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};

    my $soil_data_obj = CXGN::BreedersToolbox::SoilData->new({ bcs_schema => $schema, parent_id => $trial_id });
    my $soil_data = $soil_data_obj->get_all_soil_data();
    my @soil_data_list = @$soil_data;
    my @formatted_soil_data;
    foreach my $info_ref (@soil_data_list) {
        my @all_soil_data = ();
        my @info = @$info_ref;
        my $trial_id = pop @info;
        my $soil_data_details = pop @info;
        my $order_ref = pop @info;
        my @data_type_order = @$order_ref;
        foreach my $type(@data_type_order) {
            my $soil_data = $soil_data_details->{$type};
            my $soil_data_string = $type.":"." ".$soil_data;
            push @all_soil_data, $soil_data_string;
        }
        my $soil_data_details_string = join("<br>", @all_soil_data);
        push @info, ($soil_data_details_string, "<a href='/breeders/trial/$trial_id/download/soil_data?format=soil_data_xls&dataLevel=soil_data&prop_id=$info[0]'>Download</a>");
        push @formatted_soil_data, {
            trial_id => $trial_id,
            prop_id => $info[0],
            description => $info[1],
            date => $info[2],
            gps => $info[3],
            type_of_sampling => $info[4],
            soil_data => $info[5],
            download_link => $info[6]
        };
    }

    $c->stash->{rest} = { data => \@formatted_soil_data };
}


sub delete_soil_data : Chained('trial') PathPart('delete_soil_data') : ActionClass('REST'){ }

sub delete_soil_data_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $prop_id = $c->req->param("prop_id");
    my $trial_id = $c->stash->{trial_id};
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to delete soil data!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to delete soil data!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    if ($user_role ne 'curator') {
        $c->stash->{rest} = {error=>'Only a curator can delete soil data'};
        $c->detach();
    }

    my $soil_data_obj = CXGN::BreedersToolbox::SoilData->new({ bcs_schema => $schema, parent_id => $trial_id, prop_id => $prop_id });
    my $error = $soil_data_obj->delete_soil_data();

    print STDERR "ERROR = $error\n";

    if ($error) {
	    $c->stash->{rest} = { error => "An error occurred attempting to delete soil data. ($@)"};
	    return;
    }

    $c->stash->{rest} = { success => 1 };

}


sub delete_all_genotyping_plates_in_project : Chained('trial') PathPart('delete_all_genotyping_plates_in_project') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);

    my $genotyping_project_id = $c->stash->{trial_id};

    if (!$c->user()){
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete genotyping plates. Please contact us." };
        $c->detach();
    }

    my $plate_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $schema,
        project_id => $genotyping_project_id
    });
    my ($data, $total_count) = $plate_info->get_plate_info();
    my @genotyping_plate_ids;
    foreach  my $plate(@$data){
        my $number_of_samples_with_data = $plate->{number_of_samples_with_data};
        if ($number_of_samples_with_data > 0) {
            $c->stash->{rest} = { error => 'Cannot delete! One or more plates have genotyping data' };
            return;
        } else {
            my $plate_id = $plate->{plate_id};
            push @genotyping_plate_ids, $plate_id;
        }
    }

    my $number_of_plates = @genotyping_plate_ids;
    my $error;
    if ($number_of_plates > 0){
        foreach my $plate_id (@genotyping_plate_ids) {
            my $trial = CXGN::Trial->new({
                bcs_schema => $schema,
                metadata_schema => $metadata_schema,
                phenome_schema => $phenome_schema,
                trial_id => $plate_id
            });
            $error = $trial->delete_metadata();
            $error .= $trial->delete_field_layout();
            $error .= $trial->delete_project_entry();

        }
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    if ($error) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    $c->stash->{rest} = { success => 1 };
}

sub trial_collect_date_range :Chained('trial') :PathPart('collect_date_range') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->stash->{trial_id};
    my $cvterm_id = $c->req->param('cvterm_id');

    my $cvterm_clause = "";

    if ($cvterm_id) {
	    $cvterm_clause = " and cvterm_id = ?";
    }

    my $q = "select min(collect_date), max(collect_date), project_id from nd_experiment_project join nd_experiment_phenotype using(nd_experiment_id) join phenotype using(phenotype_id) join cvterm on(cvalue_id=cvterm_id) where nd_experiment_project.project_id=?  $cvterm_clause group by nd_experiment_project.project_id"; 
    my $dbh =  $c->dbc->dbh;
    my $h = $dbh->prepare($q);
    if ($cvterm_id) { 
	    $h->execute($trial_id, $cvterm_id);
    }
    else {
	    $h->execute($trial_id);
    }

    my ($start_date, $end_date, $project_id) = $h->fetchrow_array();

    if (! $project_id) {
	    $c->stash->{rest} = { error => "Trial with id $trial_id does not exist" };
	    return;
    }

    # print STDERR "collect_date_range: START DATE $start_date, END DATE $end_date\n";
    $c->stash->{rest} = { trial_id => $trial_id,
	     start_date => $start_date,
	     end_date => $end_date,
    };
}

sub get_analysis_instance_stock_type {
	my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $project = $schema->resultset('Project::Project')->find({
        project_id => $trial_id,
    });

    my $trial_layout_json_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property')->cvterm_id();

    my $trial_layout_json = $project->projectprops->find({ 'type_id' => $trial_layout_json_type_id });

    my $design;

    if ($trial_layout_json) {
        $design = decode_json $trial_layout_json->value;
    }

    if (keys %{$design}) {
        my $sample_design_key = (keys %{$design})[0];
        my $sample_trial_entry = $design->{$sample_design_key};

        if ($sample_trial_entry->{'accession_name'}) {
            return 'accession';
        } elsif($sample_trial_entry->{'analysis_result_stock_name'}) {
            return 'analysis_result';
        }
    }

}


sub stock_entry_summary_trial : Chained('trial') PathPart('stock_entry_summary') Args(0) {

    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $trial_id = $c->stash->{trial_id};
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id});
    my $stock_entries = $trial->get_stock_entry_summary();

    my @summary;
    foreach my $entry (@$stock_entries) {
        my ($parent_stock_name, $parent_stock_id, $parent_stock_type, $plot_name, $plot_id, $plant_name, $plant_id, $tissue_sample_name, $tissue_sample_id) =@$entry;
        my $parent_stock_link;
        if ($parent_stock_type eq 'accession') {
            $parent_stock_link = qq{<a href="/stock/$parent_stock_id/view">$parent_stock_name</a>};
        } elsif ($parent_stock_type eq 'cross') {
            $parent_stock_link = qq{<a href="/cross/$parent_stock_id">$parent_stock_name</a>};
        } elsif ($parent_stock_type eq 'family_name') {
            $parent_stock_link = qq{<a href="/family/$parent_stock_id">$parent_stock_name</a>};
        }

        push @summary, [$parent_stock_link, qq{<a href="/stock/$plot_id/view">$plot_name</a>}, qq{<a href="/stock/$plant_id/view">$plant_name</a>}, qq{<a href="/stock/$tissue_sample_id/view">$tissue_sample_name</a>}];
    }


    $c->stash->{rest} = { data => \@summary };
}


1;
