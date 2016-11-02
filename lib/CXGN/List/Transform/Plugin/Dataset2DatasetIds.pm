
package CXGN::List::Transform::Plugin::Dataset2DatasetIds;

use Moose;
use Data::Dumper;

sub name {
    return "dataset_2_dataset_ids";
}

sub display_name {
    return "dataset to dataset IDs";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "dataset") and ($type2 eq "dataset_ids")) {
	return 1;
    }
    else {  return 0; }
}


sub transform {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my $object = shift;

    my @transform = ();
    my @missing = ();

    print STDERR "Untransformed list data: ".Dumper($list)."\n";

    foreach my $l (@$list) {

      my ($type, $elements) = split(":(.+)", $l);
      my $type_singular = $type;
      $type_singular =~ s/s$//;
      my $transform_name = $type . "_2_" . $type_singular . "_ids";
      my @elements = split(",", $elements);

      foreach my $p ($object->plugins()) {
        if ($transform_name eq $p->name()) {
          my $data = $p->transform($schema, \@elements);
          my $transform = %$data{'transform'};
          if (scalar @$transform > 0) {
            push @transform, $type_singular . "_ids:" . join(",", @$transform);
          }
          my $missing = %$data{'missing'};
          if (scalar @$missing > 0) {
            push @missing, $type_singular . "_ids:" . join(",", @$missing);
          }
        }
      }
    }

    return {
      transform => \@transform,
	    missing => \@missing,
    };
}

1;
