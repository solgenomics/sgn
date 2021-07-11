use strict;
use warnings;

my $qtl_analysis_detail_page =
  CXGN::Phenome::QtlAnalysisDetailPage->new();

package CXGN::Phenome::QtlAnalysisDetailPage;



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
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;

use GD;
use GD::Graph::bars;
use GD::Graph::lines;
use GD::Graph::points;
#BEGIN { local $SIG{__WARN__} = sub {}; require GD::Graph::Map }
use Statistics::Descriptive;
use Math::Round::Var;
use Number::Format;
use File::Temp qw / tempfile tempdir /;
use File::Copy;
use File::Spec;
use File::Path qw / mkpath /;
use File::Basename;
use File::Spec::Functions qw / catfile catdir/;
use File::stat;
use File::Slurp qw / read_file /;
use Cache::File;
use Path::Class;
use Try::Tiny;
use CXGN::Contact;
use String::Random;
#use Storable qw / store retrieve /;

use base qw / CXGN::Page::Form::SimpleFormPage CXGN::Phenome::Main/;

use CatalystX::GlobalContext qw( $c );

sub new
{
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->set_script_name("qtl_analysis.pl");

    return $self;
}

sub define_object
{
    my $self = shift;

    $self->set_dbh( CXGN::DB::Connection->new() );
    my %args          = $self->get_args();
    my $population_id = $args{population_id};
     my $stock_id = $args{stock_id};
    my $object;
    #########################
    # this page needs to be re-written with CXGN::Chado::Stock object
    # and without SimpleFormPage, since edits should be done on the parent page only
    #########################

    unless ( ($population_id and $population_id =~ /^\d+$/) || ($stock_id and $stock_id =~ /^\d+$/) )
    {
        $c->throw_404("A proper <strong>population id or stock id</strong> argument is missing");
    }

    if ($stock_id)
    {
        $object = CXGN::Phenome::Population->new_with_stock_id($self->get_dbh, $stock_id);
        $population_id = $object->get_population_id;
    } else
    {
        $object = CXGN::Phenome::Population->new($self->get_dbh, $population_id) ;
    }

    $self->set_object_id($population_id);
    $self->set_object(
                       CXGN::Phenome::Population->new(
                                        $self->get_dbh(), $self->get_object_id()
                       )
                     );

    $self->set_primary_key("population_id");
    $self->set_owners( $self->get_object()->get_owners() );

    my $trait_id = $args{cvterm_id};
    $trait_id = undef if $trait_id =~ m/\D+/;

    if ($trait_id)
    {
	$self->set_trait_id($trait_id);
    } else {
	$c->throw_404("A proper <strong>cvterm id</strong> argument is missing");
    }


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
qq |<a href="/qtl/view/$population_id">$pop_name</a> |;

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
        $form = CXGN::Page::Form::Editable->new();
    }
    else
    {
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

    my %args            = $self->get_args();
    my $dbh             = $self->get_dbh();
    my $population      = $self->get_object();
    my $population_id   = $self->get_object_id();
    my $population_name = $population->get_name();
    my $term_id         = $self->get_trait_id();
    my $term_name       = $self->get_trait_name();

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
"../phenome/qtl_analysis.pl?population_id=$population_id&amp;cvterm_id=$term_id";
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
qq|<a href="/publication/$pub_id/view" >PMID:$accession</a> |;
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
                'Abstract',
qq|$abstract <b> <i>$authors.</i> $journal. $pyear. $volume($issue). $pages.</b>|,
                0,                         #< do not show by default
                'abstract_optional_show'
                ,    #< don't use the default button-like style
                                               );

            $pubmed .=
qq|<div><a href="$url_pubmed$accession" target="blank">$pub_info</a> $title $abstract_view </div> |;
        }
    }

    print info_section_html( title    => 'Population details',
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
                      'Trait data',
                      qq |$phenotype_data|,
                      0,                                #<  don't show data by default
                                       );
	    $data_download .=
