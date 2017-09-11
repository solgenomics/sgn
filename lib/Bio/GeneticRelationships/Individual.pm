package Bio::GeneticRelationships::Individual;
use strict;
use warnings;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Data::Dumper;

use Bio::GeneticRelationships::Pedigree;

=head1 NAME

Indvidual - An individual organism with genetic relationships to other individuals

=head1 SYNOPSIS

my $variable = Bio::GeneticRelationships::Individual->new();

=head1 DESCRIPTION

This class stores information about an individual organism and its genetic relationships to other individuals.

=head2 Methods

=over

=cut

has 'name' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_name',
    required => 1,
    );

has 'id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_id',
    );

has 'pedigree' => (
    isa =>'Bio::GeneticRelationships::Pedigree',
    is => 'rw',
    predicate => 'has_pedigree',
    );


###
1;#do not remove
###

=pod

=back

=head1 LICENSE

Same as Perl.

=head1 AUTHORS

Jeremy D. Edwards <jde22@cornell.edu>

=cut
