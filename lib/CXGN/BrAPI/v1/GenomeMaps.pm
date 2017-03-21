package CXGN::BrAPI::v1::GenomeMaps;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'metadata_schema' => (
	isa => 'CXGN::Metadata::Schema',
	is => 'rw',
	required => 1,
);

has 'phenome_schema' => (
	isa => 'CXGN::Phenome::Schema',
	is => 'rw',
	required => 1,
);

has 'page_size' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'page' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);


sub list {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $start = $page_size*$page;
    my $end = $page_size*($page+1)-1;
	my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
	my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );
	my $total_count = $rs->count;
	$rs = $rs->slice($start, $end);

	my @data;
	while (my $row = $rs->next()) {
		my %map_info;
		print STDERR "Retrieving map info for ".$row->name()." ID:".$row->nd_protocol_id()."\n";
		#$self->bcs_schema->storage->debug(1);
		my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $row->nd_protocol_id() } )->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {select=>['genotype.description', 'genotypeprops.value'], as=>['description', 'value'], rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

		my $lg_row = $lg_rs->first();

		if (!$lg_row) {
			die "This was never supposed to happen :-(";
		}

		my $scores = JSON::Any->decode($lg_row->get_column('value'));
		my %chrs;

		my $marker_count =0;
		foreach my $m (sort genosort (keys %$scores)) {
			my ($chr, $pos) = split "_", $m;
			#print STDERR "CHR: $chr. POS: $pos\n";
			$chrs{$chr} = $pos;
			$marker_count++;
		}
		my $lg_count = scalar(keys(%chrs));

		%map_info = (
			mapDbId =>  $row->nd_protocol_id(),
			name => $row->name(),
			species => $lg_row->get_column('description'),
			type => "physical",
			unit => "bp",
			markerCount => $marker_count,
			publishedDate => undef,
			comments => "",
			linkageGroupCount => $lg_count,
		);

		push @data, \%map_info;
	}

    my %result = (data => \@data);
	push @$status, { 'success' => 'Maps list result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub detail {
	my $self = shift;
	my $map_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();

	# maps are just marker lists associated with specific protocols
	my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->find( { nd_protocol_id => $map_id } );
	my %map_info;
	my @data;

	print STDERR "Retrieving map info for ".$rs->name()."\n";
	#$self->bcs_schema->storage->debug(1);
	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $rs->nd_protocol_id() })->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

	if (!$lg_rs) {
		die "This was never supposed to happen :-(";
	}

	my %chrs;
	my %markers;
	my @ordered_refmarkers;
	while (my $profile = $lg_rs->next()) {
		my $profile_json = $profile->value();
		my $refmarkers = JSON::Any->decode($profile_json);
		#print STDERR Dumper($refmarkers);
		push @ordered_refmarkers, sort genosort keys(%$refmarkers);
	}

	foreach my $m (@ordered_refmarkers) {
		my ($chr, $pos) = split "_", $m;
		#print STDERR "CHR: $chr. POS: $pos\n";

		$markers{$chr}->{$m} = 1;
		if ($pos) {
			if ($chrs{$chr}) {
				if ($pos > $chrs{$chr}) {
					$chrs{$chr} = $pos;
				}
			} else {
				$chrs{$chr} = $pos;
			}
		}
	}

	foreach my $ci (sort (keys %chrs)) {
		my $num_markers = scalar keys %{ $markers{$ci} };
		my %linkage_groups_data = (
			linkageGroupId => $ci,
			numberMarkers => $num_markers,
			maxPosition => $chrs{$ci}
		);
		push @data, \%linkage_groups_data;
	}

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);

	my %result = (
		mapDbId =>  $rs->nd_protocol_id(),
		name => $rs->name(),
		type => "physical",
		unit => "bp",
		linkageGroups => $data_window,
	);

	push @$status, { 'success' => 'Map detail result constructed' };
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub positions {
	my $self = shift;
	my $inputs = shift;
	my $map_id = $inputs->{map_id};
	my $min = $inputs->{min};
	my $max = $inputs->{max};
	my @linkage_group_ids = $inputs->{linkage_group_ids} ? @{$inputs->{linkage_group_ids}} : ();
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my %linkage_groups;
	if (scalar(@linkage_group_ids)>0) {
		%linkage_groups = map { $_ => 1 } @linkage_group_ids;
	}

	my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
	my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->find( { nd_protocol_id => $map_id } );

	my @markers;
	print STDERR "Retrieving map info for ".$rs->name()."\n";
	#$self->bcs_schema->storage->debug(1);
	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $rs->nd_protocol_id()})->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

	if (!$lg_rs) {
		die "This was never supposed to happen :-(";
	}

	my @ordered_refmarkers;
	while (my $profile = $lg_rs->next()) {
		my $profile_json = $profile->value();
		my $refmarkers = JSON::Any->decode($profile_json);
		#print STDERR Dumper($refmarkers);
		push @ordered_refmarkers, sort genosort keys(%$refmarkers);
	}

	my %chrs;

	foreach my $m (@ordered_refmarkers) {
		my ($chr, $pos) = split "_", $m;
		#print STDERR "CHR: $chr. POS: $pos\n";
		$chrs{$chr} = $pos;
		#   "markerDbId": 1,
		#   "markerName": "marker1",
		#   "location": "1000",
		#   "linkageGroup": "1A"

		if (%linkage_groups) {
			if (exists $linkage_groups{$chr} ) {
				if ($min && $max) {
					if ($pos >= $min && $pos <= $max) {
						push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
					}
				} elsif ($min) {
					if ($pos >= $min) {
						push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
					}
				} elsif ($max) {
					if ($pos <= $max) {
						push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
					}
				} else {
					push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
				}
			}
		} else {
			push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
		}

	}

	if ($page_size == 20) {
		$page_size = 100000;
	}
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@markers,$page_size,$page);
	my %result = (data => $data_window);
	push @$status, { 'success' => 'Map positions result constructed' };
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub genosort {
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) {
	$a_chr = $1;
	$a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) {
	$b_chr = $1;
	$b_pos = $2;
    }

    if ($a_chr && $b_chr) {
      if ($a_chr == $b_chr) {
          return $a_pos <=> $b_pos;
      }
      return $a_chr <=> $b_chr;
    } else {
      return -1;
    }
}



1;
