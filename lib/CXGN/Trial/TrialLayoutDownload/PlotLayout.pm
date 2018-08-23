package CXGN::Trial::TrialLayoutDownload::PlotLayout;

=head1 NAME

CXGN::Trial::TrialLayoutDownload::PlotLayout - an object to handle downloading a plot level trial layout. this should only be called from CXGN::Trial::TrialLayoutDownload

=head1 USAGE

my $trial_plot_layout = CXGN::Trial::TrialLayoutDownload::PlotLayout->new({
    bcs_schema=>$schema,
    treatment_trial_list=>\@treatment_trials,
});
my $result = $trial_plot_layout->retrieve();

=head1 DESCRIPTION

Will output an array of arrays, where each row is a plot in the trial. the columns are based on the supplied selected_cols and the columns will include any treatments (management factors) that are part of the trial.

=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'selected_cols' => (
    isa => 'HashRef[Str]',
    is => 'rw',
    required => 1
);

#This treatment_info_hash contains all the info needed to make and fill the columns for the various treatments (management factors). All of these lists are in the same order.
#A key called treatment_trial_list that is a arrayref of the CXGN::Trial entries that represent the treatments (management factors) in this trial
#A key called treatment_trial_names_list that is an arrayref of just the treatment (management factor) names
#A key called treatment_units_hash_list that is a arrayref of hashrefs where the hashrefs indicate the stocks that the treatment was applied to.
has 'treatment_info_hash' => (
    isa => 'HashRef',
    is => 'rw',
);

sub retrieve {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my %selected_cols = %{$self->selected_cols};

    my @possible_cols = ('plot_name','plot_id','accession_name','accession_id','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');


    my @header;
    foreach (@possible_cols){
        if ($selected_cols{$_}){
            push @header, $_;
        }
    }
    foreach (@treatment_names){
        push @header, "ManagementFactor:".$_;
    }
    foreach (@selected_trait_names){
        push @header, $_;
    }
    push @output, \@header;

}

1;
