package CXGN::Phenotypes::StorePhenotypes;

=head1 NAME

CXGN::Phenotypes::StorePhenotypes - an object to handle storing phenotypes for SGN stocks

=head1 USAGE

 my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({ schema => $schema} );

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

has 'schema' => (
		 is  => 'rw',
		 isa =>  'DBIx::Class::Schema',
		 required => 1,
		);

has 'stock_list' => (isa => 'ArrayRef', is => 'ro',);

has 'trait_list' => (isa => 'HashRef', is => 'ro',);


sub verify {
  my $self = shift;
  my $schema = $self->schema;
}

sub _verify_plots {
}

sub _verify_traits {
}

sub _verify_trait_values {
}

sub commit {

}

###
1;
###
