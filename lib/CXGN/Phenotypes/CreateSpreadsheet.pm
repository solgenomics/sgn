package CXGN::Phenotypes::CreateSpreadsheet;

=head1 NAME

CXGN::Phenotypes::CreateSpreadsheet - an object to create a spreadsheet for collecting phenotypes

=head1 USAGE

 my $phenotype_spreadsheet = CXGN::Phenotypes::CreateSpreadsheet->new({schema => $schema, trial_id => $trial_id, trait_list => \$trait_list} );
 $create_spreadsheet->create();

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial::TrialLayout;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 required => 1,
		);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', required => 1);
has 'trait_list' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_trait_list', required => 1);
has 'filename' => (isa => 'Str', is => 'ro',
		   predicate => 'has_filename',
		   reader => 'get_filename',
		   writer => '_set_filename',
		  );
has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');


sub _verify {
    my $self = shift;

    my $trial_id = $self->get_trial_id();
    my @trait_list = @{$self->get_trait_list()};

    return 1;
}


sub create {
    my $self = shift;
    my $schema = $self->get_schema();
    my $trial_id = $self->get_trial_id();
    my @trait_list = @{$self->get_trait_list()};
    my $spreadsheet_metadata = $self->get_file_metadata();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    my %design = %{$trial_layout->get_design()};
    my @plot_names = @{$trial_layout->get_plot_names};

    foreach my $key (sort { $a <=> $b} keys %design) {
      my %design_info = %{$design{$key}};
      my $plot_name = $design_info{'plot_name'};
      my $block_number = $design_info{'block_number'};
      my $rep_number = $design_info{'rep_number'};
      print STDERR "spreadsheet row:  $plot_name $block_number $rep_number\n";
    }

    return 1;
}



###
1;
###
