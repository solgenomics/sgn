
use strict;
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



# my $vhost = CXGN::VHost->new();

# my $viewer = CXGN::Cview::Chromosome_viewer -> new();

# $viewer -> set_temp_dir(File::Spec->catfile($vhost->get_conf('tempfiles_subdir'), "cview"));
# $viewer -> set_basedir($vhost->get_conf('basepath'));
# $viewer -> set_show_offsets($show_offsets);
# $viewer -> set_map_id($map_id);
# $viewer -> set_map_version_id($map_version_id);
# $viewer -> set_ref_chr($chr_nr);
# $viewer -> set_cM($cM);
# $viewer -> set_clicked($clicked);
# $viewer -> set_zoom($zoom);
# $viewer -> set_show_physical($show_physical);
# $viewer -> set_show_ruler($show_ruler);
# $viewer -> set_show_IL($show_IL);
# $viewer -> set_comp_map_id($comp_map_id);
# $viewer -> set_comp_map_version_id($comp_map_version_id);
# $viewer -> set_comp_chr($comp_chr);
# $viewer -> set_color_model($color_model);
# $viewer -> set_display_marker_type($marker_type);
# $viewer -> set_force($force);

# if ($map_chr_select) { 
#     my ($comp_map_id, $comp_chr) = split / /, $map_chr_select; 
#     $viewer->set_comp_map_version_id($comp_map_id);
#     $viewer->set_comp_chr($comp_chr);
# }
# $viewer -> set_size($size);
# $viewer -> set_hilite($hilite);
# $viewer -> set_cM_start($cM_start);
# $viewer -> set_cM_end($cM_end);
# $viewer -> set_confidence($confidence);
# $viewer -> set_show_zoomed($show_zoomed);

# # output the page
# #
# $page->header("SGN Comparative Viewer");
# $viewer->generate_page();
# $page->footer();
