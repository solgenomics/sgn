package SGN::Controller::QuickSearch;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Class::MOP;
use HTML::Entities;
use List::MoreUtils 'uniq';
use Time::HiRes 'time';
use URI::FromHash 'uri';
use Class::Load ':all';
use CXGN::Marker::Tools;
use CXGN::Tools::Identifiers qw/ identifier_url identifier_namespace /;
use CXGN::Tools::Text qw/to_tsquery_string trim/;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
use Data::Dumper;

=head1 NAME

SGN::Controller::QuickSearch - implement the quick search
functionality of the site

=head1 DESCRIPTION

Performs a search for each entity in the database and reports the
number of hits for each entity. Links are provided on an overview page
to allow the user to complete the search. In addition to the database,
quick_search.pl also searches google for the solgenomics.net domain,
parses the page that Google returns to report the number of hits on
the web site (which includes static and dynamic pages). The link
provided with that search is going directly to Google.  Similarly, the
search is Google search is repeated without the domain constraint to
show the number of hits on the world wide web in total. A link for
that search is also provided.


## TO DO: Make this a little more modern and move this code to
## an AJAX Controller...

=head1 PUBLIC ACTIONS

=cut

my %searches = (

    # function-based searches
    clone      => { function => \&quick_clone_search, exact => 1 },
    est        => { function => \&quick_est_search,   exact => 1 },
    microarray => { function => \&quick_array_search, exact => 1 },
    marker     => { function => \&quick_marker_search  },
    manual_annotations    => { function => \&quick_manual_annotation_search    },
    automatic_annotations => { function => \&quick_automatic_annotation_search },
    sgn_pages  => { function => \&quick_page_search },
#    web        => { function => \&quick_web_search  },
    phenotype  => { function => \&quick_phenotype_search },
    accessions => { function => \&quick_accession_search },
    plots      => { function => \&quick_plot_search },
    populations=> { function => \&quick_populations_search },
    trials     => { function => \&quick_trials_search },
    locations  => { function => \&quick_locations_search },
    traits     => { function => \&quick_traits_search },
    breeding_programs => { function => \&quick_bp_search },

    # search-framework searches
    people     => { sf_class    => 'CXGN::Searches::People',
                    result_desc => 'people',
                    search_path => '/solpeople/people_search.pl'
                  },
    library    => { sf_class    => 'CXGN::Searches::Library',
                    result_desc => 'cDNA libraries',
                    search_path => '/search/library_search.pl',
                },
    #bac        => { sf_class       => 'CXGN::Genomic::Search::Clone',
   #                 result_desc => 'BAC identifiers',
    #                search_path => '/maps/physical/clone_search.pl',
     #           },
    unigene    => { sf_class       => 'CXGN::Unigene::Search',
                    result_desc => 'unigene identifiers',
                    search_path => '/search/ug-ad2.pl',
                    exact       => 1,
                },
    image      => { sf_class    => 'CXGN::Searches::Images',
                    result_desc => 'images',
                    search_path => '/search/image_search.pl',
                },
    locus_allele      => { sf_class    => 'CXGN::Phenome',
                           result_desc => 'locus or allele identifiers',
                           search_path => '/search/locus',
                       },

    # note that there is also another method of searching using site feature xrefs
  );


=head2 quick_search

Public path: /search/quick

Handles POST or GET quick searches.  Parameter can be either C<term>
or C<q>.  If optional param C<showtimes> is true, shows number of
seconds each of the search steps took.

=cut

sub quick_search: Path('/search/quick') {
    my ( $self, $c ) = @_;

    # use either 'term' or 'q' as the search term
    my ($term) = grep defined, @{ $c->req->parameters }{'term','q'};

    $term =~ s/^\s*|\s*$//g;

    defined $term && length $term
        or $c->throw_client_error( public_message => 'Must provide a search term' );

    $c->stash(
        quick_search_term => $term,
        term              => $term,
        show_times        => $c->req->parameters->{showtimes},
        template          => '/search/quick_search.mas',
        );

    return if $c->forward('redirect_by_ident');

    $c->forward('execute_predefined_searches');
    $c->forward('search_with_xrefs');
    $c->forward('redirect_if_only_one_possible');
}

