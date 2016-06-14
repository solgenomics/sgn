
=head1 DESCRIPTION
A QTL detail page.

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;
use warnings;


use CGI qw //;
use CXGN::People::PageComment;
use CXGN::Phenome::Population;
use CXGN::Phenome::UserTrait;
use CXGN::Phenome::Qtl;
use CXGN::Marker;
use CXGN::Map;
use CXGN::DB::Connection;
use CXGN::Chado::Cvterm;
use List::MoreUtils qw / uniq /;
use List::Util qw / max min/;
use File::Slurp qw / read_file /;
use Number::Format;
use SGN::Exception;


use CatalystX::GlobalContext qw( $c );

my $cgi = CGI->new();
my %params = $cgi->Vars();

our $pop_id    = $params{population_id};
our $trait_id  = $params{term_id};
our $lg        = $params{chr};
our $p_m       = $params{peak_marker};
our $lod       = $params{lod};
our $qtl_image = $params{qtl};

if (    !$pop_id
     || !$trait_id
     || !$lg
     || !$p_m   
     || !$qtl_image )
{
    die 'QTL detail page error:  A required argument is missing';
}


our ($l_m,  $r_m);
our $dbh         = CXGN::DB::Connection->new();
our $pop         = CXGN::Phenome::Population->new($dbh, $pop_id);
our $pop_name    = $pop->get_name();
our $trait_name  = trait_name();
our ($ci_table, $marker_details) = confidence_interval();

foreach my $k (keys %$marker_details) {    
    $l_m = $k if ($marker_details->{$k}{orientation} eq  'left');
    $r_m = $k if ($marker_details->{$k}{orientation} eq  'right');
}

my $genetic_link = genetic_map();
my $cmv_link     = marker_positions();
my $markers      = markers();
my $legend       = legend();
my $comment      = comment();
my $download_qtl = download_qtl_region();
$ci_table        = order_by_position();

$c->forward_to_mason_view( '/qtl/qtl/index.mas',
                           qtl_image    => $qtl_image,
                           pop_name     => $pop_name,
                           trait_name   => $trait_name,
                           cmv_link     => $cmv_link,
                           markers      => $markers,
                           marker_link  => $ci_table,
                           genetic_map  => $genetic_link,
                           legend       => $legend,
                           download     => $download_qtl,
                           comment      => $comment,
);



=head2 marker_positions

 Usage: $map_viewer = marker_positions();
 Desc: generates a link to the comparative map viewer page
       using the flanking markers and peak marker.
 Ret: a link to the map viewer page
 Args: None
 Side Effects:
 Example:

=cut


sub marker_positions
{
    my $mapv_id = $pop->mapversion_id();   
    my $l_m_pos = $marker_details->{$l_m}{position};
    my $p_m_pos = $marker_details->{$p_m}{position};
    my $r_m_pos = $marker_details->{$r_m}{position};
    
    my $fl_markers
        = qq |<a href="../cview/view_chromosome.pl?map_version_id=$mapv_id&chr_nr=$lg&show_ruler=1&show_IL=&show_offsets=1&comp_map_version_id=&comp_chr=&color_model=&show_physical=&size=&show_zoomed=1&confidence=-2&hilite=$l_m+$p_m+$r_m&marker_type=&cM_start=$l_m_pos&cM_end=$r_m_pos">Chromosome $lg ($l_m, $r_m)</a> |;

    return $fl_markers;
}

=head2 markers

 Usage: $markers = markers();
 Desc: creates  marker objects
 Ret:  array ref of marker objects
 Args: None
 Side Effects:
 Example:

=cut


sub markers
{
    my @mrs = uniq ($l_m, $p_m, $r_m);

    my @markers;
    foreach my $mr (@mrs) 
    {
	if($mr) 
	{
	    my $marker = CXGN::Marker->new_with_name($dbh, $mr);
	    if (!$marker) 
	    {
		my @marker_id = CXGN::Marker::Tools::marker_name_to_ids( $dbh, $mr);		
		if ($marker_id[0]) 
		{
		    $marker = CXGN::Marker->new($dbh, $marker_id[0]);
		}
	    }
	    
	    push @markers, $marker if $marker;
	}
    }

    return \@markers;
       
}

