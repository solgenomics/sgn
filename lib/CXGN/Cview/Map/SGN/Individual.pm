
=head1 NAME

CXGN::Cview::Map::SGN::Individual - a map object that represents the genetic composition of an individual accession

=head1 DESCRIPTION

Inhertis from CXGN::Cview::Map

=head1 AUTHORS

Lukas Mueller

=cut

use strict;
use warnings;

package CXGN::Cview::Map::SGN::Individual;

use base 'CXGN::Cview::Map';

sub new { 
    my $class = shift;
    my $dbh = shift;
    my $individual_id=shift;

    my $self = $class->SUPER::new($dbh);

    return $self;
}

1;
 
