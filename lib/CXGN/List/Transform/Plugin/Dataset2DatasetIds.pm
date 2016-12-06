
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

    my @ids= ();
    my @missing_ids = ();

    print STDERR "Untransformed list data: ".Dumper($list)."\n";

    foreach my $l (@$list) {

      my ($type, $elements) = split(":(.+)", $l);
      my $type_singular = $type;
      $type_singular =~ s/e?s$//;
      my $transform_name = $type . "_2_" . $type_singular . "_ids";
      my @elements = split(",", $elements);

      foreach my $p ($object->plugins()) {
        if ($transform_name eq $p->name()) {
          my $data = $p->transform($schema, \@elements);
          my %data_hash = %$data;
          my $transformed = $data_hash{'transform'};
          my @transformed_array = @$transformed;
          if (scalar @transformed_array > 0) {
            push @ids, $type_singular . "_ids:" . join(",", @transformed_array);
          }
          my $missing = $data_hash{'missing'};
          my @missing_array = @$missing;
          if (scalar @missing_array > 0) {
            push @missing_ids, $type_singular . "_ids:" . join(",", @missing_array);
          }
        }
      }

    }

    return {
      transform => \@ids,
	    missing => \@missing_ids,
    };
}

1;
