
=encoding utf-8

=head1 NAME

CXGN::Analysis - manage analyses on Breedbase

=head1 DESCRIPTION

Analyses are stored much like trials, starting out in the project table, and linking through to nd_experiment and stock through linking tables, as well phentoype to store the analysis results. Additional metadata is stored in in a projectprop with the type_id 'analysis_metadata_json'. The type of the project is 'analysis_project' (stored in a projectprop as well). Each analysis is assigned to a user, using and sp_person_id assigned in a projectprop.

=head2 TYPES

The data structure is built using type ids that are different from a regular field trial.

=over 4

=item nd_experiment.type_id

The nd_experiment.type_id links to 'analysis_experiment' (nd_experiment_property) (equivalent to 'field_experiment' in a trial),

=item stock.type_id

The stock.type_id links to 'analysis_instance' (stock_property) (equivalent to 'plot' in a trial)

=item stock_relationship.type_id

The stock_relationship.type_id links to 'analysis_of' (equivalent to 'plot_of' in field trials)

This is summarized in the following table:

 ┌──────────────────┬───────────────────────┬───────────────────┬────────────────┐
 │ project type     │ nd_experiment.type_id │ stock.type_id     │ stock_relation │
 │                  │                       │                   │ ship.type_id   │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ trial            │ field_experiment      │ plot              │ plot_of        │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ genotyping_plate │ genotyping_experiment │ tissue_sample     │ sample_of      │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ analysis         │ analysis_experiment   │ analysis_instance │ analysis_of    │
 └──────────────────┴───────────────────────┴───────────────────┴────────────────┘


=back

The data in  analysis_metdata_json is managed by the CXGN::Analysis::AnalysisMetadata class and contains the dataset_id used to generate the analysis, the actual analysis protocol that was run, and the traits relevant to the analysis.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::Analysis;

use Moose;

extends 'CXGN::Project';

use Try::Tiny;
use DateTime;
use Data::Dumper;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialDesignStore;
use CXGN::Trial::TrialLayout;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Analysis::AnalysisMetadata;
use CXGN::List::Transform;
use CXGN::Dataset;
use CXGN::AnalysisModel::SaveModel;
use CXGN::People::Person;
use CXGN::AnalysisModel::GetModel;
use JSON::XS;

=head2 bcs_schema()

=cut

has 'bcs_schema' => (is => 'rw', isa => 'Bio::Chado::Schema', required => 1 );

=head2 people_schema()

=cut

has 'people_schema' => (is => 'rw', isa => 'CXGN::People::Schema', required=>1);

=head2 metadata_schema()

=cut

has 'metadata_schema' => (is => 'rw', isa => 'CXGN::Metadata::Schema', required=>1);

=head2 phenome_schema()

=cut

has 'phenome_schema' => (is => 'rw', isa => 'CXGN::Phenome::Schema', required=>1);

=head2 project_id()

=cut

#has 'project_id' => (is => 'rw', isa => 'Int');

=head2 name()

=cut

#has 'name' => (is => 'rw', isa => 'Str');

=head2 description()

=cut

##has 'description' => (is => 'rw', isa => 'Str', default => "No description");

=head2 breeding_program_id()

=cut

has 'breeding_program_id' => (is => 'rw', isa => 'Int');

=head2 accession_names()

=cut

has 'accession_names' => (is => 'rw', isa => 'Maybe[ArrayRef]', lazy => 1, builder => '_load_accession_names');

=head2 design()

=cut

has 'design' => (is => 'rw', isa => 'Ref', lazy => 1, builder => '_get_layout');

=head2 traits()

=cut

has 'traits' => (is => 'rw', isa => 'ArrayRef', builder => '_load_traits', lazy => 1);

=head2 nd_geolocation_id()

=cut

has 'nd_geolocation_id' => (is => 'rw', isa=> 'Maybe[Int]');

=head2 user_id()

=cut

has 'user_id' => (is => 'rw', isa => 'Int');

=head2 user_role()

=cut

has 'user_role' => (is => 'rw', isa => 'Str');

=head2 analysis_model_protocol_id()

nd_protocol_id of save model information

=cut

has 'analysis_model_protocol_id' => (isa => 'Int|Undef', is => 'rw');

=head2 metadata()

CXGN::Analysis::AnalysisMetadata object.

=cut

has 'metadata' => (isa => 'Maybe[CXGN::Analysis::AnalysisMetadata]', is => 'rw');

