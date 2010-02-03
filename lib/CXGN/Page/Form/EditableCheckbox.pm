=head1 NAME 

CXGN::Page::Form::EditableCheckbox;

=head1 DESCRIPTION

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;

package CXGN::Page::Form::EditableCheckbox;

use base qw/ CXGN::Page::Form::Checkbox /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:	a hashref with the following keys:
			display_name  (name of the field for display purposes)
			field_name (name of the form element)
			contents (the value used when the checkbox is selected)
			selected (whether checked; this field is evaluated in Boolean context)
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

sub render { 
    my $self = shift;
    my $selected = "";
    if ($self->get_contents()) { $selected = "checked=\"checked\""; }
    return "<input type=\"checkbox\" id=\"" . $self->get_id() . "\" name=\"" . $self->get_field_name()."\" $selected />\n";
}

return 1;
