


=head1 NAME
           
           
=head1 SYNOPSYS

         
=head1 DESCRIPTION


=head1 AUTHOR(S)


=head1 VERSION
 

=head1 LICENSE


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