#sub BUILDARGS {
#    my $self = shift;
#    my $args = shift;
#    $args->{trial_id} = $args->{project_id};
#}

#has 'project' => (isa => 'CXGN::Project', is => 'rw');

=head2 year()

year the analysis was done.

=cut

#has 'year' => (isa => 'Str', is => 'rw');

=head2 saved_model()

information about the saved model.

=cut

has 'saved_model' => (isa => 'HashRef', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    print STDERR "BUILD CXGN::Analysis...\n";
    my $metadata;

    if ($self->get_trial_id()) {
        my $schema = $args->{bcs_schema};
        print STDERR "Location id retrieved : = ".$self->get_location()->[0]."\n";
        $self->nd_geolocation_id($self->get_location()->[0]);

        my $metadata_json_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_metadata_json', 'project_property')->cvterm_id();
        my $rs = $self->bcs_schema()->resultset("Project::Projectprop")->search( { project_id => $self->get_trial_id(), type_id => $metadata_json_id });

        my $stockprop_id;
        if ($rs->count() > 0) {
            $stockprop_id = $rs->first()->projectprop_id();
        }

        print STDERR "Create AnalysisMetadata object...\n";
        $metadata = CXGN::Analysis::AnalysisMetadata->new( { bcs_schema => $schema, prop_id => $stockprop_id });
        $self->metadata($metadata);

        $stockprop_id = $metadata->prop_id();

        my $time = DateTime->now();
        print STDERR "prop_id is $stockprop_id...\n";
        if (! defined($stockprop_id)) {
            print STDERR "project_id = ".$self->get_trial_id()." with stockprop_id = undefined...storing metadata...\n";
            $metadata->parent_id($self->get_trial_id());
            $metadata->create_timestamp($time->ymd()." ".$time->hms());
            $metadata->store();
        }

        my $analysis_nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_experiment', 'experiment_type')->cvterm_id();
        my $nd_protocol_q = "SELECT nd_protocol_id FROM nd_experiment_protocol JOIN nd_experiment ON (nd_experiment_protocol.nd_experiment_id = nd_experiment.nd_experiment_id) JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id) WHERE nd_experiment.type_id=$analysis_nd_experiment_type_id AND project_id=?;";
        my $nd_protocol_h = $schema->storage->dbh()->prepare($nd_protocol_q);
        $nd_protocol_h->execute($self->get_trial_id());
        my ($nd_protocol_id) = $nd_protocol_h->fetchrow_array();
        if ($nd_protocol_id) {
            my $m = CXGN::AnalysisModel::GetModel->new({
                bcs_schema=>$schema,
                metadata_schema=>$self->metadata_schema(),
                phenome_schema=>$self->phenome_schema(),
                nd_protocol_id=>$nd_protocol_id
            });
            my $saved_model_object = $m->get_model();
            $self->saved_model($saved_model_object);
        }
    }
    else {
        # otherwise create an empty project object with an empty metadata object...
        #
        die "need a project id...";
    }
    $self->metadata($metadata);
}

=head2 retrieve_analyses_by_user

 Usage:        my @analyses = CXGN::Analysis->retrieve_analyses_by_user($schema, $user_id);
 Desc:         Class function to retrieve all analyses by user_id
 Ret:          a list of listrefs with analysis data
 Args:         $schema - a BCS schema object, $user_id - the numeric id of a user
 Side Effects:
 Example:

=cut

sub retrieve_analyses_by_user {
    my $class = shift;
    my $bcs_schema = shift;
    my $people_schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $user_id = shift;
    my $analyses_type = shift;

    my $user_info_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_sp_person_id', 'project_property')->cvterm_id();
    my $analysis_info_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'analysis_metadata_json', 'project_property')->cvterm_id();

    my $q = "SELECT userinfo.project_id, analysisinfo.value FROM projectprop AS userinfo
        JOIN projectprop AS analysisinfo on (userinfo.project_id=analysisinfo.project_id)
        WHERE userinfo.type_id=? AND analysisinfo.type_id=? AND userinfo.value=?";

    my $h = $bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($user_info_type_id, $analysis_info_type_id, $user_id);

    my @analyses = ();
    while (my ($project_id, $analysis_info) = $h->fetchrow_array()) {
        print STDERR "Instantiating analysis project for project ID $project_id...\n";
        my $info = decode_json $analysis_info;
        if ($analyses_type) {
            if ($info->{analysis_model_type} eq $analyses_type) {
                push @analyses, CXGN::Analysis->new( { bcs_schema => $bcs_schema, people_schema => $people_schema, metadata_schema => $metadata_schema, phenome_schema => $phenome_schema, trial_id=> $project_id });
            }
        }
        else {
            push @analyses, CXGN::Analysis->new( { bcs_schema => $bcs_schema, people_schema => $people_schema, metadata_schema => $metadata_schema, phenome_schema => $phenome_schema, trial_id=> $project_id });
        }
    }

    return @analyses;
}

