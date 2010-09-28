
use strict;
use warnings;

package CXGN::Cview::Map::SGN::Scaffold;

use base qw | CXGN::Cview::Map |;

use CXGN::Cview::Chromosome::Scaffold;
use CXGN::Cview::Ruler::ScaffoldRuler;

sub new { 
    my $class = shift;
    my $dbh = shift;
    my $id = shift;
    my $args = shift;
    my $self = $class->SUPER::new($dbh);

    $self->{file} = $args->{file};
    $self->{marker_link} = $args->{marker_link};
    $self->set_id($id);
    $self->set_temp_dir($args->{temp_dir});
    $self->set_chromosome_lengths();

    $self->set_chromosome_names(qw | 1 2 3 4 5 6 7 8 9 10 11 12 | );
    $self->set_chromosome_count(12);
    $self->cache_chromosome_lengths();
    $self->set_short_name($args->{short_name});
    $self->set_long_name($args->{long_name});
    $self->set_abstract($args->{abstract});
    $self->set_units('bp');


    return $self;
}

sub get_chromosome { 
    my $self = shift;
    my $chr_nr = shift;

    my $INTER_SCAFFOLD_DISTANCE = 10_000;

    my $chr = CXGN::Cview::Chromosome::Scaffold->new($self->{file}, $chr_nr, $self->{marker_link});
    $chr->set_height(500);
    $chr->set_width(20);

    return $chr;
}

sub get_chromosome_section { 
     my $self = shift;
     my $chr_nr = shift;
     my $start = shift;
     my $end = shift;
    
     my $chr = $self->get_chromosome($chr_nr);
     $chr->set_section($start, $end);
     return $chr;

}

sub get_overview_chromosome { 
    my $self = shift;
    my $chr_nr = shift;
    my $chr = $self->get_chromosome($chr_nr);
    $chr->set_height(100);

    my @m = $chr->get_markers();
    foreach my $m (@m) { 
	$m->hide_label();
    }
    return $chr;
}

sub cache_chromosome_lengths { 
    my $self = shift;
    my $temp_dir = $self->get_temp_dir();
    my $path = File::Spec->catfile($temp_dir, "chromosome_length_cache.".$self->get_id().".txt");
    if (! -e $path) { 	
	open my $F, ">", $path or die "Can't open file $path for writing: $!";
	foreach my $chr_nr ($self->get_chromosome_names()) { 
	    my $chr = CXGN::Cview::Chromosome::Scaffold->new($self->{file}, $chr_nr, $self->{marker_link});
	    print STDERR "$chr_nr\t".$chr->get_length()."\n";
	    print $F join "\t", ($chr_nr, $chr->get_length());
	    print $F "\n";
	}
	close($F);

	
    }

    my @lengths = ();
    open( my $G, '<', $path) or die "Cant open file $path for reading: $!";
    while (<$G>) { 
	chomp;
	my ($chr, $length) = split /\t/;
	push @lengths, $length;
    }
    close($G);
    $self->set_chromosome_lengths(@lengths);

}

sub can_zoom { 
    return 1;
}

sub get_marker_count { 
    my $self = shift;
    my $chr_nr = shift;

    return $self->get_chromosome($chr_nr)->get_markers();
}

sub get_marker_type_stats { 
    return "";
}

sub collapsed_marker_count { 
    return 20;
}

sub initial_zoom_height { 
    return 10_000_000;

}

sub get_map_stats { 
    return "This map only contains scaffolds.";
}

sub show_ruler { 
    return 0;
}

return 1;
