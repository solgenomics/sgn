package CXGN::Trial::TrialLayoutDownload::PlotLayout;

=head1 NAME

CXGN::Trial::TrialLayoutDownload::PlotLayout - an object to handle downloading a plot level trial layout. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 USAGE

my $trial_plot_layout = CXGN::Trial::TrialLayoutDownload::PlotLayout->new({
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
my $result = $trial_plot_layout->retrieve();

=head1 DESCRIPTION

Will output an array of arrays, where each row is a plot in the trial. the columns are based on the supplied selected_cols and the columns will include any treatments (management factors) that are part of the trial. additionally, trait performance can be included in column using the overall_performance_hash. this should only be called from CXGN::Trial::TrialLayoutDownload

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

    my @possible_cols = ('plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');

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

    my @plot_design = values %design;
    @plot_design = sort { $a->{plot_number} <=> $b->{plot_number} } @plot_design;
    my $pedigree_strings = $self->_get_all_pedigrees(\%design);

    my @overall_trait_names = sort keys %$overall_performance_hash;
    my @exact_trait_names = sort keys %$exact_performance_hash;

    foreach my $design_info (@plot_design) {
        my $line;
        foreach (@possible_cols){
            if ($selected_cols{$_}){
                #print STDERR "Working on column $_\n";
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
                    push @$line, $pedigree_strings->{$design_info->{"accession_name"}};
                } else {
                    push @$line, $design_info->{$_};
                }
            }
        }

        #print STDERR "Adding treatment and trait performance\n";

        $line = $self->_add_treatment_to_line($treatment_units_hash_list, $line, $design_info->{'plot_name'});
        $line = $self->_add_exact_performance_to_line(\@exact_trait_names, $line, $exact_performance_hash, $design_info->{'plot_name'});
        $line = $self->_add_overall_performance_to_line(\@overall_trait_names, $line, $overall_performance_hash, $design_info, $all_stats);
        push @output, $line;
    }

    return \@output;
}

1;
