package CXGN::Phenotypes::CreateSpreadsheet;

=head1 NAME

CXGN::Phenotypes::CreateSpreadsheet - an object to create a spreadsheet for collecting phenotypes

=head1 USAGE

 my $phenotype_spreadsheet = CXGN::Phenotypes::CreateSpreadsheet->new();
 $create_spreadsheet->create($c,$trial_id, \@trait_list, \%spreadsheet_metadata);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial::TrialLayout;

sub _verify {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $trait_list_ref = shift;
    my $spreadsheet_metadata_ref = shift;
    return 1;
}


sub create {
    my $self = shift;
    my $c = shift;
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $trait_list_ref = shift;
    my $spreadsheet_metadata_ref = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );

    my %design = %{$trial_layout->get_design()};
    my @plot_names = @{$trial_layout->get_plot_names};

    foreach my $key (sort { $a <=> $b} keys %design) {
      my %design_info = %{$design{$key}};
      my $plot_name = $design_info{'plot_name'];
      my $block_number = $design_info{'block_number'];
      my $rep_number = $design_info{'rep_number'];

    }



    return 1;
}



###
1;
###
