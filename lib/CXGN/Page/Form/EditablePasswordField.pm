=head1 NAME

EditablePasswordField.pm -- implements an editable password field on a html form.

=head1 DESCRIPTION

Please see L<CXGN::Page::Form> for more information.

=head1 AUTHOR(S)

Evan Herbst

=cut


use strict;
use CXGN::Page::Form::PasswordField;


package CXGN::Page::Form::EditablePasswordField;

use base qw / CXGN::Page::Form::PasswordField /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub render { 
    my $self = shift;
    
    return " <input type=\"password\" class=\"form-control\" id=\"" . $self->get_id() . "\" name=\"".$self->get_field_name()."\" value=\"".$self->get_contents()."\" size=\"".$self->get_length()."\" />\n";
}


return 1;
