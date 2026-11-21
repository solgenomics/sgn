package CXGN::Analysis::AnalysisCreate;

=head1 NAME

CXGN::Analysis::AnalysisCreate - A Moose object to handle storing analyses, analysis results, and model information

=head1 USAGE

my $m = CXGN::Analysis::AnalysisCreate->new({
    bcs_schema=>$bcs_schema,
    people_schema=>$people_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    analysis_to_save_boolean=>$analysis_to_save_boolean,
    analysis_name=>$analysis_name,
    analysis_description=>$analysis_description,
    analysis_year=>$analysis_year,
    analysis_breeding_program_id=>$analysis_breeding_program_id,
    analysis_protocol=>$analysis_protocol,
    analysis_dataset_id=>$analysis_dataset_id,
    analysis_accession_names=>$analysis_accession_names,
    is_analysis_result_stock_type=>$is_analysis_result_stock_type,
    analysis_result_stock_names=>$analysis_result_stock_names,
    analysis_trait_names=>$analysis_trait_names,
    analysis_statistical_ontology_term=>$analysis_statistical_ontology_term,
    analysis_precomputed_design_optional=>$analysis_precomputed_design_optional,
    analysis_result_values=>$analysis_result_values,
    analysis_result_values_type=>$analysis_result_values_type,
    analysis_result_summary=>$analysis_result_summary,
    analysis_result_trait_compose_info=>$analysis_result_trait_compose_info,
    analysis_model_id=>$analysis_model_id,
    analysis_model_name=>$analysis_model_name,
    analysis_model_description=>$analysis_model_description,
    analysis_model_is_public=>$analysis_model_is_public,
    analysis_model_language=>$analysis_model_language,
    analysis_model_type=>$analysis_model_type,
    analysis_model_properties=>$analysis_model_properties,
    analysis_model_application_name=>$analysis_model_application_name,
    analysis_model_application_version=>$analysis_model_application_version,
    analysis_model_file=>$analysis_model_file,
    analysis_model_file_type=>$analysis_model_file_type,
    analysis_model_training_data_file=>$analysis_model_training_data_file,
    analysis_model_training_data_file_type=>$analysis_model_training_data_file_type,
    analysis_model_auxiliary_files=>$analysis_model_auxiliary_files,
    allowed_composed_cvs=>\@allowed_composed_cvs,
    composable_cvterm_delimiter=>$composable_cvterm_delimiter,
    composable_cvterm_format=>$composable_cvterm_format,
    user_id=>$user_id,
    user_name=>$user_name,
    user_role=>$user_role
});
my $saved_analysis_object = $m->store();

=head1 AUTHORS

Nicolas Morales <nm529@cornell.edu>

=cut

use Moose;
use Data::Dumper;
use DateTime;
use CXGN::UploadFile;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use JSON;
use CXGN::AnalysisModel::SaveModel;
use CXGN::Onto;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1
);

has 'archive_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'base_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'dbhost' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'dbname' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'dbpass' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'dbuser' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'tempfile_for_deleting_nd_experiment_ids' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'analysis_to_save_boolean' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'analysis_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_year' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_breeding_program_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'analysis_protocol' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_dataset_id' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_accession_names' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'is_analysis_result_stock_type' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

has 'analysis_result_stock_names' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
    default => sub { [] },
);

has 'analysis_trait_names' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'analysis_statistical_ontology_term' => (
    isa => 'Str|Undef',
    is => 'rw',
);

# Optional: a statistical ontology term per trait name, for analyses where the
# traits were not all computed the same way. Traits not listed here use
# analysis_statistical_ontology_term.
has 'analysis_statistical_ontology_term_by_trait' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'analysis_precomputed_design_optional' => (
    isa => 'HashRef[HashRef]|Undef',
    is => 'rw',
);

has 'analysis_result_values' => (
    isa => 'HashRef[HashRef]|Undef',
    is => 'rw',
);

has 'analysis_result_values_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_result_summary' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'analysis_result_trait_compose_info_time' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'analysis_model_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'analysis_model_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_is_public' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_language' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_properties' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'analysis_model_application_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_application_version' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_file' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_file_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'analysis_model_training_data_file' => (
    isa => 'Str|Undef',
    is => 'rw',
    required => 1
);

has 'analysis_model_training_data_file_type' => (
    isa => 'Str|Undef',
    is => 'rw',
    required => 1
);

