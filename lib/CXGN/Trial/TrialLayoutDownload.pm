package CXGN::Trial::TrialLayoutDownload;

=head1 NAME

CXGN::Trial::TrialLayoutDownload

=head1 SYNOPSIS

Module to format layout info for trial based on which columns user wants to see. Selected columns can be:
- for plot level layout: 'plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json'
- for plant level layout: 'plant_name','plant_id','subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json'
- for subplot level layout:
'subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json'
- for tissue sample field trial level layout:
'tissue_sample_name','tissue_sample_id','plant_name','plant_id','subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','tissue_sample_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json'

This module can also optionally include treatments into the output.
This module can also optionally include accession trait performace summaries into the output.

This module is used from CXGN::Trial::Download::Plugin::TrialLayoutExcel, CXGN::Trial::Download::Plugin::TrialLayoutCSV, CXGN::Fieldbook::DownloadTrial, CXGN::Trial->get_plots, CXGN::Trial->get_plants, CXGN::Trial->get_subplots, CXGN::Trial->get_tissue_samples

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plots',
    treatment_project_ids => [1,2],
    selected_columns => {"plot_name"=>1,"plot_number"=>1,"block_number"=>1},
    selected_trait_ids => [1,2,3],
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
use CXGN::Trial::TrialLayoutDownload::PlotLayout;
use CXGN::Trial::TrialLayoutDownload::PlantLayout;
use CXGN::Trial::TrialLayoutDownload::SubplotLayout;
use CXGN::Trial::TrialLayoutDownload::TissueSampleLayout;
use CXGN::Trial::TrialLayoutDownload::GenotypingPlateLayout;

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

#The attributes below are populated when get_layout_output is run, so should not be instantiatied
#----------------------

#This is a hashref of the cached trial_layout_json that comes from CXGN::Trial::TrialLayout
has 'design' => (
    isa => 'HashRef',
    is => 'rw',
);

subtype 'Trial',
  as 'Ref',
    where { $_ =~ /CXGN::Trial/ || $_ =~ /CXGN::PhenotypingTrial/ || $_ =~  /CXGN::GenotypingTrial/ || $_ =~ /CXGN::Folder/ || $_ =~ /CXGN::CrossingTrial/ },
  message { "The string, $_, was not a valid trial object type"};



has 'trial' => (
    isa => 'Trial',
    is => 'rw',
);

#This treatment_info_hash contains all the info needed to make and fill the columns for the various treatments (management factors). All of these lists are in the same order.
#A key called treatment_trial_list that is a arrayref of the CXGN::Trial entries that represent the treatments (management factors) in this trial
#A key called treatment_trial_names_list that is an arrayref of just the treatment (management factor) names
#A key called treatment_units_hash_list that is a arrayref of hashrefs where the hashrefs indicate the stocks that the treatment was applied to.
has 'treatment_info_hash' => (
    isa => 'HashRef',
    is => 'rw',
);

#This phenotype_performance_hash is a hashref of hashref where the top key is the trait name, subsequent key is the stock id, and subsequent object contains mean, mix, max, stdev, count, etc for that trait and stock
has 'phenotype_performance_hash' => (
    isa => 'HashRef',
    is => 'rw',
);

