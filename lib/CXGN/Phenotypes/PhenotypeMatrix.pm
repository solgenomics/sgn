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
    plot_list=>$plot_list,
    plant_list=>$plant_list,
    include_timestamp=>$include_timestamp,
    include_pedigree_parents=>$include_pedigree_parents,
    exclude_phenotype_outlier=>0,
    dataset_excluded_outliers=>$dataset_excluded_outliers,
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

has 'dataset_excluded_outliers' => (
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

has 'repetitive_measurements' => (
    isa => 'Str',
    is => 'rw',
    default => sub { return 'average'; }, # can be first, last, average, all
);

has 'single_measurements' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => 'last', # can be first or last
);

has 'trait_repeat_types' => ( # returns the repeat type for every trait keyed by cvterm_id
    isa => 'HashRef|Undef',
    is => 'rw',
    default => sub { return {} },
);

sub get_phenotype_matrix {
    my $self = shift;
    my $include_pedigree_parents = $self->include_pedigree_parents();
    my $include_timestamp = $self->include_timestamp;
    my $include_phenotype_primary_key = $self->include_phenotype_primary_key;

    $self->trait_repeat_types( $self->retrieve_trait_repeat_types() );
    print STDERR "GET PHENOMATRIX ".$self->search_type."\n";
    
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
            plot_list=>$self->plot_list,
            plant_list=>$self->plant_list,
            subplot_list=>$self->subplot_list,
            include_timestamp=>$include_timestamp,
            exclude_phenotype_outlier=>$self->exclude_phenotype_outlier,
            dataset_excluded_outliers=>$self->dataset_excluded_outliers,
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

	    #print STDERR "DATA = ".Dumper($data);
	
        foreach my $obs_unit (@$data){
            print STDERR "observation_unit_values: " . Dumper($obs_unit) . "\n";
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

	        #print STDERR "OBS UNIT = ".Dumper($obs_unit);
	        my $observations = $obs_unit->{observations};

	        #print STDERR "OBSERVATIONS BEFORE FORMAT: ".Dumper($observations);

            #if (scalar(@$observations) > 0) {


	        my %phenotype_ids;
	        my %trait_observations = ();
	        if (@$observations > 0) {
		        %trait_observations = $self->format_observations($observations);
	        }

	        print STDERR "FORMATTED OBSERVATIONS =".Dumper(\%trait_observations)."\n";

	        if ($include_phenotype_primary_key) {
		        foreach my $observation (@$observations) {
		            $phenotype_ids{$observation->{trait_name}} = $observation->{phenotype_id};
		        }
	        }

            if ($self->repetitive_measurements () eq "all") {
                my $max_values = 1;
	            foreach my $trait (@sorted_traits) {
                    if (ref($trait_observations{$trait}) eq 'ARRAY') {
                        my $trait_count = scalar(@{$trait_observations{$trait}});
                        $max_values = $trait_count if $trait_count > $max_values;
                    }
                }
                for (my $i = 0; $i < $max_values; $i++) {
                    my @line = @line;
                    foreach my $trait (@sorted_traits) {
                        if (ref($trait_observations{$trait}) eq 'ARRAY') {
                            my $v = $trait_observations{$trait}[$i];
                            push @line, $v;
                        } else {
                            push @line, ($i == 0) ? $trait_observations{$trait} : undef;
                        }
                    }
                    push @line, $obs_unit->{notes} if $i == 0;
                    # print STDERR "final line after all values: " . Dumper(\@line) . "\n";
                    my %unit_treatments;
                    if ($treatment_details->{$obs_unit->{observationunit_stock_id}}) {
                        %unit_treatments = %{$treatment_details->{$obs_unit->{observationunit_stock_id}}};
                    };
                    foreach my $name (@$treatment_names) {
                        # print STDERR "adding treatment $name " . Dumper ($unit_treatments{$name}) . "\n";
                        push @line, $unit_treatments{$name};
                    }
                    push @info, \@line;
                }
            }else {
                my @line = @line;
                foreach my $trait (@sorted_traits) {
                    push @line, $trait_observations{$trait};
                    # print STDERR "adding trait $trait : " . $trait_observations{$trait} . "\n";
		            if ($include_phenotype_primary_key) {
		                push @line, $phenotype_ids{$trait};
                        print STDERR "add the pheno_id for each trait $trait : $phenotype_ids{$trait}\n";
		            }
	            }
                # print STDERR "print the list of sorted_traits:" . Dumper (\@sorted_traits) . "\n";
                push @line, $obs_unit->{notes};
                # add treatment values to each obsunit line
                my %unit_treatments;
                if ($treatment_details->{$obs_unit->{observationunit_stock_id}}) {
                    %unit_treatments = %{$treatment_details->{$obs_unit->{observationunit_stock_id}}};
                };
                foreach my $name (@$treatment_names) {
                    # print STDERR "Adding treatment $name with value: " . ($unit_treatments{$name} // '') . "\n";
                    push @line, $unit_treatments{$name};
                }
                push @info, \@line;
            }
        }
    }
    else {  ### NATIVE ??!!
	
        $data = $phenotypes_search->search();
        #print STDERR "DOWNLOAD DATA =".Dumper($data)."\n";

        my %obsunit_data;
        my %traits;

        # print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
        # print STDERR "Construct Pheno Matrix Start:".localtime."\n";
        my @unique_obsunit_list = ();
        my %seen_obsunits;
        my %process_obs;

	    foreach my $d (@$data) {
            # print STDERR "check the retrieved data: " . Dumper($d) . "\n";
            my $phenotype_uniquename = $d->{phenotype_uniquename};
            my $collect_date;
            if ($phenotype_uniquename =~ /date:\s+(\d{4}-\d{2}-\d{2})/) {
                $collect_date = $1;
                $d->{collect_date} = $collect_date;
            }else {
                $collect_date = undef;
                $d->{collect_date} = undef;
            }
	        my $value = $d->{phenotype_value};
	        if ($include_timestamp && exists($d->{timestamp})) {
	    	    $value .= ",$d->{timestamp}";
	        }
	        push @{ $obsunit_data{$d->{obsunit_stock_id}}->{$d->{trait_name} } }, [$value, $collect_date];
	    }
	
        foreach my $d (@$data) {
            my $cvterm = $d->{trait_name};
            if ($cvterm){
                my $obsunit_id = $d->{obsunit_stock_id};
                if (!exists($seen_obsunits{$obsunit_id})) {
                    push @unique_obsunit_list, $obsunit_id;
                    $seen_obsunits{$obsunit_id} = 1;
                }

                #my $cvterm = $trait."|".$cvterm_accession;
                # if ($include_timestamp && $timestamp_value) {
                #     $obsunit_data{$obsunit_id}->{$cvterm} = "$value,$timestamp_value";
                # } else {
                #     $obsunit_data{$obsunit_id}->{$cvterm} = $value;
                # }
                # print STDERR "repetitive_measurements value passed from the CSV plugin : " . $self->repetitive_measurements() . "\n";
                # print STDERR "data contents: " . Dumper($obsunit_data{$obsunit_id}->{$cvterm}) . "\n";

		        if (ref($obsunit_data{$obsunit_id}->{$cvterm}) eq "ARRAY") {
		            if ($self->repetitive_measurements() eq "first") {
                        my $first_entry = shift(@{$obsunit_data{$obsunit_id}->{$cvterm}});
                        my $first_obs_value = $first_entry->[0];
                        my $first_obs_collect_date = $first_entry->[1];
                        my $output_val = defined $first_obs_collect_date ? "$first_obs_value, $first_obs_collect_date" : $first_obs_value;
                        $obsunit_data{$obsunit_id}->{$cvterm} = $output_val;
                        # print STDERR "see the values and collect date of first observations: " . $obsunit_data{$obsunit_id}->{$cvterm} . "\n";
		            }elsif ($self->repetitive_measurements() eq "last") {
                        my $last_entry = pop(@{$obsunit_data{$obsunit_id}->{$cvterm}});
                        my $last_obs_value = $last_entry->[0];
                        my $last_obs_collect_date = $last_entry->[1];
                        my $output_val = defined $last_obs_collect_date ? "$last_obs_value, $last_obs_collect_date" : $last_obs_value;
                        $obsunit_data{$obsunit_id}->{$cvterm} = $output_val;
                        # print STDERR "the last value of the trait obs: $output_val\n";
		            }elsif ($self->repetitive_measurements() eq "average") {
		        	    my $count = 0;
		        	    my $sum = 0;
                        my $latest_date; #using the last_date as the collect_date for the averaged values
		        	    foreach my $v (@{ $obsunit_data{$obsunit_id}->{$cvterm}}) {
		        	        if (defined($v->[0])) {   
		        	    	    $sum += $v->[0];
		        	    	    $count++;
                                if (defined($v->[1])) {
                                    $latest_date = $v->[1];
                                    # print STDERR "the latest date: $latest_date\n";
                                }
		        	        }
		        	    }
                        ## the collected_date for the average obs will prin the first collect_date of that obs
		        	    if ($count > 0) {
                            my $average_value = $sum/$count;
                            my $output_val = defined $latest_date ? "$average_value, $latest_date" : $average_value;
                            $obsunit_data{$obsunit_id}->{$cvterm} = $output_val;
                            # print STDERR "the average value : $output_val\n";
		        	    }
		        	    else {
		        	        $obsunit_data{$obsunit_id}->{$cvterm} = undef;
		        	    }
		            }elsif ($self->repetitive_measurements() eq "all") {
                        if (!$process_obs{$obsunit_id}->{$cvterm}) {
                            $process_obs{$obsunit_id}->{$cvterm} = 1;
                            # print STDERR "see all values for block wise - first, intermediate and last: $obsunit_id, $cvterm\n"; #debugging only
                            my $values_ref = $obsunit_data{$obsunit_id}->{$cvterm};
                            my @output_values;

                            foreach my $entry (@$values_ref) {
                                my ($value, $date);
                                if (ref($entry) eq 'ARRAY') {
                                    ($value, $date) = @$entry;
                                }else {
                                    $value = $entry;
                                    $date = undef;
                                }
                                my $output_val = defined $date ? "$value, $date" : $value;
                                push @output_values, [$value, $date];
                                # print STDERR "Value: $output_val\n";
                            }
                            # Instead of joining, we store these separately
                            $obsunit_data{$obsunit_id}->{$cvterm} = \@output_values;
                            # print STDERR "Processed 'all values' for obsunit_id: $obsunit_id, trait: $cvterm\n";
                            # print STDERR "Value-Date Pairs: " . Dumper(\@output_values) . "\n";
                        }
		            }else {
                        my $values_ref = shift(@{$obsunit_data{$obsunit_id}->{$cvterm}});
                        my $value = $values_ref->[0];
                        my $collect_date = $values_ref->[1];
                        my $output_val = defined $collect_date ? "$value, $collect_date" : $value;
                        $obsunit_data{$obsunit_id}->{$cvterm} = $output_val;
                        # print STDERR "check the single value: $output_val\n";
                    }
		        }

                # $obsunit_data{$obsunit_id}->{'notes'} = $d->{notes};
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
        #print STDERR "PLOT DATA = ".Dumper \%plot_data;
        # print STDERR "TRAITS = ".Dumper \%traits;

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
            if ($include_phenotype_primary_key) {
                push @line, $trait.'_phenotype_id';
            }
        }
        push @line, 'notes';

        # add treatment names to header
        foreach my $name (@$treatment_names) {
            push @line, $name;
        }

        push @info, \@line;

        foreach my $p (@unique_obsunit_list) {
            my $values_max = 1;
            foreach my $trait (@sorted_traits) {
                if (ref($obsunit_data{$p}->{$trait}) eq 'ARRAY') {
                    my $trait_count = scalar(@{$obsunit_data{$p}->{$trait}});
                    $values_max = $trait_count if $trait_count > $values_max;
                }
            }
            print STDERR " maximum values fr the observation unit $p is $values_max\n";
            for (my $i = 0; $i < $values_max; $i++) {
                my @line = @{$obsunit_data{$p}->{metadata}};
                foreach my $trait (@sorted_traits) {
                    my $value_with_date = '';
                    if(ref($obsunit_data{$p}->{$trait}) eq 'ARRAY') {
                        my $value_entry = $obsunit_data{$p}->{$trait}[$i];
                        my ($v, $cd) = @$value_entry;
                        $value_with_date = defined($v) ? (defined($cd) ? "$v, $cd" : $v) : undef;
                        push @line, $value_with_date;
                    } else {
                        my $v = $obsunit_data{$p}->{$trait};
                        my $cd = $obsunit_data{$p}->{$trait.'_collect_date'};
                        #the recorded will be added to the obs value by separating with comma
                        $value_with_date = ($i == 0 && defined($v)) ? (defined($cd) ? "$v, $cd" : $v) : undef;
                        push @line, $value_with_date;
                        # push @line, ($i == 0) ? $obsunit_data{$p}->{$trait.'_collect_date'} : '';
                    }
                }
                push @line, $obsunit_data{$p}->{'notes'} if $i == 0;
                # }
                # add treatment values to each obsunit line
                # my %unit_treatments;
                # if ($treatment_details->{$p}) {
                #     %unit_treatments = %{$treatment_details->{$p}};
                # };
                foreach my $name (@$treatment_names) {
                    push @line, $treatment_details->{$p}->{$name};
                }
                push @info, \@line;
            }
        }
    }

    # print STDERR "check the info data structure " . Dumper \@info;
    # print STDERR "Construct Pheno Matrix End:".localtime."\n";
    return @info;
}

