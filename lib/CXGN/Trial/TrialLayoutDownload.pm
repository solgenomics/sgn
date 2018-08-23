package CXGN::Trial::TrialLayoutDownload;

=head1 NAME

CXGN::Trial::TrialLayoutDownload

=head1 SYNOPSIS

Module to format layout info for trial based on which columns user wants to see. Selected columns can be 'plant_name','subplot_name','plot_name','block_number','subplot_number','plant_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','synonyms', or 'tier'.
This module can also optionally include treatments into the output.
This module can also optionally include accession trait performace summaries into the output.

This module is used from CXGN::Trial::Download::Plugin::TrialLayoutExcel, CXGN::Trial::Download::Plugin::TrialLayoutCSV, CXGN::Fieldbook::DownloadTrial

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plots',
    treatment_project_ids => [1,2],
    selected_columns => {"plot_name"=>1,"plot_number"=>1,"block_number"=>1},
    selected_trait_ids => [1,2,3],
    selected_trait_names => ['trait1|CO:00001', 'trait2|CO:000002']
});
my $output = $trial_layout_download->get_layout_output();

Output is an ArrayRef or ArrayRefs where the first entry is the Header and subsequent entries are the layout entries.


If you don't need treatments or phenotype summaries included you can ignore those keys like:

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plots',
    selected_columns => {"plot_name"=>1,"plot_number"=>1,"block_number"=>1},
});
my $output = $trial_layout_download->get_layout_output();

Data Level can be plots, plants, subplots (for splitplot design), field_trial_tissue_samples (for seeing tissue_samples linked to plants in a field trial), plate (for seeing genotyping_layout plate tissue_samples)

=head1 AUTHORS


=cut


use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Accession;
use JSON;
use CXGN::Phenotypes::Summary;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

has 'trial_id'   => (
    isa => "Int",
    is => 'ro',
    required => 1,
);

has 'data_level' => (
    is => 'ro',
    isa => 'Str',
    default => 'plots',
);
  
has 'treatment_project_ids' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'selected_columns' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {"plot_name"=>1, "plot_number"=>1} }
);

has 'selected_trait_ids'=> (
    is => 'ro',
    isa => 'ArrayRef[Int]|Undef',
);

has 'selected_trait_names'=> (
    is => 'ro',
    isa => 'ArrayRef[Str]|Undef',
);

