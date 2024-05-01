
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
    my $data;
    my $marker;
    my $term;
    my $count;
    my $protocol_id;
    my $found;
    my @row;
    my @missing = ();

    my $q = "select cvterm_id from public.cvterm where name = 'vcf_map_details'";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array(); 

    #if protocol_id found get data from nd_protocolprop
    foreach $term (@$list) {
	eval {$str = decode_json $term;};
        foreach $key ( keys %$str ) {
	    if ($key eq "genotyping_protocol_id") {
		$protocol_id = $str->{$key};
		$q = "SELECT value from nd_protocolprop where type_id = ? AND nd_protocol_id = ?";
		$h = $schema->storage->dbh()->prepare($q);
		$h->execute($type_id, $protocol_id);
		if (@row = $h->fetchrow_array()) {
                    $data = decode_json($row[0]);
                } else {
		    print STDERR "error protocol $protocol_id not found\n";
		    push @missing, "protocol $protocol_id not found";
		}
	    }
        }
    }
    $q = "SELECT nd_protocol_id from materialized_markerview where marker_name = ?";
    $h = $schema->storage->dbh()->prepare($q);

    foreach $term (@$list) {
        eval {$str = decode_json $term;};
        if ($@) {			#simple list
	    foreach $marker ( $term ) {
	        $h->execute($marker);
		if (@row = $h->fetchrow_array()) {
		} else {
		    push @missing, $term;
		}
            }
	} else {			#json list
	    foreach $key ( keys %$str ) {
	        if ($key eq "marker_name") {
		    $marker = $str->{$key};
		    $found = 0;
		    foreach (@{$data->{marker_names}}) {
			my $item = $_;
                        if ($item eq $marker) {
                            $found = 1;
			}
                    }
		    if (!$found) {
			push @missing, $marker;
		    }
	        }
	    }
	}
        #$schema->storage->debug(1);
    }
    return { missing => \@missing };

}

1;
