package CXGN::Trial::TrialLayoutDownload::GenotypingPlateLayout;

=head1 NAME

CXGN::Trial::TrialLayoutDownload::GenotypingPlateLayout - an object to handle downloading a genotyping trial plate layout. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 USAGE

my $plate_layout = CXGN::Trial::TrialLayoutDownload::GenotypingPlateLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => $data_level,
    selected_columns => \%selected_cols,
    design => $design,
    trial => $selected_trial,
});
my $result = $plate_layout->retrieve();

=head1 DESCRIPTION

Will output an array of arrays, where each row is a well tissue sample in the genotyping plate trial. the columns are based on the supplied selected_cols. this should only be called from CXGN::Trial::TrialLayoutDownload

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
    my @possible_cols = ('genotyping_project_name', 'genotyping_facility', 'trial_name', 'acquisition_date', 'exported_tissue_sample_name', 'tissue_sample_name', 'well_A01', 'row_number', 'col_number', 'source_observation_unit_name', 'accession_name', 'accession_id', 'synonyms', 'pedigree', 'dna_person', 'notes', 'tissue_type', 'extraction', 'concentration', 'volume', 'is_blank', 'year', 'location_name', 'facility_identifier');

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
    my $genotyping_facility_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_facility' })->first->cvterm_id();
    my $geno_project_name_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_project_name' })->first->cvterm_id();
    my $genotyping_facility = $schema->resultset("Project::Projectprop")->search({ project_id => $trial->get_trial_id(), type_id => $genotyping_facility_cvterm_id } )->first->value();

    my $genotyping_project_name;
    my $genotyping_project_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_project_and_plate_relationship', 'project_relationship');
    my $project_and_plate_relationship_cvterm_id = $genotyping_project_relationship_cvterm->cvterm_id();
    my $relationships_rs = $schema->resultset("Project::ProjectRelationship")->find ({
        subject_project_id => $self->trial_id(),
        type_id => $project_and_plate_relationship_cvterm_id
    });

    if ($relationships_rs) {
        my $genotyping_project_id = $relationships_rs->object_project_id();
        $genotyping_project_name = $schema->resultset('Project::Project')->find( { project_id => $genotyping_project_id})->name();
    } else {
        $genotyping_project_name = $schema->resultset("NaturalDiversity::NdExperimentProject")->search({
            project_id => $trial->get_trial_id()
        })->search_related('nd_experiment')->search_related('nd_experimentprops',{
            'nd_experimentprops.type_id' => $geno_project_name_cvterm_id
        })->first->value();
    }

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
                } elsif ($_ eq 'location_name'){
                    push @$line, $location_name;
                } elsif ($_ eq 'tissue_sample_name'){
                    push @$line, $design_info->{'plot_name'};
                } elsif ($_ eq 'well_A01'){
                    push @$line, $design_info->{'plot_number'};
                } elsif ($_ eq 'exported_tissue_sample_name'){
                    push @$line, $design_info->{'plot_name'}.'|||'.$design_info->{'accession_name'};
                } elsif ($_ eq 'synonyms'){
                    my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
                    push @$line, join ',', @{$accession->synonyms}
                } elsif ($_ eq 'pedigree'){
                    push @$line, $pedigree_strings->{$design_info->{"accession_name"}};
                } elsif ($_ eq 'genotyping_project_name'){
                    my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
                    push @$line, $accession->get_pedigree_string('Parents');
                } elsif ($_ eq 'pedigree'){
                    my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info->{"accession_id"}});
                    push @$line, $accession->get_pedigree_string('Parents');
                }else {
                    push @$line, $design_info->{$_};
                }
            }
        }
        push @output, $line;
    }

    return \@output;
}

1;