qq { Download population: <span><a href="/qtl/download/phenotype/$population_id"><b>Phenotype data</b></a> | <a href="/qtl/download/genotype/$population_id"><b>Genotype data</b></a></span> };
    }


        my (
             $image_pheno, $title_pheno, $image_map_pheno,
             $plot_html
           );
        ( $image_pheno, $title_pheno, $image_map_pheno ) = $self->
          population_distribution();

      $plot_html .= qq | <table  cellpadding = 5><tr><td> |;
        $plot_html .= $image_pheno . $image_map_pheno;
        $plot_html .= qq | </td><td> |;
        $plot_html .= $title_pheno . qq | <br/> |;


	my @phe_summ =  ( [ 'No. of obs units', $all_indls_count ],
			  [ 'Minimum', $min ],
			  [ 'Maximum', $max ],
			  [ 'Mean', $avg ],
			  [ 'Standard deviation', $std ]
	                );

	my @summ;
	foreach my $phe_summ ( @phe_summ )
	{
	    push @summ, [ map { $_ } ( $phe_summ->[0], $phe_summ->[1] ) ];
	}

	my $summ_data  = columnar_table_html(
                                              headings   => [ '',  ''],
                                              data       => \@summ,
                                              __alt_freq   => 2,
                                              __alt_width  => 1,
                                              __alt_offset => 3,
                                              __align      => 'l',
                                            );


        $plot_html .= $summ_data;
	$plot_html .= qq | </td></tr></table> |;



        my ( $qtl_image, $legend);

        #using standard deviation of 0.01 as an arbitrary cut off to run
	#qtl analysis. Probably, need to think of better solution.
	if ( $std >= 0.01 ) {
	    $qtl_image           = $self->qtl_plot();
	    $legend = $self->legend();
	}
	else {
	    $qtl_image = 'There is no statistically significant phenotypic
                          variation for this trait to run
                          QTL analysis.';
	}


	my $qtl_html = qq | <table><tr><td width=70%>$qtl_image</td><td width=30%>$legend</td></tr></table> |;
        my $qtl_effects_ref = $self->qtl_effects();
        my $explained_variation = $self->explained_variation();
        my ($qtl_effects_data, $explained_variation_data);

        if ($qtl_effects_ref)
        {
            $qtl_effects_data  = columnar_table_html(
                                              data         => $qtl_effects_ref,
                                              __alt_freq   => 2,
                                              __alt_width  => 1,
                                              __alt_offset => 3,
                                              __align      => 'l',
                                            );


        } else
        {
            $qtl_effects_data = "No QTL effects estimates were found for QTL(s) of  this trait.";
        }

        if ($explained_variation) {
         $explained_variation_data  = columnar_table_html(
                                              data         => $explained_variation,
                                              __alt_freq   => 2,
                                              __alt_width  => 1,
                                              __alt_offset => 3,
                                              __align      => 'l',
                                            );

        } else  {
            $explained_variation_data = "No explained variation estimates were found for QTL(s) of this trait.";
        }

        print info_section_html(
                                title    => 'QTL(s)',
                                contents => $qtl_html,
                                );


        print info_section_html( title    => 'Variation explained by QTL(s) ( Interacting QTLs model )',
                                 contents => $explained_variation_data
                                 );

        print info_section_html( title    => 'QTL effects',
                                 contents => $qtl_effects_data
                                 );

        print info_section_html(
	                        title    => 'Phenotype frequency distribution',
                                contents => $plot_html,
                               );

	print info_section_html(
	                        title    => 'Download data',
	 	                contents => $data_view . " " . $data_download,
                                collapsible => 1,
                                collapsed   => 1,
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
                           title       => 'Publication(s)',
                           contents    => $pubmed,
                           collapsible => 1,
                           collapsed   => 1,
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
    $self->remove_permu_file();

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
 }

