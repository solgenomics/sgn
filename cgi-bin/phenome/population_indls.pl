#!/usr/bin/perl -w

=head1 DESCRIPTION

Creates a trait/cvterm page with a description of 
the population on which the trait/cvterm was evaluated, 
displays the frequency distribution of its phenotypic data
and most importantly produces the on-the-fly  QTL analysis 
output for the trait and more.... 

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

my $population_indls_detail_page =
  CXGN::Phenome::PopulationIndlsDetailPage->new();

package CXGN::Phenome::PopulationIndlsDetailPage;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw /info_section_html
  page_title_html
  columnar_table_html
  html_optional_show
  info_table_html
  tooltipped_text
  html_alternate_show
  /;

use CXGN::Phenome::Population;
use CXGN::Phenome::Qtl;
use CXGN::Phenome::PopulationDbxref;
use CXGN::Tools::WebImageCache;
use SGN::Context;
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;

use GD;
use GD::Graph::bars;
use GD::Graph::lines;
use GD::Graph::points;
use GD::Graph::Map;
use Statistics::Descriptive;
use Math::Round::Var;
use File::Temp qw /tempfile tempdir/;
use File::Copy;
use File::Spec;
use File::Basename;
use File::stat;
use Cache::File;
use CXGN::Scrap::AjaxPage;
use CXGN::Contact;
use Storable qw / store /;


use CXGN::Page::UserPrefs;
use base qw / CXGN::Page::Form::SimpleFormPage CXGN::Phenome::Main/;

sub new
{
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->set_script_name("population_indls.pl");

    return $self;
}

sub define_object
{
    my $self = shift;

    $self->set_dbh( CXGN::DB::Connection->new() );
    my %args          = $self->get_args();
    my $population_id = $args{population_id};
    unless ( !$population_id || $population_id =~ m /^\d+$/ )
    {
        $self->get_page->message_page(
                          "No population exists for identifier $population_id");
    }
    $self->set_object_id($population_id);
    $self->set_object(
                       CXGN::Phenome::Population->new(
                                        $self->get_dbh(), $self->get_object_id()
                       )
                     );
    $self->set_primary_key("population_id");
    $self->set_owners( $self->get_object()->get_owners() );
}

sub generate_form
{
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();

    my $population    = $self->get_object();
    my $population_id = $self->get_object_id();
    my $type_id       = $args{type_id};
    my $type          = $args{type};
    my $pop_name      = $population->get_name();
    my $pop_link =
qq |<a href="/phenome/population.pl?population_id=$population_id">$pop_name</a> |;

    my $sp_person_id = $population->get_sp_person_id();
    my $submitter    = CXGN::People::Person->new( $self->get_dbh(),
                                              $population->get_sp_person_id() );
    my $submitter_name =
      $submitter->get_first_name() . " " . $submitter->get_last_name();
    my $submitter_link =
qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;

    my $login_user    = $self->get_user();
    my $login_user_id = $login_user->get_sp_person_id();
    my $form          = undef;
    if (
         $self->get_action() =~ /edit|store/
         && (    $login_user_id = $submitter
              || $self->get_user()->get_user_type() eq 'curator' )
       )
    {
        print STDERR "Generating EditableForm..\n";
        $form = CXGN::Page::Form::Editable->new();
    }
    else
    {
        print STDERR "Generating static Form...\n";
        $form = CXGN::Page::Form::Static->new();
    }

    $form->add_label(
                      display_name => "Name:",
                      field_name   => "name",
                      contents     => $pop_link,
                    );

    $form->add_textarea(
                         display_name => "Description: ",
                         field_name   => "description",
                         object       => $population,
                         getter       => "get_description",
                         setter       => "set_description",
                         columns      => 40,
                         rows         => 4,
                       );

    $form->add_label(
                      display_name => "Uploaded by: ",
                      field_name   => "submitter",
                      contents     => $submitter_link,
                    );
    $form->add_hidden( field_name => "population_id",
                       contents   => $args{population_id} );

    $form->add_hidden(
                       field_name => "sp_person_id",
                       contents   => $self->get_user()->get_sp_person_id(),
                       object     => $population,
                       setter     => "set_sp_person_id",
                     );

    $form->add_hidden( field_name => "action", contents => "store" );

    $self->set_form($form);

    if ( $self->get_action =~ /view|edit/ )
    {
        $self->get_form->from_database();

    }
    elsif ( $self->get_action =~ /store/ )
    {
        $self->get_form->from_request( $self->get_args() );

    }

}

