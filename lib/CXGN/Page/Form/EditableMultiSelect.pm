=head1 NAME 

CXGN::Page::Form::MultiSelect;

=head1 DESCRIPTION

Implements a static (non-editable) multiple-selection list on a static form. For more information, see L<CXGN::Page::Form>.

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;
use CXGN::Page::Form::MultiSelect;

package CXGN::Page::Form::EditableMultiSelect;

use base qw/ CXGN::Page::Form::MultiSelect /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub new
{
	my $class = shift;
	my %params = @_;
	my $self = $class->SUPER::new(%params);
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
	my $html = "<select class=\"form-control\" id=\"" . $self->get_id() . "\" name=\"" . $self->get_field_name() . "\" multiple=\"multiple\">";
	for(my $i = 0; $i < scalar($self->get_choice_array()); $i++)
	{
		if($self->is_selected($i))
		{
			$html .= "<option value=\"" . $self->get_choice($i) . "\" selected=\"selected\">" . $self->get_label($i) . "</option>";
		}
		else
		{
			$html .= "<option value=\"" . $self->get_choice($i) . "\">" . $self->get_label($i) . "</option>";
		}
	}
	return $html . "</select>";
}

return 1;