sub format_observations {
    my $self = shift;
    my $observations = shift;

    if (scalar(@$observations) == 0) {
	    print STDERR "No observations in this obs_unit... Skipping.\n";
	    return [];
    }
    
    my %trait_observations;
    my $include_timestamp = $self->include_timestamp;
    my $dataset_excluded_outliers_ref = $self->dataset_excluded_outliers;

    my $de_duplicated_observations = $self->detect_multiple_measurements($observations);
    
    foreach my $observation (@$de_duplicated_observations){
	    my $collect_date = $observation->{collect_date};
	    my $timestamp = $observation->{timestamp};
        my $value = $observation->{value};

        if ($self->repetitive_measurements() eq 'all') {
            $trait_observations{$observation->{trait_name}} = [];
            push @{$trait_observations{$observation->{trait_name}}}, $value;
            next;
        }
	    if ($include_timestamp && $timestamp) {

	        if (ref($observation->{value})) {
	    	    $observation->{value} = join("|", map { $_->{value}.",".$timestamp}  @$observation);
	        }
	        $trait_observations{$observation->{trait_name}} = "$observation->{value},$timestamp";
    
	    }
	    elsif ($include_timestamp && $collect_date) {
	        if (ref($observation->{value})) {
	    	    $observation->{value} = join("|", map {$_->{value}.",".$collect_date} @$observation);
	        }
	        $trait_observations{$observation->{trait_name}} = "$observation->{value},$collect_date";
    
	    }
	    else {
	        if (ref($observation->{value})) {
	    	    $observation->{value} = join("|", @{$observation->{value}});
	        }
	        $trait_observations{$observation->{trait_name}} = $observation->{value};
    
	    }

	    ### FOR debugging only:
	    #$trait_observations{$observation->{trait_name}}.=$observation->{squash_method};
    
	    # dataset outliers will be empty fields if are in @$dataset_excluded_outliers_ref list of pheno_id outliers
	    if(grep {$_ == $observation->{'phenotype_id'}} @$dataset_excluded_outliers_ref) {
	        $trait_observations{$observation->{trait_name}} = ''; # empty field for outlier NA
	    }
    }

    #print STDERR "detecting multiple observations in ".Dumper($observations);
    return %trait_observations;
}

