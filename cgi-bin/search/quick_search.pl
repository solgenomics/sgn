=head1 NAME

 quick_search.pl

=head1 DESCRIPTION

performs a search for each entity in the database and reports the
number of hits for each entity. Links are provided on an overview page
to allow the user to complete the search. In addition to the database,
quick_search.pl also searches google for the sgn.cornell.edu domain,
parses the page that Google returns to report the number of hits on
the web site (which includes static and dynamic pages). The link
provided with that search is going directly to Google.  Similarly, the
search is Google search is repeated without the domain constraint to
show the number of hits on the world wide web in total. A link for
that search is also provided.

=head1 AUTHORS

 Lukas Mueller, Feb 15, 2004

=cut

use strict;
use warnings;
use English;
use UNIVERSAL qw/isa/;
use Time::HiRes qw/time/;
use LWP::UserAgent;

our %urlencode;
use Tie::UrlEncoder;
use HTML::Entities;
use Tie::Function;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw/blue_section_html page_title_html info_table_html/;
use CXGN::Tools::Text qw/to_tsquery_string trim/;
use CXGN::Tools::Identifiers qw/identifier_url link_identifier clean_identifier identifier_namespace/;
use CXGN::Marker::Tools;

#search-framework search classes
use CXGN::Searches::People;
use CXGN::Searches::Library;
use CXGN::Genomic::Search::Clone;
use CXGN::Unigene::Search;
use CXGN::Phenome;
use CXGN::Phenotypes;
use CXGN::Searches::Images;

my %searches = (
		 clone      => { function => \&quick_clone_search, exact => 1 },
		 est        => { function => \&quick_est_search,   exact => 1 },
		 microarray => { function => \&quick_array_search, exact => 1 },
		 marker     => { function => \&quick_marker_search  },
		 manual_annotations    => { function => \&quick_manual_annotation_search    },
		 automatic_annotations => { function => \&quick_automatic_annotation_search },
                 sgn_pages  => { function => \&quick_page_search },
		 web        => { function => \&quick_web_search  },
                 people     => { class       => 'CXGN::Searches::People',
		                 result_desc => 'people',
				 search_path => '/solpeople/people_search.pl'
			       },
		 library    => { class       => 'CXGN::Searches::Library',
		                 result_desc => 'cDNA libraries',
				 search_path => '/search/library_search.pl',
			       },
		 bac        => { class       => 'CXGN::Genomic::Search::Clone',
				 result_desc => 'BAC identifiers',
				 search_path => '/maps/physical/clone_search.pl',
			       },
		 unigene    => { class       => 'CXGN::Unigene::Search',
				 result_desc => 'unigene identifiers',
				 search_path => '/search/ug-ad2.pl',
				 exact       => 1,
			       },
                 phenotype  => { class       => 'CXGN::Phenotypes',
 				 result_desc => 'phenotype identifiers',
 				 search_path => '/search/phenotype_search.pl',
 			       },
                 image      => { class       => 'CXGN::Searches::Images',
 				 result_desc => 'images',
 				 search_path => '/search/image_search.pl',
 			       },
                 locus_allele      => { class       => 'CXGN::Phenome',
 				        result_desc => 'locus or allele identifiers',
 				        search_path => '/search/locus_search.pl',
 			              },
	       );

our $page = CXGN::Page->new("SGN Quick Search page",'Rob');
our $db = CXGN::DB::Connection->new;
our ($print_individual_times) = $page->get_arguments('showtimes');

my $begintime = time;

my ($term) = $page->get_arguments('term');
$term = trim($term);

