
=head1 NAME

CXGN::List::Transform - transform lists from one type to another

=head1 SYNOPSYS

 my $tf = CXGN::List::Transform->new();
 if (my $transform_name = $tf->can_transform("accessions", "accession_ids")) {
   my $tf_list = @$tf->tranform($schema, $transform_name, $list_ref);
 }

=cut

package CXGN::List::Transform;

use Moose;
use Data::Dumper;
use Module::Pluggable require => 1;

=head2 can_transform

 Usage:        my $tf_name = $tf->can_transform("accessions", "accession_ids");
 Desc:         ask if to types can be transformed. Returns the name of the
               transform, to be used with the transform() function
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    foreach my $p ($self->plugins()) {
	if ($p->can_transform($type1, $type2)) {
	    return $p->name();
	}
    }
    return 0;
}

=head2 transform

 Usage:        $tf->transform($schema, $transform_name, $list_ref);
 Desc:
 Args:         $schema (Bio::Chado::Schema)
               $transform_name (obtain from can_transform())
               $list_ref of elements to transform
 Returns:      a hashref with two keys, transform and missing, both
               of which are arrayrefs of strings.
 Side Effects:
 Example:

=cut

sub transform {
    my $self = shift;
    my $schema = shift;
    my $transform_name = shift;
    my $list = shift;

    my $data;

    foreach my $p ($self->plugins()) {
        if ($transform_name eq $p->name()) {
             $data = $p->transform($schema, $list, $self);
        }
    }
    return $data;
}

1;