sub create_and_store_analysis_design {
    my $self = shift;
    my $precomputed_design_to_save = shift; #DESIGN HASHREF

    my $schema = $self->bcs_schema();
    my $dbh = $schema->storage->dbh();

    print STDERR "CREATE AND STORE ANALYSIS DESIGN...\n";

    if (!$self->user_id()) {
        die "Need an sp_person_id to store an analysis.";
    }
    if (!$self->get_description()) {
        die "Need a description to store an analysis.";
    }
    if (!$self->get_name()) {
        die "Need a name to store an analysis.";
    }
    if (!$self->breeding_program_id()) {
        die "Need a breeding program to store an analysis.";
    }

    my $p = CXGN::People::Person->new($dbh, $self->user_id);
    my $user_name = $p->get_username;

    if (!$self->year()) {
        my $dt = DateTime->now();
        my $year = $dt->year();
        print STDERR "Year: $year\n";
        print STDERR "No year provided. Using current year ($year).\n";
        $self->year($year);
    }

    my $computation_location_name = "[Computation]";
    my $calculation_location_id = $schema->resultset("NaturalDiversity::NdGeolocation")->search({ description => $computation_location_name })->first->nd_geolocation_id();
    $self->nd_geolocation_id($calculation_location_id);
    $self->set_location($calculation_location_id);

    my $breeding_program_name = $schema->resultset("Project::Project")->find({project_id=>$self->breeding_program_id()})->name();
    $self->set_breeding_program($self->breeding_program_id());

    # store user info
    #
    print STDERR "Storing user info...\n";
    my $project_sp_person_term_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_sp_person_id', 'project_property')->cvterm_id();
    my $row = $schema->resultset("Project::Projectprop")->create({
        project_id => $self->get_trial_id(),
        type_id=>$project_sp_person_term_cvterm_id,
        value=>$self->user_id(),
    });

    # Store metadata
    #
    my $time = DateTime->now();
    if (!$self->metadata()) {
        print STDERR "Storing metadata...\n";
        my $metadata = CXGN::Analysis::AnalysisMetadata->new({ bcs_schema => $schema });
        print STDERR "Analysis ID = ".$self->get_trial_id()."\n";
        $metadata->parent_id($self->get_trial_id());
        $self->metadata( $metadata );
        $self->metadata()->create_timestamp($time->ymd()." ".$time->hms());
    }

    # store dataset info, if available. Copy the actual dataset json,
    # so that dataset  info is frozen and does not reflect future
    # changes.
    #
    if ($self->metadata()->dataset_id()) {
        print STDERR "Retrieving data for dataset_id ".$self->metadata->dataset_id()."\n";
        my $ds = CXGN::Dataset->new( { schema => $schema, people_schema => $self->people_schema(), sp_dataset_id => $self->metadata()->dataset_id() });
        my $data = $ds->to_hashref();
        #print STDERR "DATA: $data\n";
        $self->metadata()->dataset_data(JSON::Any->encode($data));
    }
    else {
        print STDERR "No dataset_id provided...\n";
    }

    $self->metadata()->parent_id($self->get_trial_id());
    $self->metadata()->modified_timestamp($time->ymd()." ".$time->hms());
    $self->metadata()->store();

    my $design;
    if (!$precomputed_design_to_save) {
        print STDERR "Create a new analysis design...\n";
        my $td = CXGN::Trial::TrialDesign->new();

        $td->set_trial_name($self->name());
        $td->set_stock_list($self->accession_names());
        $td->set_design_type("Analysis");

        if ($td->calculate_design()) {
            print STDERR "Design calculated :-) ...\n";
            $design = $td->get_design();
            $self->design($design);
        }
        else {
            die "An error occurred creating the analysis design.";
        }
    } else {
        $design = $precomputed_design_to_save;
    }
    # print STDERR Dumper $design;

    print STDERR "Store design...\n";

    my $saved_model_protocol_id;
    if ($self->analysis_model_protocol_id) {
        $saved_model_protocol_id = $self->analysis_model_protocol_id();
    }

    my $analysis_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_experiment', 'experiment_type')->cvterm_id();

    my $trial_create = CXGN::Trial::TrialCreate->new({
        trial_id => $self->get_trial_id(),
		owner_id => $self->user_id(),
        chado_schema => $schema,
        dbh => $dbh,
        operator => $user_name,
        design => $design,
        design_type => $analysis_experiment_type_id,
        program => $breeding_program_name,
        trial_year => $self->year(),
        trial_description => $self->description(),
        trial_location => $computation_location_name,
        trial_name => $self->name(),
        trial_type => $analysis_experiment_type_id,
        is_analysis => 1,
        analysis_model_protocol_id => $saved_model_protocol_id,
    });

#    my $validate_error = $trial_create->validate_design();
#    my $store_error;
#    if ($validate_error) {
#	print STDERR "VALIDATE ERROR! "; #.Dumper($validate_error)."\n";
#    }
#    else {
##	print STDERR "Valiation successful. Storing...\n";
#	try { $store_error = $design_store->store() }
#	catch { $store_error = $_ };
#    }
#    if ($store_error) {
#	die "ERROR SAVING TRIAL!: $store_error\n";
#    }

    try {
        $trial_create->save_trial();
    }
    catch {
        die "Error saving trial: $_";
    };

    #Refresh layout cache
    $self->_get_layout()->get_design();

    print STDERR "Done with design create & store.\n";
    return $self->get_trial_id();
}


