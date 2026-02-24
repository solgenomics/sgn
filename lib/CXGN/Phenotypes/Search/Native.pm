package CXGN::Phenotypes::Search::Native;

=head1 NAME

CXGN::Phenotypes::Search::Native - an object to handle searching phenotypes across database. called from factory CXGN::Phenotypes::SearchFactory. Processes phenotype search against cxgn schema.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'Native',    #can be either 'MaterializedViewTable', or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        subplot_list=>$subplot_list,
        exclude_phenotype_outlier=>0,
        include_timestamp=>$include_timestamp,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        start_date => $start_date,
        end_date => $end_date,
        include_dateless_items => $include_dateless_items,
        limit=>$limit,
        offset=>$offset
    }
);
my @data = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Calendar;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(plot, plant, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'program_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'folder_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'analysis_result_stock_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plant_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'subplot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'observation_id_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'exclude_phenotype_outlier' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'trait_contains' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'phenotype_min_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'phenotype_max_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'start_date' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => '1900-01-01',
    );

has 'end_date' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => '2100-12-31',
    );

has 'include_dateless_items' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => 1,
    );

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
    );

has 'experiment_type' => (
    isa => 'Str',
    is => 'rw',
    default => 'field_layout',
    );

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";
    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $is_a_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
    my $plant_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $folder_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();
    my $plot_width_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_width', 'project_property')->cvterm_id();
    my $plot_length_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_length', 'project_property')->cvterm_id();
    my $field_size_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_size', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_be_genotyped_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_be_genotyped', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_cross', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $analysis_instance_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $analysis_result_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_result', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    my $additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_additional_info', 'phenotype_property')->cvterm_id();
    my $external_references_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_external_references', 'phenotype_property')->cvterm_id();
    my $notes_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'notes', 'stock_property')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $analysis_instance_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $subplot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my $design_layout_sql = '';
    my $design_layout_select = '';
    my $phenotypeprop_sql = '';
    my %design_layout_hash;
    my $using_layout_hash;
    #For performance reasons the number of joins to stock can be reduced if a trial is given. If trial(s) given, use the cached layout from TrialLayout instead.

    print STDERR "start date here: ".$self->start_date()." and the end date here: ".$self->end_date()."\n";

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {

        $using_layout_hash = 1;
        foreach (@{$self->trial_list}){
            my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $_, experiment_type=>$self->experiment_type()});
            my $tl = $trial_layout->get_design();

            my @plots_list;
            while(my($key,$val) = each %$tl){
                $design_layout_hash{$val->{plot_id}} = $val;
                if($val->{plant_ids}){
                    foreach my $p (@{$val->{plant_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }
                if($val->{subplot_ids}){
                    foreach my $p (@{$val->{subplot_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }
                if($val->{tissue_sample_ids}){
                    foreach my $p (@{$val->{tissue_sample_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }

                if($val->{plot_id}){
                    push @plots_list, $val->{plot_id};
                }
            }

            
            #For performace reasons it is faster to include specific stock_ids in the query.
            if ($self->data_level eq 'analysis_instance'){
                if (!$self->plot_list){
                    $self->plot_list(\@plots_list);
                }
            }

            print STDERR "\n\n fetching layout for  ".$self->data_level. " time: ".  localtime ."\n";
            if ($self->data_level eq 'plot'){
                if (!$self->plot_list){
                    $self->plot_list([]);
                }
                my $plots = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_plots();
                foreach (@$plots){
                    push @{$self->plot_list}, $_->[0];
                }
            }

            if ($self->data_level eq 'accession'){
                if (!$self->accession_list){
                    $self->accession_list([]);
                }
                my $accessions = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_accessions();
                # print STDERR "Accessions for trial $_ : ".Dumper($accessions)."\n";
                foreach (@$accessions){
                    print STDERR "iterating accessions: " . Dumper( $_) . "\n";
                    print STDERR "Pushing accession ".$_->{'stock_id'}."\n";
                    push @{$self->accession_list}, $_->{'stock_id'};
                }

                if (!$self->plot_list){
                    $self->plot_list([]);
                }
                my $plots = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_plots();
                foreach (@$plots){
                    push @{$self->plot_list}, $_->[0];
                }
            }

            if ($self->data_level eq 'plant'){
                if (!$self->plant_list){
                    $self->plant_list([]);
                }
                my $plants = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_plants();
                foreach (@$plants){
                    push @{$self->plant_list}, $_->[0];
                }
            }
            if ($self->data_level eq 'subplot'){
                if (!$self->subplot_list){
                    $self->subplot_list([]);
                }
                my $subplots = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_subplots();
                foreach (@$subplots){
                    push @{$self->subplot_list}, $_->[0];
                }
            }


        }
    } else {
        print STDERR "\n\n design_layout_sql for  ".$self->data_level. " time: ".  localtime ."\n";
        $design_layout_sql = " LEFT JOIN stockprop AS rep ON (observationunit.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
            LEFT JOIN stockprop AS block_number ON (observationunit.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
            LEFT JOIN stockprop AS plot_number ON (observationunit.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
            LEFT JOIN stockprop AS row_number ON (observationunit.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
            LEFT JOIN stockprop AS col_number ON (observationunit.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id)
            LEFT JOIN stockprop AS plant_number ON (observationunit.stock_id=plant_number.stock_id AND plant_number.type_id = $plant_number_type_id)
            LEFT JOIN stockprop AS is_a_control ON (observationunit.stock_id=is_a_control.stock_id AND is_a_control.type_id = $is_a_control_type_id) ";
        $design_layout_select = " ,rep.value, block_number.value, plot_number.value, is_a_control.value, row_number.value, col_number.value, plant_number.value";
    }
    
    if ($self->exclude_phenotype_outlier) {
        $phenotypeprop_sql = "JOIN (
                SELECT phenotype_id
                FROM phenotype
                WHERE phenotype_id NOT IN (
                    SELECT phenotype_id
                    FROM phenotypeprop
                    WHERE type_id = $phenotype_outlier_type_id
                )
            ) AS not_outliers
            ON not_outliers.phenotype_id = nd_experiment_phenotype.phenotype_id"
    };

    my $from_clause = " FROM stock as observationunit 
      LEFT JOIN stock_relationship ON (observationunit.stock_id=stock_relationship.subject_id) AND stock_relationship.type_id IN ($analysis_instance_of_type_id, $plot_of_type_id, $plant_of_type_id, $subplot_of_type_id, $tissue_sample_of_type_id)
      LEFT JOIN cvterm as observationunit_type ON (observationunit_type.cvterm_id = observationunit.type_id)
      LEFT JOIN stock as germplasm ON (stock_relationship.object_id=germplasm.stock_id) AND germplasm.type_id IN ($accession_type_id, $analysis_result_type_id, $cross_type_id, $family_name_type_id)
      $design_layout_sql
      LEFT JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=observationunit.stock_id)
      LEFT JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
      LEFT JOIN phenotype USING(phenotype_id)
      $phenotypeprop_sql
      LEFT JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
      LEFT JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
      LEFT JOIN db USING(db_id)
      LEFT JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
      LEFT JOIN project USING (project_id)
      LEFT JOIN project_relationship ON (project.project_id=project_relationship.subject_project_id AND project_relationship.type_id = $breeding_program_rel_type_id)
      LEFT JOIN project as breeding_program ON (breeding_program.project_id=project_relationship.object_project_id)
      LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
      LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
      LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)
      LEFT JOIN projectprop as planting_date ON (project.project_id=planting_date.project_id AND planting_date.type_id = $planting_date_type_id)
      LEFT JOIN projectprop as harvest_date ON (project.project_id=harvest_date.project_id AND harvest_date.type_id = $havest_date_type_id)
      LEFT JOIN projectprop as plot_width ON (project.project_id=plot_width.project_id AND plot_width.type_id = $plot_width_type_id)
      LEFT JOIN projectprop as plot_length ON (project.project_id=plot_length.project_id AND plot_length.type_id = $plot_length_type_id)
      LEFT JOIN projectprop as field_size ON (project.project_id=field_size.project_id AND field_size.type_id = $field_size_type_id)
      LEFT JOIN projectprop as field_trial_is_planned_to_be_genotyped ON (project.project_id=field_trial_is_planned_to_be_genotyped.project_id AND field_trial_is_planned_to_be_genotyped.type_id = $field_trial_is_planned_to_be_genotyped_type_id)
      LEFT JOIN projectprop as field_trial_is_planned_to_cross ON (project.project_id=field_trial_is_planned_to_cross.project_id AND field_trial_is_planned_to_cross.type_id = $field_trial_is_planned_to_cross_type_id)
      LEFT JOIN stockprop AS notes ON (observationunit.stock_id=notes.stock_id AND notes.type_id = $notes_type_id)
      LEFT JOIN phenotypeprop as additional_info ON (phenotype.phenotype_id=additional_info.phenotype_id AND additional_info.type_id = $additional_info_type_id)
      LEFT JOIN phenotypeprop as external_references ON (phenotype.phenotype_id=external_references.phenotype_id AND external_references.type_id = $external_references_type_id)
      LEFT JOIN project_relationship folder_rel ON (project.project_id = folder_rel.subject_project_id AND folder_rel.type_id = $folder_rel_type_id)
      LEFT JOIN project folder ON (folder.project_id = folder_rel.object_project_id)";

    my $select_clause = "SELECT observationunit.stock_id, 
                        observationunit.uniquename, 
                        observationunit_type.name, 
                        germplasm.uniquename, 
                        germplasm.stock_id, 
                        project.project_id, 
                        project.name, 
                        project.description, 
                        plot_width.value, 
                        plot_length.value, 
                        field_size.value, 
                        field_trial_is_planned_to_be_genotyped.value, 
                        field_trial_is_planned_to_cross.value, 
                        breeding_program.project_id, 
                        breeding_program.name, 
                        breeding_program.description, 
                        year.value, 
                        design.value, 
                        location.value, 
                        planting_date.value, 
                        harvest_date.value, 
                        folder.project_id, 
                        folder.name, 
                        folder.description, 
                        cvterm.cvterm_id, 
                        (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, 
                            phenotype.value, 
                            phenotype.uniquename, 
                            phenotype.phenotype_id, 
                            phenotype.collect_date, 
                            phenotype.operator, 
                            additional_info.value, 
                            external_references.value, 
                            count(phenotype.phenotype_id) OVER() AS full_count, 
                            string_agg(distinct(notes.value), ', ') AS notes ".$design_layout_select;

    my $order_clause = " ORDER BY 6, 2, 29";

    my $group_by = " GROUP BY observationunit.stock_id, 
                    observationunit.uniquename, 
                    observationunit_type.name, 
                    germplasm.uniquename, 
                    germplasm.stock_id, 
                    project.project_id, 
                    project.name, 
                    project.description,
                    plot_width.value, 
                    plot_length.value, 
                    field_size.value, 
                    field_trial_is_planned_to_be_genotyped.value, 
                    field_trial_is_planned_to_cross.value, 
                    breeding_program.project_id, 
                    breeding_program.name, 
                    breeding_program.description, 
                    year.value, 
                    design.value, 
                    location.value, 
                    planting_date.value, 
                    harvest_date.value, 
                    folder.project_id, 
                    folder.name, 
                    folder.description, 
                    cvterm.cvterm_id, 
                    (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, 
                    phenotype.value, 
                    phenotype.uniquename, 
                    phenotype.phenotype_id, 
                    phenotype.collect_date, 
                    phenotype.operator, 
                    additional_info.value, 
                    external_references.value ".$design_layout_select;

    my @where_clause;
    my $accession_list = $self->accession_list;
    print STDERR "Native search Accession list is ".Dumper($accession_list)."\n";

    my $analysis_result_stock_list = $self->analysis_result_stock_list;
    
    if ($self->analysis_result_stock_list && scalar(@{$self->analysis_result_stock_list})>0) {
        print STDERR "Native search adding analysis result_stock_list to sql\n";
        my $accession_sql = _sql_from_arrayref($self->analysis_result_stock_list);
        push @where_clause, "germplasm.stock_id in ($accession_sql)";
    }

    # print STDERR "plot list is ".Dumper($self->plot_list)."\n";
    if (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_plant_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit.stock_id in ($plot_and_plant_and_subplot_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list);
        push @where_clause, "observationunit.stock_id in ($plot_and_plant_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit.stock_id in ($plot_and_subplot_sql)";
    } elsif (($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plant_and_subplot_sql = _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit.stock_id in ($plant_and_subplot_sql)";
    } elsif ($self->plot_list && scalar(@{$self->plot_list})>0 && (!$self->accession_list || scalar(@{$self->accession_list}) == 0)) {
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, "observationunit.stock_id in ($plot_sql)";
    } elsif ($self->plant_list && scalar(@{$self->plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($self->plant_list);
        push @where_clause, "observationunit.stock_id in ($plant_sql)";
    } elsif ($self->subplot_list && scalar(@{$self->subplot_list})>0) {
        my $subplot_sql = _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit.stock_id in ($subplot_sql)";

    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->accession_list && scalar(@{$self->accession_list})>0)) {
        #if only accessions are given, we need to join to analysis_result and get all analysis results for those accessions
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, "observationunit.stock_id in ($plot_sql) AND germplasm.stock_id in ($accession_sql)";
    } elsif (($self->accession_list && scalar(@{$self->accession_list})>0) && ($self->plot_list && scalar(@{$self->plot_list})==0)) {
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        push @where_clause, "germplasm.stock_id in ($accession_sql)";
    }

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, "project.project_id in ($trial_sql)";
    }
    if ($self->program_list && scalar(@{$self->program_list})>0) {
        my $program_sql = _sql_from_arrayref($self->program_list);
        push @where_clause, "breeding_program.project_id in ($program_sql)";
    }
    if ($self->folder_list && scalar(@{$self->folder_list})>0) {
        my $folder_sql = _sql_from_arrayref($self->folder_list);
        push @where_clause, "folder.project_id in ($folder_sql)";
    }

    # print STDERR "Trait list is ".Dumper($self->trait_list)."\n";
    if ($self->trait_list && scalar(@{$self->trait_list})>0) {
        my $trait_sql = _sql_from_arrayref($self->trait_list);
        push @where_clause, "(cvterm.cvterm_id in ($trait_sql) OR cvterm.cvterm_id IS NULL)";
    }
    if ($self->location_list && scalar(@{$self->location_list})>0) {
        my $arrayref = $self->location_list;
        my $sql = join ("','" , @$arrayref);
        my $location_sql = "'" . $sql . "'";
        push @where_clause, "location.value in ($location_sql)";
    }
    if ($self->year_list && scalar(@{$self->year_list})>0) {
        my $arrayref = $self->year_list;
        my $sql = join ("','" , @$arrayref);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, "year.value in ($year_sql)";
    }
    if ($self->trait_contains && scalar(@{$self->trait_contains})>0) {
        foreach (@{$self->trait_contains}) {
            if ( $_ ne '' ) {
                push @where_clause, "(((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text like '%".lc($_)."%'";
            }
        }
    }

    my $datelessq = "";

    if ($self->include_dateless_items()) {
	$datelessq = " phenotype.collect_date IS NULL OR ";
    }

    my ($start_date, $end_date);
    if ($self->start_date() =~ m/(\d{4}\-\d{2}\-\d{2})/) {
	$start_date = $1;
    }

    if ($self->end_date() =~ m/(\d{4}\-\d{2}\-\d{2})/) {
	$end_date = $1;
    }

    #print STDERR "the start date here: $start_date. And the end date here: $end_date\n";

    if ($start_date && $end_date) {
        #print STDERR "including the date query\n";
	    push @where_clause, " ( $datelessq ( phenotype.collect_date >= '$start_date'::date and phenotype.collect_date <= '$end_date'::date ) ) ";
        #push @where_clause, " ( $datelessq ( phenotype.collect_date >= $start_date and phenotype.collect_date <= $end_date ) ) ";
    }

    if ($self->observation_id_list && scalar(@{$self->observation_id_list})>0) {
        my $arrayref = $self->observation_id_list;
        my $sql = join ("','" , @$arrayref);
        my $phenotype_id_sql = "'" . $sql . "'";

        push @where_clause, "phenotype.phenotype_id in ($phenotype_id_sql)";
    }

    if ($self->phenotype_min_value && !$self->phenotype_max_value) {
        push @where_clause, "phenotype.value::real >= ".$self->phenotype_min_value;
        push @where_clause, "phenotype.value~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && !$self->phenotype_min_value) {
        push @where_clause, "phenotype.value::real <= ".$self->phenotype_max_value;
        push @where_clause, "phenotype.value~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && $self->phenotype_min_value) {
        push @where_clause, "phenotype.value::real BETWEEN ".$self->phenotype_min_value." AND ".$self->phenotype_max_value;
        push @where_clause, "phenotype.value~\'$numeric_regex\'";
    }

    if ($self->data_level ne 'all') {
        print STDERR "\n\n data level is ".$self->data_level."\n\n";
        my $data_level = $self->data_level;
        if ($data_level eq 'accession'){
            $data_level = 'plot';
        }
        my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $data_level, 'stock_type')->cvterm_id();
        push @where_clause, "observationunit.type_id = $stock_type_id"; #ONLY plot or plant or subplot or tissue_sample
    } else {
        push @where_clause, "(observationunit.type_id = $plot_type_id 
        OR observationunit.type_id = $plant_type_id
        OR observationunit.type_id = $analysis_instance_id 
        OR observationunit.type_id = $subplot_type_id 
        OR observationunit.type_id = $tissue_sample_type_id)"; #plots AND plants AND subplots AND tissue_samples
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my  $q = $select_clause . $from_clause . $where_clause . $group_by . $order_clause . $limit_clause . $offset_clause;

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $germplasm_uniquename, $germplasm_stock_id, $project_project_id, $project_name, $project_description, $plot_width, $plot_length, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $breeding_program_project_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $planting_date, $harvest_date,
    $folder_id, $folder_name, $folder_description, $trait_id, $trait_name, $phenotype_value, $phenotype_uniquename, $phenotype_id, $phenotype_collect_date, $phenotype_operator, $phenotype_additional_info, $phenotype_external_references, $full_count, $notes, $rep_select, $block_number_select, $plot_number_select, $is_a_control_select, $row_number_select, $col_number_select, $plant_number) = $h->fetchrow_array()) {
        my $timestamp_value;
        my $operator_value;
        if ($include_timestamp) {
            if ($phenotype_collect_date){
                $timestamp_value = $phenotype_collect_date;
            } else {
                if ($phenotype_uniquename){
                    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                    if ($p2){
                        my ($timestamp, $operator_value) = split /  operator = /, $p2;
                        if ( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                            $timestamp_value = $timestamp;
                        }
                    }
                }
            }
        }
        if ($phenotype_operator){
            $operator_value = $phenotype_operator;
        } else {
            if ($phenotype_uniquename){
                my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                if ($p2){
                    my ($timestamp, $operator_value) = split /  operator = /, $p2;
                }
            }
        }
        my $rep;
        my $block_number;
        my $plot_number;
        my $row_number;
        my $col_number;
        my $is_a_control;
        if ($using_layout_hash){
            $rep = $design_layout_hash{$observationunit_stock_id}->{rep_number};
            $block_number = $design_layout_hash{$observationunit_stock_id}->{block_number};
            $plot_number = $design_layout_hash{$observationunit_stock_id}->{plot_number};
            $row_number = $design_layout_hash{$observationunit_stock_id}->{row_number};
            $col_number = $design_layout_hash{$observationunit_stock_id}->{col_number};
            $is_a_control = $design_layout_hash{$observationunit_stock_id}->{is_a_control};
        } else {
            $rep = $rep_select;
            $block_number = $block_number_select;
            $plot_number = $plot_number_select;
            $row_number = $row_number_select;
            $col_number = $col_number_select;
            $is_a_control = $is_a_control_select;
        }
        my $synonyms = $synonym_hash_lookup{$germplasm_uniquename};
        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);

        if ($notes) { $notes =~ s/\R//g; }
        if ($project_description) { $project_description =~ s/\R//g; }
        if ($breeding_program_description) { $breeding_program_description =~ s/\R//g };
        if ($folder_description) { $folder_description =~ s/\R//g };

        push @result, {
            obsunit_stock_id => $observationunit_stock_id,
            obsunit_uniquename => $observationunit_uniquename,
            obsunit_type_name => $observationunit_type_name,
            accession_uniquename => $germplasm_uniquename,
            accession_stock_id => $germplasm_stock_id,
            synonyms => $synonyms,
            trial_id => $project_project_id,
            trial_name => $project_name,
            trial_description => $project_description,
            plot_width => $plot_width,
            plot_length => $plot_length,
            field_size => $field_size,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            breeding_program_id => $breeding_program_project_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            year => $year,
            design => $design,
            location_name => $location_name,
            location_id => $location_id,
            planting_date => $planting_date_value,
            harvest_date => $harvest_date_value,
            folder_id => $folder_id,
            folder_name => $folder_name,
            folder_description => $folder_description,
            trait_id => $trait_id,
            trait_name => $trait_name,
            phenotype_value => $phenotype_value,
            phenotype_uniquename => $phenotype_uniquename,
            phenotype_id => $phenotype_id,
            timestamp => $timestamp_value,
            operator => $operator_value,
            full_count => $full_count,
            rep => $rep,
            block => $block_number,
            plot_number => $plot_number,
            is_a_control => $is_a_control,
            notes => $notes,
            row_number => $row_number,
            col_number => $col_number,
            plant_number => $plant_number,
            phenotype_additional_info => $phenotype_additional_info,
            phenotype_external_references => $phenotype_external_references
        };

    }

    print STDERR "Search End:".localtime."\n";
    return \@result;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
