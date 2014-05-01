
use strict;

package CXGN::Bulk::Converter;

use base 'CXGN::Bulk';
use File::Slurp;

our %solyc_conversion_hash;

sub process_parameters { 
    my $self = shift;
    $self->{output_fields} = [ 'Input', 'Output' ];
    
    my @ids = split /\s+/, $self->{ids};

    $self->{ids} = \@ids;

    if (@ids) { 
	return 1;
    }
    else { 
	return 0;
    }
}

sub process_ids { 
    my $self = shift;
    
    if (!%solyc_conversion_hash) { 
	$self->get_hash();
    }
    
    $self->{query_start_time} = time();
    my ($dump_fh, $notfound_fh) = $self->create_dumpfile();
    my @not_found = ();
    foreach my $id (@{$self->{ids}}) { 
	print STDERR "Converting $id to $solyc_conversion_hash{uc($id)}\n";
	if (exists($solyc_conversion_hash{uc($id)})) { 
	    print $dump_fh "$id\t$solyc_conversion_hash{uc($id)}\n";
	}
	else { 
	    print $notfound_fh "$id\t(not found)\n";
	}
    }
    close($dump_fh);
    close($notfound_fh);
    $self->{query_time} = time() - $self -> {query_start_time};
}

sub get_hash { 
    my $self = shift;
    
    print STDERR "Generating hash... ";

    my @conversion = ();
    foreach my $file (@{$self->{solyc_conversion_files}}) { 
	print STDERR "(processing $file) ";
	my @lines = read_file($file);
	@conversion = (@conversion, @lines);
    }
    
    foreach my $entry (@conversion) { 
	my @fields = split /\t/, $entry;
	$solyc_conversion_hash{uc($fields[0])} = $fields[1];
    }

    print STDERR "Done.\n";

}

1;