# store analysis values is a separate call and has to be called after
# storing the design

sub store_analysis_values {
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $values = shift;
    my $plots = shift;
    my $traits = shift;
    my $operator = shift;
    my $basepath = shift;
    my $dbhost = shift;
    my $dbname = shift;
    my $dbuser = shift;
    my $dbpass = shift;
    my $tempfile_path = shift;

    print STDERR "Storing analysis values...\n";

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = 'none';
    $phenotype_metadata{'archived_file_type'} = 'analysis_values';
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        bcs_schema => $self->bcs_schema(),
        basepath => $basepath,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        temp_file_nd_experiment_id => $tempfile_path,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        user_id => $self->user_id(),
        stock_list => $plots,
        trait_list => $traits,
        values_hash => $values,
        has_timestamps => 0,
        overwrite_values => 1,
        metadata_hash => \%phenotype_metadata,
    });

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();

    if ($verified_warning) {
        warn $verified_warning;
    }
    if ($verified_error) {
        die $verified_error;
    }

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

    if ($stored_phenotype_error) {
	die "An error occurred storing the phenotypes: $stored_phenotype_error\n";
    }

}

sub _get_layout {
    my $self = shift;

    # Load the design
    #
    my $design = CXGN::Trial::TrialLayout->new({ schema => $self->bcs_schema(), trial_id => $self->get_trial_id(), experiment_type=> 'analysis_experiment'});

    # print STDERR "_get_layout: design = ".Dumper($design->get_design);

    #print STDERR "ERROR IN LAYOUT: ".Dumper($error)."\n";
    #print STDERR "READ DESIGN: ".Dumper($design->get_design());
    return $design;
}

sub get_phenotype_matrix {
    my $self = shift;
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema(),
        search_type => "MaterializedViewTable",
        data_level => "analysis_instance",
        experiment_type => "analysis_experiment",
        trial_list=> [ $self->get_trial_id() ],
    );
    my @data = $phenotypes_search->get_phenotype_matrix();
    return \@data;
}

sub _load_accession_names {
    my $self = shift;

    my $design = $self->design();
    #print STDERR "Design = ".Dumper($design);

    my @accessions = $design->get_accession_names();
    print STDERR "ACCESSIONS: ". Dumper(\@accessions);
    # get the accessions from the design (not the dataset!)
    #
    return $self->design()->get_accession_names();
}

sub _load_traits {
    my $self = shift;

    my $phenotypes = $self->get_phenotype_matrix();

    my $header = $phenotypes->[0];

    my $traits = [ @$header[39..scalar(@$header)-1] ];

    print STDERR "_load_traits: TRAITS: ".Dumper($traits);
    #$self->traits($traits);
    return $traits;
}

1;

#__PACKAGE__->meta->make_immutable;
