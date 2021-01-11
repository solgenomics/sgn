package CXGN::Trial::TrialLayoutDownload::SamplingTrialLayout;

=head1 NAME

CXGN::Trial::TrialLayoutDownload::SamplingTrialLayout - an object to handle downloading a sampling trial layout. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 USAGE

my $plate_layout = CXGN::Trial::TrialLayoutDownload::SamplingTrialLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => $data_level,
    selected_columns => \%selected_cols,
    design => $design,
    trial => $selected_trial,
});
my $result = $plate_layout->retrieve();

=head1 DESCRIPTION

Will output an array of arrays, where each row is a tissue sample in the sampling trial. the columns are based on the supplied selected_cols. this should only be called from CXGN::Trial::TrialLayoutDownload

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

extends 'CXGN::Trial::TrialLayoutDownload';

sub retrieve {
    my $self = shift;
    my $schema = $self->schema();
    my %selected_cols = %{$self->selected_columns};
    my %design = %{$self->design};
    my $trial = $self->trial;
    my @output;

    my @possible_cols = ('trial_name', 'year', 'location', 'sampling_facility', 'sampling_trial_sample_type', 'acquisition_date', 'tissue_sample_name', 'plot_number', 'rep_number', 'source_observation_unit_name', 'accession_name', 'synonyms', 'dna_person', 'notes', 'tissue_type', 'extraction', 'concentration', 'volume');

    my @header;
    foreach (@possible_cols){
        if ($selected_cols{$_}){
            push @header, $_;
        }
    }
    push @output, \@header;

    my $trial_name = $trial->get_name ? $trial->get_name : '';
    my $location_name = $trial->get_location ? $trial->get_location->[1] : '';
    my $trial_year = $trial->get_year ? $trial->get_year : '';
    my $sampling_facility_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sampling_facility', 'project_property')->cvterm_id();
    my $sampling_trial_sample_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sampling_trial_sample_type', 'project_property')->cvterm_id();
    my $sampling_facility = $schema->resultset("Project::Projectprop")->search({ project_id => $trial->get_trial_id(), type_id => $sampling_facility_cvterm_id } )->first->value();
    my $sampling_type = $schema->resultset("Project::Projectprop")->search({ project_id => $trial->get_trial_id(), type_id => $sampling_trial_sample_type_cvterm_id } )->first->value();

    my $pedigree_strings = $self->_get_all_pedigrees(\%design);

    foreach my $key (sort { $a cmp $b} keys %design) {
        my $design_info = $design{$key};
        my $line;
        foreach (@possible_cols){
            if ($selected_cols{$_}){
                if ($_ eq 'trial_name'){
                    push @$line, $trial_name;
                } elsif ($_ eq 'year'){
                    push @$line, $trial_year;
                } elsif ($_ eq 'location'){
                    push @$line, $location_name;
                } elsif ($_ eq 'sampling_facility'){
                    push @$line, $sampling_facility;
                } elsif ($_ eq 'sampling_trial_sample_type'){
                    push @$line, $sampling_type;
                } elsif ($_ eq 'tissue_sample_name'){
                    push @$line, $design_info->{'plot_name'};
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
        push @output, $line;
    }

    return \@output;
}

1;
