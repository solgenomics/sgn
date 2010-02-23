


=head1 NAME

CXGN::Cview::Map::SGN::Sequence - a map to display sequence-based maps           
           
=head1 SYNOPSYS

 my $map = CXGN::Cview::Map::SGN::Sequence -> new($dbh, $id);
 my chromosome = $map->get_chromosome(12);

See L<CXGN::Cview::Map> for a full description of the interface.
         
=head1 DESCRIPTION

This map inherits from L<CXGN::Cview::Map::SGN::Genetic>. The only change is that it sets the map units to MB (default is cM).

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 VERSION

1.0
 
=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Map::SGN::Sequence;

use CXGN::Cview::Map::SGN::Genetic;
use base qw | CXGN::Cview::Map::SGN::Genetic | ;

sub new { 
    my $class = shift;
    my $dbh = shift;
    my $id = shift;
    my $self = $class->SUPER::new($dbh, $id);
    $self->set_units("MB");
    return $self;
}

return 1;
