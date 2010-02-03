=head1 NAME 

CXGN::Page::Form::RadioList;

=head1 DESCRIPTION

Implements a static (non-editable) list of radio buttons on a static form. For more information, see L<CXGN::Page::Form>.

=head1 AUTHOR(S)

Evan Herbst

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::EditableRadioList;

use base qw/ CXGN::Page::Form::RadioList /;

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
	my $html = '';
	for(my $i = 0; $i < scalar($self->get_choice_array()); $i++)
	{
		$html .= "<br />" if $i > 0;
		$html .= "<input type=\"radio\" id=\"" . $self->get_id_prefix() . $self->get_choice($i) . "\" name=\"" . $self->get_field_name() . "\" value=\"" . $self->get_choice($i) . "\" ";
		#an XHTML note: most of the time, non-valued attributes like CHECKED need to be given as CHECKED="CHECKED"; apparently not for radio buttons -- Evan, 1 / 11 / 07
		$html .= "checked " if $self->get_contents() eq $self->get_choice($i);
		$html .= "/>" . $self->get_label($i);
	}
	return $html;
}

return 1;
