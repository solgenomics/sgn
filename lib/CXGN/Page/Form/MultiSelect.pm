=head1 NAME 

CXGN::Page::Form::MultiSelect;

=head1 DESCRIPTION

Implements a static (non-editable) multiple-selection list on a static form. For more information, see L<CXGN::Page::Form>.

Currently a MultiSelect displays as a multiple-selection drop-down menu. It could also be a series of checkboxes with the same field name; 
implement that yourself if you need it.

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::MultiSelect;

use base qw/ CXGN::Page::Form::ElementI /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:         a hashref with the following keys:
               display_name  (name of the field for display purposes)
               field_name (name of the variable)
					choices (an arrayref of IDs for the strings to be shown)
					labels (an arrayref of strings to be shown)
					contents (an arrayref of values that will be evaluated as Booleans to get the initial selection)
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
	foreach my $param (qw(choices labels))
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
	#render as a comma-separated list of labels
	my @selected_labels = ();
	for(my $i = 0; $i < scalar($self->get_choice_array()); $i++)
	{
		if($self->is_selected($i))
		{
			push @selected_labels, $self->get_label($i);
		}
	}
	return join(", ", @selected_labels);
}

=head2 set_from_external

Args: string with all values for this field separated by \0

=cut

sub set_from_external
{
	my ($self, $value_string) = @_;
	my %values = map {$_ => 1} split(/\0/, $value_string); #map only values that appear to 1
	my @choices = $self->get_choice_array();
	for(my $i = 0; $i < scalar(@choices); $i++)
	{
		if($values{$choices[$i]})
		{
			$self->set_selected($i, 1);
		}
	}
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

=head2 set_choices

Args: arrayref of choices

=cut

sub set_choices
{
	my ($self, $choices) = @_;
	$self->{choices} = $choices;
}

=head2 get_label

Args: label index

=cut

sub get_label
{
	my ($self, $i) = @_;
	return $self->{labels}->[$i];
}

=head2 set_labels

Args: arrayref of labels

=cut

sub set_labels
{
	my ($self, $labels) = @_;
	$self->{labels} = $labels;
}

=head2 is_selected

Args: index to check

=cut

sub is_selected
{
	my ($self, $i) = @_;
	return $self->{contents}->[$i];
}

=head2 set_selected

Args: index, an expression that will be evaluated in Boolean context

=cut

sub set_selected
{
	my ($self, $i, $val) = @_;
	$self->{contents}->[$i] = ($val ? 1 : 0);
}

return 1;