sub get_layout_output { 
    my $self = shift;
    my $trial_id = $self->trial_id();
    my $schema = $self->schema();
    my %errors;
    my @error_messages;
    my @output;

    print STDERR "TrialLayoutDownload for Trial id: ($trial_id) ".localtime()."\n";

    my $trial_layout;
    try {
        my %param = ( schema => $schema, trial_id => $trial_id );
        if ($self->data_level eq 'plate'){
            $param{experiment_type} = 'genotyping_layout';
        } else {
            $param{experiment_type} = 'field_layout';
        }
        $trial_layout = CXGN::Trial::TrialLayout->new(\%param);
    };
    if (!$trial_layout) {
        push @error_messages, "Trial does not have valid field design.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $selected_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
    my $has_plants = $selected_trial->has_plant_entries();
    my $has_subplots = $selected_trial->has_subplot_entries();
    my $has_tissue_samples = $selected_trial->has_tissue_sample_entries();

    my $location_name = $selected_trial->get_location ? $selected_trial->get_location->[1] : '';
    my $trial_year = $selected_trial->get_year ? $selected_trial->get_year : '';
    my $accessions = $selected_trial->get_accessions();
    my @accession_ids;
    foreach (@$accessions){
        push @accession_ids, $_->{stock_id};
    }

    my $treatments = $self->treatment_project_ids();
    my @treatment_trials;
    my @treatment_names;
    my @treatment_units_array;
    if ($treatments){
        foreach (@$treatments){
            my $treatment_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_});
            my $treatment_name = $treatment_trial->get_name();
            push @treatment_trials, $treatment_trial;
            push @treatment_names, $treatment_name;
        }
    }

    my $trial_name =  $trial_layout->get_trial_name();
    my $design = $trial_layout->get_design();
    if (!$design){
        push @error_messages, "Trial does not have valid field design. Please contact us.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    #print STDERR Dumper $design;

    my %selected_cols = %{$self->selected_columns};
    my @selected_col_keys = keys %selected_cols;
    my @selected_traits = $self->selected_trait_ids() ? @{$self->selected_trait_ids} : ();
    my @selected_trait_names = $self->selected_trait_names() ? @{$self->selected_trait_names} : ();
    my $summary_values = [];
    if (scalar(@selected_traits)>0){ 
        my $summary = CXGN::Phenotypes::Summary->new({
            bcs_schema=>$schema,
            trait_list=>\@selected_traits,
            accession_list=>\@accession_ids
        });
        $summary_values = $summary->search();
    }
    my %fieldbook_trait_hash;
    foreach (@$summary_values){
        $fieldbook_trait_hash{$_->[0]}->{$_->[8]} = $_;
    }
    #print STDERR Dumper \%fieldbook_trait_hash;

    my @possible_cols = ();
    if ($self->data_level eq 'plots') {
        @possible_cols = ('plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_plots() : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($self->data_level eq 'plants') {
        @possible_cols = ('plant_name','plant_id','subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_plants() : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($self->data_level eq 'subplots') {
        @possible_cols = ('subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_subplots() : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($self->data_level eq 'field_trial_tissue_samples') {
        @possible_cols = ('tissue_sample_name','tissue_sample_id','plant_name','plant_id','subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','tissue_sample_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_tissue_samples() : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($self->data_level eq 'plate') {
        #to make the download in the header for genotyping plates more easily understood, the terms change here
        if (exists($selected_cols{'plot_name'})){
            $selected_cols{'tissue_sample_name'} = 1;
            delete $selected_cols{'plot_name'};
        }
        if (exists($selected_cols{'plot_number'})){
            $selected_cols{'well_A01'} = 1;
            delete $selected_cols{'plot_number'};
        }
        $selected_cols{'exported_tissue_sample_name'} = 1;
        @possible_cols = ('trial_name', 'acquisition_date', 'exported_tissue_sample_name', 'tissue_sample_name', 'well_A01', 'row_number', 'col_number', 'source_observation_unit_name', 'accession_name', 'dna_person', 'notes', 'tissue_type', 'extraction', 'concentration', 'volume', 'is_blank');
    }

    my @header;
    foreach (@possible_cols){
        if ($selected_cols{$_}){
            push @header, $_;
        }
    }
    my @treatment_stock_hashes;
    foreach (@treatment_names){
        push @header, "ManagementFactor:".$_;
    }
    foreach my $u (@treatment_units_array){
        my %treatment_stock_hash;
        foreach (@$u){
            $treatment_stock_hash{$_->[1]}++;
        }
        push @treatment_stock_hashes, \%treatment_stock_hash;
    }

    foreach (@selected_trait_names){
        push @header, $_;
    }
    push @output, \@header; 
    my (@rows, @cols);
    if ($self->data_level eq 'plot_fieldMap' ) {
        my %hash;
        foreach my $key (keys %$design) {
            my $design_info = $design->{$key};
            my $row_num = $design_info->{row_number};
            my $col_num = $design_info->{col_number};
            my $accession = $design_info->{accession_name};
            $hash{$row_num}->{$col_num} = $accession; 
            push @rows, $row_num;
            push @cols, $col_num;     
        }
        print STDERR "TrialLayoutDownload End for Trial id: ($trial_id) ".localtime()."\n";
        return {output => \%hash, rows => \@rows, cols => \@cols};
    }
    else{
        foreach my $key (sort { $a <=> $b} keys %$design) {
            my $design_info = $design->{$key};
            if ($self->data_level eq 'plots' ) {
                push @output, _construct_ouput_for_plots($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
            }
            if ($self->data_level eq 'subplots' && $has_subplots) {
                push @output, _construct_ouput_for_subplots($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
            }
            if ($self->data_level eq 'plants' && $has_plants) {
                if ($has_subplots){
                    push @output, _construct_ouput_for_plants_with_subplots($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
                } else {
                    push @output, _construct_ouput_for_plants($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
                }
            }
            if ($self->data_level eq 'field_trial_tissue_samples' && $has_tissue_samples) {
                #Tissue samples require that trial has plants before tissues sample can be created, so this should always be true.
                if ($has_plants){
                    if ($has_subplots){
                        push @output, _construct_ouput_for_tissue_samples_with_subplots_and_plants($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
                    } else {
                        push @output, _construct_ouput_for_tissue_samples_with_plants($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name, $trial_year, \@treatment_stock_hashes, \@selected_trait_names, \%fieldbook_trait_hash);
                    }
                }
            }
            if ($self->data_level eq 'plate') {
                push @output, _construct_ouput_for_wells_in_plate($schema, $design_info, \@possible_cols, \%selected_cols, $location_name, $trial_name);
            }
        }
    }

    print STDERR "TrialLayoutDownload End for Trial id: ($trial_id) ".localtime()."\n";
    return {output => \@output};
}

sub _construct_ouput_for_plots {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;

    my $line;
    foreach (@$possible_cols){
        if ($selected_cols->{$_}){
            if ($_ eq 'location_name'){
                push @$line, $location_name;
            } elsif ($_ eq 'plot_geo_json'){
                push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
            } elsif ($_ eq 'trial_name'){
                push @$line, $trial_name;
            } elsif ($_ eq 'year'){
                push @$line, $trial_year;
            } elsif ($_ eq 'tier'){
                my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                push @$line, $row."/".$col;
            } elsif ($_ eq 'synonyms'){
                my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
                push @$line, join ',', @{$accession->synonyms}
            } elsif ($_ eq 'pedigree'){
                my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
                push @$line, $accession->get_pedigree_string('Parents');
            } else {
                push @$line, $design_info->{$_};
            }
        }
    }
    $line = _add_treatment_to_line($treatment_stock_hashes, $line, $design_info->{'plot_name'});
    $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
    return $line;
}

sub _construct_ouput_for_plants {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;

    my $plant_names = $design_info->{'plant_names'};
    my $plant_ids = $design_info->{'plant_ids'};
    my $plant_index_numbers = $design_info->{'plant_index_numbers'};
    my $i = 0;
    my %plant_id_hash;
    my %plant_index_number_hash;
    foreach (@$plant_names){
        $plant_id_hash{$_} = $plant_ids->[$i];
        $plant_index_number_hash{$_} = $plant_index_numbers->[$i];
        $i++;
    }

    my $acc_synonyms = '';
    if (exists($selected_cols->{'synonyms'})){
        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_synonyms = join ',', @{$accession->synonyms};
    }
    my $acc_pedigree = '';
    if (exists($selected_cols->{'pedigree'})){
        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_pedigree = $accession->get_pedigree_string('Parents');
    }
    my @lines;
    foreach (sort @$plant_names) {
        my $line;
        foreach my $c (@$possible_cols){
            if ($selected_cols->{$c}){
                if ($c eq 'plant_name'){
                    push @$line, $_;
                } elsif ($c eq 'plant_id'){
                    push @$line, $plant_id_hash{$_};
                } elsif ($c eq 'plant_number'){
                    push @$line, $plant_index_number_hash{$_};
                } elsif ($c eq 'location_name'){
                    push @$line, $location_name;
                } elsif ($c eq 'plot_geo_json'){
                    push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
                } elsif ($c eq 'trial_name'){
                    push @$line, $trial_name;
                } elsif ($c eq 'year'){
                    push @$line, $trial_year;
                } elsif ($c eq 'tier'){
                    my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                    my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                    push @$line, $row."/".$col;
                } elsif ($c eq 'synonyms'){
                    push @$line, $acc_synonyms;
                } elsif ($c eq 'pedigree'){
                    push @$line, $acc_pedigree;
                } else {
                    push @$line, $design_info->{$c};
                }
            }
        }
        $line = _add_treatment_to_line($treatment_stock_hashes, $line, $_);
        $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
        push @lines, $line;
    }
    return @lines;
}

sub _construct_ouput_for_subplots {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;
    my $subplot_names = $design_info->{'subplot_names'};
    my $subplot_ids = $design_info->{'subplot_ids'};
    my $subplot_index_numbers = $design_info->{'subplot_index_numbers'};
    my $i = 0;
    my %subplot_id_hash;
    my %subplot_index_number_hash;
    foreach (@$subplot_names){
        $subplot_id_hash{$_} = $subplot_ids->[$i];
        $subplot_index_number_hash{$_} = $subplot_index_numbers->[$i];
        $i++;
    }
    my $subplot_num = 1;
    my $acc_synonyms = '';
    if (exists($selected_cols->{'synonyms'})){
        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_synonyms = join ',', @{$accession->synonyms};
    }
    my $acc_pedigree = '';
    if (exists($selected_cols->{'pedigree'})){
        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_pedigree = $accession->get_pedigree_string('Parents');
    }
    my @lines;
    foreach (sort @$subplot_names) {
        my $line;
        foreach my $c (@$possible_cols){
            if ($selected_cols->{$c}){
                if ($c eq 'subplot_name'){
                    push @$line, $_;
                } elsif ($c eq 'subplot_id'){
                    push @$line, $subplot_id_hash{$_};
                } elsif ($c eq 'subplot_number'){
                    push @$line, $subplot_index_number_hash{$_};
                } elsif ($c eq 'location_name'){
                    push @$line, $location_name;
                } elsif ($c eq 'plot_geo_json'){
                    push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
                } elsif ($c eq 'trial_name'){
                    push @$line, $trial_name;
                } elsif ($c eq 'year'){
                    push @$line, $trial_year;
                } elsif ($c eq 'tier'){
                    my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                    my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                    push @$line, $row."/".$col;
                } elsif ($c eq 'synonyms'){
                    push @$line, $acc_synonyms;
                } elsif ($c eq 'pedigree'){
                    push @$line, $acc_pedigree;
                } else {
                    push @$line, $design_info->{$c};
                }
            }
        }
        $line = _add_treatment_to_line($treatment_stock_hashes, $line, $_);
        $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
        push @lines, $line;
    }
    return @lines;
}

sub _construct_ouput_for_plants_with_subplots {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;

    my $subplot_plant_names = $design_info->{'subplots_plant_names'};
    my $plant_names = $design_info->{'plant_names'};
    my $plant_ids = $design_info->{'plant_ids'};
    my $plant_index_numbers = $design_info->{'plant_index_numbers'};
    my $i = 0;
    my %plant_id_hash;
    my %plant_index_number_hash;
    foreach (@$plant_names){
        $plant_id_hash{$_} = $plant_ids->[$i];
        $plant_index_number_hash{$_} = $plant_index_numbers->[$i];
        $i++;
    }
    my $subplot_names = $design_info->{'subplot_names'};
    my $subplot_ids = $design_info->{'subplot_ids'};
    my $subplot_index_numbers = $design_info->{'subplot_index_numbers'};
    my $j = 0;
    my %subplot_id_hash;
    my %subplot_index_number_hash;
    foreach (@$subplot_names){
        $subplot_id_hash{$_} = $subplot_ids->[$j];
        $subplot_index_number_hash{$_} = $subplot_index_numbers->[$j];
        $j++;
    }

    my $acc_synonyms = '';
    if (exists($selected_cols->{'synonyms'})){
        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_synonyms = join ',', @{$accession->synonyms};
    }
    my $acc_pedigree = '';
    if (exists($selected_cols->{'pedigree'})){
        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_pedigree = $accession->get_pedigree_string('Parents');
    }
    my @lines;
    foreach my $s (sort keys %$subplot_plant_names) {
        my $plants = $subplot_plant_names->{$s};
        foreach my $p (sort @$plants){
            my $line;
            foreach my $c (@$possible_cols){
                if ($selected_cols->{$c}){
                    if ($c eq 'plant_name'){
                        push @$line, $p;
                    } elsif ($c eq 'plant_id'){
                        push @$line, $plant_id_hash{$p};
                    } elsif ($c eq 'subplot_name'){
                        push @$line, $s;
                    } elsif ($c eq 'subplot_id'){
                        push @$line, $subplot_id_hash{$s};
                    } elsif ($c eq 'subplot_number'){
                        push @$line, $subplot_index_number_hash{$s};
                    } elsif ($c eq 'plant_number'){
                        push @$line, $plant_index_number_hash{$p};
                    } elsif ($c eq 'location_name'){
                        push @$line, $location_name;
                    } elsif ($c eq 'plot_geo_json'){
                        push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
                    } elsif ($c eq 'trial_name'){
                        push @$line, $trial_name;
                    } elsif ($c eq 'year'){
                        push @$line, $trial_year;
                    } elsif ($c eq 'tier'){
                        my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                        my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                        push @$line, $row."/".$col;
                    } elsif ($c eq 'synonyms'){
                        push @$line, $acc_synonyms;
                    } elsif ($c eq 'pedigree'){
                        push @$line, $acc_pedigree;
                    } else {
                        push @$line, $design_info->{$c};
                    }
                }
            }
            $line = _add_treatment_to_line($treatment_stock_hashes, $line, $p);
            $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
            push @lines, $line;
        }
    }
    return @lines;
}

sub _construct_ouput_for_tissue_samples_with_subplots_and_plants {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;

    my $subplot_plant_names = $design_info->{'subplots_plant_names'};
    my $plant_tissue_names = $design_info->{'plants_tissue_sample_names'};
    my $plant_names = $design_info->{'plant_names'};
    my $plant_ids = $design_info->{'plant_ids'};
    my $plant_index_numbers = $design_info->{'plant_index_numbers'};
    my $i = 0;
    my %plant_id_hash;
    my %plant_index_number_hash;
    foreach (@$plant_names){
        $plant_id_hash{$_} = $plant_ids->[$i];
        $plant_index_number_hash{$_} = $plant_index_numbers->[$i];
        $i++;
    }
    my $subplot_names = $design_info->{'subplot_names'};
    my $subplot_ids = $design_info->{'subplot_ids'};
    my $subplot_index_numbers = $design_info->{'subplot_index_numbers'};
    my $j = 0;
    my %subplot_id_hash;
    my %subplot_index_number_hash;
    foreach (@$subplot_names){
        $subplot_id_hash{$_} = $subplot_ids->[$j];
        $subplot_index_number_hash{$_} = $subplot_index_numbers->[$j];
        $j++;
    }
    my $tissue_sample_names = $design_info->{'tissue_sample_names'};
    my $tissue_sample_ids = $design_info->{'tissue_sample_ids'};
    my $tissue_sample_index_numbers = $design_info->{'tissue_sample_index_numbers'};
    my $k = 0;
    my %tissue_sample_id_hash;
    my %tissue_sample_index_number_hash;
    foreach (@$tissue_sample_names){
        $tissue_sample_id_hash{$_} = $tissue_sample_ids->[$k];
        $tissue_sample_index_number_hash{$_} = $tissue_sample_index_numbers->[$k];
        $k++;
    }

    my $acc_synonyms = '';
    if (exists($selected_cols->{'synonyms'})){
        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_synonyms = join ',', @{$accession->synonyms};
    }
    my $acc_pedigree = '';
    if (exists($selected_cols->{'pedigree'})){
        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_pedigree = $accession->get_pedigree_string('Parents');
    }
    my @lines;
    foreach my $s (sort keys %$subplot_plant_names) {
        my $plants = $subplot_plant_names->{$s};
        foreach my $p (sort @$plants){
            my $tissues = $plant_tissue_names->{$p};
            foreach my $t (sort @$tissues){
                my $line;
                foreach my $c (@$possible_cols){
                    if ($selected_cols->{$c}){
                        if ($c eq 'tissue_sample_name'){
                            push @$line, $t;
                        } elsif ($c eq 'tissue_sample_id'){
                            push @$line, $tissue_sample_id_hash{$t};
                        } elsif ($c eq 'plant_name'){
                            push @$line, $p;
                        } elsif ($c eq 'plant_id'){
                            push @$line, $plant_id_hash{$p};
                        } elsif ($c eq 'subplot_name'){
                            push @$line, $s;
                        } elsif ($c eq 'subplot_id'){
                            push @$line, $subplot_id_hash{$s};
                        } elsif ($c eq 'subplot_number'){
                            push @$line, $subplot_index_number_hash{$s};
                        } elsif ($c eq 'plant_number'){
                            push @$line, $plant_index_number_hash{$p};
                        } elsif ($c eq 'tissue_sample_number'){
                            push @$line, $tissue_sample_index_number_hash{$t};
                        } elsif ($c eq 'location_name'){
                            push @$line, $location_name;
                        } elsif ($c eq 'plot_geo_json'){
                            push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
                        } elsif ($c eq 'trial_name'){
                            push @$line, $trial_name;
                        } elsif ($c eq 'year'){
                            push @$line, $trial_year;
                        } elsif ($c eq 'tier'){
                            my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                            my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                            push @$line, $row."/".$col;
                        } elsif ($c eq 'synonyms'){
                            push @$line, $acc_synonyms;
                        } elsif ($c eq 'pedigree'){
                            push @$line, $acc_pedigree;
                        } else {
                            push @$line, $design_info->{$c};
                        }
                    }
                }
                $line = _add_treatment_to_line($treatment_stock_hashes, $line, $t);
                $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
                push @lines, $line;
            }
        }
    }
    return @lines;
}

sub _construct_ouput_for_tissue_samples_with_plants {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;
    my $trial_year = shift;
    my $treatment_stock_hashes = shift;
    my $selected_trait_names = shift;
    my $fieldbook_trait_hash = shift;

    my $plant_tissue_names = $design_info->{'plants_tissue_sample_names'};
    my $plant_names = $design_info->{'plant_names'};
    my $plant_ids = $design_info->{'plant_ids'};
    my $plant_index_numbers = $design_info->{'plant_index_numbers'};
    my $i = 0;
    my %plant_id_hash;
    my %plant_index_number_hash;
    foreach (@$plant_names){
        $plant_id_hash{$_} = $plant_ids->[$i];
        $plant_index_number_hash{$_} = $plant_index_numbers->[$i];
        $i++;
    }
    my $tissue_sample_names = $design_info->{'tissue_sample_names'};
    my $tissue_sample_ids = $design_info->{'tissue_sample_ids'};
    my $tissue_sample_index_numbers = $design_info->{'tissue_sample_index_numbers'};
    my $k = 0;
    my %tissue_sample_id_hash;
    my %tissue_sample_index_number_hash;
    foreach (@$tissue_sample_names){
        $tissue_sample_id_hash{$_} = $tissue_sample_ids->[$k];
        $tissue_sample_index_number_hash{$_} = $tissue_sample_index_numbers->[$k];
        $k++;
    }

    my $acc_synonyms = '';
    if (exists($selected_cols->{'synonyms'})){
        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_synonyms = join ',', @{$accession->synonyms};
    }
    my $acc_pedigree = '';
    if (exists($selected_cols->{'pedigree'})){
        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
        $acc_pedigree = $accession->get_pedigree_string('Parents');
    }
    my @lines;
    foreach my $p (sort keys %$plant_tissue_names) {
        my $tissues = $plant_tissue_names->{$p};
        foreach my $t (sort @$tissues){
            my $line;
            foreach my $c (@$possible_cols){
                if ($selected_cols->{$c}){
                    if ($c eq 'tissue_sample_name'){
                        push @$line, $t;
                    } elsif ($c eq 'tissue_sample_id'){
                        push @$line, $tissue_sample_id_hash{$t};
                    } elsif ($c eq 'plant_name'){
                        push @$line, $p;
                    } elsif ($c eq 'plant_id'){
                        push @$line, $plant_id_hash{$p};
                    } elsif ($c eq 'plant_number'){
                        push @$line, $plant_index_number_hash{$p};
                    } elsif ($c eq 'tissue_sample_number'){
                        push @$line, $tissue_sample_index_number_hash{$t};
                    } elsif ($c eq 'location_name'){
                        push @$line, $location_name;
                    } elsif ($c eq 'plot_geo_json'){
                        push @$line, $design_info->{"plot_geo_json"} ? encode_json $design_info->{"plot_geo_json"} : '';
                    } elsif ($c eq 'trial_name'){
                        push @$line, $trial_name;
                    } elsif ($c eq 'year'){
                        push @$line, $trial_year;
                    } elsif ($c eq 'tier'){
                        my $row = $design_info->{"row_number"} ? $design_info->{"row_number"} : '';
                        my $col = $design_info->{"col_number"} ? $design_info->{"col_number"} : '';
                        push @$line, $row."/".$col;
                    } elsif ($c eq 'synonyms'){
                        push @$line, $acc_synonyms;
                    } elsif ($c eq 'pedigree'){
                        push @$line, $acc_pedigree;
                    } else {
                        push @$line, $design_info->{$c};
                    }
                }
            }
            $line = _add_treatment_to_line($treatment_stock_hashes, $line, $t);
            $line = _add_trait_performance_to_line($selected_trait_names, $line, $fieldbook_trait_hash, $design_info);
            push @lines, $line;
        }
    }
    return @lines;
}

sub _construct_ouput_for_wells_in_plate {
    my $schema = shift;
    my $design_info = shift;
    my $possible_cols = shift;
    my $selected_cols = shift;
    my $location_name = shift;
    my $trial_name = shift;

    my $line;
    foreach (@$possible_cols){
        if ($selected_cols->{$_}){
            if ($_ eq 'trial_name'){
                push @$line, $trial_name;
            } elsif ($_ eq 'tissue_sample_name'){
                push @$line, $design_info->{'plot_name'};
            } elsif ($_ eq 'well_A01'){
                push @$line, $design_info->{'plot_number'};
            } elsif ($_ eq 'exported_tissue_sample_name'){
                push @$line, $design_info->{'plot_name'}.'|||'.$design_info->{'accession_name'};
            } else {
                push @$line, $design_info->{$_};
            }
        }
    }
    return $line;
}

sub _add_treatment_to_line {
    my $treatment_stock_hashes = shift;
    my $line = shift;
    my $design_unit_name = shift;
    foreach (@$treatment_stock_hashes){
        if(exists($_->{$design_unit_name})){
            push @$line, 1;
        } else {
            push @$line, '';
        }
    }
    return $line;
}

sub _add_trait_performance_to_line {
    my $selected_trait_names = shift;
    my $line = shift;
    my $fieldbook_trait_hash = shift;
    my $design_info = shift;
    foreach my $t (@$selected_trait_names){
        my $perf = $fieldbook_trait_hash->{$t}->{$design_info->{"accession_id"}};
        if($perf){
            push @$line, "Avg: ".$perf->[3]." Min: ".$perf->[5]." Max: ".$perf->[4]." Count: ".$perf->[2]." StdDev: ".$perf->[6];
        } else {
            push @$line, '';
        }
    }
    return $line;
}

1;