sub population_distribution
{
    my $self      = shift;
    my $pop_id    = $self->get_object_id();
    my $pop       = $self->get_object();
    my $pop_name  = $pop->get_name();
    my $term_name = $self->get_trait_name();
    my $term_id   = $self->get_trait_id();
    my $dbh       = $self->get_dbh();


    my $basepath     = $c->get_conf("basepath");
    my $tempfile_dir = $c->get_conf("tempfiles_subdir");

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
    $self->cache_temp_path();

    my $cache = CXGN::Tools::WebImageCache->new();
    $cache->set_basedir($basepath);
    $cache->set_temp_dir( $tempfile_dir . '/temp_images');
    $cache->set_expiration_time(259200);
    $cache->set_key( "popluation_distribution" . $pop_id . $term_id );
    $cache->set_map_name("popmap$pop_id$term_id");

    my ( @value,    @indl_id, @indl_name );

    $cache->set_force(0);
    if ( !$cache->is_valid() )
    {

	my ( $indl_id, $indl_name, $value ) = $pop->plot_cvterm($term_id);
	@value = @{$value};

        my $stat = Statistics::Descriptive::Full->new();
        $stat->add_data(@value);
        my %f = $stat->frequency_distribution(10);

        my ( @keys, @counts );

        for ( sort { $a <=> $b } keys %f )
        {
	    my $round = Math::Round::Var->new(0.001);
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
                     x_label           => "$term_name values",
                     y_label           => "No. of observation units",
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
qq | Phenotype frequency distribution of experimental lines evaluated for $term_name. Bars represent the number of experimental lines with $term_name values greater than the lowest value but less or equal to the highest value of the range. |;

    return $image, $title, $image_map;
}

sub qtl_plot
{
    my $self           = shift;
    my $dbh            = $self->get_dbh();
    my $pop_id         = $self->get_object_id();
    my $population     = $self->get_object();
    my $pop_name       = $population->get_name();
    my $mapversion     = $population->mapversion_id();
    my @linkage_groups = $population->linkage_groups();
    my $term_name      = $self->get_trait_name();
    my $term_id        = $self->get_trait_id();
    my $ac             = $population->cvterm_acronym($term_name);
    my $basepath       = $c->get_conf("basepath");
    my $tempfile_dir   = $c->get_conf("tempfiles_subdir");

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) = $self->cache_temp_path();
    my $cache_tempimages = Cache::File->new( cache_root => $tempimages_path );
    $cache_tempimages->purge();

    my ( @marker,  @chr,  @pos,   @lod, @chr_qtl, @peak_markers );
    my ( $qtl_image, $image, $image_t, $image_url, $image_html, $image_t_url,
         $thickbox, $title, $l_m, $p_m, $r_m );

    my $round       = Number::Format->new();
    $qtl_image      = $self->qtl_images_exist();
    my $permu_data  = $self->permu_file();
    my $stat_option = $self->qtl_stat_option();

    unless ( $qtl_image && -s $permu_data > 1 && $stat_option=~/default/)
    {
        my ( $qtl_summary, $peak_markers_file ) = $self->run_r();

        open my $qtl_fh, "<", $qtl_summary or die "can't open $qtl_summary: $!\n";

        my $header = <$qtl_fh>;
        while ( my $row = <$qtl_fh> )
        {
            my ( $marker, $chr, $pos, $lod ) = split( /\t/, $row );
            push @marker, $marker;
            push @chr,    $chr;
            push @pos, $round->round($pos, 1);
            push @lod, $round->round($lod, 2);
        }

        my @o_lod = sort(@lod);
        my $max   = $o_lod[-1];
        $max = $max + (0.5);


        open my $markers_fh, "<", $peak_markers_file
           or die "can't open $peak_markers_file: !$\n";

        $header = <$markers_fh>;
        while ( my $row = <$markers_fh> )

        {
	    chomp($row);
            my ($trash, $chr_qtl, $peak_marker ) = split( /\t/, $row );
            push @chr_qtl, $chr_qtl;
            push @peak_markers, $peak_marker;
        }

	my (@h_markers, @chromosomes, @lk_groups);
	my $h_marker;

	@lk_groups  = @linkage_groups;
	@lk_groups  = sort ( { $a <=> $b } @lk_groups );
        my $random  = String::Random->new();
       # my $user_id = $c->user->get_object->get_sp_person_id() if $c->user;
       # my $qtl_obj = CXGN::Phenome::Qtl->new($user_id);
       # my ($user_qtl_dir, $user_dir) = $qtl_obj->get_user_qtl_dir($c);

        for ( my $i = 0 ; $i < @linkage_groups ; $i++ )
	{
	    my $lg = shift(@lk_groups);
            my $key_h_marker;
            #my %keys_to_urls=();

            if ($self->qtl_stat_option() eq 'user params')
            {
                $key_h_marker = $random->randpattern("CCccCCnnn") . '_'. $lg;
               # %keys_to_urls = ("user_params_${lg}" => $key_h_marker);
               # store(\%keys_to_urls, "$user_dir/image_urls");

            }
            elsif ( $self->qtl_stat_option() eq 'default')

            {
                $key_h_marker = "$ac" . "_pop_" . "$pop_id" . "_chr_" . $lg;
            }

            $h_marker = $cache_tempimages->get($key_h_marker)
                      ? $self->qtl_stat_option eq 'default'
                      : undef
                      ;

	    unless ($h_marker)
	    {
		push @chromosomes, $lg;
		$p_m = $peak_markers[$i];
		$p_m =~ s/\s//;

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
		my $lod1 = $permu_threshold{$p_keys[0]};

		$h_marker =
		    qq |/phenome/qtl.pl?population_id=$pop_id&amp;term_id=$term_id&amp;chr=$lg&amp;peak_marker=$p_m&amp;lod=$lod1|;

		$cache_tempimages->set( $key_h_marker, $h_marker, '30 days' );
                push @h_markers, $h_marker;
	    }
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
                push @pos_chr, $round->round($pos_chr_e, 1);
                push @lod_chr, $round->round($lod_chr_e, 2);
            }

            my $cache_qtl_plot = CXGN::Tools::WebImageCache->new();
	   $cache_qtl_plot->set_basedir($basepath);
           $cache_qtl_plot->set_temp_dir( $tempfile_dir . "/temp_images" );
#	    $cache_qtl_plot->set_temp_dir( $tempimages_path);
          $cache_qtl_plot->set_expiration_time(259200);


           if ($self->qtl_stat_option() eq 'user params')
            {
                $cache_qtl_plot->set_key($random->randpattern("CCccCCnnn"));
                $cache_qtl_plot->set_force(1);
           }
           elsif ( $self->qtl_stat_option() eq 'default')
           {
                $cache_qtl_plot->set_key("qtlplot" . $i . "small" . $pop_id . $term_id);
                $cache_qtl_plot->set_force(0);
           }

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
                        push @pos_chr, $round->round($pos_chr, 1);
                        push @lod_chr, $round->round($lod_chr, 2);

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


###########thickbox
            my $cache_qtl_plot_t = CXGN::Tools::WebImageCache->new();
            $cache_qtl_plot_t->set_basedir($basepath);
            $cache_qtl_plot_t->set_temp_dir( $tempfile_dir . "/temp_images" );
           # $cache_qtl_plot_t->set_temp_dir( $tempimages_path);
	    $cache_qtl_plot_t->set_expiration_time(259200);

           if ($self->qtl_stat_option() eq 'user params')
           {
                $cache_qtl_plot_t->set_key($random->randpattern("CCccccnnn"));
                $cache_qtl_plot_t->set_force(1);
           }

            elsif ( $self->qtl_stat_option() eq 'default')

           {
                $cache_qtl_plot_t->set_key("qtlplot_" . $i . "_thickbox_" . $pop_id . $term_id);
                $cache_qtl_plot_t->set_force(0);
           }


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
qq | <a href="$image_t_url" title="<a href=$h_marker&amp;qtl=$image_t_url><font color=#f87431><b>>>>>Go to the QTL page>>>> </b></font></a>" class="thickbox" rel="gallary-qtl"> <img src="$image_url" alt="Chromosome $i $image_t_url $image_url" /> </a> |;

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
    my $self       = shift;
    my $dbh        = $self->get_dbh();
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();
    my $term_name  = $self->get_trait_name();
    my $term_id    = $self->get_trait_id();

    my $ac = $population->cvterm_acronym($term_name);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $prod_permu_file  = $self->permu_file();
    my $gen_dataset_file = $population->genotype_file($c);
    my $phe_dataset_file = $population->phenotype_file($c);
    my $crosstype_file   = $self->crosstype_file();
    my $stat_file = $self->stat_files();

    my $input_file_list_temp =
      File::Temp->new(
                       TEMPLATE => "infile_list_${ac}_$pop_id-XXXXXX",
                       DIR      => $prod_temp_path,
                       UNLINK   => 0,
                     );
    my $file_in = $input_file_list_temp->filename();

    my $file_cvin = File::Temp->new(
                                     TEMPLATE => 'cvterm_input-XXXXXX',
                                     DIR      => $prod_temp_path,
                                     UNLINK   => 0,
                                   );
    my $file_cv_in = $file_cvin->filename();

    open my $cv_fh, ">", $file_cv_in or die "can't open $file_cv_in: $!\n";
    $cv_fh->print($ac);

    my $popid_temp = File::Temp->new(
                                     TEMPLATE => 'popid-XXXXXX',
                                     DIR      => $prod_temp_path,
                                     UNLINK   => 0,
                                   );
    my $file_popid = $popid_temp->filename();

    open my $popid_fh, ">", $file_popid or die "can't open $file_popid: $!\n";
    $popid_fh->print($pop_id);

    my $file_in_list = join( "\t",
                             $file_cv_in,       $file_popid,
                             $gen_dataset_file, $phe_dataset_file,
                             $prod_permu_file, $crosstype_file, $stat_file);

    open my $fi_fh, ">", $file_in or die "can't open $file_in: $!\n";
    $fi_fh->print ($file_in_list);

    return $file_in;

}

=head2 outfile_list

 Usage: my ($file_out, $qtl_summary, $peak_markers) = $self->outfile_list();
 Desc: returns an R output tempfile containing a tempfile supposed to hold the qtl
       mapping output and another tempfile for the qtl peak markers
       and the qtl mapping output and qtl peak makers files separately
       (convenient for reading their data when plotting the qtl)
 Ret: R output file names (with abosulte path)
 Args:
 Side Effects:
 Example:

=cut

sub outfile_list
{
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();
    my $term_id    = $self->get_trait_id();
    my $term_name  = $self->get_trait_name();
    my $dbh        = $self->get_dbh();

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
                                 DIR      => $prod_cache_path,
                                 UNLINK   => 0
    );
    my $qtl_summary = $qtl_temp->filename;

    my $marker_temp = File::Temp->new(
                            TEMPLATE => "peak_markers_${ac}_$pop_id-XXXXXX",
                            DIR      => $prod_cache_path,
                            UNLINK   => 0
    );

    my $peak_markers = $marker_temp->filename;

    my $ci_lod = $population->ci_lod_file($c, $ac);
    my $qtl_effects = $population->qtl_effects_file($c, $ac);
    my $explained_variation = $population->explained_variation_file($c, $ac);
    my $file_out_list = join ( "\t"
        ,$qtl_summary
        ,$peak_markers
	,$ci_lod
        ,$qtl_effects
        ,$explained_variation
	);

    open my $fo_fh, ">", $file_out or die "can't open $file_out: $!\n";
    $fo_fh->print ($file_out_list);

    return $file_out, $qtl_summary, $peak_markers;
}

=head2 cache_temp_path

 Usage: my ($solqtl_cache, $solqtl_tempfiles, $solqtl_temp_images) = $self->cache_temp_path();
 Desc: creates the 'solqtl/cache', 'solqtl/tempfiles', and 'solqtl/temp_images', subdirs in the /export/prod/tmp,
 Ret: returns the dirs above
 Args: none
 Side Effects:
 Example:

=cut

sub cache_temp_path {
    my $geno_version = $c->config->{default_genotyping_protocol};
    $geno_version    = 'analysis-data' if ($geno_version =~ /undefined/) || !$geno_version;
    $geno_version    =~ s/\s+//g;
    my $tmp_dir      = $c->site_cluster_shared_dir;
    $tmp_dir         = catdir($tmp_dir, $geno_version);

    my $solqtl_dir         = catdir($tmp_dir, 'solqtl');
    my $solqtl_cache       = catdir($tmp_dir, 'solqtl', 'cache');
    my $solqtl_tempfiles   = catdir($tmp_dir, 'solqtl', 'tempfiles');

    my $basepath = $c->config->{basepath};
    my $temp_dir  = $c->config->{tempfiles_subdir};

    my $tempimages   = catdir($basepath, $temp_dir, "temp_images" );

    mkpath ([$solqtl_cache, $solqtl_tempfiles, $tempimages], 0, 0755);
    return $solqtl_cache, $solqtl_tempfiles, $tempimages;


}



=head2 crosstype_file

 Usage: my $cross_file = $self->crosstype_file();
 Desc: creates the crosstype file in the /data/prod/tmp/r_qtl/tempfiles,

 Ret: crosstype filename (with absolute path)
 Args: none
 Side Effects:
 Example:

=cut

sub crosstype_file {
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();

    my $type_id = $population->get_cross_type_id
        or die "population '$pop_id' has no cross_type, does not seem to be the product of a cross!";
    my ($cross_type) = $self->get_dbh->selectrow_array(<<'', undef, $type_id);
                          select cross_type
                          from cross_type
                          where cross_type_id = ?

    my $rqtl_cross_type = { 'Back cross'        => 'bc',
                            'F2'                => 'f2',
                            'RIL (selfing)' => 'rilself',
                            'RIL (sibling mating)'  => 'rilsib'
                          }->{$cross_type}
                          or die "unknown cross_type '$cross_type' for population '$pop_id'";

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
	$self->cache_temp_path();

    my $cross_temp = File::Temp->new(
        TEMPLATE => "cross_type_${pop_id}-XXXXXX",
        DIR      => $prod_temp_path,
        UNLINK   => 0,
       );

    $cross_temp->print( $rqtl_cross_type );
    return $cross_temp->filename;
}

=head2 run_r

 Usage: my ($qtl_summary, $peak_markers) = $self->run_r();
 Desc: run R in the cluster; returns the R output files (with abosulate filepath) with qtl mapping data
       and peak markers
 Ret:
 Args:  none
 Side Effects:
 Example:

=cut

sub run_r {
    my $self = shift;

    my ($solqtl_cache, $solqtl_temp, $solqtl_tempimages) = $self->cache_temp_path();
    my $prod_permu_file = $self->permu_file();
    my $input_file      = $self->infile_list();
    my ($output_file, $qtl_summary, $peak_markers) = $self->outfile_list();

    my $pop_id = $self->get_object_id();
    my $trait_id = $self->get_trait_id();

    $c->stash->{analysis_tempfiles_dir} = $solqtl_temp;
    $c->stash->{r_temp_file} = "solqtl-${pop_id}-${trait_id}";
    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_script}    = 'R/solGS/qtl_analysis.r';

    $c->controller('solGS::AsyncJob')->run_r_script($c);

    return $qtl_summary, $peak_markers;

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
    my $self       = shift;
    my $dbh        = $self->get_dbh();
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();
    my $pop_name   = $population->get_name();
    my $term_name  = $self->get_trait_name();
    my $term_id    = $self->get_trait_id();

    my $ac = $population->cvterm_acronym($term_name);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    my $file_cache = Cache::File->new( cache_root => $prod_cache_path );

    my $key_permu = "$ac" . "_" . $pop_id . "_permu";
    my $filename  = "permu_" . $ac . "_" . $pop_id;

    my  $permu_file = $file_cache->get($key_permu);

    unless ($permu_file)
    {

        my $permu = undef;

        my $permu_file = File::Spec->catfile( $prod_cache_path, $filename );

	open my $permu_fh, ">", $permu_file or die "can't open $permu_file: !$\n";
        $permu_fh->print($permu);


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

    my %permu_threshold;

    my $permu_file = fileparse($prod_permu_file);
    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    $permu_file = File::Spec->catfile( $prod_cache_path, $permu_file );

    my $round1 = Math::Round::Var->new(0.1);

    open my $permu_fh, "<", $permu_file
      or die "can't open $permu_file: !$\n";

    my $header = <$permu_fh>;

    while ( my $row = <$permu_fh> )
    {
        my ( $significance, $lod_threshold ) = split( /\t/, $row );
        $lod_threshold = $round1->round($lod_threshold);
        $permu_threshold{$significance} = $lod_threshold;
    }

    return \%permu_threshold;

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
    my $self       = shift;
    my $pop_id     = $self->get_object_id();
    my $population = $self->get_object();
    my $pop_name   = $population->get_name();
    my $term_name  = $self->get_trait_name();
    my $term_id    = $self->get_trait_id();
    my $dbh        = $self->get_dbh();
    my $qtl_image  = undef;

    my @linkage_groups = $population->linkage_groups();
    @linkage_groups = sort ( { $a <=> $b } @linkage_groups );

    my $ac = $population->cvterm_acronym($term_name);

    my $basepath     = $c->get_conf("basepath");
    my $tempfile_dir = $c->get_conf("tempfiles_subdir");

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
            $self->cache_temp_path();

    my $cache_tempimages = Cache::File->new( cache_root => $tempimages_path );
    $cache_tempimages->purge();

    my $cache_qtl_plot = CXGN::Tools::WebImageCache->new();
    $cache_qtl_plot->set_basedir($basepath);
    $cache_qtl_plot->set_temp_dir( $tempfile_dir . "/temp_images" );

    if ($self->qtl_stat_option eq 'default')
    {
        my ( $image, $image_t, $image_url, $image_html, $image_t_url,
             $thickbox, $title );


      IMAGES: foreach my $lg (@linkage_groups)
      {
          my $key_h_marker = "$ac" . "_pop_" . "$pop_id" . "_chr_" . $lg;
          my $h_marker     = $cache_tempimages->get($key_h_marker);

          my $key = "qtlplot" . $lg . "small" . $pop_id . $term_id;
          $cache_qtl_plot->set_key($key);

          if ( $cache_qtl_plot->is_valid )
          {
              $image      = $cache_qtl_plot->get_image_tag();
              $image_url  = $cache_qtl_plot->get_image_url();
          }

          my $key_t = "qtlplot_" . $lg . "_thickbox_" . $pop_id . $term_id;
          $cache_qtl_plot->set_key($key_t);

          if ( $cache_qtl_plot->is_valid )
          {
              $image_t     = $cache_qtl_plot->get_image_tag();
              $image_t_url = $cache_qtl_plot->get_image_url();

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
    }
    else
    {

        foreach my $lg (@linkage_groups)
        {
            my $key_h_marker = $ac . "_pop_" . $pop_id . "_chr_" . $lg;
            $cache_tempimages->remove($key_h_marker);

            my $key = "qtlplot" . $lg . "small" . $pop_id . $term_id;
            $cache_qtl_plot->set_key($key);

            if ($cache_qtl_plot->is_valid)
            {
            $cache_qtl_plot->destroy();
            }
            my $key_t = "qtlplot_" . $lg . "_thickbox_" . $pop_id . $term_id;
            $cache_qtl_plot->set_key($key_t);

            if ($cache_qtl_plot->is_valid)
            {
            $cache_qtl_plot->destroy();
            }
            $qtl_image = undef;
        }
    }

    return $qtl_image;

}


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
    my $self   = shift;
    my $pop_id = $self->get_object_id();
    my $pop    = $self->get_object();
    my $user_id;
    if ($c->user)
    {
        $user_id = $c->user->get_object->get_sp_person_id;
    } else
    {
        $user_id = $pop->get_sp_person_id();
    }

    my $qtl            = CXGN::Phenome::Qtl->new($user_id);
    my $user_stat_file = $qtl->get_stat_file($c, $pop_id);

    my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
      $self->cache_temp_path();

    open my $user_stat_fh, "<", $user_stat_file or die "can't open file: !$\n";

    my $stat_files;

    while (<$user_stat_fh>)
    {
        my ( $parameter, $value ) = split( /\t/, $_ );

        my $stat_temp = File::Temp->new(
                                      TEMPLATE => "${parameter}_$pop_id-XXXXXX",
                                      DIR      => $prod_temp_path,
                                      UNLINK   => 0
        );
        my $stat_file = $stat_temp->filename;

        open my $sf_fh, ">", $stat_file or die "can't open file: !$\n";
        $sf_fh->print($value);


        $stat_files .= $stat_file . "\t";

    }

    my $stat_param_files =
      $prod_temp_path . "/" . "stat_temp_files_pop_id_${pop_id}";

    open my $stat_param_fh, ">", $stat_param_files or die "can't open file: !$\n";
    $stat_param_fh->print ($stat_files);


    return $stat_param_files;

}

=head2 stat_param_hash

 Usage: my $stat_param = $self->stat_param_hash();
 Desc: creates a hash table (with the statistical parameters (as key) and
       their corresponding values) out of a tab delimited
       statistical parameters file.
 Ret: a hashref for statistical parameter key and value pairs table
 Args: None
 Side Effects:
 Example:

=cut

sub stat_param_hash
{
    my $self   = shift;
    my $pop_id = $self->get_object_id();
    my $pop    = $self->get_object();
    my $user_id;
    if ($c->user) {
        $user_id = $c->user->get_object->get_sp_person_id;
    } else {
        $user_id = $pop->get_sp_person_id();
    }
    my $qtl            = CXGN::Phenome::Qtl->new($user_id);
    my $user_stat_file = $qtl->get_stat_file($c, $pop_id);

    open my $user_stat_fh, "<", $user_stat_file or die "can't open file: !$\n";

    my %stat_param;

    while (<$user_stat_fh>)
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
    my $pop  = $self->get_object();
    my $user_id;
    if ($c->user) {
        $user_id = $c->user->get_object->get_sp_person_id;
    } else {
        $user_id = $pop->get_sp_person_id();
    }

    my $qtl       = CXGN::Phenome::Qtl->new($user_id);
    my $stat_file = $qtl->get_stat_file($c, $pop->get_population_id());
    my @stat;
    my $ci=1;

    open my $sf, "<", $stat_file or die "$! reading $stat_file\n";
    while (my $row = <$sf>)
    {
	chomp($row);
        my ( $parameter, $value ) = split( /\t/, $row );
	if ($parameter =~/qtl_method/) {$parameter = 'Mapping method';}
	if ($parameter =~/qtl_model/) {$parameter = 'Mapping model';}
	if ($parameter =~/prob_method/) {$parameter = 'QTL genotype probability method';}
	if ($parameter =~/step_size/) {$parameter = 'Genome scan size (cM)';}
	if ($parameter =~/permu_level/) {$parameter = 'Permutation significance level';}
	if ($parameter =~/permu_test/) {$parameter = 'No. of permutations';}
	if ($parameter =~/prob_level/) {$parameter = 'QTL genotype signifance level';}
	if ($parameter =~/stat_no_draws/) {$parameter = 'No. of imputations';}

        if ( $value eq 'zero' || $value eq 'Marker Regression' )
        {
            $ci = 0;
        }

        unless (($parameter =~/No. of imputations/ && !$value ) ||
	        ($parameter =~/QTL genotype probability/ && !$value ) ||
                ($parameter =~/Permutation significance level/ && !$value)
	       )

	{
            if ($parameter =~/Genome scan/ && $value eq 'zero' || !$value)
            {
                $value = '0.0'
            }

            push @stat, [map{$_} ($parameter, $value)];

	}

    }

    my $sm;
    foreach my $st (@stat) {
	foreach my $i (@$st) {
	    if ($i =~/zero/)  {
		foreach my $s (@stat) {
		    foreach my $j (@$s) {
			$j =~ s/Maximum Likelihood/Marker Regression/;
			$ci = 0;
		    }
		}
	    }
	}
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

    if  (!$lod1)
    {
	$lod1 = qq |<i>Not calculated</i>|;
    }

    push @stat,
    [
     map {$_} ('LOD threshold', $lod1)
    ];


    if ($ci) {
	push @stat,
	[
	 map {$_} ('Confidence interval', 'Based on 95% Bayesian Credible Interval')
	];
    }

    push @stat,
    [
     map {$_} ('QTL software', "<a href=http://www.rqtl.org>R/QTL</a>")
    ];
    push @stat,
    [
     map {$_} ('Citation', "<a href=http://www.biomedcentral.com/1471-2105/11/525>solQTL</a>")
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

=head2 set_trait_id, get_trait_id

 Usage:
 Desc: the 'cvterm id' here is not necessarily a cvterm id,
       but may also be user submitted trait id...
 Ret:
 Args:
 Side Effects:
 Example:

=cut



sub get_trait_id {
    my $self = shift;
    return $self->{cvterm_id};
}
sub set_trait_id {
    my $self = shift;
    return $self->{cvterm_id} = shift;
}

=head2 get_trait_name
 Usage: my $term_name = $self->get_trait_name()
 Desc: retrieves the name of the trait whether
       it is stored in the user_trait or cvterm table
 Return: a trait name
 Args: None
 Side Effects:
 Example:

=cut
sub get_trait_name {
    my $self        = shift;
    my $population  = $self->get_object();
    my $term_id     = $self->get_trait_id();
    my $dbh         = $c->dbc()->dbh();

    my ($term_obj, $term_name);
    if ( $population->get_web_uploaded() )
    {
        $term_obj  = CXGN::Phenome::UserTrait->new( $dbh, $term_id );
        $term_name = $term_obj->get_name();
    }
    else
    {
        $term_obj  = CXGN::Chado::Cvterm->new( $dbh, $term_id );
        $term_name = $term_obj->get_cvterm_name();
    }

    return $term_name;


}

sub qtl_effects {
    my $self       = shift;
    my $trait_name = $self->get_trait_name();
    my $pop        = $self->get_object();
    $trait_name   = $pop->cvterm_acronym($trait_name);

    my $file = $pop->qtl_effects_file($c, $trait_name);

    if ( -s $file > 1 )
    {

        my @effects =  map  { [ split( /\t/, $_) ]}  read_file( $file );
        my $trash   = shift(@effects);

        push @effects, map { [ $_ ] } (" ", "QTL effects interpretation example: 2\@100 means
                                        QTL at linkage group 2 and position 100cM.",
                                        "2\@100:3\@100 means interaction between QTL at linkage
                                        group 2 position 100 cM and QTL at linkage group 3
                                        position 100 cM. 'a' and 'd' stand for additive and domininace
                                        effects, respectively."
                                      );
        return \@effects;
    } else
    {
        return undef;
    }

}

sub explained_variation {
    my $self       = shift;
    my $trait_name = $self->get_trait_name();
    my $pop        = $self->get_object();
    $trait_name    = $pop->cvterm_acronym($trait_name);

    my $file = $pop->explained_variation_file($c, $trait_name);

    if ( -s $file > 1 )
    {
        my @anova =  map  { [ split( /\t/, $_) ]}  read_file( $file );
        $anova[0][0] = "Source";

        if ( $anova[1][0] eq 'Model')
        {
            push @anova, map { [ $_ ] } ("  ", "The ANOVA model is based on a single QTL
                                         significant source of variation"
                                        );
        }
        else
        {
            push @anova, map { [ $_ ] } ( "  ",  "Variance source interpretation example: 2\@100 means
                                          QTL at linkage group 2 and position 100cM.",
                                          "2\@100:3\@100 means interaction between QTL at linkage
                                          group 2 position
                                          100 cM and QTL at linkage group 3 position 100 cM."
                                       );
        }


        return \@anova;
    } else
    {
        return undef;
    }

}

sub qtl_stat_option {
    my $self    = shift;
    my $pop_id  = $self->get_object_id();
    my $user_id = $c->user->get_object->get_sp_person_id if $c->user;
    my $qtl_obj = CXGN::Phenome::Qtl->new($user_id);

    my ($user_qtl_dir, $user_dir) = $qtl_obj->get_user_qtl_dir($c);
    my $stat_options_file         = "$user_dir/stat_options_pop_${pop_id}.txt";

    my $stat_option = -e $stat_options_file && read_file($stat_options_file) =~ /Yes/ ? 'default'
                    : !-e $stat_options_file                                          ? 'default'
                    :                                                                   'user params'
                    ;

    return $stat_option;
}

sub remove_permu_file {
    my $self = shift;
    my $population = $self->get_object();

    if ($self->qtl_stat_option eq 'user params')
    {
        my $ac = $population->cvterm_acronym($self->get_trait_name());
        my ( $prod_cache_path, $prod_temp_path, $tempimages_path ) =
            $self->cache_temp_path();

        my $file_cache = Cache::File->new( cache_root => $prod_cache_path );
        my $key_permu = $ac . "_" . $population->get_population_id() . "_permu";

        unlink($self->permu_file());
        $file_cache->remove($key_permu);

    }
}