#run the term through CXGN::Tools::Identifiers, and if it's
#recognized as an exact SGN identifier match, just redirect them to
#that page
sub redirect_by_ident : Private {
    my ( $self, $c ) = @_;

    my $term = $c->stash->{term};

    if ( my $direct_url = identifier_url($term) ) {
        my $namespace = identifier_namespace($term);
        #if the URL is just to this page, it's not useful
        unless( $direct_url =~ m!quick_search\.pl|search/quick! #unless the url is to quick_search
                || $namespace eq 'est'  # don't auto-redirect for est names, some markers are called this
               ) {

            #if it's an external link, don't redirect, but put it in the external_link variable
            if ( $direct_url =~ m@(f|ht)tp://@
                 && $direct_url !~ /sgn\.cornell\.edu|solgenomics\.net/
               ) {
                my ($domain) = $direct_url =~ m|://(?:www\.)?([^/]+)|;
                $c->stash->{results}{external_link}{result} = [ $direct_url, '1 direct information page' ];
            } else {
                $c->res->redirect( $direct_url );
                return 1;
            }
        }
    }

    return;
}

# another optimization: if the quick search found only one
# possible URL to go to, go there
sub redirect_if_only_one_possible : Private {
    my ( $self, $c ) = @_;

    my @possible_urls = uniq(
         grep $_ !~ m!^https?://! && $_ !~ m!^/solpeople!,
         grep defined,
         ( map $_->{result}->[0],
           values %{$c->stash->{results}}
         ),
         ( map ''.$_->url,
           @{ $c->stash->{xrefs} || [] }
         ),
       );

    if( @possible_urls == 1 ) {
        $c->log->debug("redirecting to only possible url: $possible_urls[0]") if $c->debug;
        $c->res->redirect( $possible_urls[0] );
        return;
    }
}

sub execute_predefined_searches: Private {
    my ( $self, $c ) = @_;

    # execute all the searches and stash the results
    for my $search_name ( sort keys %searches ) {
	print STDERR "performing quick search for $search_name (". Dumper($searches{$search_name}).")...\n";
         my $search = $searches{$search_name};
         my $b = time;
         my $searchresults = $self->do_quick_search(
             $c->dbc->dbh,
             %$search,
             term => $c->stash->{term},
	     schema => $c->dbic_schema("Bio::Chado::Schema"),
           );
         $c->stash->{results}{$search_name} = {
             result => $searchresults,
             time   => time - $b,
             exact  => $search->{exact}
           };
	print STDERR Dumper($searchresults);
    }
}

sub search_with_xrefs: Private {
    my ( $self, $c ) = @_;

    my $b = time;
    my @xrefs = $c->feature_xrefs( $c->stash->{term} );
    $c->stash->{xrefs} = \@xrefs;
    $c->stash->{xrefs_time} = time - $b;
}

#do a quick search with either a legacy quick search function or a
#WWWSearch-implementing search
sub do_quick_search {
    my ( $self, $db, %args ) = @_;

    if ($args{function}) { #just run legacy functions and return their results
	print STDERR "INVOKING $args{function} with $args{term}\n";
        return $args{function}->( $self, $db,$args{term}, $args{schema});
    } else {
        my $classname = $args{sf_class}
            or die 'Must provide a class name';

        Class::Load::load_class( $classname );
        $classname->isa( 'CXGN::Search::SearchI' )
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
                return [ "$args{search_path}?$qstr", "$count $args{result_desc}" ];
            }
        }
        return [undef, "0 $args{result_desc}"];
    }

    die 'this point should not be reached';
}

###################### LEGACY QUICK SEARCH FUNCTIONS ##########################

sub quick_est_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;

    my $est_link = [ undef, "0 EST identifiers" ];

    # the est quick search should support identifiers of the form SGN-E999999, SGN_E999999, SGNE999999
    # and also E999999, as well as straight number (999999).

    if ($term =~ /^\d+$/ || ( identifier_namespace($term) || '' )eq 'sgn_e' )
    {
      my ($id_term) = $term =~ /(\d+)/;
      my $count = sql_query_count($db, "SELECT count(*) FROM est WHERE est.est_id = ?",$id_term);
      if ($count != 0) {
          $est_link = [
              "/search/est.pl?request_id=$id_term&request_from=0&request_type=7&search=Search",
              "$count EST identifiers",
            ];
      }
    }
    return $est_link;
}

sub quick_clone_search {
    my $self = shift;
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

    my $query = "SELECT clone_id FROM sgn.clone $where_clause";
    my ($clone_id) = $db->selectrow_array($query, undef, $term);

    my $clone_link = [undef, "0 cDNA clone identifiers"];
    if ($clone_id) {
	$clone_link = [
            "/search/est.pl?request_id=SGN-C$clone_id&request_from=0&request_type=automatic&search=Search",
            "1 cDNA clone identifier",
          ];
    }
    return $clone_link;
}