has 'analysis_model_auxiliary_files' => (
    isa => 'ArrayRef|Undef',
    is => 'rw'
);

has 'allowed_composed_cvs' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
);

has 'composable_cvterm_delimiter' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'composable_cvterm_format' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'user_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'user_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'user_role' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

sub store {
    my $self = shift;
    my $bcs_schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $metadata_schema = $self->metadata_schema();
    my $phenome_schema = $self->phenome_schema();
    my $archive_path = $self->archive_path();
    my $basepath = $self->base_path();
    my $dbhost = $self->dbhost();
    my $dbname = $self->dbname();
    my $dbuser = $self->dbuser();
    my $dbpass = $self->dbpass();
    my $tempfile_for_deleting_nd_experiment_ids = $self->tempfile_for_deleting_nd_experiment_ids();
    my $analysis_to_save_boolean = $self->analysis_to_save_boolean();
    my $analysis_name = $self->analysis_name();
    my $analysis_description = $self->analysis_description();
    my $analysis_year = $self->analysis_year();
    my $analysis_breeding_program_id = $self->analysis_breeding_program_id();
    my $analysis_protocol = $self->analysis_protocol();
    my $analysis_dataset_id = $self->analysis_dataset_id();
    my $analysis_accession_names = $self->analysis_accession_names();
    my $analysis_result_stock_names = $self->analysis_result_stock_names();
    my $is_analysis_result_stock_type = $self->is_analysis_result_stock_type();
    my $analysis_trait_names = $self->analysis_trait_names();
    my $analysis_statistical_ontology_term = $self->analysis_statistical_ontology_term();
    my $analysis_statistical_ontology_term_by_trait = $self->analysis_statistical_ontology_term_by_trait() || {};
    my $analysis_precomputed_design_optional = $self->analysis_precomputed_design_optional();
    my $analysis_result_values = $self->analysis_result_values();
    my $analysis_result_values_type = $self->analysis_result_values_type();
    my $analysis_result_summary = $self->analysis_result_summary();
    my $analysis_result_trait_compose_info_time = $self->analysis_result_trait_compose_info_time();
    my $analysis_model_protocol_id = $self->analysis_model_id();
    my $analysis_model_name = $self->analysis_model_name();
    my $analysis_model_description = $self->analysis_model_description();
    my $analysis_model_is_public = $self->analysis_model_is_public;
    my $analysis_model_language = $self->analysis_model_language();
    my $analysis_model_type = $self->analysis_model_type();
    my $analysis_model_properties = $self->analysis_model_properties();
    my $analysis_model_application_name = $self->analysis_model_application_name();
    my $analysis_model_application_version = $self->analysis_model_application_version();
    my $analysis_model_file = $self->analysis_model_file();
    my $analysis_model_file_type = $self->analysis_model_file_type();
    my $analysis_model_training_data_file = $self->analysis_model_training_data_file();
    my $analysis_model_training_data_file_type = $self->analysis_model_training_data_file_type();
    my $analysis_model_auxiliary_files = $self->analysis_model_auxiliary_files();
    my $allowed_composed_cvs = $self->allowed_composed_cvs();
    my $composable_cvterm_delimiter = $self->composable_cvterm_delimiter();
    my $composable_cvterm_format = $self->composable_cvterm_format();
    my $user_id = $self->user_id();
    my $user_name = $self->user_name();
    my $user_role = $self->user_role();

    # Check every trait and statistical term before anything is written.
    if ($analysis_to_save_boolean eq 'yes') {
        $self->_resolve_trait_ids();
        $self->_resolve_statistical_term_ids();
    }

    # print Dumper $analysis_model_type;
    my $model_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $analysis_model_type, 'protocol_type')->cvterm_id();

    if ($analysis_to_save_boolean eq 'yes' && !$analysis_name) {
        return { error => "No analysis name given, but trying to save an analysis." };
    }

    if (!$analysis_model_protocol_id) {
        $analysis_model_properties->{protocol} = $analysis_protocol;

        my $mo = CXGN::AnalysisModel::SaveModel->new({
            bcs_schema=>$bcs_schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            archive_path=>$archive_path,
            model_name=>$analysis_model_name,
            model_description=>$analysis_model_description,
            model_language=>$analysis_model_language,
            model_type_cvterm_id=>$model_type_cvterm_id,
            model_properties=>$analysis_model_properties,
            application_name=>$analysis_model_application_name,
            application_version=>$analysis_model_application_version,
            dataset_id=>$analysis_dataset_id,
            is_public=>$analysis_model_is_public,
            user_id=>$user_id,
            user_role=>$user_role
        });
        $analysis_model_protocol_id = $mo->save_model()->{nd_protocol_id};
    }

    my $saved_analysis_id;
    if ($analysis_to_save_boolean eq 'yes') {

        my %trait_id_map = %{ $self->_resolve_trait_ids() };
        my %stat_id_map = %{ $self->_resolve_statistical_term_ids() };
        my @trait_ids = values %trait_id_map;

        my %unique_stat_ids = map { $_ => 1 } values %stat_id_map;
        my $categories = {
            object => [],
            attribute => [ keys %unique_stat_ids ],
            method => [],
            unit => [],
            trait => \@trait_ids,
            tod => [],
            toy => [],
            gen => [],
        };

        my %time_term_map;

        if ($analysis_result_trait_compose_info_time) {
            my %unique_toy;
            foreach my $v (values %$analysis_result_trait_compose_info_time) {
                foreach (@$v) {
                    my $trait_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, $_)->cvterm_id();
                    $unique_toy{$trait_id}++;
                    $time_term_map{$_} = $trait_id;
                }
            }
            my @toy = keys %unique_toy;
            $categories->{toy} = \@toy;
        }

        # print Dumper $categories;

		if  (@{ $categories->{toy} }) {
	        my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($bcs_schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, $categories);
	        my $existing_traits = $traits->{existing_traits};
	        my $new_traits = $traits->{new_traits};

	        my %new_trait_names;
	        foreach (@$new_traits) {
	            my $components = $_->[0];
	            $new_trait_names{$_->[1]} = join ',', @$components;
	        }

	       my $onto = CXGN::Onto->new( { schema => $bcs_schema } );
	       my $new_terms = $onto->store_composed_term(\%new_trait_names);
	   }

        # Analysis results are not measurements of the trait, so they are stored
        # under a post-composed trait: the trait plus the statistical term (and
        # time terms, if any). Missing composed traits are created here.
        my %composed_trait_map;
        my $onto = CXGN::Onto->new( { schema => $bcs_schema } );
        my $delimiter = defined($composable_cvterm_delimiter) && $composable_cvterm_delimiter ne '' ? $composable_cvterm_delimiter : '|';
        foreach my $trait_name (@$analysis_trait_names) {
            my $trait_id = $trait_id_map{$trait_name};
            my $stat_id = $stat_id_map{$trait_name};
            my @time_ids = map { $time_term_map{$_} } @{ $analysis_result_trait_compose_info_time->{$trait_name} || [] };

            # Results that are themselves statistics (e.g. principal component
            # scores) or that already include this statistical term are stored as they are.
            my $trait_extended_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $trait_id, 'extended') // '';
            my %trait_components = map { $_ => 1 } @{ SGN::Model::Cvterm->get_components_from_trait($bcs_schema, $trait_id) };
            if ($trait_extended_name =~ /\|SGNSTAT:\d+$/ || ($trait_components{$stat_id} && !@time_ids)) {
                $composed_trait_map{$trait_name} = $trait_name;
                next;
            }

            my $components = [ $trait_id, $stat_id, @time_ids ];
            my $composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, $components);
            if (!$composed_cvterm_id) {
                my $composed_name = join $delimiter, map { SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $_, 'concise') } ($trait_id, @time_ids, $stat_id);
                $onto->store_composed_term({ $composed_name => join(',', @$components) });
                $composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, $components);
            }
            die "Could not create the post-composed trait for \"$trait_name\". The results were not stored under the original trait.\n" if !$composed_cvterm_id;
            $composed_trait_map{$trait_name} = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $composed_cvterm_id, 'extended');
        }
        my @composed_trait_names = values %composed_trait_map;

        #Project BUILD inserts project entry
        my $a = CXGN::Analysis->new({
            bcs_schema => $bcs_schema,
            people_schema => $people_schema,
            metadata_schema => $metadata_schema,
            phenome_schema => $phenome_schema,
            name => $analysis_name,
        });

        $saved_analysis_id = $a->get_trial_id();
        if ($analysis_dataset_id !~ /^\d+$/) {
            print STDERR "Dataset ID $analysis_dataset_id not acceptable.\n";
            $analysis_dataset_id = undef;
        }

        if ($analysis_dataset_id) {
            $a->metadata()->dataset_id($analysis_dataset_id);
        }

        my $year_type_id = $bcs_schema->resultset('Cv::Cvterm')->find({ name => 'project year' })->cvterm_id;
        my $year_rs = $bcs_schema->resultset('Project::Projectprop')->create({
            type_id => $year_type_id,
            value => $analysis_year,
            project_id => $saved_analysis_id
        });

        $a->year($analysis_year);
        $a->breeding_program_id($analysis_breeding_program_id);
        
        if (defined $analysis_result_stock_names && @$analysis_result_stock_names) {
            $a->analysis_result_stock_names($analysis_result_stock_names);
        } else {
            $a->accession_names($analysis_accession_names);
        }
        
        $a->description($analysis_description);
        $a->user_id($user_id);

        $a->metadata()->traits(\@composed_trait_names);
        $a->metadata()->analysis_protocol($analysis_protocol);
        $a->metadata()->result_summary($analysis_result_summary);
        $a->metadata()->analysis_model_type($analysis_model_type);
        $a->analysis_model_protocol_id($analysis_model_protocol_id);

        if ($analysis_precomputed_design_optional) {
            while (my($plot_number, $plot_obj) = each %$analysis_precomputed_design_optional) {
                $plot_obj->{plot_name} = $analysis_name."_".$plot_obj->{plot_name};
                $analysis_precomputed_design_optional->{$plot_number} = $plot_obj;
            }
        }

        if ($analysis_result_values_type eq 'analysis_result_new_stocks') {
            print STDERR"\n\n\n Storing analysis_result_new_stocks: $analysis_result_values_type\n";
            my $stocks_stored = $self->store_analysis_result_stock_names($bcs_schema, $analysis_result_stock_names);
        }

        my ($verified_warning, $verified_error);
        print STDERR "Storing the analysis...\n";
        eval {
            ($verified_warning, $verified_error) = $a->create_and_store_analysis_design($analysis_precomputed_design_optional);
        };

        my @errors;
        my @warnings;
        if ($@) {
            push @errors, $@;
        }
        elsif ($verified_warning) {
            push @warnings, $verified_warning;
        }
        elsif ($verified_error) {
            push @errors, $verified_error;
        }

        if (@errors) {
            print STDERR "SORRY! Errors: ".join("\n", @errors);
            return { error => join "; ", @errors };
        }

        print STDERR "Store analysis values...\n";
        my $analysis_result_values_save = {};
        if ($analysis_result_values_type eq 'analysis_result_values_match_precomputed_design') {
            while (my($field_plot_name, $trait_obj) = each %$analysis_result_values) {
                while (my($trait_name, $val) = each %$trait_obj) {
                    $analysis_result_values_save->{$analysis_name."_".$field_plot_name}->{$composed_trait_map{$trait_name}} = $val;
                }
            }
        }
        elsif ($analysis_result_values_type eq 'analysis_result_values_match_accession_names') {
            print STDERR"\n\n\n analysis_result_values_type: $analysis_result_values_type\n";
            my %analysis_result_values_fix_plot_names;
            my $design = $a->design();
            foreach (values %$design) {
                $analysis_result_values_fix_plot_names{$_->{stock_name}} = $_->{plot_name};
            }

            while (my ($accession_name, $trait_pheno) = each %$analysis_result_values) {
                while (my($trait_name, $val) = each %$trait_pheno) {
                    $analysis_result_values_save->{$analysis_result_values_fix_plot_names{$accession_name}}->{$composed_trait_map{$trait_name}} = $val;
                }
            }
        }
        elsif ($analysis_result_values_type eq 'analysis_result_new_stocks') {
    
            my %analysis_result_values_fix_plot_names;
            my $design = $a->design();
            foreach (values %{$design}) {
                $analysis_result_values_fix_plot_names{$_->{stock_name}} = $_->{plot_name};
            }

            while (my ($stock_name, $trait_pheno) = each %{$analysis_result_values}) {
                while (my ($trait_name, $val) = each %{$trait_pheno}) {
                    $analysis_result_values_save->{$analysis_result_values_fix_plot_names{$stock_name}}->{$composed_trait_map{$trait_name}} = $val;
                }
            }
        }
        
        my @analysis_instance_names = keys %$analysis_result_values_save;
    
        eval {
            $a->store_analysis_values(
                $metadata_schema,
                $phenome_schema,
                $analysis_result_values_save,
                \@analysis_instance_names,
                \@composed_trait_names,
                $user_name,
                $basepath,
                $dbhost,
                $dbname,
                $dbuser,
                $dbpass,
                $tempfile_for_deleting_nd_experiment_ids,
                $is_analysis_result_stock_type
            );
        };

        if ($@) {
            print STDERR "An error occurred storing analysis values ($@).\n";
            return { error => "An error occurred storing the values ($@).\n" };
        }

        my $refresh = $self->_refresh_matviews($bcs_schema, 'fullview', 'concurrent');
    }

    my $analysis_model = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$bcs_schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$analysis_model_protocol_id
    });

