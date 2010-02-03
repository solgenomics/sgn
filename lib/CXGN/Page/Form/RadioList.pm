=head1 NAME 

CXGN::Page::Form::RadioList;

=head1 DESCRIPTION

Implements a static (non-editable) list of radio buttons on a static form. For more information, see L<CXGN::Page::Form>.

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::RadioList;

use base qw/ CXGN::Page::Form::ElementI /;

=head2 new

 Usage:        don't currently make use of the 'id' parameter, unlike other form fields
 Desc:
 Ret:
 Args:         a hashref with the following keys:
               display_name  (name of the field for display purposes)
               field_name (name of the variable)
					id_prefix (a string to be prepended to the choices to get radio-button element IDs)
					choices (a listref of values for the buttons to be shown)
					labels (a listref of labels for the buttons to be shown)
               contents (the current value of the field; can be empty)
               object (the object this field maps to)
               getter (the getter function for this field in the object)
               setter (the setter function for this field in the object)
 Side Effects:
 Example:

=cut

sub new
{
	my $class = shift;
	my %params = @_;
	my $self = $class->SUPER::new(%params);
	#store the parameters that aren't handled by our superclass
	foreach my $param (qw(choices labels id_prefix))
	{
		my $set_func = "set_$param";
		$self->$set_func($params{$param});
	}
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

sub render
{
	my $self = shift;
	my $html = "<ul>";
	for(my $i = 0; $i < scalar($self->get_choice_array()); $i++)
	{
		if($self->get_contents() eq $self->get_choice($i))
		{
			$html .= "<li> &raquo;&nbsp;" . $self->get_label($i) . "&nbsp;&laquo; </li>";
		}
		else
		{
			$html .= "<li>" . $self->get_label($i) . "</li>";
		}
	}
	return $html . "</ul>";
}

=head2 get_id_prefix

=cut

sub get_id_prefix
{
	my $self = shift;
	return $self->{id_prefix};
}

=head2 get_choice

Args: choice index

=cut

sub get_choice
{
	my ($self, $i) = @_;
	return $self->{choices}->[$i];
}

=head2 get_choice_array

Ret: array (not arrayref) of choices

=cut

sub get_choice_array
{
	my $self = shift;
	return @{$self->{choices}};
}

=head2 get_label

Args: label index

=cut

sub get_label
{
	my ($self, $i) = @_;
	return $self->{labels}->[$i];
}

=head2 set_id_prefix

Args: string

=cut

sub set_id_prefix
{
	my ($self, $prefix) = @_;
	$self->{id_prefix} = $prefix;
}

=head2 set_choices

Args: arrayref of choices

=cut

sub set_choices
{
	my ($self, $choices) = @_;
	$self->{choices} = $choices;
}

=head2 set_labels

Args: arrayref of labels

=cut

sub set_labels
{
	my ($self, $labels) = @_;
	$self->{labels} = $labels;
}

return 1;
