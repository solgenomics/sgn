
package CXGN::GenotypeProtocol;

use Moose;

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON::Any;

has 'schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'nd_protocol_id' => ( 
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'name' => (
	isa => 'Str',
	is => 'rw',
);

has 'markers' => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->_get_markers();
	}
);

has 'chromosomes' => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->_get_chromosomes();
	}
);

has 'markers_by_chromosomes' => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->_get_markers_by_chromosomes();
	}
);


has 'marker_details' => (
	is => 'rw',
);


	
sub BUILD {
    my $self = shift;

    my $protocol = $self->schema()->resultset('NaturalDiversity::NdProtocol')->find({ nd_protocol_id=>$self->nd_protocol_id() });

    if (!$protocol) {
		die "The specified protocol with id ".$self->nd_protocol_id()." does not exist!";
    }

    $self->name($protocol->name());

	#my $protocolprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'vcf_map_details', 'protocol_property')->cvterm_id;

	my $protocolprop = $self->schema()->resultset('NaturalDiversity::NdProtocolprop')->find({ nd_protocol_id=>$self->nd_protocol_id() });
	
	if (!$protocolprop) {
		print STDERR "The specified protocol with id ".$self->nd_protocol_id()." has no protocolprop!\n";
    }
	
	my $marker_details;
	if ($protocolprop) {
		$marker_details = JSON::Any->decode($protocolprop->value());
	}
	$self->marker_details($marker_details);
}

sub _get_markers {
	my $self = shift;
	
	my $marker_details = $self->marker_details();
	my @markers;
	foreach my $m (sort keys %$marker_details) {
		push @markers, $m;
	}
	return \@markers
}

sub _get_chromosomes {
	my $self = shift;
	
	my $marker_details = $self->marker_details();
	#print STDERR Dumper $marker_details;
	
	my %chrs;
	foreach my $m (values %$marker_details) {
		if ($m->{chrom}) {
			$chrs{$m->{chrom}} = 1;
		}
	}
	return \%chrs;
}

sub _get_markers_by_chromosomes {
	my $self = shift;
	
	my $marker_details = $self->marker_details();
	my $markers = $self->markers();
	
	my %chrs;
	foreach my $m (@$markers) {
        my $chr = $marker_details->{$m}->{chrom};
        my $pos = $marker_details->{$m}->{pos};
		$chrs{$chr}->{$m} = $pos;
	}
	return \%chrs;
}

1;