if ($analysis_model_file) {
    $analysis_model->store_analysis_model_files({
        project_id => $saved_analysis_id,
        archived_model_file_type=>$analysis_model_file_type,
        model_file=>$analysis_model_file,
        archived_training_data_file_type=>$analysis_model_training_data_file_type,
        archived_training_data_file=>$analysis_model_training_data_file,
        archived_auxiliary_files=>$analysis_model_auxiliary_files,
        archive_path=>$archive_path,
        user_id=>$user_id,
        user_role=>$user_role
    });
}

    return { success => 1, analysis_id => $saved_analysis_id, model_id => $analysis_model_protocol_id };
}

# trait name => cvterm_id; dies if a trait is not in the database
sub _resolve_trait_ids {
    my $self = shift;
    my %ids;
    foreach my $trait_name (@{ $self->analysis_trait_names() || [] }) {
        my $row = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($self->bcs_schema(), $trait_name);
        die "The trait \"$trait_name\" is not in the database.\n" if !$row;
        $ids{$trait_name} = $row->cvterm_id();
    }
    return \%ids;
}

# trait name => cvterm_id of its statistical ontology term; dies if a term is
# missing or not in the database
sub _resolve_statistical_term_ids {
    my $self = shift;
    my $by_trait = $self->analysis_statistical_ontology_term_by_trait() || {};
    my %ids;
    my %cache;
    foreach my $trait_name (@{ $self->analysis_trait_names() || [] }) {
        my $term = $by_trait->{$trait_name} || $self->analysis_statistical_ontology_term();
        die "No statistical ontology term was given for \"$trait_name\".\n" if !$term;
        if (!exists $cache{$term}) {
            my $row = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($self->bcs_schema(), $term);
            die "The statistical ontology term \"$term\" is not in the database.\n" if !$row;
            $cache{$term} = $row->cvterm_id();
        }
        $ids{$trait_name} = $cache{$term};
    }
    return \%ids;
}

