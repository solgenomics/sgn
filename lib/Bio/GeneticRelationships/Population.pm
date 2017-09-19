
=head1 NAME

Bio::GeneticRelationships::Population - a class to represent parent relationships with populations, such as open pollinated and polycross crosses

=head1 AUTHORS

    Lukas Mueller <lam87@cornell.edu>
    Guillaume Bauchet <gjb99@cornell.edu>

=cut

package Bio::GeneticRelationships::Population;

use Moose;

extends 'Bio::GeneticRelationships::Individual';

has 'members' => (
    isa => 'ArrayRef',
    is => 'rw',
    );

1;
