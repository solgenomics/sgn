=head1 NAME

EditableField.pm -- implements an editable field on an html form.

=head1 DESCRIPTION

Please see L<CXGN::Page::Form> for more information.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;

package CXGN::Page::Form::EditableField;

use CXGN::Page::Form::Field;
use base qw / CXGN::Page::Form::Field /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub render {
    my $self = shift;
    my $id = $self->get_id;
    my $input =  " <input class=\"form-control\" type=\"text\" id=\"" . $self->get_id() . "\" name=\"".$self->get_field_name()."\" value=\"".$self->get_contents()."\" size=\"".$self->get_length()."\"  onclick=\"jqueryStuff()\" />\n";

    return $input;
}


return 1;
