
use strict;
use CXGN::Page::Form::ElementI;


package CXGN::Page::Form::Hidden;

use base qw / CXGN::Page::Form::ElementI /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    return $self;
}

sub render { 
    my $self = shift;
    return;
    #return "HIDDEN!\n";
    # hidden fields do not render at all in
    # the non editable version. That was easy!
    #
}

return 1;