sub detect_multiple_measurements {
    my $self = shift;
    my $trait_observations = shift;

    my %duplicate_measurements;

#    print STDERR "CHECKING MULTIPLE MEASUREMENTS...\n";
    
    if (! $trait_observations) { return []; }
    foreach my $o (@$trait_observations) {
	    my $trait_id = $o->{trait_id};
	    push @{$duplicate_measurements{$trait_id}}, $o;
    }

    foreach my $trait_id (keys %duplicate_measurements) {
	    if (scalar(@{$duplicate_measurements{$trait_id}})>1) {
	        #print STDERR "De-duplicating measurements... ".Dumper($duplicate_measurements{$trait_id});
    
	        my $trait_observations = $self->process_duplicate_measurements($duplicate_measurements{$trait_id});
	        $duplicate_measurements{$trait_id} = [ $trait_observations ];

	        #print STDERR "After de-duplication: ".Dumper($duplicate_measurements{$trait_id});
	    }
    }

    #print STDERR "DUPLICATE MEASUREMENTS: ".Dumper(\%duplicate_measurements);

    my @processed_observations;
    foreach my $trait_id (keys %duplicate_measurements) { 
	    push @processed_observations, @{$duplicate_measurements{$trait_id}}[0];
    }

    #print STDERR "PROCESSED observations = ".Dumper(\@processed_observations);
    
    return \@processed_observations; 
}