$term or $page->message_page('You did not enter a search term.');
$term =~ s/[\"\'\\]//g;
my $html_term = encode_entities($term);

#now run the term through CXGN::Tools::Identifiers, and if it's
#recognized as an exact SGN identifier match, just redirect them to
#that page
my $external_link = '<span class="ghosted">0 direct information pages</span>';
if( my $direct_url = identifier_url($term) ) {
  #if the URL is just to this page, it's not useful
  unless( $direct_url =~ /quick_search\.pl/) { #unless the url is to quick_search

    #if it's an external link, don't redirect, but put it in the external_link variable
    if( $direct_url =~ m@(f|ht)tp://@
	&& $direct_url !~ /sgn\.cornell\.edu/
      ) {
      my ($domain) = $direct_url =~ m|://(?:www\.)?([^/]+)|;
      my $clean = clean_identifier($term);
      $external_link = qq|<a href="$direct_url" class="quicksearch_hit">1 direct information page ($domain)</a>|;
    } else {
      $page->client_redirect($direct_url);
      exit(0);
    }
  }
}

#make a %search tied hash that will print out the html and javascript to do each of the searches
tie(my %search,
    'Tie::Function' => sub {
      my $searchname = shift;
      die  "No $searchname search defined" unless exists($searches{$searchname});
      my $search = $searches{$searchname};
      my $b = time;
      my $searchresults = do_quick_search(%$search, term => $term).($search->{exact} ? '*' : '');
      my $timestr = $print_individual_times ? sprintf(' (%0.1f sec)',time-$b) : '';
      "<div>$searchresults$timestr</div>"
    }
   );

my $results_html = <<EOHTML;
<div style="float: left; width: 50%">
  <dl>
  <dt>Identifiers</dt>
  <dd>
    $search{clone}
    $search{est}
    $search{unigene}
    $search{microarray}
    $search{marker}
    $search{bac}
    $search{phenotype}
    $search{locus_allele}
  </dd>
  <dt>People (searching by name)</dt>
  <dd>$search{people}</dd>
  </dl>
</div>
<div style="float: right; width: 50%">
  <dl>
  <dt>cDNA libraries</dt>
  <dd>$search{library}</dd>
  <dt>Annotations</dt>
  <dd>
    $search{manual_annotations}
    $search{automatic_annotations}
  </dd>
  <dt>Web pages</dt>
  <dd>
    $search{sgn_pages}
    $external_link
    $search{web}
  </dd>
  <dt>Images</dt>
  <dd>
    $search{image}
  </dd>
  </dl>
</div>
* &ndash; exact matches only
EOHTML

$page->header;
print page_title_html("Quick search: '$html_term'");
print <<EOHTML;
<p>
  The quick search does not perform the same queries as full searches of the various types.<br />
  Generally, quick-search results will be a subset of full results.
</p>
EOHTML
print blue_section_html('Results',
			sprintf('%0.2f seconds',time-$begintime),
			$results_html);
$page->footer;



###############################################################################
############################### SUBROUTINES ###################################
###############################################################################

#do a quick search with either a legacy quick search function or a
#WWWSearch-implementing search
sub do_quick_search {
  my %args=@_;

  if($args{function}) { #just run legacy functions and return their results
    return $args{function}->($db,$args{term});
  }
  else {
    my $classname = $args{class}
      or die 'Must provide a class name';

    isa($classname,'CXGN::Search::SearchI')
      or die "'$classname' is not a CXGN::Search::SearchI-implementing object";

    my $search = $classname->new;
    my $query  = $search->new_query;

    #check that the query has a quick_search function
    $query->can('quick_search')
      or die "Search '$classname' does not appear to have a query object with a quick_search method";

    if ( $query->quick_search($args{term}) ) {
      my $results = $search->do_search($query);
      my $count   = $results->total_results;
      die 'count should not be negative' if $count < 0;

      if ($count > 0) {
	my $qstr = encode_entities($query->to_query_string());
	return qq{<a class="quicksearch_hit" href="$args{search_path}?$qstr">$count $args{result_desc}</a>};
      }
    }
    return "0 $args{result_desc}";
  }

  die 'this point should not be reached';
}

###################### LEGACY QUICK SEARCH FUNCTIONS ##########################

sub quick_est_search {
    my $db = shift;
    my $term = shift;

    my $est_link = "0 EST identifiers";

    # the est quick search should support identifiers of the form SGN-E999999, SGN_E999999, SGNE999999
    # and also E999999, as well as straight number (999999).

    if ($term =~ /^\d+$/ || identifier_namespace($term) eq 'sgn_e' )
    {
      my ($id_term) = $term =~ /(\d+)/;
      my $count = sql_query_count($db, "SELECT count(*) FROM est WHERE est.est_id = ?",$id_term);
      if ($count != 0) {
	$est_link = qq|<a class="quicksearch_hit" href="/search/est.pl?request_id=$id_term&request_from=0&request_type=7&search=Search">$count EST identifiers</a>|;
      }
    }
    return $est_link;
}

sub quick_clone_search {
    my $db = shift;
    my $term = shift;

    # adjust if EST
    unless ($term =~ m|^ccc|) { # coffee clone name.
      $term =~ s|([a-z]{4})(\d{1,2})([a-z]\d{1,2})|$1-$2-$3|i;
    }

    # the quick clone search supports searching of clone name and
    # clone ids.  Clone ids can be entered as SGNC999999, SGN-C999999,
    # SGN_C999999 or C999999.  if the input does not correspond to any
    # of these formats, the clone_name is searched.  may have to add
    # something for the dashes that are sometimes not present in the
    # clone names.
    #
    my $where_clause = "";
    if ($term =~ /^(?:(SGN[\-\_]?)?C)?(\d+)$/i) {
      $where_clause = "WHERE clone_id = ?";
      $term = $2;
    } else {
      $where_clause = "WHERE clone_name ilike ?";
    }

    my $sgn = $db->qualify_schema('sgn');
    my $query = "SELECT clone_id FROM $sgn.clone $where_clause";
    my ($clone_id) = $db->selectrow_array($query, undef, $term);

    my $clone_link = "0 cDNA clone identifiers";
    if ($clone_id) {
	$clone_link =<<EOF;
<a class="quicksearch_hit"
   href="/search/est.pl?request_id=SGN-C$clone_id&request_from=0&request_type=automatic&search=Search">1 cDNA clone identifier</a>
EOF
    }
    return $clone_link;
}

# For quick_search queries without the Version#-Release#- prefix, the version and release are
# assumed to both be one. This is hardcoded below in two variables $version and $release.
sub quick_array_search {
    my $db = shift;
    my $term = shift;

    my $version = 1; # default version is 1
    my $release = 1; # default release is 1
    my $spot = "";

    my $array_link = "0 array identifiers";

    # the array quick search should support the following formats:
    # 1-1-1.1.1.1 (proper), -1-1.1.1.1, 1-1.1.1.1, -1.1.1.1 and 1.1.1.1

    my $id_term = "";
    if ($term =~ /^-?\d*-?(\d+\.\d+\.\d+\.\d+)$/) { # incomplete or absent Version#-Release#- prefix
	$id_term = $version . "-" . $release . "-" . $1; # use default prefix
	$spot = $1;
    }

    if ($term =~ /^(\d+)-(\d+)-(\d+\.\d+\.\d+\.\d+)$/) { # complete Version#-Release#- prefix
	$spot = $3;
	$id_term = $term; # use new version and release values
    }

    if ($id_term) {
	my $query = "SELECT count(*) FROM microarray AS m WHERE m.spot_id = ? AND m.version = ? AND m.release = ?";
	my $count = sql_query_count($db , $query, $spot,$version,$release);

	if ($count != 0) {
	    $array_link = qq|<a class="quicksearch_hit" href="/search/est.pl?request_id=$id_term&request_from=0&request_type=14&search=Search">$count array identifiers</a>|;
	}
    }
    return $array_link;
}

sub quick_marker_search {
    my $db = shift;
    my $term = shift;

    # adjust if EST
    $term =~ s/([a-z]{4})(\d{1,2})([a-z]\d{1,2})/$1-$2-$3/i;

    my $marker_link = "0 marker identifiers";
    my $count = CXGN::Marker::Tools::marker_name_to_ids($db,$term);
    if ($count != 0) {
	$marker_link = qq|<a class="quicksearch_hit" href="/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=$term&w822_submit=Search&w822_mapped=off&w822_species=Any&w822_protos=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=Any&w822_maps=Any">$count marker identifiers</a>|;
    }
    return $marker_link;
}

sub quick_manual_annotation_search {
    my $db = shift;
    my $term = shift;

    # It's a syntax error for whitespace to occur in tsquery query strings.  Replace with ampersands.
    my $cleaned_term = to_tsquery_string($term);
    my $count = sql_query_count($db, <<EOSQL, $cleaned_term);
SELECT COUNT(*)
  FROM manual_annotations
 WHERE annotation_text_fulltext @@ to_tsquery(?)
EOSQL

    my $unigene_count = do {
      if($count > 0) {
	sql_query_count($db,<<EOSQL,$cleaned_term);
SELECT COUNT(DISTINCT(unigene_member.unigene_id))
  FROM manual_annotations,
       seqread,
       est,
       unigene_member
WHERE annotation_text_fulltext @@ to_tsquery(?)
  AND manual_annotations.annotation_target_id=seqread.clone_id
  AND seqread.read_id=est.read_id
  AND est.est_id=unigene_member.est_id
EOSQL
      } else {
	0
      }
    };

    return
      $count > 0 ? qq( <a class="quicksearch_hit" href="/search/annotation_search_result.pl?search_text=$term&Submit=search&request_from=0&search_type=manual_search">$count manual annotations to $unigene_count unigenes</a> )
	         : "0 manual annotations";
}

sub quick_automatic_annotation_search {
    my $db = shift;
    my $term = shift;
    my $cleaned_term = to_tsquery_string($term);
    my $count = sql_query_count($db, "select count(*) from blast_defline where defline_fulltext @@ to_tsquery(?)",$cleaned_term);

    my $unigene_count = "(not determined -- number of annotations too large)";
    if ($count < 10000) {
      $unigene_count = sql_query_count($db, <<EOSQL,$cleaned_term);
SELECT COUNT(DISTINCT(unigene.unigene_id))
FROM blast_defline,
     blast_hits,
     blast_annotations,
     unigene
WHERE defline_fulltext @@ to_tsquery(?)
  AND blast_defline.defline_id=blast_hits.defline_id
  AND blast_hits.blast_annotation_id=blast_annotations.blast_annotation_id
  AND blast_annotations.apply_id=unigene.unigene_id
  AND blast_annotations.apply_type=15
EOSQL
    }
    my $automatic_annotation_link = "0 automatic annotations";
    if ($count !=0) {
      $automatic_annotation_link = qq|<a class="quicksearch_hit" href="/search/annotation_search_result.pl?search_text=$term&Submit=search&request_from=0&search_type=blast_search">$count automatic annotations to $unigene_count unigenes</a>|;
    }
    return $automatic_annotation_link;
}

sub sql_query_count {
    my $db = shift;
    my $query = shift;
    my $qh = $db -> prepare_cached($query);
    $qh -> execute(@_);
    my ($count) = $qh -> fetchrow_array();
    return $count;
}

sub google_search {
  my( $site_title, $term, $site_address ) = @_;

  my $qstr = "q=$urlencode{$term}&btnG=Google+Search";
  $qstr .= "&domains=$site_address&sitesearch=$site_address" if $site_address;

  my $lwp_ua = LWP::UserAgent->new;
  $lwp_ua->agent('SGN Quick Search ( Mozilla compatible )');
  my $res = $lwp_ua->request( HTTP::Request->new(GET => "http://www.google.com/custom?$qstr") );

  my $count = do {
    if( $res ->is_success ) {
      my $cont = $res->content;
      $cont =~ s/\<.*?\>//g;
      my ($c) = $cont =~ /Results\s*\d*?\s*\-\s*\d*\s*of\s*(?:about)?\s*?([\d\,]+)/;
      $c
    }
  };

  $qstr =~ s/&/&amp;/g;

  return
    $count ? qq|<a class="quicksearch_hit" href="http://www.google.com/custom?$qstr">$count web pages on $site_title.</a>|
           : "0 web pages on $site_title";
}

sub quick_web_search {
  my (undef,$term) = @_;
  # works the same way as quick_page_search, except that the domain contraint is removed from the
  # search.
  return google_search('the entire web',$term);
}
sub quick_page_search {
  my (undef,$term) = @_;
  return google_search('SGN',$term,'sgn.cornell.edu');
}


