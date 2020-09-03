package CXGN::BrAPI::v2::MarkerPositions;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use CXGN::Cview::MapFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';


sub search {
	my $self = shift;
	my $inputs = shift;
	my $c = shift;

	my $linkage_group_ids = $inputs->{linkageGroupName} || ($inputs->{linkageGroupNames} || ());
    my $map_id = $inputs->{mapDbId} || ($inputs->{mapDbIds} || ());
    my $min = $inputs->{minPosition} || ($inputs->{minPosition} || ());
    my $max = $inputs->{maxPosition} || ($inputs->{maxPosition} || ());
    my $marker_id = $inputs->{variantDbId} || ($inputs->{variantDbIds} || ());

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter =0;
	my @maps;

	my $map_factory = CXGN::Cview::MapFactory->new($self->bcs_schema()->storage->dbh(), $c->config ) ; #$inputs->{config});

	if ( $map_id ) {
		@maps = $map_factory->create( { map_id => $map_id });
	} else {
		@maps = $map_factory->get_all_maps();
	}
	
	my @data;
	my $passes_search;

	foreach my $map (@maps) {
		my $map_name = $map->get_short_name();
		my $map_id = $map->get_id();

		foreach my $chr ($map->get_chromosomes()) {
			my $lg = $chr->get_name();
	
		    foreach my $m ($chr->get_markers()) {
		    	my $m_id = $m->get_id();
		    	my $position = $m->get_offset();

				$passes_search = 1;
				if ( $linkage_group_ids && ! grep { $_ eq $lg } @{$linkage_group_ids} ) { $passes_search = 0;};
				if ( $marker_id && ! grep { $_ eq $m_id } @{$marker_id} ) { $passes_search = 0;};
				if ( $min && $min->[0] > $position ) { $passes_search = 0;};
				if ( $max && $max->[0] < $position ) { $passes_search = 0;};

				if ($passes_search) {
					if ($counter >= $start_index && $counter <= $end_index) {
					    push @data, {
						    variantDbId => $m_id,
						    variantName => $m->get_name(),
						    position => $position,
						    linkageGroupName => $lg,
						    mapDbId => qq|$map_id|,
						    mapName => $map_name,
					    }
					}
					$counter++;
				}
		    }
		}
	}

    my $marker_count = scalar(@data);

	my %result = ( data => \@data );
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($marker_count,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Maps detail result constructed');
}

1;
