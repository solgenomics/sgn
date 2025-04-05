package CXGN::Phenotypes::PhenotypeMatrix;

=head1 NAME

CXGN::Phenotypes::PhenotypeMatrix - an object to handle creating the phenotype matrix. Uses SearchFactory to handle searching native database or materialized views.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
    bcs_schema=>$schema,
    search_type=>$search_type,
    data_level=>$data_level,
    trait_list=>$trait_list,
    trial_list=>$trial_list,
    program_list=>$self->program_list,
    folder_list=>$self->folder_list,
    year_list=>$year_list,
    location_list=>$location_list,
    accession_list=>$accession_list,
    analysis_result_stock_list=>$analysis_result_stock_list,
    plot_list=>$plot_list,
    plant_list=>$plant_list,
    include_timestamp=>$include_timestamp,
    include_pedigree_parents=>$include_pedigree_parents,
    exclude_phenotype_outlier=>0,
    dataset_exluded_outliers=>$dataset_exluded_outliers,
    trait_contains=>$trait_contains,
    phenotype_min_value=>$phenotype_min_value,
    phenotype_max_value=>$phenotype_max_value,
    start_date => $start_date,
    end_date => $end_date,
    include_dateless_items => $include_dateless_items,
    limit=>$limit,
    offset=>$offset
);
my @data = $phenotypes_search->get_phenotype_matrix();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BreedersToolbox::Projects;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#PREFERRED MaterializedViewTable (MaterializedViewTable or Native)
has 'search_type' => (
    isa => 'Str',
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

has 'include_pedigree_parents' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_phenotype_primary_key' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'exclude_phenotype_outlier' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has 'dataset_exluded_outliers' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
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
    default => sub { return "1900-01-01"; },
    );

has 'end_date' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => sub { return "2100-12-31"; },
    );

