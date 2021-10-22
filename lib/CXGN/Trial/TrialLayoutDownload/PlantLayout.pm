package CXGN::Trial::TrialLayoutDownload::PlantLayout;

=head1 NAME

CXGN::Trial::TrialLayoutDownload::PlantLayout - an object to handle downloading a plant level trial layout. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 USAGE

my $trial_plant_layout = CXGN::Trial::TrialLayoutDownload::PlantLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => $data_level,
    selected_columns => \%selected_cols,
    selected_trait_ids => \@selected_traits,
    treatment_project_ids => $treatments,
    design => $design,
    trial => $selected_trial,
    treatment_info_hash => \%treatment_info_hash,
    overall_performance_hash => \%fieldbook_trait_hash,
    all_stats => $all_stats,
});
my $result = $trial_plant_layout->retrieve();

=head1 DESCRIPTION

Will output an array of arrays, where each row is a plant in the trial. the columns are based on the supplied selected_cols and the columns will include any treatments (management factors) that are part of the trial. additionally, trait performance can be included in column using the overall_performance_hash. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Accession;
use JSON;

extends 'CXGN::Trial::TrialLayoutDownload';

sub retrieve {
    my $self = shift;
    my $schema = $self->schema();
    my %selected_cols = %{$self->selected_columns};
    my %design = %{$self->design};
    my $trial = $self->trial;
    my $treatment_info_hash = $self->treatment_info_hash || {};
    my $treatment_list = $treatment_info_hash->{treatment_trial_list} || [];
    my $treatment_name_list = $treatment_info_hash->{treatment_trial_names_list} || [];
    my $treatment_units_hash_list = $treatment_info_hash->{treatment_units_hash_list} || [];
    my $trait_header = $self->trait_header || [];
    my $exact_performance_hash = $self->exact_performance_hash || {};
    my $overall_performance_hash = $self->overall_performance_hash || {};
    my $all_stats = $self->all_stats;
    my @output;
    my $trial_stock_type = $self->trial_stock_type();

    my @possible_cols = ('plant_name','plant_id','subplot_name','subplot_id','plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');

    my @header;
    foreach (@possible_cols){
        if ($selected_cols{$_}){
            if (($_ eq 'accession_name') && ($trial_stock_type eq 'family_name')) {
                push @header, 'family_name';
            } elsif (($_ eq 'accession_name') && ($trial_stock_type eq 'cross')) {
                push @header, 'cross_unique_id';
            } else {
                push @header, $_;
            }
        }
    }

    foreach (@$treatment_name_list){
        push @header, "ManagementFactor:".$_;
    }
    foreach (@$trait_header){
        push @header, $_;
    }

    push @output, \@header;

    my $trial_name = $trial->get_name ? $trial->get_name : '';
    my $location_name = $trial->get_location ? $trial->get_location->[1] : '';
    my $trial_year = $trial->get_year ? $trial->get_year : '';
    my $pedigree_strings = $self->_get_all_pedigrees(\%design);

    #Turn plot level design into a plant level design that can be sorted on plot_number and then plant index number..
    my @plant_design;
    while (my($plot_number, $design_info) = each %design){
        my $acc_synonyms = '';
        if (exists($selected_cols{'synonyms'})){
            my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
            $acc_synonyms = join ',', @{$accession->synonyms};
        }
        my $acc_pedigree = '';
        if (exists($selected_cols{'pedigree'})){
            $acc_pedigree = $pedigree_strings->{$design_info->{"accession_name"}};
        }
        $design_info->{synonyms} = $acc_synonyms;
        $design_info->{pedigree} = $acc_pedigree;

        my $subplot_plant_names = $design_info->{'subplots_plant_names'};
        my $subplot_names = $design_info->{'subplot_names'};
        my $subplot_ids = $design_info->{'subplot_ids'};
        my $subplot_index_numbers = $design_info->{'subplot_index_numbers'};
        my $j = 0;
        my %plant_subplot_hash;
        foreach my $subplot_name (@$subplot_names){
            my $plant_names = $subplot_plant_names->{$subplot_name};
            foreach my $plant_name (@$plant_names){
                $plant_subplot_hash{$plant_name}->{subplot_id} = $subplot_ids->[$j];
                $plant_subplot_hash{$plant_name}->{subplot_number} = $subplot_index_numbers->[$j];
                $plant_subplot_hash{$plant_name}->{subplot_name} = $subplot_name;
            }
            $j++;
        }

        my $plant_names = $design_info->{'plant_names'};
        my $plant_ids = $design_info->{'plant_ids'};
        my $plant_index_numbers = $design_info->{'plant_index_numbers'};
        my $i = 0;
        foreach my $plant_name (@$plant_names){
            my %plant_design = %$design_info;
            $plant_design{plant_name} = $plant_name;
            $plant_design{plant_id} = $plant_ids->[$i];
            $plant_design{plant_number} = $plant_index_numbers->[$i];
            $plant_design{subplot_name} = $plant_subplot_hash{$plant_name}->{subplot_name};
            $plant_design{subplot_id} = $plant_subplot_hash{$plant_name}->{subplot_id};
            $plant_design{subplot_number} = $plant_subplot_hash{$plant_name}->{subplot_number};
            push @plant_design, \%plant_design;
            $i++;
        }
    }
    #print STDERR Dumper \@plant_design;

    my @overall_trait_names = sort keys %$overall_performance_hash;
    my @exact_trait_names = sort keys %$exact_performance_hash;

    no warnings 'uninitialized';
    @plant_design = sort { $a->{plot_number} <=> $b->{plot_number} || $a->{subplot_number} <=> $b->{subplot_number} || $a->{plant_number} <=> $b->{plant_number} } @plant_design;

    foreach my $design_info (@plant_design) {
        my $line;
        foreach my $c (@possible_cols){
            if ($selected_cols{$c}){
                if ($c eq 'location_name'){
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
                } else {
                    push @$line, $design_info->{$c};
                }
            }
        }
        $line = $self->_add_treatment_to_line($treatment_units_hash_list, $line, $design_info->{plant_name});
        $line = $self->_add_exact_performance_to_line(\@exact_trait_names, $line, $exact_performance_hash, $design_info->{plant_name});
        $line = $self->_add_overall_performance_to_line(\@overall_trait_names, $line, $overall_performance_hash, $design_info, $all_stats);
        push @output, $line;
    }

    return \@output;
}

1;
