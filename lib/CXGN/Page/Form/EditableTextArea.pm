
=head1 NAME

CXGN::Page::Form::EditableTextArea

=head1 DESCRIPTION

Implements an editable textarea. For further information, see L<CXGN::Page::Form>.


=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut


use strict;
use CXGN::Page::Form::TextArea;

package CXGN::Page::Form::EditableTextArea;

use base qw / CXGN::Page::Form::TextArea /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub render { 
    my $self = shift;
	 my $id = $self->get_id();
    my $name = $self->get_field_name();
    my $contents = $self->get_contents();
    my $rows = $self->get_rows();
    my $columns = $self->get_columns();

    return qq { <textarea class="form-control" id="$id" name="$name" rows="$rows" cols="$columns">$contents</textarea>\n };

}



return 1;
