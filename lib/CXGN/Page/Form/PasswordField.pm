=head1 NAME 

CXGN::Page::Form::PasswordField;

=head1 DESCRIPTION

Implements a static (non-editable) password field on a static form. For more information, see L<CXGN::Page::Form>.

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::PasswordField;

use base qw/ CXGN::Page::Form::ElementI /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:         a hashref with the following keys:
               display_name  (name of the field for display purposes)
               field_name (name of the form element)
               contents (the current value of the field)
               length (the length of the input field in characters)
               object (the object this field maps to)
               getter (the getter function for this field in the object)
               setter (the setter function for this field in the object)
 Side Effects:
 Example:

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

=head2 render

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub render { 
    my $self = shift;
   
    return ('*' x length($self->get_contents())) . "\n";
}

return 1;
