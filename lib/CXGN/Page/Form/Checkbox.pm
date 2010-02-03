=head1 NAME 

CXGN::Page::Form::Checkbox - a class to represent checkboxes on CXGN::Page::Form forms.

=head1 DESCRIPTION

For more information about the form framework see L<CXGN::Page::Form>. The checkbox form element consists of two classes, CXGN::Page::Form::Checkbox, which inherits from L<CXGN::Page::Form::ElementI> and represents a static (or non-editable) checkbox, and CXGN::Page::Form::EditableCheckbox , which inherits from L<CXGN::Page::Form::Checkbox> and is used on editable forms. These classes were introduced by Evan, but re-factored somewhat by Lukas. Evan introduced an additional property for the Checkbox classes, called "selected" (with accessors get_selected and set_selected). This was refactored into using the content property, which is used by all other ElementI classes to keep track of there status. If this property is set to true, the checkbox is checked; if it is false, it is unchecked. Thus, this class is perfectly compatible with all the other code that deals with ElementI, and the additional function, set_from_external(), is not strictly necessary (although it may be useful in the future for more complex user interface elements).

=head1 AUTHOR(S)

Evan Herbst

=head1 FUNCTIONS

This class overrides the following functions:

=cut

use strict;

package CXGN::Page::Form::Checkbox;

use base qw/ CXGN::Page::Form::ElementI /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:         a hashref with the following keys:
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
    my %params = @_;
    $self->set_selected($params{selected});
    return $self;
}

=head2 render()

renders the checkbox as a static element.

=cut

sub render { 
    my $self = shift;
   
    return $self->get_contents() ? "(yes)" : "(no)";
}

=head2 set_from_external

Override ElementI. This is somewhat deprecated.

=cut

# sub set_from_external
# {
# 	my ($self, $value) = @_;
# 	#contents should have been set in the constructor; expect value to either equal contents or be empty (as in a request string)
	
# #	$self->set_selected(($value eq $self->get_contents()) ? 1 : 0);
# 	 if (($value =~ /on|t|1/i)) { 
# # 	    $self->set_selected(1); # set selected is deprecated
#  	    $self->set_contents(1);
#  	}
#  	if ($value =~ /f|0/i || !defined($value)) { 
#  	    #$self->set_selected(0); #set selected is deprecated
#  	    $self->set_contents(0);
#  	}

# }

return 1;