sub get_layout_output { 
    my $self = shift;
    my $trial_id = $self->trial_id();
    my $schema = $self->schema();
    my $data_level = $self->data_level();
    my %selected_cols = %{$self->selected_columns};
    my $treatments = $self->treatment_project_ids();
    my @selected_traits = $self->selected_trait_ids() ? @{$self->selected_trait_ids} : ();
    my %errors;
    my @error_messages;

    print STDERR "TrialLayoutDownload for Trial id: ($trial_id) ".localtime()."\n";

    my $trial_layout;
    try {
        my %param = ( schema => $schema, trial_id => $trial_id );
        if ($data_level eq 'plate'){
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
    my $design = $trial_layout->get_design();
    if (!$design){
        push @error_messages, "Trial does not have valid field design. Please contact us.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }
    #print STDERR Dumper $design;

    if ($data_level eq 'plot_fieldMap' ) {
        my %hash;
        my @rows;
        my @cols;
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

    my $selected_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
    my $has_plants = $selected_trial->has_plant_entries();
    my $has_subplots = $selected_trial->has_subplot_entries();
    my $has_tissue_samples = $selected_trial->has_tissue_sample_entries();

    my $accessions = $selected_trial->get_accessions();
    my @accession_ids;
    foreach (@$accessions){
        push @accession_ids, $_->{stock_id};
    }

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

    if ($data_level eq 'plots') {
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_observation_units_direct('plot', ['treatment_experiment']) : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($data_level eq 'plants') {
        if (!$has_plants){
            push @error_messages, "Trial does not have plants, so you should not try to download a plant level layout.";
            $errors{'error_messages'} = \@error_messages;
            return \%errors;
        }
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_observation_units_direct('plant', ['treatment_experiment']) : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($data_level eq 'subplots') {
        if (!$has_subplots){
            push @error_messages, "Trial does not have subplots, so you should not try to download a subplot level layout.";
            $errors{'error_messages'} = \@error_messages;
            return \%errors;
        }
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_observation_units_direct('subplot', ['treatment_experiment']) : [];
            print STDERR Dumper $treatment_units;
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($data_level eq 'field_trial_tissue_samples') {
        if (!$has_tissue_samples){
            push @error_messages, "Trial does not have tissue samples, so you should not try to download a tissue sample level layout.";
            $errors{'error_messages'} = \@error_messages;
            return \%errors;
        }
        foreach (@treatment_trials){
            my $treatment_units = $_ ? $_->get_observation_units_direct('tissue_sample', ['treatment_experiment']) : [];
            push @treatment_units_array, $treatment_units;
        }
    } elsif ($data_level eq 'plate') {
        #to make the download in the header for genotyping trials more easily understood, the terms change here
        if (exists($selected_cols{'plot_name'})){
            $selected_cols{'tissue_sample_name'} = 1;
            delete $selected_cols{'plot_name'};
        }
        if (exists($selected_cols{'plot_number'})){
            $selected_cols{'well_A01'} = 1;
            delete $selected_cols{'plot_number'};
        }
        $selected_cols{'exported_tissue_sample_name'} = 1;
    }

    my @treatment_stock_hashes;
    foreach my $u (@treatment_units_array){
        my %treatment_stock_hash;
        foreach (@$u){
            $treatment_stock_hash{$_->[1]}++;
        }
        push @treatment_stock_hashes, \%treatment_stock_hash;
    }

    my %treatment_info_hash = (
        treatment_trial_list => \@treatment_trials,
        treatment_trial_names_list => \@treatment_names,
        treatment_units_hash_list => \@treatment_stock_hashes
    );

    my $layout_build = {
        schema => $schema,
        trial_id => $trial_id,
        data_level => $data_level,
        selected_columns => \%selected_cols,
        selected_trait_ids => \@selected_traits,
        treatment_project_ids => $treatments,
        design => $design,
        trial => $selected_trial,
        treatment_info_hash => \%treatment_info_hash,
        phenotype_performance_hash => \%fieldbook_trait_hash
    };
    my $layout_output;
    if ($data_level eq 'plots' ) {
        $layout_output = CXGN::Trial::TrialLayoutDownload::PlotLayout->new($layout_build);
    }
    if ($data_level eq 'plants' ) {
        $layout_output = CXGN::Trial::TrialLayoutDownload::PlantLayout->new($layout_build);
    }
    if ($data_level eq 'subplots' ) {
        $layout_output = CXGN::Trial::TrialLayoutDownload::SubplotLayout->new($layout_build);
    }
    if ($data_level eq 'field_trial_tissue_samples' ) {
        $layout_output = CXGN::Trial::TrialLayoutDownload::TissueSampleLayout->new($layout_build);
    }
    if ($data_level eq 'plate' ) {
        $layout_output = CXGN::Trial::TrialLayoutDownload::GenotypingPlateLayout->new($layout_build);
    }
    my $output = $layout_output->retrieve();
    #print STDERR Dumper $output;

    print STDERR "TrialLayoutDownload End for Trial id: ($trial_id) ".localtime()."\n";
    return {output => $output};
}

sub _add_treatment_to_line {
    my $self = shift;
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
    my $self = shift;
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