sub display_page
{
    my $self = shift;

    $self->get_page->jsan_use("jQuery");
    $self->get_page->jsan_use("thickbox");

    $self->get_page->add_style( text => <<EOS);
a.abstract_optional_show {
  color: blue;
  cursor: pointer;
  white-space: nowrap;
}
div.abstract_optional_show {
  background: #f0f0ff;
  border: 1px solid #9F9FC7;
  margin: 0.2em 1em 0.2em 1em;
  padding: 0.2em 0.5em 0.2em 1em;
}
EOS

    my %args      = $self->get_args();
    my $cvterm_id = $args{cvterm_id};

    my $dbh = $self->get_dbh();

    my $population      = $self->get_object();
    my $population_id   = $self->get_object_id();
    my $population_name = $population->get_name();

    my ( $term_obj, $term_name, $term_id );

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    #used to show certain elements to only the proper users
    my $login_user      = $self->get_user();
    my $login_user_id   = $login_user->get_sp_person_id();
    my $login_user_type = $login_user->get_user_type();

    $self->get_page()
      ->header(" SGN: $term_name values in population $population_name");

    print page_title_html(
                    "SGN: $term_name values in population $population_name \n");

    my $population_html = $self->get_edit_link_html() . qq |<a href="qtl_form.pl">[New QTL Population]</a><br/>|;

    #print all editable form  fields
    $population_html .= $self->get_form()->as_table_string();
    my $population_obj = $self->get_object();

    
    my $page =
"../phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$term_id";
    $args{calling_page} = $page;

    my $pubmed;
    my $url_pubmed = qq | http://www.ncbi.nlm.nih.gov/pubmed/|;

    my @publications = $population->get_population_publications();
    my $abstract_view;
    my $abstract_count = 0;

    foreach my $pub (@publications)
    {
        my (
             $title,    $abstract, $authors, $journal,
             $pyear,    $volume,   $issue,   $pages,
             $obsolete, $pub_id,   $accession
           );
        $abstract_count++;

        my @dbxref_objs = $pub->get_dbxrefs();
        my $dbxref_obj  = shift(@dbxref_objs);
        $obsolete =
          $population_obj->get_population_dbxref($dbxref_obj)->get_obsolete();

        if ( $obsolete eq 'f' )
        {
            $pub_id = $pub->get_pub_id();

            $title    = $pub->get_title();
            $abstract = $pub->get_abstract();
            $pyear    = $pub->get_pyear();
            $volume   = $pub->get_volume();
            $journal  = $pub->get_series_name();
            $pages    = $pub->get_pages();
            $issue    = $pub->get_issue();

            $accession = $dbxref_obj->get_accession();
            my $pub_info =
qq|<a href="/chado/publication.pl?pub_id=$pub_id" >PMID:$accession</a> |;
            my @authors;
            my $authors;

            if ($pub_id)
            {

                my @pubauthors_ids = $pub->get_pubauthors_ids($pub_id);

                foreach my $pubauthor_id (@pubauthors_ids)
                {
                    my $pubauthor_obj =
                      CXGN::Chado::Pubauthor->new( $self->get_dbh,
                                                   $pubauthor_id );
                    my $last_name   = $pubauthor_obj->get_surname();
                    my $first_names = $pubauthor_obj->get_givennames();
                    my @first_names = split( /,/, $first_names );
                    $first_names = shift(@first_names);
                    push @authors, ( "$first_names" . "  " . "$last_name" );
                    $authors = join( ", ", @authors );
                }
            }

            $abstract_view = html_optional_show(
                "abstracts$abstract_count",
                'Show/hide abstract',
qq|$abstract <b> <i>$authors.</i> $journal. $pyear. $volume($issue). $pages.</b>|,
                0,                         #< do not show by default
                'abstract_optional_show'
                ,    #< don't use the default button-like style
                                               );

            $pubmed .=
qq|<div><a href="$url_pubmed$accession" target="blank">$pub_info</a> $title $abstract_view </div> |;
        }
    }

    print info_section_html( title    => 'Population Details',
                             contents => $population_html, );

    my $is_public = $population->get_privacy_status();
    my ( $submitter_obj, $submitter_link ) = $self->submitter();

    if (    $is_public
         || $login_user_type eq 'curator'
         || $login_user_id == $population->get_sp_person_id() )
    {

	my $phenotype = "";
	my @phenotype;

	my ( $indl_id, $indl_name, $indl_value ) =
	    $population->get_all_indls_cvterm($term_id);

	my ( $min, $max, $avg, $std, $count ) =
	    $population->get_pop_data_summary($term_id);

	for ( my $i = 0 ; $i < @$indl_name ; $i++ )
	{

	    push @phenotype,
	    [
	     map { $_ } (
		 qq | <a href="/phenome/individual.pl?individual_id=$indl_id->[$i]">$indl_name->[$i]</a>|,
                $indl_value->[$i]
	     )
	    ];
	}

	my ( $phenotype_data, $data_view, $data_download );
	my $all_indls_count = scalar(@$indl_name);

	if (@phenotype)
	{
	    $phenotype_data = columnar_table_html(
		headings => [
		    'Plant accession',
		    'Value',

		],
		data         => \@phenotype,
		__alt_freq   => 2,
		__alt_width  => 1,
		__alt_offset => 3,
		__align      => 'l',
                                             );

	    $data_view = html_optional_show(
                      "phenotype",
                      'View/hide phenotype raw data',
                      qq |$phenotype_data|,
                      0,                                #<  show data by default
                                       );
	    $data_download .=
qq { Download population: <span><a href="pop_download.pl?population_id=$population_id"><b>\[Phenotype raw data\]</b></a><a href="genotype_download.pl?population_id=$population_id"><b>[Genotype raw data]</b></a></span> };
    }


        my (
             $image_pheno, $title_pheno, $image_map_pheno,
             $plot_html,   $normal_dist
           );
        ( $image_pheno, $title_pheno, $image_map_pheno ) =
          population_distribution($population_id);
        $plot_html .= "<table  cellpadding = 5><tr><td>";
        $plot_html .= $image_pheno . $image_map_pheno;
        $plot_html .= "</td><td>";
        $plot_html .= $title_pheno . "<br/>";
        $plot_html .= <<HTML;
        <b>Data Summay:</b><br />
	<b>No. of observation units:</b> $all_indls_count<br /> 
        <b>Minimum:</b> $min<br /> 
        <b>Maximum:</b> $max <br /> 
        <b>Mean:</b> $avg <br /> 
        <b>Standard deviation:</b> $std<br />
HTML

        $plot_html .= "</td></tr></table>";

        my $qtl_image           = $self->qtl_plot();
  
	my $legend = $self->legend($population);
	my $qtl_html = "<table><tr><td width=70%>$qtl_image</td><td width=30%>$legend</td></tr></table>";

        print info_section_html( 
                                title    => 'QTL(s)',
                                contents => $qtl_html, 
                                );

        print info_section_html( 
	                        title    => 'Phenotype Frequency Distribution',
                                contents => $plot_html . $normal_dist, 
                               );
   
	print info_section_html( 
	                        title    => 'Phenotype Data', 
	 	                contents => $data_view . " " . $data_download, 
	 	               ); 

    }
    else
    {
        my $message =
          "The QTL data for this trait in this population is not public yet. 
                       If you would like to know more about this data, 
                       please contact the owner of the data: <b>$submitter_link</b> 
                       or email to SGN:
                       <a href=mailto:sgn-feedback\@sgn.cornell.edu>
                       sgn-feedback\@sgn.cornell.edu</a>.\n";

        print info_section_html( title    => 'QTL(s)',
                                 contents => $message );
    }

    print info_section_html(
                           title => 'Literature Annotation',
                           contents => $pubmed,
                           );

    if ($population_name)
    {
        my $page_comment_obj =
	    CXGN::People::PageComment->new( $self->get_dbh(), "population",
					    $population_id,
					    $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args()
	    );
        print $page_comment_obj->get_html();
    }

    $self->get_page()->footer();

    exit();
}

# override store to check if a locus with the submitted symbol/name already exists in the database

sub store
{
    my $self          = shift;
    my $population    = $self->get_object();
    my $population_id = $self->get_object_id();
    my %args          = $self->get_args();

    $self->SUPER::store(0);

    exit();
}

