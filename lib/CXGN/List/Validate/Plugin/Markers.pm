package CXGN::List::Validate::Plugin::Markers;

use strict;
use warnings;
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
    my $name;
    my $protocol_id;
    my $protocol_name;
    my $protocol_id_all;
    my %other_protocols;
    my $found;
    my @row;
    my $val;
    my @missing = ();
    my @warning = ();

    my $q = "select cvterm_id from public.cvterm where name = 'vcf_map_details'";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array(); 

    #if protocol_id found get data from nd_protocolprop
    foreach $term (@$list) {
	eval { $str = decode_json($term); 1; } or next;
        next unless ref($str) eq 'HASH';
        foreach $key ( keys %$str ) {
	    if ($key eq "genotyping_protocol_id") {
		$protocol_id = $str->{$key};
		$q = "SELECT value from nd_protocolprop where type_id = ? AND nd_protocol_id = ?";
		$h = $schema->storage->dbh()->prepare($q);
		$h->execute($type_id, $protocol_id);
		($val) = $h->fetchrow_array();
		if (defined $val) {
                    $data = decode_json($val);
                } else {
		    print STDERR "error protocol $protocol_id not found\n";
		    push @missing, "protocol $protocol_id not found";
		}
		$q = "SELECT name from nd_protocol where nd_protocol_id = ?";
		$h = $schema->storage->dbh()->prepare($q);
		$h->execute($protocol_id);
                ($protocol_name) = $h->fetchrow_array();
	    }
        }
    }
    $q = "SELECT nd_protocol_id from materialized_markerview where marker_name = ?";
    $h = $schema->storage->dbh()->prepare($q);
    my $q2 = "SELECT materialized_markerview.nd_protocol_id, name from materialized_markerview, nd_protocol where materialized_markerview.nd_protocol_id = nd_protocol.nd_protocol_id and marker_name = ?";
    my $h2 = $schema->storage->dbh()->prepare($q2);

    foreach $term (@$list) {
        eval {$str = decode_json $term;};
        if ($@) {			#simple list
	    $h->execute($term);
	    ($protocol_id_all) = $h->fetchrow_array();
            if (!defined $protocol_id_all) {
	        push @missing, $term;
	    }
	} else {			#json list
	    next unless ref($str) eq 'HASH';
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
		    $h2->execute($marker);      #search other protocols
		    while (@row = $h2->fetchrow_array()) {
		        ($protocol_id_all, $name) = @row;
			if ($protocol_id_all != $protocol_id ) {
			   next if $protocol_id_all == $protocol_id;
			   push @{ $other_protocols{$marker} }, $name;
		        } 
                    }
	        }
	    }
	}
    }
	if (%other_protocols) {
	    my $formatted = "selected protocol $protocol_name, markers also found in\n";
	    foreach my $marker (keys %other_protocols) {
                $formatted .= "$marker\n\t" . join("\n\t", @{$other_protocols{$marker}}) . "\n";
            }
            push @warning, $formatted;
	}
        #$schema->storage->debug(1);

    return { missing => \@missing,
             warning => \@warning };

}

1;