# For quick_search queries without the Version#-Release#- prefix, the version and release are
# assumed to both be one. This is hardcoded below in two variables $version and $release.
sub quick_array_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;

    my $version = 1; # default version is 1
    my $release = 1; # default release is 1
    my $spot = "";

    my $array_link = [ undef, "0 array identifiers" ];

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
	    $array_link = [
                "/search/est.pl?request_id=$id_term&request_from=0&request_type=14&search=Search",
                "$count array identifiers",
              ];
	}
    }
    return $array_link;
}

sub quick_phenotype_search {
    my ($self, $db, $term) = @_;
    my $q = "select count (distinct stock_id ) from stock left join stockprop using (stock_id) left join cvterm on stockprop.type_id = cvterm.cvterm_id where stock.name ilike ? or stock.uniquename ilike ? or (stockprop.value ilike ? and cvterm.name ilike ? ) " ;
    my $count = sql_query_count( $db , $q , "\%$term\%","\%$term\%","\%$term\%", "\%synonym\%" );
    my $pheno_link = [ undef , "0 phenotype identifiers"];
    if ($count>0) {
        $pheno_link = ["/search/stocks?any_name=$term" ,
                       "$count phenotype identifiers" ];
    }
    return $pheno_link;
}

sub quick_marker_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;

    # adjust if EST
    $term =~ s/([a-z]{4})(\d{1,2})([a-z]\d{1,2})/$1-$2-$3/i;

    my $marker_link = [undef, "0 marker identifiers"];
    my $count = CXGN::Marker::Tools::marker_name_to_ids($db,$term);
    if ($count != 0) {
	$marker_link = [
            "/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=$term&w822_submit=Search&w822_mapped=off&w822_species=Any&w822_protos=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=Any&w822_maps=Any",
            "$count marker identifiers"
          ];
    }
    return $marker_link;
}

sub quick_manual_annotation_search {
    my $self = shift;
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
      $count > 0 ? ["/search/annotation_search_result.pl?search_text=$term&Submit=search&request_from=0&search_type=manual_search", "$count manual annotations on $unigene_count unigenes"]
                 : [undef, "0 manual annotations"];
}

sub quick_automatic_annotation_search {
    my $self = shift;
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
    my $automatic_annotation_link = [undef, "0 automatic annotations"];
    if ($count !=0) {
      $automatic_annotation_link = [ "/search/annotation_search_result.pl?search_text=$term&Submit=search&request_from=0&search_type=blast_search", "$count automatic annotations on $unigene_count unigenes" ];
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
  my( $self, $site_title, $term, $site_address ) = @_;

  print STDERR "Googling...\n";
  my $google_url = uri( scheme   => 'http',
                        host     => 'www.google.com',
                        path     => '/custom',
                        query    => {
                            q    => $term,
                            ( $site_address
                              ? ( sitesearch => $site_address )
                              : ()
                            ),
                        },
                        query_separator => '&',
                      );

  my $lwp_ua = LWP::UserAgent->new;
  $lwp_ua->agent( 'SGN Quick Search ( Mozilla compatible )' );
  my $res = $lwp_ua->request( HTTP::Request->new( GET => $google_url ));

  print STDERR "Hello world!\n";
  my $count = do {
    if( $res ->is_success ) {
      my $cont = $res->content;
      $cont =~ s/\<.*?\>//g;
      my ($c) = $cont =~ /Results\s*\d*?\s*\-\s*\d*\s*of\s*(?:about)?\s*?([\d\,]+)/;
      $c
    }
  };

  print STDERR "Returning search results...\n";
  if( $count ) {
      return [ $google_url, "$count pages on $site_title" ];
  } else {
      return [ undef, "0 pages on $site_title" ];
  }
}

sub stock_search {
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $term = shift;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $type, 'stock_type')->cvterm_id();
    my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => { ilike => $term} , type_id => $accession_type_id });

    my ($id, $name);
    if ($rs->count() > 0) {
	my $row = $rs->next();
	$id = $row->stock_id();
	$name = $row->uniquename();
	print STDERR "FOUND: $id, $name\n";
    }
    return ($id, $name);
}

sub quick_accession_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    my ($id, $name) = $self->stock_search($schema, 'accession', $term);
    if ($id) {
	print STDERR "Found accession $id, $name\n";
	return [ '/stock/'.$id.'/view', "1 accession: ".$name ];
    }
    else {
	print STDERR "Found no accession... ???\n";
	return [ '', "0 accession identifers" ];
    }
}

