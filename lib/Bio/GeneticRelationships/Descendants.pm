package Bio::GeneticRelationships::Descendants;
use strict;
use warnings;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Bio::GeneticRelationships::Individual;

=head1 NAME

    Bio::GeneticRelationships::Descendants - Descendants of an individual

=head1 SYNOPSIS

    my $variable = Bio::GeneticRelationships::Descendants->new();

=head1 DESCRIPTION

    This class stores an individual's descendants and their relationships.

=head2 Methods

=over

=cut




has 'name' => (isa => 'Str',is => 'rw', predicate => 'has_name', required => 1,);
has 'offspring' => (isa => 'ArrayRef[Bio::GeneticRelationships::Individual]', is => 'rw', predicate => 'has_offspring');


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