sub store_analysis_result_stock_names {
    my ($self, $bcs_schema, $stocks) = @_;

    my $stock_cvterm_id = SGN::Model::Cvterm
        ->get_cvterm_row($bcs_schema, 'analysis_result','stock_type')
        ->cvterm_id;

    eval {
     foreach my $stock_name (@$stocks) {
        my $stock = $bcs_schema->resultset("Stock::Stock")
	            ->find_or_create({
		            name => $stock_name,
		            type_id => $stock_cvterm_id,
                    uniquename => $stock_name,
	            });
     }

    };

    if ($@) {
            print STDERR "An error occurred storing analysis result stocks ($@).\n";
            return { error => "An error occurred storing nalysis result stocks ($@).\n" };
    } else {
        print STDERR "\nDONE storing new analysis result stocks!\n";
        my $refresh = $self->_refresh_matviews($bcs_schema, 'stockprop', 'concurrent');
        return 1;
    }

}

sub _refresh_matviews {
    my ($self, $bcs_schema, $view, $mode) = @_;

    $view = $view ? $view : 'all_but_genoview';
    $mode = $mode ? $mode : 'concurrent';
    my $dbh = $bcs_schema->storage->dbh;

    my $bs = CXGN::BreederSearch->new( {dbh=>$dbh, dbname=>$self->dbname,} );
    my $refresh = $bs->refresh_matviews(
                                        $self->dbhost, 
                                        $self->dbname, 
                                        $self->dbuser, 
                                        $self->dbpass, 
                                        $view, 
                                        $mode, 
                                        $self->base_path
                    );

    print Dumper "\n\n\nRefreshed matviews: $refresh\n\n\n";
    return $refresh;
}

1;
