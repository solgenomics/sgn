package CXGN::BrAPI::v2::GenomeMaps;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use CXGN::Cview::MapFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

=head2 list

 Usage:        $brapi->list()
 Desc:         lists all available maps.
 Ret:          returns a hash with all the map info
               for each map, the following keys are present:
		        mapDbId
			name
			species
			type
			unit
			markerCount
			comments
			linkageGroupCount
               see brapi documentation for more information.
 Args:         usual brapi args (pageSize etc)
 Side Effects:
 Example:

=cut

sub list {
    my $self = shift;
    my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $crop_id = $inputs->{commonCropName} || ($inputs->{commonCropNames} || ());
    my $scientific_id = $inputs->{scientificName} || ($inputs->{scientificNames} || ());
    my $type_id = $inputs->{type} || ($inputs->{types} || ());
    my $map_id = $inputs->{mapDbId} || ($inputs->{mapDbIds} || ());
 	# mapPUI
	# programDbId
	# trialDbId
	# studyDbId
	my @maps;

	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;

	my $map_factory = CXGN::Cview::MapFactory->new($self->bcs_schema()->storage->dbh(), $inputs->{config});

	if ( $map_id ) {
		@maps = $map_factory->create( { map_id => $map_id->[0] });
	} else {
		@maps = $map_factory->get_all_maps();
	}

	my @data;
	my $passes_search;

  	my $query = "SELECT map_id, date_loaded, count(distinct(location_id)) FROM sgn.map_version JOIN marker_location using (map_version_id) WHERE map_version_id=? GROUP BY 1,2";
	my $sth = $self->bcs_schema->storage()->dbh()->prepare($query);

	foreach my $m (@maps) {
        my $map_version_id = $m->get_id();
        if ($map_version_id =~ /\D/) { next; } # not a valid id
        $sth->execute($map_version_id);
        my ($map_id, $date_loaded, $marker_count) = $sth->fetchrow_array();
		
        my $map_type = $m->get_type();
        my $map_units = $m->get_units();
        if ($map_type eq 'sequence'){
            $map_type = 'Physical';
            $map_units = 'Mb';
        } else {
            $map_type = 'Genetic';
            $map_units = 'cM';
        }
        my $scientific_name = $m->get_organism();
        my $common_name = $m->get_common_name();

		$passes_search = 1;
        if ( $crop_id && ! grep { $_ eq $common_name } @{$crop_id} ) { $passes_search = 0;};
        if ( $scientific_id && ! grep { $_ eq $scientific_name } @{$scientific_id} ) { $passes_search = 0;};
        if ( $type_id && ! grep { $_ eq $map_type } @{$type_id} ) { $passes_search = 0;};

		if ( $passes_search ){ 
	        my %map_info = (
			    additionalInfo => {name => $m->get_long_name()},
				comments => $m->get_abstract(),			
	            commonCropName => $common_name,
	            documentationURL => "https://brapi.org",
	            linkageGroupCount => $m->get_chromosome_count(),
	            mapDbId =>  qq|$map_id|,
	            mapName => $m->get_short_name(),
	            mapPUI => undef,
				markerCount => $marker_count,
	            publishedDate => $date_loaded,
	            scientificName => $scientific_name,
	            type => $map_type,
				unit => $map_units,
			);
			push @data, \%map_info;
		}
	}

	my $total_count = scalar(@maps);
	my %result = (data => \@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination,
							 \@data_files, $status, 'Maps list result constructed');
}


=head2 detail

 Usage:        $brapi->detail()
 Desc:         returns the detail information of a map in brapi format
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub detail {
	my $self = shift;
	my $map_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my %result;

	my $map_factory = CXGN::Cview::MapFactory->new($self->bcs_schema->storage()->dbh());
	my $map = $map_factory->create( { map_id => $map_id });

	if ($map){
	    my $map_type = $map->get_type();
	    my $map_units = $map->get_units();
	    if ($map_type eq 'sequence'){
	        $map_type = 'Physical';
	        $map_units = 'Mb';
	    } else {
	        $map_type = 'Genetic';
	        $map_units = 'cM';
	    }

		my $scientific_name = $map->get_organism();
	    
	    my $query = "SELECT map_id, date_loaded, count(distinct(location_id)) FROM sgn.map_version JOIN marker_location using (map_version_id) WHERE map_version_id=? GROUP BY 1,2";
		my $sth = $self->bcs_schema->storage()->dbh()->prepare($query);
	    my $map_version_id = $map->get_id();
		if ($map_version_id =~ /\D/) { next; } 
		$sth->execute($map_version_id);
		my ($map_id1, $date_loaded, $marker_count) = $sth->fetchrow_array();

		%result = (
			additionalInfo => { name => $map->get_long_name() },
			comments => $map->get_abstract(),			
	        commonCropName => $map->get_common_name(),
	        documentationURL => "https://brapi.org",
	        linkageGroupCount => $map->get_chromosome_count(),
	        mapDbId =>  qq|$map_id|,
	        mapName => $map->get_short_name(),
	        mapPUI => undef,
			markerCount => $marker_count,
	        publishedDate => $date_loaded,
	        scientificName => $scientific_name,
	        type => $map_type,
			unit => $map_units,
		);
	}

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Maps detail result constructed');
}


sub linkagegroups {
	my $self = shift;
	my $inputs = shift;
	my $map_id = $inputs->{map_id};
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $total_count = 0;
	my @data = ();

	my $map_factory = CXGN::Cview::MapFactory->new($self->bcs_schema->storage()->dbh());
	my $map = $map_factory->create( { map_id => $map_id });

	if ($map){
		foreach my $chr ($map->get_chromosomes()) {
		    push @data, {
				additionalInfo => {},
				linkageGroupName => $chr->get_name(),
				markerCount => scalar($chr->get_markers()),
				maxPosition => $chr->get_length()
		    };
		    $total_count++;
		}
	}

	my @data_files;
	my %result = (data => \@data);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Maps detail result constructed');
}

# =head2 genosort

#  Usage:        genosort($a_chr, $a_pos, $b_chr, $b_pos)
#  Desc:         sorts marker coordinates according to position for marker names
#                of the format S(\d+)_(.*)
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub genosort {
#     my ($a_chr, $a_pos, $b_chr, $b_pos);
#     if ($a =~ m/S(\d+)\_(.*)/) {
# 	$a_chr = $1;
# 	$a_pos = $2;
#     }
#     if ($b =~ m/S(\d+)\_(.*)/) {
# 	$b_chr = $1;
# 	$b_pos = $2;
#     }

#     if ($a_chr && $b_chr) {
#       if ($a_chr == $b_chr) {
#           return $a_pos <=> $b_pos;
#       }
#       return $a_chr <=> $b_chr;
#     } else {
#       return -1;
#     }
# }

# sub get_protocolprop_hash {
# 	my $self = shift;
# 	my $nd_protocol_id = shift;
# 	my $prop_rs = $self->bcs_schema->resultset('NaturalDiversity::NdProtocolprop')->search({'me.nd_protocol_id' => $nd_protocol_id}, {join=>['type'], +select=>['type.name', 'me.value'], +as=>['name', 'value']});
# 	my $prop_hash;
# 	while (my $r = $prop_rs->next()){
# 		push @{ $prop_hash->{$r->get_column('name')} }, $r->get_column('value');
# 	}

# 	return $prop_hash;
# }

1;
