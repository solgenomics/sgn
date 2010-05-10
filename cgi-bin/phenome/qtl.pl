#!/usr/bin/perl -w

=head1 DESCRIPTION
A QTL detail page.

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw /info_section_html
  page_title_html
  columnar_table_html
  html_optional_show
  info_table_html
  tooltipped_text
  html_alternate_show
  /;

use CXGN::People::PageComment;
use CXGN::Phenome::Population;
use CXGN::Phenome::UserTrait;
use CXGN::Phenome::Qtl;
use CXGN::Marker;
use CXGN::Map;
use CXGN::DB::Connection;
use CXGN::Chado::Cvterm;
use List::MoreUtils qw /uniq/;

my $page = CXGN::Page->new( "qtl", "isaak" );
my ( $pop_id, $trait_id, $lg, $l_m, $p_m, $r_m, $lod, $qtl_image ) =
  $page->get_encoded_arguments(
                                "population_id", "term_id",
                                "chr",           "l_marker",
                                "p_marker",      "r_marker",
                                "lod",            "qtl"
                              );
my $dbh          = CXGN::DB::Connection->new();
my $pop          = CXGN::Phenome::Population->new( $dbh, $pop_id );
my $pop_name     = $pop->get_name();
my $trait_name   = &trait_name( $pop, $trait_id );
my $genetic_link = &genetic_map($pop);
my $cmv_link     = &marker_positions( $pop, $lg, $l_m, $p_m, $r_m );
my $gbrowse_link = &genome_positions( $l_m, $p_m, $r_m );
my $marker_link  = &marker_detail( $l_m, $p_m, $r_m );
my $legend       = &legend();
my $comment      = &comment();

$c->forward_to_mason_view('/qtl/qtl.mas', qtl_image=>$qtl_image, pop_name=>$pop_name, trait_name=>$trait_name, cmv_link=>$cmv_link, gbrowse_link=>$gbrowse_link, marker_link=>$marker_link, genetic_map=>$genetic_link, legend=>$legend, comment=>$comment);


sub marker_positions
{
    my ( $pop, $lg, $l_m, $p_m, $r_m ) = @_;
    my $mapv_id = $pop->mapversion_id();
    my $l_m_pos = $pop->get_marker_position( $mapv_id, $l_m );
    my $p_m_pos = $pop->get_marker_position( $mapv_id, $p_m );
    my $r_m_pos = $pop->get_marker_position( $mapv_id, $r_m );

    my $fl_markers =
qq |<a href="../cview/view_chromosome.pl?map_version_id=$mapv_id&chr_nr=$lg&show_ruler=1&show_IL=&show_offsets=1&comp_map_version_id=&comp_chr=&color_model=&show_physical=&size=&show_zoomed=1&confidence=-2&hilite=$l_m+$p_m+$r_m&marker_type=&cM_start=$l_m_pos&cM_end=$r_m_pos">Chromosome $lg ($l_m, $r_m)</a> |;

    return $fl_markers;
}

sub genome_positions
{
    my ( $l_m, $p_m, $r_m ) = uniq @_;   
    my $genome_pos =
      qq |<a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?name=$l_m">$l_m</a>|;
    $genome_pos .=
qq |<br/><a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?name=$p_m">$p_m</a>|;
    if ($r_m)
    {
        $genome_pos .=
qq |<br/><a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?name=$r_m">$r_m</a>|;
    }
    return $genome_pos;
}

#move this to the population object
sub genetic_map
{
    my $pop      = shift;
    my $mapv_id  = $pop->mapversion_id();
    my $map      = CXGN::Map->new( $dbh, { map_version_id => $mapv_id } );
    my $map_name = $map->get_long_name();
    my $genetic_map =
      qq | <a href=/cview/map.pl?map_version_id=$mapv_id&hilite=$l_m+$p_m+$r_m>$map_name</a>|;

    return $genetic_map;

}

sub marker_detail
{
    my @markers = @_;
    my ( $m_link, $desc );
    for ( my $i = 0 ; $i < @markers ; $i++ )
    {
        my $marker = CXGN::Marker->new_with_name( $dbh, $markers[$i] );
        my $m_id = $marker->marker_id() unless !$marker;
        if ( $i == 0 ) { $desc = "Left flanking marker:"; }
        if ( $i == 1 ) { $desc = "Peak (<i>or the closest</i>) marker:"; }
        if ( $i == 2 ) { $desc = "Right flanking marker:"; }
        $m_link .=
qq |<br/>$desc <a href="/search/markers/markerinfo.pl?marker_id=$m_id">$markers[$i]</a>|
          unless !$marker;
    }

    return $m_link;
}

sub trait_name
{
    my ( $pop, $trait_id ) = @_;

    my ( $term_obj, $term_name, $term_id );
    if ( $pop->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $trait_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $trait_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    return $term_name;
}


sub legend {

   my $sp_person_id   = $pop->get_sp_person_id();
   my $qtl            = CXGN::Phenome::Qtl->new($sp_person_id);
    my $user_stat_file = $qtl->get_stat_file($c, $pop_id);
    my @stat;
    
    open $_, "<", $user_stat_file or die "$! reading $user_stat_file\n";
    while (my $row = <$_>)
    {
        my ( $parameter, $value ) = split( /\t/, $row );
	if ($parameter =~/qtl_method/) {$parameter = 'Mapping method';}
	if ($parameter =~/qtl_model/) {$parameter = 'Mapping model';}
	if ($parameter =~/prob_method/) {$parameter = 'QTL genotype probablity method';}
	if ($parameter =~/step_size/) {$parameter = 'Genome scan size (cM)';}
	if ($parameter =~/permu_level/) {$parameter = 'Permutation significance level';}
	if ($parameter =~/permu_test/) {$parameter = 'No. of permutations';}
	if ($parameter =~/prob_level/) {$parameter = 'QTL genotype signifance level';}


	push @stat, [map{$_} ($parameter, $value)];

    }
    
    if  (!$lod) 
    {
	$lod = qq |<i>Not calculated</i>|;
    }
        
    push @stat, 
    [
     map {$_} ('LOD threshold', $lod)
    ];
    push @stat, 
    [
     map {$_} ('Confidence interval', 'Based on 95% Bayesian Credible Interval')
    ];

  

     return \@stat;

}

sub comment {
    my $comment;
    if ($pop_id) {  
	my $page_comment_obj = CXGN::People::PageComment->new($dbh, "population", $pop_id, "/phenome/qtl.pl?population_id=$pop_id");  
	$comment = $page_comment_obj->get_html();
    }
    return $comment;

}
