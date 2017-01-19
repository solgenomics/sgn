
package CXGN::List::Validate::Plugin::Numbers;

use Moose;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

sub name {
    return "numbers";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @missing = ();
    foreach my $term (@$list) {
      if (!looks_like_number($term)) {
	       push @missing, $term;
	    }
    }
    return { missing => \@missing };
}

1;