has 'include_dateless_items' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => sub { return 1; },
    );

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub get_phenotype_matrix {
    my $self = shift;
    my $include_pedigree_parents = $self->include_pedigree_parents();
    my $include_timestamp = $self->include_timestamp;
    my $include_phenotype_primary_key = $self->include_phenotype_primary_key;

    # print STDERR "GET PHENOMATRIX search type ".$self->search_type."\n";
    # print STDERR "GET PHENOMATRIX accession list: ".$self->accession_list."\n";
    # print STDERR "GET PHENOMATRIX plot list: ".$self->plot_list."\n";
    # print STDERR "GET PHENOMATRIX ananlysis_result_stock_list: ".$self->analysis_result_stock_list."\n";
    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $self->search_type,
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$self->data_level,
            trait_list=>$self->trait_list,
            trial_list=>$self->trial_list,
            program_list=>$self->program_list,
            folder_list=>$self->folder_list,
            year_list=>$self->year_list,
            location_list=>$self->location_list,
            accession_list=>$self->accession_list,
            analysis_result_stock_list=>$self->analysis_result_stock_list,
            plot_list=>$self->plot_list,
            plant_list=>$self->plant_list,
            subplot_list=>$self->subplot_list,
            include_timestamp=>$include_timestamp,
            exclude_phenotype_outlier=>$self->exclude_phenotype_outlier,
            dataset_exluded_outliers=>$self->dataset_exluded_outliers,
            trait_contains=>$self->trait_contains,
            phenotype_min_value=>$self->phenotype_min_value,
            phenotype_max_value=>$self->phenotype_max_value,
	    start_date => $self->start_date(),
	    end_date => $self->end_date(),
	    include_dateless_items => $self->include_dateless_items(),
            limit=>$self->limit,
            offset=>$self->offset
        }
    );

    my ($data, $unique_traits);
    my @info;
    my @metadata_headers = ( 'studyYear', 'programDbId', 'programName', 'programDescription', 'studyDbId', 'studyName', 'studyDescription', 'studyDesign', 'plotWidth', 'plotLength', 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross', 'plantingDate', 'harvestDate', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber', 'colNumber', 'entryType', 'plantNumber');

    if ($self->search_type eq 'MaterializedViewTable'){
        ($data, $unique_traits) = $phenotypes_search->search();        
        print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
        print STDERR "Construct Pheno Matrix Start:".localtime."\n";

        my @line = @metadata_headers;
        push @line, ('plantedSeedlotStockDbId', 'plantedSeedlotStockUniquename', 'plantedSeedlotCurrentCount', 'plantedSeedlotCurrentWeightGram', 'plantedSeedlotBoxName', 'plantedSeedlotTransactionCount', 'plantedSeedlotTransactionWeight', 'plantedSeedlotTransactionDescription', 'availableGermplasmSeedlotUniquenames');

        if ($include_pedigree_parents){
            push @line, ('germplasmPedigreeFemaleParentName', 'germplasmPedigreeFemaleParentDbId', 'germplasmPedigreeMaleParentName', 'germplasmPedigreeMaleParentDbId');
        }

        my @sorted_traits = sort keys(%$unique_traits);
        foreach my $trait (@sorted_traits) {
            push @line, $trait;
            if ($include_phenotype_primary_key) {
                push @line, $trait.'_phenotype_id';
            }
        }
        push @line, 'notes';

        # retrieve treatments and add treatment names to header
        my %seen_obsunits = map { $_->{observationunit_stock_id} => 1 } @$data;
        my $project_object = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
        my $treatment_info = {};
        if ($self->trial_list) {
            $treatment_info = $project_object->get_related_treatments($self->trial_list, \%seen_obsunits);
        }
        my $treatment_names = $treatment_info->{treatment_names};
        my $treatment_details = $treatment_info->{treatment_details};

        foreach my $name (@$treatment_names) {
            push @line, $name;
        }

        push @info, \@line;

        foreach my $obs_unit (@$data){
            my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';
            my $synonyms = $obs_unit->{germplasm_synonyms};
            my $synonym_string = $synonyms ? join ("," , @$synonyms) : '';
            my $available_germplasm_seedlots = $obs_unit->{available_germplasm_seedlots};
            my %available_germplasm_seedlots_uniquenames;
            foreach (@$available_germplasm_seedlots){
                $available_germplasm_seedlots_uniquenames{$_->{stock_uniquename}}++;
            }
            my $available_germplasm_seedlots_uniquenames = join ' AND ', (keys %available_germplasm_seedlots_uniquenames);

            my $trial_name = $obs_unit->{trial_name};
            my $trial_desc = $obs_unit->{trial_description};

            $trial_name =~ s/\s+$//g;
            $trial_desc =~ s/\s+$//g;

            my @line = ($obs_unit->{year}, $obs_unit->{breeding_program_id}, $obs_unit->{breeding_program_name}, $obs_unit->{breeding_program_description}, $obs_unit->{trial_id}, $trial_name, $trial_desc, $obs_unit->{design}, $obs_unit->{plot_width}, $obs_unit->{plot_length}, $obs_unit->{field_size}, $obs_unit->{field_trial_is_planned_to_be_genotyped}, $obs_unit->{field_trial_is_planned_to_cross}, $obs_unit->{planting_date}, $obs_unit->{harvest_date}, $obs_unit->{trial_location_id}, $obs_unit->{trial_location_name}, $obs_unit->{germplasm_stock_id}, $obs_unit->{germplasm_uniquename}, $synonym_string, $obs_unit->{observationunit_type_name}, $obs_unit->{observationunit_stock_id}, $obs_unit->{observationunit_uniquename}, $obs_unit->{obsunit_rep}, $obs_unit->{obsunit_block}, $obs_unit->{obsunit_plot_number}, $obs_unit->{obsunit_row_number}, $obs_unit->{obsunit_col_number}, $entry_type, $obs_unit->{obsunit_plant_number}, $obs_unit->{seedlot_stock_id}, $obs_unit->{seedlot_uniquename}, $obs_unit->{seedlot_current_count}, $obs_unit->{seedlot_current_weight_gram}, $obs_unit->{seedlot_box_name}, $obs_unit->{seedlot_transaction_amount}, $obs_unit->{seedlot_transaction_weight_gram}, $obs_unit->{seedlot_transaction_description}, $available_germplasm_seedlots_uniquenames);

            if ($include_pedigree_parents) {
                my $germplasm = CXGN::Stock->new({schema => $self->bcs_schema, stock_id=>$obs_unit->{germplasm_stock_id}});
                my $parents = $germplasm->get_parents();
                push @line, ($parents->{'mother'}, $parents->{'mother_id'}, $parents->{'father'}, $parents->{'father_id'});
            }

            my $observations = $obs_unit->{observations};
#            print STDERR "OBSERVATIONS =".Dumper($observations)."\n";
            my $include_timestamp = $self->include_timestamp;
            my %trait_observations;
            my %phenotype_ids;
            my $dataset_exluded_outliers_ref = $self->dataset_exluded_outliers;
            foreach my $observation (@$observations){
                my $collect_date = $observation->{collect_date};
                my $timestamp = $observation->{timestamp};

                if ($include_timestamp && $timestamp) {
                    $trait_observations{$observation->{trait_name}} = "$observation->{value},$timestamp";
                }
                elsif ($include_timestamp && $collect_date) {
                    $trait_observations{$observation->{trait_name}} = "$observation->{value},$collect_date";
                }
                else {
                    $trait_observations{$observation->{trait_name}} = $observation->{value};
                }

                # dataset outliers will be empty fields if are in @$dataset_exluded_outliers_ref list of pheno_id outliers
                if(grep {$_ == $observation->{'phenotype_id'}} @$dataset_exluded_outliers_ref) {
                    $trait_observations{$observation->{trait_name}} = ''; # empty field for outlier NA
                }
            }

            if ($include_phenotype_primary_key) {
                foreach my $observation (@$observations) {
                    $phenotype_ids{$observation->{trait_name}} = $observation->{phenotype_id};
                }
            }
            foreach my $trait (@sorted_traits) {
                push @line, $trait_observations{$trait};
                if ($include_phenotype_primary_key) {
                    push @line, $phenotype_ids{$trait};
                }
            }
            push @line, $obs_unit->{notes};

            # add treatment values to each obsunit line
            my %unit_treatments;
            if ($treatment_details->{$obs_unit->{observationunit_stock_id}}) {
                %unit_treatments = %{$treatment_details->{$obs_unit->{observationunit_stock_id}}};
            };
            foreach my $name (@$treatment_names) {
                push @line, $unit_treatments{$name};
            }

            push @info, \@line;
        }
    } else {
        $data = $phenotypes_search->search();
        #print STDERR "DOWNLOAD DATA =".Dumper($data)."\n";

        my %obsunit_data;
        my %traits;

        print STDERR "PhenotypeMatrix No of lines retrieved (Native Search): ".scalar(@$data)."\n";
        print STDERR "PhenotypeMatrix Construct Pheno Matrix Start:".localtime."\n";
        my @unique_obsunit_list = ();
        my %seen_obsunits;        

        foreach my $d (@$data) {
            my $cvterm = $d->{trait_name};
            if ($cvterm){
                my $obsunit_id = $d->{obsunit_stock_id};
                if (!exists($seen_obsunits{$obsunit_id})) {
                    push @unique_obsunit_list, $obsunit_id;
                    $seen_obsunits{$obsunit_id} = 1;
                }

                my $timestamp_value = $d->{timestamp};
                my $value = $d->{phenotype_value};
                #my $cvterm = $trait."|".$cvterm_accession;
                if ($include_timestamp && $timestamp_value) {
                    $obsunit_data{$obsunit_id}->{$cvterm} = "$value,$timestamp_value";
                } else {
                    $obsunit_data{$obsunit_id}->{$cvterm} = $value;
                }
                $obsunit_data{$obsunit_id}->{'notes'} = $d->{notes};

                my $synonyms = $d->{synonyms};
                my $synonym_string = $synonyms ? join ("," , @$synonyms) : '';
                my $entry_type = $d->{is_a_control} ? 'check' : 'test';

                my $trial_name = $d->{trial_name};
                my $trial_desc = $d->{trial_description};

                $trial_name =~ s/\s+$//g;
                $trial_desc =~ s/\s+$//g;

                $obsunit_data{$obsunit_id}->{metadata} = [
                    $d->{year},
                    $d->{breeding_program_id},
                    $d->{breeding_program_name},
                    $d->{breeding_program_description},
                    $d->{trial_id},
                    $trial_name,
                    $trial_desc,
                    $d->{design},
                    $d->{plot_width},
                    $d->{plot_length},
                    $d->{field_size},
                    $d->{field_trial_is_planned_to_be_genotyped},
                    $d->{field_trial_is_planned_to_cross},
                    $d->{planting_date},
                    $d->{harvest_date},
                    $d->{location_id},
                    $d->{location_name},
                    $d->{accession_stock_id},
                    $d->{accession_uniquename},
                    $synonym_string,
                    $d->{obsunit_type_name},
                    $d->{obsunit_stock_id},
                    $d->{obsunit_uniquename},
                    $d->{rep},
                    $d->{block},
                    $d->{plot_number},
                    $d->{row_number},
                    $d->{col_number},
                    $entry_type,
                    $d->{plant_number}
                ];
                $traits{$cvterm}++;
            }
        }
        #print STDERR Dumper \%plot_data;
        #print STDERR Dumper \%traits;

        # retrieve treatments
        my $project_object = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
        my $treatment_info = {};
        if ($self->trial_list) {
            $treatment_info = $project_object->get_related_treatments($self->trial_list, \%seen_obsunits);
        }
        my $treatment_names = $treatment_info->{treatment_names};
        my $treatment_details = $treatment_info->{treatment_details};

        my @line = @metadata_headers;

        my @sorted_traits = sort keys(%traits);
        foreach my $trait (@sorted_traits) {
            push @line, $trait;
        }
        push @line, 'notes';

        # add treatment names to header
        foreach my $name (@$treatment_names) {
            push @line, $name;
        }

        push @info, \@line;

        foreach my $p (@unique_obsunit_list) {
            my @line = @{$obsunit_data{$p}->{metadata}};

            foreach my $trait (@sorted_traits) {
                push @line, $obsunit_data{$p}->{$trait};
            }
            push @line,  $obsunit_data{$p}->{'notes'};

            # add treatment values to each obsunit line
            my %unit_treatments;
            if ($treatment_details->{$p}) {
                %unit_treatments = %{$treatment_details->{$p}};
            };
            foreach my $name (@$treatment_names) {
                push @line, $unit_treatments{$name};
            }
            push @info, \@line;
        }
    }

    #print STDERR Dumper \@info;
    print STDERR "PhenotypeMatrix Construct Pheno Matrix End:".localtime."\n";
    return @info;
}

1;
