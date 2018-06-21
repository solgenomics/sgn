
package CXGN::GenotypeIO;

use Moose;
use JSON::Any;
use Data::Dumper;
use CXGN::Genotype;

use CXGN::GenotypeIOmain;

has 'format' => ( isa => 'Str',
		  is  => 'rw',
		  default => 'vcf', # or dosage
    );

has 'plugin' => ( isa => 'Ref',
		  is  => 'rw',
    );



sub BUILD { 
    my $self = shift;
    my $args = shift;

    my $plugin = CXGN::GenotypeIOmain->new();

    if ($args->{format} eq "vcf") { 
	$plugin->load_plugin("VCF");
    }
    elsif ($args->{format} eq "dosage") { 
	$plugin->load_plugin("Dosage");
    }
    elsif ($args->{format} eq "dosage_transposed") { 
	$plugin->load_plugin("DosageTransposed");
    }
    else { 
	print STDERR "No valid format provided. Using vcf.\n";
	$plugin->load_plugin("VCF");
    }
    $plugin->file($args->{file});

    my $data = $plugin->init($args);    
    
    $self->plugin($plugin);

    #print STDERR "count = $data->{count}\n";
    #$self->count($data->{count});
    #$self->header($data->{header});
    #$self->current(0);
}

sub next { 
    my $self  =shift;

    my ($markers, $rawscores, $accession_name) = $self->plugin()->next();
    if (keys(%$rawscores)==0) { return undef; }
    my $gt = CXGN::Genotype->new();
    $gt->name($accession_name);
    $gt->rawscores($rawscores);
    $gt->markers($self->markers());
    
#    print STDERR "NAME: $genotype\n";
#    print STDERR join ", ", keys %$rawscores;

    return $gt;
}

sub next_vcf_row {
	my $self = shift;
	my ($marker_info, $values) = $self->plugin()->next();
	
	if (!$marker_info) {
		return;
	}
	return ($marker_info, $values);
	
}

sub accessions { 
    my $self = shift;
    return $self->plugin()->accessions();
}

sub observation_unit_names { 
    my $self = shift;
    return $self->plugin()->observation_unit_names();
}

sub markers { 
    my $self = shift;
    #print STDERR "Markers now: ".Dumper($self->plugin()->markers())."\n";
    return $self->plugin()->markers();
}

sub close { 
    my $self = shift;
    $self->plugin()->close();
}

sub summary_stats { 
    my $self = shift;
    
    my $file = $self->plugin()->file();
    my $stats = $self->plugin()->summary_stats($file);
    return $stats;
}


1;
