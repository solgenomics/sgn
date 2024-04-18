
package CXGN::List::Validate::Plugin::Markers;

use strict;
use warnings;
use Moose;
use CXGN::Marker::Search;
use JSON;

sub name { 
    return "markers";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $str;
    my $key;
    my @missing = ();
    my $q = "SELECT nd_protocol_id from materialized_markerview where marker_name = ?";
    my $h = $schema->storage->dbh()->prepare($q);
    foreach my $term (@$list) {
	eval {$str = decode_json $term;};
        if ($@) {
	    foreach ( $term ) {
		$h->execute($_);
		if ($h->fetchrow_array()) {
		} else {
		    print STDERR "error not found $_\n";
		    push @missing, $term;
		}
	    }
	} else {
	    foreach $key ( keys %$str ) {
		if ($key eq "marker_name") {
		    $h->execute($str->{$key});
		    if ($h->fetchrow_array()) {
		    } else {
			print STDERR "error not found $str->{$key}\n";
			push @missing, $term;
		    }
	        }
	    }
	}
	#$schema->storage->debug(1);
    }
    return { missing => \@missing };

}

1;
