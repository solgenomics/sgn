use CatalystX::GlobalContext qw( $c );

use strict;
use warnings;
use CXGN::Page;
use CXGN::DB::Connection; 

my $dbh = CXGN::DB::Connection->new();

my $page = CXGN::Page->new("SGN comparative viewer", "Lukas");

my ($map_id, $map_version_id, $chr_nr, $cM, $zoom, $show_physical, $show_ruler, $show_IL, $comp_map_id, $comp_map_version_id, $comp_chr, $color_model, $map_chr_select, $size, $hilite, $cM_start, $cM_end, $confidence, $show_zoomed, $marker_type, $show_offsets, $force, $clicked)
	= $page->get_encoded_arguments("map_id", "map_version_id", "chr_nr", "cM", "zoom","show_physical", "show_ruler", "show_IL", "comp_map_id", "comp_map_version_id", "comp_chr", "color_model", "map_chr_select", "size", "hilite", "cM_start", "cM_end", "confidence", "show_zoomed", "marker_type", "show_offsets", "force", "clicked");


$c->forward_to_mason_view('/cview/chr/index.mas', 
			  dbh => $dbh,
			  map_id=>$map_id, 
			  map_version_id=>$map_version_id, 
			  chr_nr=>$chr_nr, 
			  cM=>$cM, 
			  zoom=>$zoom, 
			  show_physical=>$show_physical, 
			  show_ruler=>$show_ruler, 
			  show_IL=>$show_IL, 
			  comp_map_id=>$comp_map_id, 
			  comp_map_version_id=>$comp_map_version_id, 
			  comp_chr=>$comp_chr, 
			  color_model=>$color_model, 
			  map_chr_select=>$map_chr_select, 
			  size=>$size, 
			  hilite=>$hilite, 
			  cM_start=>$cM_start, 
			  cM_end=>$cM_end, 
			  confidence=>$confidence, 
			  show_zoomed=>$show_zoomed, 
			  marker_type=>$marker_type, 
			  show_offsets=>$show_offsets, 
			  force=>$force, 
			  clicked=>$clicked 
    );