=head2 genetic_map

 Usage: $population_map = genetic_map();
 Desc: generates a link to the genetic map of the
       population
 Ret: a link to the genetic map
 Args: None
 Side Effects:
 Example:

=cut


sub genetic_map
{
    my $mapv_id     = $pop->mapversion_id();
    my $map         = CXGN::Map->new( $dbh, { map_version_id => $mapv_id } );
    my $map_name    = $map->get_long_name();
    my $map_sh_name = $map->get_short_name();
    my $genetic_map
        = qq | <a href=/cview/map.pl?map_version_id=$mapv_id&hilite=$l_m+$p_m+$r_m>$map_name ($map_sh_name)</a>|;

    return $genetic_map;

}

=head2 confidence_interval

 Usage: ($marker_table, $marker_details) = confidence_interval();
 Desc: reads the confidence interval data for the QTL from a 
       file containing the genome-wide confidence intervals 
       and their lod profile. It calculates the left and right 
       markers, their position values; and some interpretation of 
       the data etc..   
 Ret: an array ref of marker details table (for the viewer) 
      and a ref to a hash of hash for the  marker details 
      (for later access to the data)  
 Args:
 Side Effects:
 Example:

=cut



sub confidence_interval
{    
    my $ci_lod_file = $pop->ci_lod_file( $c, 
					$pop->cvterm_acronym( $trait_name )
	);
   
    my (@marker_lods,  @all_lods, @all_positions, @marker_html);
    my %marker_details_of = ();
      
    my @rows =  grep { /\t$lg\t/ } read_file( $ci_lod_file );
   
    my $rnd  = Number::Format->new();

    foreach my $row (@rows) {
	my ( $m, $m_chr, $m_pos, $m_lod ) = split (/\t/, $row);
	push @all_lods, $m_lod;
	push @all_positions, $m_pos;	
	
	my $marker = CXGN::Marker->new_with_name( $dbh, $m );
		
	unless  ( !$marker ) 
	{
	    push @marker_lods, $m_lod;   
	}    
    }
    
    my $peak_marker_lod = $rnd->round(max( @marker_lods), 2 );
    my $highest_lod     = $rnd->round(max( @all_lods), 2 );
    my $right_position  = $rnd->round(max( @all_positions), 2 );
    my $left_position   = $rnd->round(min( @all_positions), 2 );

    my ($peak_marker, $linkage_group, $peak_position) = split (/\t/, $rows[1]);
    $peak_position = $rnd->round($peak_position, 1);
    
    foreach my $row ( @rows ) 
    {  
	my ($m, $m_chr, $m_pos, $m_lod)  = split (/\t/, $row);
	$m_pos = $rnd->round( $m_pos, 2 );
	$m_lod = $rnd->round( $m_lod, 2 );

	my $marker = CXGN::Marker->new_with_name( $dbh, $m );	   
	    
	unless ( !$marker )
	{
		
	    $marker_details_of{$m}{name}          = $m;
	    $marker_details_of{$m}{linkage_group} = $m_chr;
	   
            $marker_details_of{$m}{position}  = !$m_pos && $m_pos ne '' ? '0.0' 
                                              : $m_pos eq '' ? 'NA' 
                                              : $m_pos
                                              ; 	

	    $marker_details_of{$m}{lod_score} = $m_lod;
	    	
	    if ($m eq $p_m) { $marker_details_of{$m}{orientation} = 'peak'; }
	    if ($m_pos == $right_position) { $marker_details_of{$m}{orientation} = 'right'; }
	    if ($m_pos == $left_position) { $marker_details_of{$m}{orientation} = 'left'; }
		
	    my $m_id    = $marker->marker_id();
	    my $remark1 = "<i>Highest LOD score is $highest_lod at $peak_position cM</i>."  if $m_lod == $peak_marker_lod;
	    my $remark2 = "<i>The closest marker to the peak position ($peak_position cM)</i>."  if $m eq $p_m;
      				
	    push @marker_html,
	    [
	     map { $_ } (
		 qq | <a href="/search/markers/markerinfo.pl?marker_id=$m_id">$m</a>|,
		 $marker_details_of{$m}{position},
		 $m_lod,
		 $remark1 . $remark2,
	     )
	    ];
	} 
    }
     

    return \@marker_html, \%marker_details_of;

}