sub process_duplicate_measurements {
    my $self = shift;
    my $trait_observations = shift;

    #print STDERR "PROCESSING DUPLICATES WITH ".Dumper($trait_observations);
    
    if ($self->repetitive_measurements() eq "first") {
	    print STDERR "Retrieving first value...\n";
	    return $trait_observations->[0];
    }elsif ($self->repetitive_measurements() eq "last") {
	    print STDERR "Retrieving last value...\n";
	    return $trait_observations->[-1] ;
    }elsif ($self->repetitive_measurements() eq "average") {
	    print STDERR "Averaging values ...\n";
	    return $self->average_observations($trait_observations);
    }elsif ($self->repetitive_measurements() eq "all") {
	    print STDERR "Retrieving all values...\n";
        return $trait_observations;
    }else {
        print STDERR "Unknown repetitive_measurements value: " . $self->repetitive_measurements() . ". Defaulting to average value.\n";
        return $self->average_observations($trait_observations);
    }

    #print STDERR "DONE WITH DUPLICATES, NOW: ".Dumper($trait_observations);
    return $trait_observations;
}

sub average_observations {
    my $self = shift;
    my $observations_ref = shift || [];

    if (! @$observations_ref) { return; }
    
    #print STDERR "Averaging Observations: ".Dumper($observations_ref);
    
    my $sum = undef;
    my $count = 0;
    my @values;
    foreach my $v (@$observations_ref) {
	if (! $v->{outlier} && defined($v->{value}) ) { 
	    $sum += $v->{value};
	    $count++;
	    push @values, $v->{value};
	}
    }

    my $avg;
    my $stddev;
    
    if (defined($sum) && ($count > 0) ) {   # make sure to return undef for measurements that are all undef
	$avg = $sum / $count;
    
	my $sqr_diff;
	
	foreach my $v (@$observations_ref) {
	    my $diff = $v->{value} - $avg;
	    $sqr_diff += $diff * $diff;
	    $count++;
	}
	$stddev = sqrt($sqr_diff/$count);
    }
    
    my $averaged_observation = $observations_ref->[0];
    $averaged_observation->{value} = $avg;
    $averaged_observation->{stddev} = $stddev;
    $averaged_observation->{averaged_from} = join(", ", @values);
    #print STDERR "Averaged Observation: ".Dumper( $averaged_observation );

    return $averaged_observation;
		      
}

sub retrieve_trait_repeat_types {
    my $self = shift;

    my %property_by_cvterm_id;
    my $sql = "SELECT cvtermprop.value, cvterm.cvterm_id, cvterm.name FROM cvterm join cvtermprop on(cvterm.cvterm_id=cvtermprop.cvterm_id) join cvterm as proptype on(cvtermprop.type_id=proptype.cvterm_id) where proptype.name='trait_repeat_type' ";
    my $sth= $self->bcs_schema()->storage()->dbh()->prepare($sql);
    $sth->execute();
    while (my ($property_value, $cvterm_id, $cvterm_name) = $sth->fetchrow_array) {
        $property_by_cvterm_id{$cvterm_id} = $property_value;
    }

    return \%property_by_cvterm_id;
}
	    
	
1;