sub population_distribution
{
    my $self = shift;
    my $doc  = CXGN::Scrap::AjaxPage->new();

    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = CXGN::DB::Connection->new();

    my ( $term_obj, $term_name, $term_id );

    my $pop = CXGN::Phenome::Population->new( $dbh, $pop_id );

    if ( $pop->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $vh           = SGN::Context->new();
    my $basepath     = $vh->get_conf("basepath");
    my $tempfile_dir = $vh->get_conf("tempfiles_subdir");

    my $cache = CXGN::Tools::WebImageCache->new(1);
    $cache->set_basedir($basepath);
    $cache->set_temp_dir( $tempfile_dir . "/temp_images" );
    $cache->set_expiration_time(259200);
    $cache->set_key( "popluation_distribution" . $pop_id . $term_id );
    $cache->set_map_name("popmap$pop_id$term_id");

    my $pop_name;
    my ( $variance, $std,     $mean );
    my ( @value,    @indl_id, @indl_name );

    $cache->set_force(0);
    if ( !$cache->is_valid() )
    {
        my $pop_obj = CXGN::Phenome::Population->new( $dbh, $pop_id );
        $pop_name = $pop_obj->get_name();
        my ( $indl_id, $indl_name, $value ) = $pop_obj->plot_cvterm($term_id);
        my @indl_id   = @{$indl_id};
        my @indl_name = @{$indl_name};
        @value = @{$value};

        my $round = Math::Round::Var->new(0.001);

        my $stat = Statistics::Descriptive::Full->new();

        $stat->add_data(@value);

        my $stat_para = Statistics::Descriptive::Sparse->new();
        $stat_para->add_data(@value);
        $std  = $stat_para->standard_deviation();
        $mean = $stat_para->mean();

        my %f = $stat->frequency_distribution(10);

        my ( @keys, @counts );

        for ( sort { $a <=> $b } keys %f )
        {
            my $key = $round->round($_);
            push @keys,   $key;
            push @counts, $f{$_};
        }

        my $min = $stat->min();
        if ( $min != 0 )
        {
            $min = $min - 0.01;
        }

        my @keys_range = $min . '-' . $keys[0];

        my $range;
        my $previous_k   = $keys[0];
        my $keys_shifted = shift(@keys);
        foreach my $k (@keys)
        {
            $range = $previous_k . '-' . $k;
            push @keys_range, $range;
            $previous_k = $k;
        }

        my $max = $counts[0];
        foreach my $i ( @counts[ 1 .. $#counts ] )
        {
            if ( $i > $max ) { $max = $i; }
        }
        $max = int( $max + ( $max * 0.1 ) );

        my $c_html;
        my @c_html;
        my ( $lower, $upper );

        foreach my $k (@keys_range)
        {
            ( $lower, $upper ) = split( /-/, $k );
            $c_html =
qq | /phenome/indls_range_cvterm.pl?cvterm_id=$term_id&amp;lower=$lower&amp;upper=$upper&amp;population_id=$pop_id |;
            push @c_html, $c_html;

        }

        my @bar_clr = ("orange");
        my @data    = ( [@keys_range], [@counts] );
        my $graph   = new GD::Graph::bars();

        $graph->set_title_font('gdTinyFont');
        $graph->set(
                     title             => " ",
                     x_label           => "Ranges for $term_name",
                     y_label           => "Frequency",
                     y_max_value       => $max,
                     x_all_ticks       => 1,
                     y_all_ticks       => 2,
                     y_label_skip      => 5,
                     y_plot_values     => 0,
                     x_label_skip      => 1,
                     width             => 400,
                     height            => 400,
                     bar_width         => 30,
                     x_labels_vertical => 1,
                     show_values       => 1,
                     textclr           => "black",
                     dclrs             => \@bar_clr,
                   );

        $cache->set_image_data( $graph->plot( \@data )->png );

        my $map = new GD::Graph::Map(
                                      $graph,
                                      hrefs       => [ \@c_html ],
                                      noImgMarkup => 1,
                                      mapName     => "popmap$pop_id$term_id",
                                      info        => "%x: %y lines",
                                    );
        $cache->set_image_map_data(
                      $map->imagemap( "popimage$pop_id$term_id.png", \@data ) );

    }

    my $image_map = $cache->get_image_map_data();
    my $image     = $cache->get_image_tag();
    my $title =
"Frequency distribution of experimental lines from population $pop_name evaluated for $term_name. Bars represent the number of experimental lines with $term_name values greater than the lower limit but less or equal to the upper limit of the range.";

    return $image, $title, $image_map;
}

sub qtl_plot
{

    my $self = shift;
    my $doc  = CXGN::Scrap::AjaxPage->new();

    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = $self->get_dbh();

    my $population     = $self->get_object();
    my $pop_name       = $population->get_name();
    my $mapversion     = $population->mapversion_id();
    my @linkage_groups = $population->linkage_groups();

 
    my ( $term_obj, $term_name, $term_id );

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $ac = $population->cvterm_acronym($term_name);

    my $vh           = SGN::Context->new();
    my $basepath     = $vh->get_conf("basepath");
    my $tempfile_dir = $vh->get_conf("tempfiles_subdir");

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();
    my $cache_tempimages = Cache::File->new( cache_root => $tempimages_path );
    $cache_tempimages->purge();

    my ( @marker,  @chr,  @pos,   @lod );
    my ( @chr_qtl, @left, @right, @peak );
    my ( $qtl_image, $image, $image_t, $image_url, $image_html, $image_t_url,
         $thickbox, $title, $l_m, $p_m, $r_m );

    my $round1 = Math::Round::Var->new(0.1);
    my $round2 = Math::Round::Var->new(1);

    $qtl_image  = $self->qtl_images_exist();
    my $permu_data = $self->permu_values_exist();
    
    unless ( $qtl_image && $permu_data )
    {

        my ( $qtl_summary, $flanking_markers ) = $self->run_r();

        open QTLSUMMARY, "<$qtl_summary" or die "can't open $qtl_summary: $!\n";

        my $header = <QTLSUMMARY>;
        while ( my $row = <QTLSUMMARY> )
        {
            my ( $marker, $chr, $pos, $lod ) = split( /\t/, $row );
            push @marker, $marker;
            push @chr,    $chr;
            $pos = $round2->round($pos);
            push @pos, $pos;
            $lod = $round1->round($lod);
            push @lod, $lod;
        }

        my @o_lod = sort(@lod);
        my $max   = $o_lod[-1];
        $max = $max + (0.5);

        close QTLSUMMARY;

        open MARKERS, "<$flanking_markers"
          or die "can't open $flanking_markers: !$\n";

        $header = <MARKERS>;
        while ( my $row = <MARKERS> )
	   
        {
	    chomp($row);
            my ($trash, $chr_qtl, $left, $peak, $right, $peakmarker ) = split( /\t/, $row );
            push @chr_qtl, $chr_qtl;
            push @left,    $left;
            push @right,   $right;
            push @peak, $peakmarker;
        }

        close MARKERS;
	my (@h_markers, @chromosomes, @lk_groups);
	my $h_marker;


	@lk_groups = @linkage_groups;
	@lk_groups = sort ( { $a <=> $b } @lk_groups );
	for ( my $i = 0 ; $i < @left ; $i++ )
	{
	    my $lg           = shift(@lk_groups);
	    my $key_h_marker = "$ac" . "_pop_" . "$pop_id" . "_chr_" . $lg;
	    $h_marker = $cache_tempimages->get($key_h_marker);

	    unless ($h_marker)
	    {

		push @chromosomes, $lg;
		$l_m = $left[$i];
		$r_m = $right[$i];
		$p_m = $peak[$i];
		my $l_pos =
		    $population->get_marker_position( $mapversion, $l_m );
		my $r_pos =
		    $population->get_marker_position( $mapversion, $r_m );



		my $permu_threshold_ref = $self->permu_values();
		my %permu_threshold     = %$permu_threshold_ref;
		my @p_keys;
		foreach my $key ( keys %permu_threshold )
		{
		    if ( $key =~ m/^\d./ )
		    {
			push @p_keys, $key;
		    }

		}
		my $lod1 = $permu_threshold{ $p_keys[0] };
		# my $log2 = $permu_threshold{ $p_keys[1] };           
		
		$h_marker = 
		    qq |/phenome/qtl.pl?population_id=$pop_id&amp;term_id=$term_id&amp;chr=$lg&amp;l_marker=$l_m&amp;p_marker=$p_m&amp;r_marker=$r_m&amp;lod=$lod1|;
 #$h_marker =
#qq |../cview/view_chromosome.pl?map_version_id=$mapversion&chr_nr=$lg&show_ruler=1&show_IL=&show_offsets=1&comp_map_version_id=&comp_chr=&color_model=&show_physical=&size=&show_zoomed=1&confidence=-2&hilite=$l_m+$p_m+$r_m&marker_type=&cM_start=$l_pos&cM_end=$r_pos |;

		$cache_tempimages->set( $key_h_marker, $h_marker, '30 days' );
	    }

	    push @h_markers, $h_marker;
	}
       
        my $count       = 0;
        my $old_chr_chr = 1;
        my (
             $chr_chr, $image,     $image_t,
             $thickbox,  $max_chr, $chr_chr_e, $marker_chr_e,
             $pos_chr_e, $lod_chr_e
           );
        my $chrs = ( scalar(@chromosomes) ) + 1;

        for ( my $i = 1 ; $i < $chrs ; $i++ )
        {
            my ( @marker_chr, @chr_chr, @pos_chr, @lod_chr, @data, @m_html ) =
              ();
            my ( $marker_chr, $pos_chr, $lod_chr, $max_chr );

            $h_marker = shift(@h_markers);

            if ( ( $i == $old_chr_chr ) && ( $i != 12 ) )
            {
                push @marker_chr, $marker_chr_e;
                push @chr_chr,    $chr_chr_e;
                $pos_chr_e = $round2->round($pos_chr_e);
                push @pos_chr, $pos_chr_e;
                $lod_chr = $round1->round($lod_chr_e);
                push @lod_chr, $lod_chr_e;
            }

            my $cache_qtl_plot = CXGN::Tools::WebImageCache->new(1);
            $cache_qtl_plot->set_basedir($basepath);
            $cache_qtl_plot->set_temp_dir( $tempfile_dir . "/temp_images" );
            $cache_qtl_plot->set_expiration_time(259200);
            $cache_qtl_plot->set_key(
                                "qtlplot" . $i . "small" . $pop_id . $term_id );
            $cache_qtl_plot->set_force(0);

            if ( !$cache_qtl_plot->is_valid() )
            {

                for ( my $j = 0 ; $j < @marker ; $j++ )
                {

                    $chr_chr = $chr[$j];

                    if ( $i == $chr_chr )
                    {
                        $marker_chr = $marker[$j];

                        $pos_chr = $pos[$j];
                        $lod_chr = $lod[$j];

                        push @marker_chr, $marker_chr;
                        push @chr_chr,    $chr_chr;
                        $pos_chr = $round2->round($pos_chr);
                        push @pos_chr, $pos_chr;
                        $lod_chr = $round1->round($lod_chr);
                        push @lod_chr, $lod_chr;

                        ( $chr_chr_e, $marker_chr_e, $pos_chr_e, $lod_chr_e ) =
                          ();
                    }

                    elsif ( $i != $chr_chr )
                    {

                        $chr_chr_e    = $chr[$j];
                        $marker_chr_e = $marker[$j];
                        $pos_chr_e    = $pos[$j];
                        $lod_chr_e    = $lod[$j];
                    }

                }

                @data = ( [ (@pos_chr) ], [@lod_chr] );
                my $graph = new GD::Graph::lines( 110, 110 );
                $graph->set_title_font('gdTinyFont');
                $graph->set(
                             title             => " ",
                             x_label           => "Chr $i (cM)",
                             y_label           => "LOD",
                             y_max_value       => 10,
                             x_all_ticks       => 5,
                             y_all_ticks       => 1,
                             y_label_skip      => 1,
                             y_plot_values     => 1,
                             x_label_skip      => 5,
                             x_plot_values     => 1,
                             x_labels_vertical => 1,
                             textclr           => "black"
                           );

                $cache_qtl_plot->set_image_data( $graph->plot( \@data )->png );

            }

            $image      = $cache_qtl_plot->get_image_tag();
            $image_url  = $cache_qtl_plot->get_image_url();
           # $image_html = qq |<a href ="$h_marker&qtl=$image_url">$image</a>|;

###########thickbox
            my $cache_qtl_plot_t = CXGN::Tools::WebImageCache->new(1);
            $cache_qtl_plot_t->set_basedir($basepath);
            $cache_qtl_plot_t->set_temp_dir( $tempfile_dir . "/temp_images" );
            $cache_qtl_plot_t->set_expiration_time(259200);
            $cache_qtl_plot_t->set_key(
                          "qtlplot_" . $i . "_thickbox_" . $pop_id . $term_id );
            $cache_qtl_plot_t->set_force(0);

            if ( !$cache_qtl_plot_t->is_valid() )
            {
                my @o_lod_chr = sort { $a <=> $b } @lod_chr;
                $max_chr = pop(@o_lod_chr);
                $max_chr = $max_chr + (0.5);

                my $graph_t = new GD::Graph::lines( 420, 420 );
                $graph_t->set_title_font('gdTinyFont');
                $graph_t->set(
                               title             => " ",
                               x_label           => "Chromosome $i (cM)",
                               y_label           => "LOD",
                               y_max_value       => $max_chr,
                               x_all_ticks       => 5,
                               y_all_ticks       => 1,
                               y_label_skip      => 1,
                               y_plot_values     => 1,
                               x_label_skip      => 5,
                               x_plot_values     => 1,
                               x_labels_vertical => 1,
                               textclr           => "black"
                             );

                $cache_qtl_plot_t->set_image_data(
                                                $graph_t->plot( \@data )->png );

            }

            $image_t     = $cache_qtl_plot_t->get_image_tag();
            $image_t_url = $cache_qtl_plot_t->get_image_url();
	  	
            $thickbox =
qq | <a href="$image_t_url" title="<a href=$h_marker&amp;qtl=$image_t_url><font color=#f87431><b>>>>Go to the QTL page>>>> </b></font></a>" class="thickbox" rel="gallary-qtl"> <img src="$image_url" alt="Chromosome $i $image_t_url $image_url" /> </a> |;

            $qtl_image .= $thickbox;
            $title       = "  ";
            $old_chr_chr = $chr_chr;
        }
    }

    return $qtl_image;
}

=head2 infile_list
 Usage: my $file_in = $self->infile_list();
 Desc: returns an R input tempfile containing a tempfile 
       holding the cvterm acronym, pop id, a filepath to the phenotype dataset file, 
        a filepath to genotype dataset file, a filepath to the permuation file.
 Ret: an R input tempfile name (with abosulte path)
 Args:
 Side Effects:
 Example:


=cut

sub infile_list
{

    my $self = shift;
    my $doc  = CXGN::Scrap::AjaxPage->new();

    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = $self->get_dbh();

    my ( $term_obj, $term_name, $term_id );
    my $population = $self->get_object();

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $ac = $population->cvterm_acronym($term_name);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $prod_permu_file  = $self->permu_file();
    my $gen_dataset_file = $self->genotype_file();
    my $phe_dataset_file = $self->phenotype_file();
    my $crosstype_file   = $self->crosstype_file();
  
    my $input_file_list_temp =
      File::Temp->new(
                       TEMPLATE => "infile_list_${ac}_$pop_id-XXXXXX",
                       DIR      => $prod_temp_path,
                       UNLINK   => 0,
                     );
    my $file_in = $input_file_list_temp->filename();

    my $file_cvin = File::Temp->new(
                                     TEMPLATE => 'cv_input-XXXXXX',
                                     DIR      => $prod_temp_path,
                                     UNLINK   => 0,
                                   );
    my $file_cv_in = $file_cvin->filename();

    open CV, ">$file_cv_in" or die "can't open $file_cv_in: $!\n";
    print CV $ac;
    close CV;

    my $file_in_list = join( "\t",
                             $file_cv_in,       "P$pop_id",
                             $gen_dataset_file, $phe_dataset_file,
                             $prod_permu_file, $crosstype_file);

    open FI, ">$file_in" or die "can't open $file_in: $!\n";
    print FI $file_in_list;
    close FI;

    return $file_in;

}

=head2 outfile_list

 Usage: my ($file_out, $qtl_summary, $flanking_markers) = $self->outfile_list();
 Desc: returns an R output tempfile containing a tempfile supposed to hold the qtl 
       mapping output and another tempfile for the qtl flanking markers 
       and the qtl mapping output and qtl flanking markers files separately 
       (convenient for reading their data when plotting the qtl)   
 Ret: R output file names (with abosulte path)
 Args:
 Side Effects:
 Example:

=cut

sub outfile_list
{
    my $self = shift;

    my $doc = CXGN::Scrap::AjaxPage->new();

    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = $self->get_dbh();

    my ( $term_obj, $term_name, $term_id );
    my $population = $self->get_object();

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $ac = $population->cvterm_acronym($term_name);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $output_file_list_temp =
      File::Temp->new(
                       TEMPLATE => "outfile_list_${ac}_$pop_id-XXXXXX",
                       DIR      => $prod_temp_path,
                       UNLINK   => 0,
                     );
    my $file_out = $output_file_list_temp->filename();

    my $qtl_temp = File::Temp->new(
                                 TEMPLATE => "qtl_summary_${ac}_$pop_id-XXXXXX",
                                 DIR      => $prod_temp_path,
                                 UNLINK   => 0
    );
    my $qtl_summary = $qtl_temp->filename;

    my $marker_temp = File::Temp->new(
                            TEMPLATE => "flanking_markers_${ac}_$pop_id-XXXXXX",
                            DIR      => $prod_temp_path,
                            UNLINK   => 0
    );

    my $flanking_markers = $marker_temp->filename;

    my $file_out_list = join(
        "\t",
        $qtl_summary,
        $flanking_markers,

        #$qtl_summary_file,
        #$flanking_markers_file
                            );
    open FO, ">$file_out" or die "can't open $file_out: $!\n";
    print FO $file_out_list;
    close FO;

    return $file_out, $qtl_summary, $flanking_markers;
}

=head2 cache_temp_path

 Usage: my ($prod_cache_path, $prod_temp_path, $tempimages_path) = $self->cache_temp_path();
 Desc: creates the 'r_qtl' dir in the '/data/prod/tmp/' dir; 
      'cache' and 'tempfiles' in the /data/prod/tmp/r_qtl/, 
       and 'temp_images' in the /data/local/cxgn/sgn/documents/tempfiles'      
 Ret: /data/prod/tmp/r_qtl/cache, /data/prod/tmp/r_qtl/tempfiles, 
      /data/local/cxgn/sgn/documents/tempfiles/temp_images
 Args: none
 Side Effects:
 Example:

=cut

sub cache_temp_path
{
    my $vh           = SGN::Context->new();
    my $basepath     = $vh->get_conf("basepath");
    my $tempfile_dir = $vh->get_conf("tempfiles_subdir");

    my $tempimages_path =
      File::Spec->catfile( $basepath, $tempfile_dir, "temp_images" );

    my $prod_temp_path = $vh->get_conf('r_qtl_temp_path');
    mkdir $prod_temp_path;
    my $prod_cache_path = "$prod_temp_path/cache";
    mkdir $prod_cache_path;
    $prod_temp_path = "$prod_temp_path/tempfiles";
    mkdir $prod_temp_path;
    -d $prod_temp_path
      or die "temp dir '$prod_temp_path' not found, and could not create!";
    -r $prod_temp_path or die "temp dir '$prod_temp_path' not readable!";
    -w $prod_temp_path or die "temp dir '$prod_temp_path' not writable!";

    return $prod_cache_path, $prod_temp_path, $tempimages_path;

}

=head2 genotype_file

 Usage: my $gen_file = $self->genotype_file();
 Desc: creates the genotype file in the /data/prod/tmp/r_qtl/cache, 
       if it does not exist yet and caches it for R.
 Ret: genotype filename (with abosolute path)
 Args: none
 Side Effects:
 Example:

=cut

sub genotype_file
{
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();
    my $file_cache = Cache::File->new( cache_root => $prod_cache_path );
    $file_cache->purge();

    my $key_gen          = "popid_" . $pop_id . "_genodata";
    my $gen_dataset_file = $file_cache->get($key_gen);

    unless ($gen_dataset_file)
    {
        my $genodata     = $population->genotype_dataset();
        my $geno_dataset = ${$genodata};

        my $filename = "genodata_" . $pop_id . ".csv";
        my $file     = "$prod_cache_path/$filename";

        open OUT, ">$file" or die "can't open $file: !$\n";
        print OUT $geno_dataset;
        close OUT;

        $file_cache->set( $key_gen, $file, '30 days' );
        $gen_dataset_file = $file_cache->get($key_gen);
    }

    return $gen_dataset_file;

}

=head2 phenotype_file

 Usage: my $gen_file = $self->phenotype_file();
 Desc: creates the phenotype file in the /data/prod/tmp/r_qtl/cache, 
       if it does not exist yet and caches it for R.
 Ret: phenotype filename (with abosolute path)
 Args: none
 Side Effects:
 Example:

=cut

sub phenotype_file
{
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();
    my $file_cache = Cache::File->new( cache_root => $prod_cache_path );

    my $key_phe          = "popid_" . $pop_id . "_phenodata";
    my $phe_dataset_file = $file_cache->get($key_phe);

    unless ($phe_dataset_file)
    {
        my $phenodata     = $population->phenotype_dataset();
        my $pheno_dataset = ${$phenodata};
        my $filename      = "phenodata_" . $pop_id . ".csv";

        my $file = "$prod_cache_path/$filename";

        open OUT, ">$file" or die "can't open $file: !$\n";
        print OUT $pheno_dataset;
        close OUT;

        $file_cache->set( $key_phe, $file, '30 days' );
        $phe_dataset_file = $file_cache->get($key_phe);
    }

    return $phe_dataset_file;

}

=head2 crosstype_file

 Usage: my $gen_file = $self->crosstype_file();
 Desc: creates the crosstype file in the /data/prod/tmp/r_qtl/temp, 
      
 Ret: crossotype filename (with abosolute path)
 Args: none
 Side Effects:
 Example:

=cut

sub crosstype_file
{
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();
 
    my $cross_type = 'bc' if ($population->get_cross_type_id() == 2);
    $cross_type = 'f2' if ($population->get_cross_type_id() == 1);
    
    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
	$self->cache_temp_path();

    my $cross_temp = File::Temp->new(
	                             TEMPLATE => "cross_type_${pop_id}-XXXXXX",
                                     DIR      => $prod_temp_path,
                                     UNLINK   => 0,
	                            );
   

    my $cross_file = $cross_temp->filename;
    
    open CF, ">$cross_file" or die "can't open $cross_file: $!\n";
    print CF $cross_type;
    close FO; 

    return $cross_file;

}



=head2 run_r

 Usage: my ($qtl_summary, $flanking_markers) = $self->run_r();
 Desc: run R in the cluster; copies permutation file from the /data/prod.. 
       to the tempimages dir; returns the R output files (with abosulate filepath) with qtl mapping data 
       and flanking markers 
 Ret: 
 Args:  none
 Side Effects:
 Example:

=cut

sub run_r
{
    my $self = shift;

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();
    my $prod_permu_file = $self->permu_file();
    my $file_in         = $self->infile_list();
    my ( $file_out, $qtl_summary, $flanking_markers ) = $self->outfile_list();
    my $stat_file = $self->stat_files();

    print STDERR "stat file: $stat_file\n";

    CXGN::Tools::Run->temp_base($prod_temp_path);

    my ( $r_in_temp, $r_out_temp ) =
      map {
        my ( undef, $filename ) =
          tempfile(
                    File::Spec->catfile(
                                         CXGN::Tools::Run->temp_base(),
                                         "population_indls.pl-$_-XXXXXX",
                                       ),
                  );
        $filename
      } qw / in out /;

    #copy our R commands into a cluster-accessible tempfile
    my $doc = CXGN::Scrap::AjaxPage->new();

    {
        my $r_cmd_file = $doc->path_to('/cgi-bin/phenome/cvterm_qtl.r');
        copy( $r_cmd_file, $r_in_temp )
          or die "could not copy '$r_cmd_file' to '$r_in_temp'";
    }

    # now run the R job on the cluster
    my $r_process = CXGN::Tools::Run->run_cluster(
        'R', 'CMD', 'BATCH',
        '--slave',
        "--args $file_in $file_out $stat_file",
        $r_in_temp,
        $r_out_temp,
        {
           working_dir => $prod_temp_path,

           # don't block and wait if the cluster looks full
           max_cluster_jobs => 1_000_000_000,
        },
    );

    sleep 1 while $r_process->alive;    #< wait for R to finish
                                        #unlink( $r_in_temp, $r_out_temp );

    copy( $prod_permu_file, $tempimages_path )
      or die "could not copy '$prod_permu_file' to '$tempimages_path'";

    return $qtl_summary, $flanking_markers;

}

=head2 permu_file

 Usage: my $permu_file = $self->permu_file();
 Desc: creates the permutation file in the /data/prod/tmp/r_qtl/cache, 
       if it does not exist yet and caches it for R. 
 Ret: permutation filename (with abosolute path)
 Args: none
 Side Effects:
 Example:

=cut

sub permu_file
{
    my $self = shift;
    my $doc  = CXGN::Scrap::AjaxPage->new();
    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = CXGN::DB::Connection->new();

    my $population = CXGN::Phenome::Population->new( $dbh, $pop_id );
    my $pop_name = $population->get_name();

    my ( $term_obj, $term_name, $term_id );

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $ac = $population->cvterm_acronym($term_name);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $file_cache = Cache::File->new( cache_root => $prod_cache_path );

    my $key_permu = "$ac" . "_" . $pop_id . "_permu";
    my $filename  = "permu_" . $ac . "_" . $pop_id;

    my $permu_file = $file_cache->get($key_permu);

    unless ($permu_file)
    {

        my $permu = undef;

        my $permu_file = "$prod_cache_path/$filename";

        open OUT, ">$permu_file" or die "can't open $permu_file: !$\n";
        print OUT $permu;
        close OUT;

        $file_cache->set( $key_permu, $permu_file, '30 days' );
        $permu_file = $file_cache->get($key_permu);
    }

    return $permu_file;

}

=head2 permu_values

 Usage: my $permu_values = $self->permu_values();
 Desc: reads the permutation output from R, 
       creates a hash with the probality level as key and LOD threshold as the value, 
      
 Ret: a hash ref of the permutation values
 Args: none
 Side Effects:
 Example:

=cut

sub permu_values
{
    my $self            = shift;
    my $prod_permu_file = $self->permu_file();

    my %permu_threshold = {};

    my $permu_file = fileparse($prod_permu_file);   
    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();
    $permu_file = File::Spec->catfile( $tempimages_path, $permu_file );

    my $round1 = Math::Round::Var->new(0.1);

    open PERMUTATION, "<$permu_file"
      or die "can't open $permu_file: !$\n";

    my $header = <PERMUTATION>;

    while ( my $row = <PERMUTATION> )
    {
        my ( $significance, $lod_threshold ) = split( /\t/, $row );
        $lod_threshold = $round1->round($lod_threshold);
        $permu_threshold{$significance} = $lod_threshold;
    }

    close PERMUTATION;

    return \%permu_threshold;

}

=head2 permu_values_exist

 Usage: my $permu_value = $self->permu_values_exist();
 Desc: checks if there is permutation value in the permutation file.
 Ret: undef or some value
 Args: none
 Side Effects:
 Example:

=cut

sub permu_values_exist
{
    my $self            = shift;
    my $prod_permu_file = $self->permu_file();

    my ( $size, $permu_file, $permu_data, $tempimages_path, $prod_cache_path,
         $prod_temp_path );

    if ($prod_permu_file)
    {

        $permu_file = fileparse($prod_permu_file);
        ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
          $self->cache_temp_path();
    }

    if ($permu_file)
    {

        $permu_file = File::Spec->catfile( $tempimages_path, $permu_file );
    }

    if ( -e $permu_file )
    {

        open P, "<$permu_file" or die "can't open $permu_file: !$\n";
        my $h = <P>;
        while ( $permu_data = <P> )
        {
            last if ($permu_data);

            # 	    #just checking if there is data in there
        }
        close P;
    }

    if ($permu_data)
    {
        return 1;
    }
    else
    {
        return 0;

    }

}

=head2 qtl_images_exist

 Usage: my $qtl_images_ref = $self->qtl_images_exist();
 Desc: checks and returns a scalar ref if the qtl plots (with thickbox and their links to the comparative viewer) exist in the cache 
 Ret: scalar ref to the images or undef
 Args: none
 Side Effects:
 Example:

=cut

sub qtl_images_exist
{
    my $self = shift;
    my $doc  = CXGN::Scrap::AjaxPage->new();

    my ( $pop_id, $cvterm_id ) =
      $doc->get_encoded_arguments( "population_id", "cvterm_id" );

    my $dbh = $self->get_dbh();

    my $population = $self->get_object();
    my $pop_name   = $population->get_name();

    my @linkage_groups = $population->linkage_groups();
    @linkage_groups = sort ( { $a <=> $b } @linkage_groups );

    my ( $term_obj, $term_name, $term_id );

    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_name();
        $term_id   = $term_obj->get_user_trait_id();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
        $term_name = $term_obj->get_cvterm_name();
        $term_id   = $term_obj->get_cvterm_id();
    }

    my $ac = $population->cvterm_acronym($term_name);

    my $vh           = SGN::Context->new();
    my $basepath     = $vh->get_conf("basepath");
    my $tempfile_dir = $vh->get_conf("tempfiles_subdir");

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $cache_tempimages = Cache::File->new( cache_root => $tempimages_path );
    $cache_tempimages->purge();

    my ( $qtl_image, $image, $image_t, $image_url, $image_html, $image_t_url,
         $thickbox, $title );

    # my $chrs = scalar(@linkage_groups) + 1;

  IMAGES: foreach my $lg (@linkage_groups)
    {
        my $cache_qtl_plot = CXGN::Tools::WebImageCache->new(1);
        $cache_qtl_plot->set_basedir($basepath);
        $cache_qtl_plot->set_temp_dir( $tempfile_dir . "/temp_images" );
      
        my $key = "qtlplot" . $lg . "small" . $pop_id . $term_id;
        $cache_qtl_plot->set_key($key);

        my $key_h_marker = "$ac" . "_pop_" . "$pop_id" . "_chr_" . $lg;
        my $h_marker     = $cache_tempimages->get($key_h_marker);

        if ( $cache_qtl_plot->is_valid )
        {
            $image      = $cache_qtl_plot->get_image_tag();
            $image_url  = $cache_qtl_plot->get_image_url();
           # $image_html = qq |<a href ="$h_marker&$image_url">$image</a>|;

        }

        my $cache_qtl_plot_t = CXGN::Tools::WebImageCache->new(1);
        $cache_qtl_plot_t->set_basedir($basepath);
        $cache_qtl_plot_t->set_temp_dir( $tempfile_dir . "/temp_images" );

        my $key_t = "qtlplot_" . $lg . "_thickbox_" . $pop_id . $term_id;
        $cache_qtl_plot_t->set_key($key_t);

        if ( $cache_qtl_plot_t->is_valid )
        {

            $image_t     = $cache_qtl_plot_t->get_image_tag();
            $image_t_url = $cache_qtl_plot_t->get_image_url();

            $thickbox =
qq | <a href="$image_t_url" title= "<a href=$h_marker&amp;qtl=$image_t_url><font color=#f87431><b>>>>Go to the QTL page>>>> </b></font></a>"  class="thickbox" rel="gallary-qtl"> <img src="$image_url" alt="Chromosome $lg $image_t_url $image_url" /> </a> |;

            $qtl_image .= $thickbox;
            $title = "  ";

        }
        else
        {
            $qtl_image = undef;
            last IMAGES;

        }

    }

    return $qtl_image;

}

# =head2 user_stat_file

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub user_stat_file {
#     my $self = shift;
#     my $pop = $self->get_object();
#     my $pop_id = $self->get_object_id();
#     my $sp_person_id = $pop->get_sp_person_id();
#     my $qtl  = CXGN::Phenome::Qtl->new($sp_person_id);
#     #$qtl->set_population_id($pop_id);

#     my ($qtl_dir, $user_dir)  = $qtl->get_user_qtl_dir();

#     my $stat_file = "$user_dir/user_stat_pop_$pop_id.txt";
#     print STDERR "stat_file: $stat_file";

#     if (-e $stat_file) {
# 	return $stat_file;
#     } else {return 0;}

# }

=head2 stat_files

 Usage: my $stat_param_files = $self->stat_files();
 Desc:  creates a master file containing individual files 
        in /data/prod/tmp/r_qtl for each statistical parameter 
        which are feed to  R.
 Ret:  an absolute path to the statistical parameter's 
       master file (and individual files)
 Args: None
 Side Effects:
 Example:

=cut

sub stat_files
{
    my $self           = shift;
    my $pop_id         = $self->get_object_id();
    my $pop            = $self->get_object();
    my $sp_person_id   = $pop->get_sp_person_id();
    my $qtl            = CXGN::Phenome::Qtl->new($sp_person_id);
    my $c = SGN::Context->new();
    my $user_stat_file = $qtl->get_stat_file($c, $pop_id);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    open F, "<$user_stat_file" or die "can't open file: !$\n";

    my $stat_files;

    while (<F>)
    {
        my ( $parameter, $value ) = split( /\t/, $_ );

        my $stat_temp = File::Temp->new(
                                      TEMPLATE => "${parameter}_$pop_id-XXXXXX",
                                      DIR      => $prod_temp_path,
                                      UNLINK   => 0
        );
        my $stat_file = $stat_temp->filename;

        open SF, ">$stat_file" or die "can't open file: !$\n";
        print SF $value;
        close SF;

        $stat_files .= $stat_file . "\t";

    }

    close F;

    my $stat_param_files =
      $prod_temp_path . "/" . "stat_temp_files_pop_id_${pop_id}";

    open STAT, ">$stat_param_files" or die "can't open file: !$\n";
    print STAT $stat_files;
    close STAT;

    return $stat_param_files;

}

=head2 stat_param_hash

 Usage: my %stat_param = $self->stat_param_hash();
 Desc: creates a hash (with the statistical parameters (as key) and 
       their corresponding values) out of a tab delimited 
       statistical parameters file.       
 Ret: a hash statistics file
 Args: None
 Side Effects:
 Example:

=cut

sub stat_param_hash
{
    my $self           = shift;
    my $pop_id         = $self->get_object_id();
    my $pop            = $self->get_object();
    my $sp_person_id   = $pop->get_sp_person_id();
    my $qtl            = CXGN::Phenome::Qtl->new($sp_person_id);
    my $c = SGN::Context->new();
    my $user_stat_file = $qtl->get_stat_file($c, $pop_id);

    open F, "<$user_stat_file" or die "can't open file: !$\n";

    my %stat_param;

    while (<F>)
    {
        my ( $parameter, $value ) = split( /\t/, $_ );

        $stat_param{$parameter} = $value;

    }

    return \%stat_param;
}

sub submitter
{
    my $self         = shift;
    my $population   = $self->get_object();
    my $sp_person_id = $population->get_sp_person_id();
    my $submitter    = CXGN::People::Person->new( $self->get_dbh(),
                                              $population->get_sp_person_id() );
    my $submitter_name =
      $submitter->get_first_name() . " " . $submitter->get_last_name();
    my $submitter_link =
qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name</a> |;

    return $submitter, $submitter_link;

}

#move to qtl or population object
sub legend {
    my $self = shift;
    my $pop = shift;
    my $sp_person_id   = $pop->get_sp_person_id();
    my $qtl            = CXGN::Phenome::Qtl->new($sp_person_id);
    my $stat_file = $qtl->get_stat_file($c, $pop->get_population_id());
    my @stat;
    
    open $_, "<", $stat_file or die "$! reading $stat_file\n";
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
    


    my $permu_threshold_ref = $self->permu_values();
    my %permu_threshold     = %$permu_threshold_ref;

    my @keys;

    foreach my $key ( keys %permu_threshold )
    {
	if ( $key =~ m/^\d./ )
	{
	    push @keys, $key;
	}

    }
    my $lod1 = $permu_threshold{ $keys[0] };
    my $lod2 = $permu_threshold{ $keys[1] };

    if  (!$lod1) 
    {
	$lod1 = qq |<i>Not calculated</i>|;
    }
        
    push @stat, 
    [
     map {$_} ('LOD threshold', $lod1)
    ];
    push @stat, 
    [
     map {$_} ('Confidence interval', 'Based on 95% Bayesian Credible Interval')
    ];
    push @stat, 
    [
     map {$_} ('QTL software', "<a href=http://www.rqtl.org>R/QTL</a>")
    ];
    my $legend_data = columnar_table_html (
	                                   headings    => [
		                                          ' ',
		                                          ' ',

		                                         ],
		                           data        => \@stat,
		                          __alt_freq   => 2,
		                          __alt_width  => 1,
		                          __alt_offset => 3,
		                          __align      => 'l',
                                             
                                          );


    return $legend_data;

}