sub quick_plot_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    my ($id, $name) = $self->stock_search($schema, 'plot', $term);

    if ($id) {
	return [ '/stock/'.$id."/view", "1 plot: ".$name ];
    }
    else {
	return [ '', "plots: No exact match." ];
    }
}

sub quick_populations_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    my ($id, $name) = $self->stock_search($schema, 'population', $term);

    if ($id) {
	return [ '/stock/'.$id."/view", "1 population: ".$name ];
    }
    else {
	return [ '', "0 populations." ];
    }
}

sub quick_trials_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    my $cv_rs = $schema->resultset("Cv::Cv")->search( { 'me.name' => 'project_type' }, { join => 'cvterms', '+select' => [ 'cvterms.name', 'cvterms.cvterm_id' ], '+as' => [ 'cvterm_name', 'cvterm_id' ]  });

    my @trial_type_ids = ();
    while (my $row = $cv_rs->next()) {
	my $cvterm_id = $row->get_column('cvterm_id');
	print STDERR "retrieving cvterm id: $cvterm_id\n";
	push @trial_type_ids, $cvterm_id;
    }

    my $rs = $schema->resultset("Project::Project")->search( { name => { ilike => $term }, 'projectprops.type_id' => { -in => [ @trial_type_ids ] } }, { join => 'projectprops', '+select' => [ 'projectprops.type_id' ], '+as' => [ 'project_type_id' ] });

    my ($id, $name);
    if ($rs->count() == 1) {
	my $row = $rs->next();
	$id = $row->project_id();
	$name = $row->name();
    }
    if ($id) { 
	return [ '/breeders/trial/'.$id, "1 trial: ".$name ];
    }
    else {
	return [ '', "0 trials" ];
    }
}

sub quick_locations_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    print STDERR "LOCATION SEARCH!\n";
    my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search( { description => { ilike => $term } });

    my ($id, $name);
    if ($rs->count() == 1) {
	my $row = $rs->next();
	$id = $row->nd_geolocation_id();
	$name = $row->description();
    }
    else {
	print STDERR "LOCATION HAS ".$rs->count()." MATCHES!!!!\n";
    }
    print STDERR "RETURNED: $id, $name\n";
    if ($id) {
	return [ '/breeders/locations/', '1 location: '.$name ]; # just link to generic locations page
    }
    else {
	return [ '', '0 locations' ];
    }
}

sub quick_traits_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    my $rs = $schema->resultset("Cv::Cvterm")->search( { name => { ilike => $term } });

    my ($id, $name);
    if ($rs->count() > 0) {
	my $row = $rs->next();
	$id = $row->cvterm_id();
	$name = $row->name();
    }
    if ($id) {
	return [ '/cvterm/'.$id.'/view', '1 trait: '.$name ];
    }
    else {	
	return [ '', '0 cvterms' ];
    }
}

sub quick_bp_search {
    my $self = shift;
    my $db = shift;
    my $term = shift;
    my $schema = shift;

    print STDERR "breeding program search... \n";
    my $rs = $schema->resultset("Project::Project")->search( { 'me.name' => { ilike => $term }  } , { cvterm_name => 'breeding_program', join => 'projectprops' => { 'cvterms', '+select' => [ 'cvterm.name'], '+as' => ['cvterm_name'] } } );

    my ($id, $name);

    if ($rs->count() > 1) {
	print STDERR $rs->count()." results, which is unexpected...\n";
	while (my $row = $rs->next()) {
	    print STDERR join("\t", $row->name(), $row->project_id())."\n";
	}
	return [ '', 'too many hits' ];
    }

    elsif ($rs->count() == 1) {
	my $row = $rs->next();
	$id = $row->project_id();
	$name = $row->name();
    }
    else {
	print STDERR "Sorry, no match!\n";
    }

    print STDERR "FOUND: $id\n";
    if ($id) {
	return [ '/breeders/program/'.$id, "1 breeding program: ".$name ];
    }
    else { 
	return [ '', '0 breeding programs' ];
    }

}

sub quick_web_search {
  my ($self, undef,$term) = @_;
  # works the same way as quick_page_search, except that the domain contraint is removed from the
  # search.
  print STDERR "Performing web search... ";
  return $self->google_search('the entire web',$term);
}

sub quick_page_search {
  my ($self, undef,$term) = @_;
  return $self->google_search('SGN',$term,'solgenomics.net');
}

__PACKAGE__->meta->make_immutable;

1;
