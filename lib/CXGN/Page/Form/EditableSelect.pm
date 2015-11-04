
use strict;
use warnings;
use CXGN::Page::Form::Select;

package CXGN::Page::Form::EditableSelect;

use base qw / CXGN::Page::Form::Select /;

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
    my %args  = @_;
    my $self  = $class->SUPER::new(%args);

    return $self;

}

sub render {
    my $self        = shift;
    my $select_id   = $self->get_id();
    my $select_name = $self->get_field_name();
    my $box         = qq { <select id="$select_id" class=\"form-control\" name="$select_name"> };
    foreach my $s ( $self->get_selections() ) {
        my $yes = "";

        if(    exists $s->[1]
            && $s->[1] =~ /\d+/
            && $self->get_contents
            && $s->[1] == $self->get_contents
          )
        {
            $yes = "selected=\"selected\"";
        }
        elsif( exists $s->[1]
            && $s->[1] =~ /\w+/
            && $self->get_contents
            && $s->[1] eq $self->get_contents()
            )
        {
            $yes = "selected=\"selected\"";
        }

        $box .= qq { <option value="$s->[1]" $yes>$s->[0]</option> };

    }
    $box .= qq { </select> };
    return $box;
}

return 1;
