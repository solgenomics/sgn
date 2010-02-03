
=head1 NAME

EditableHidden.pm

=head1 DESCRIPTION

Deals with the representation of hidden fields on editable forms. The hidden field itself is of course not editable -- the editable in the name just means that it will be rendered on an editable form. 

For more information, see L<CXGN::Page::Form>.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=head1 FUNCTIONS

The following functions are overridden from the parent class CXGN::Page::Form::Hidden which itself implements the CXGN::Page::Form::ElementI interface.

=cut

use strict;
use CXGN::Page::Form::Hidden;

package CXGN::Page::Form::EditableHidden;

use base qw / CXGN::Page::Form::Hidden /;

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
    
	 my $id = $self->get_id();
    my $name = $self->get_field_name();
    my $value = $self->get_contents();

    my $s = qq { <input type="hidden" id="$id" name="$name" value="$value" /> };
    return $s;

}

return 1;