=head2 trait_name

 Usage: $trait_name = trait_name()
 Desc: returns the name of the QTL trait
 Ret: trait name
 Args: None
 Side Effects:
 Example:

=cut


sub trait_name
{
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

=head2 legend

 Usage: $legend = legend();
 Desc: generates the appropriate legend describing the 
       statistical methods and parameters used for the
       QTL analysis
 Ret: an array ref 
 Args: None
 Side Effects:
 Example:

=cut


sub legend
{
    my $user_id;
    if ($c->user) {
        $user_id = $c->user->get_object->get_sp_person_id;
    } else {
        $user_id = $pop->get_sp_person_id();
    }

    my $qtl            = CXGN::Phenome::Qtl->new( $user_id );
    my $user_stat_file = $qtl->get_stat_file( $c, $pop_id );
    my @stat;
    my $ci;

    open my $uf, "<", $user_stat_file or die "$! reading $user_stat_file";
    while ( my $row = <$uf> )
    {
        chomp($row);
        my ( $parameter, $value ) = split( /\t/, $row );

        if ( $parameter =~ /qtl_method/ )
        {
            $parameter = 'Mapping method';
        }
        if ( $parameter =~ /qtl_model/ )
        {
            $parameter = 'Mapping model';
        }
        if ( $parameter =~ /prob_method/ )
        {
            $parameter = 'QTL genotype probability method';
        }
        if ( $parameter =~ /step_size/ )
        {
            $parameter = 'Genome scan size (cM)';
        }
        if ( $parameter =~ /permu_level/ )
        {
            $parameter = 'Permutation significance level';
        }
        if ( $parameter =~ /permu_test/ ) {
            $parameter = 'No. of permutations';
        }
        if ( $parameter =~ /prob_level/ )
        {
            $parameter = 'QTL genotype significance level';
        }
        if ( $parameter =~ /stat_no_draws/ )
        {
            $parameter = 'No. of imputations';
        }
        if ( $value eq 'zero' || $value eq 'Marker Regression' )
        {
            $ci = 'none';
        }

        unless ( ( $parameter =~ /No. of imputations/ && !$value )
            || ( $parameter =~ /QTL genotype probability/ && !$value )
            || ( $parameter =~ /Permutation significance level/ && !$value ) )

        {
            push @stat, [ $parameter, $value ];

        }
    }

    foreach my $st ( @stat )
    {
        foreach my $i ( @$st )
        {
            if ( $i =~ /zero/ )
            {
                foreach my $s ( @stat )
                {
                    foreach my $j (@$s)
                    {
                        $j =~ s/Maximum Likelihood/Marker Regression/;
                        $ci = 'none';
                    }
                }
            }
        }
    }

    if ( !$lod )
    {
        $lod = qq |<i>Not calculated</i>|;
    }

    push @stat, [ map {$_} ( 'LOD threshold', $lod ) ];

    unless ($ci)
    {
        push @stat,
            [ map {$_} ( 'Confidence interval',
                         'Based on 95% Bayesian Credible Interval'
              )
            ];
    }

    return \@stat;

}


sub download_qtl_region 
{
my $link = qq | <a href="https://www.eu-sol.wur.nl/marker2seq/marker2seq.do?marker1=$l_m&marker2=$r_m">View/download</a> genetic markers in the tomato F2.2000 reference map region (+5cM) matching the QTL region and gene models from the ITAG annotated tomato genome. |;

$link  .=   qq | <p><i>Courtesy of</i> <a href="http://www.eu-sol.wur.nl"><img src ="/img/eusol_logo_small.jpg"/></a></p> |;

    return $link;

}


=head2 comment

 Usage: $comment = comment();
 Desc: generates the comment section html
 Ret: the comment html
 Args:
 Side Effects:
 Example:

=cut


sub comment
{
    my $comment;
    if ($pop_id)
    {
        my $page_comment_obj =
            CXGN::People::PageComment->new( $dbh, "population", $pop_id,
                                    "/phenome/qtl.pl?population_id=$pop_id" );
        $comment = $page_comment_obj->get_html();
    }
    return $comment;

}


sub order_by_position {
    my ($marker_html, $markers_details) = confidence_interval();
    my @marker_html = sort { $a->[1] <=> $b->[1] }  @$marker_html;
    return \@marker_html;
}
