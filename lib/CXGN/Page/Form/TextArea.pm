
=head1 NAME 

CXGN::Page::Form::Field;

=head1 DESCRIPTION

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::TextArea;

use CXGN::Tools::Text;

use base qw/ CXGN::Page::Form::ElementI /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:         a hashref with the following keys:
               display_name  (name of the field for display purposes)
               field_name (name of the form element)
               contents (the current value of the field)
               length (the length of the input field in characters)
               object (the object this field maps to)
               getter (the getter function for this field in the object)
               setter (the setter function for this field in the object)
               rows (number of rows in the text area. Default: 4)
               columns (number of columns in the text area Default: 40).
 Side Effects:
 Example:

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);

    $self->set_rows($args{rows});
    $self->set_columns($args{columns});

    return $self;
}

=head2 get_columns

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_columns {
  my $self=shift;
  if (!exists($self->{columns})) { $self->{columns}=40; }
  return $self->{columns};

}

=head2 set_columns

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_columns {
  my $self=shift;
  $self->{columns}=shift;
}

=head2 get_rows

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_rows {
  my $self=shift;
  if (!exists($self->{rows})) { $self->{rows}=4; }
  return $self->{rows};

}

=head2 set_rows

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_rows {
  my $self=shift;
  $self->{rows}=shift;
}




=head2 render

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub render { 
    my $self = shift;
    return CXGN::Tools::Text::format_field_text($self->get_contents()) ;
}

return 1;
