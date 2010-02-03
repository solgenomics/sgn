
=head1 NAME

CXGN::Page::Form::Select - a class for representing html pulldown menus in forms

=head1 DESCRIPTION

See L<CXGN::Page::Form> for details. 

Inherits from L<CXGN::Page::Form::ElementI>.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 Constructor and member functions:

=cut

use strict;
use CXGN::Page::Form::ElementI;

package CXGN::Page::Form::Select;

use base qw / CXGN::Page::Form::ElementI /;

=head2 new

 Usage:        create a new Select object
 Desc:
 Ret:
 Args:         a hash with the following keys:
               display_name
               field_name
               contents
               length
               object
               getter
               setter
               validate
               select_list_ref
               select_id_list_ref
 Side Effects:
 Example:

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);

    #print STDERR "Parameters after SUPER: ".(join ", ", @_)."\n";
    for (my $i=0; $i<@{$args{select_list_ref}}; $i++) { 
	$self->add_selection($args{select_list_ref}->[$i], $args{select_id_list_ref}->[$i]);
	#print STDERR "Adding selection $args{select_list_ref}->[$i], $args{select_id_list_ref}->[$i]\n";
    }
    return $self;
}

=head2 get_selected

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_selected {
  my $self=shift;
  if (!exists($self->{selected})) { $self->{selected}=""; }
  return $self->{selected};

}

=head2 set_selected

 Usage:
 Desc:         returns the selected id
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_selected {
  my $self=shift;
  $self->{selected}=shift;
}

=head2 get_selected_label

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_selected_label {
    my $self = shift;
    foreach my $s ($self->get_selections()) { 
	if ($self->get_contents() eq $s->[1]) { 
	    return "$s->[0]";
	}
    }
    return "?";
}



=head2 add_selection

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_selection {
    my $self = shift;
    my $name = shift;
    my $id = shift;
    if (!exists($self->{selections})) { @{$self->{selections}}=(); }
    push @{$self->{selections}}, [$name, $id];
}

=head2 get_selections

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_selections {
    my $self = shift;
    return @{$self->{selections}};
}



sub render { 
    my $self = shift;
    
    return $self->get_selected_label();
}

return 1;
