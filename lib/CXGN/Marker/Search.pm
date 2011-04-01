use strict;

package CXGN::Marker::Search;

use CXGN::Marker;
use CXGN::Marker::LocMarker;
use CXGN::Marker::Tools qw(clean_marker_name);


=head1 NAME

CXGN::Marker::Search - object to return lists of markers based on your criteria

=head1 SYNOPSIS

  use CXGN::Marker::Search;
  my $search = CXGN::Marker::Search->new();

  #add criteria here, for example..
  $search->on_chromosome('5');

  $search->perform_search(1,30);
  my @marker_objects = $search->fetch_full_objects();


=head1 DESCRIPTION

Running a search consists of three steps:

0. Create marker search object

1. Specify search criteria, as many as you like

2. Call perform_search() to execute the SQL

3. Retrieve search results with one of the fetch_* functions. These can return a list of marker_id's, a list of location_id's, or a list of full-fledged marker objects.

As an alternative to (2) and (3), you may instead want to perform the query yourself (say if you want to use it as a subquery in a larger SQL statement your program is writing). In this case, the function return_subquery_with_placeholders() will do what you require; steps (2) and (3) are not necessary.

=cut



# minor setup things
my $physical;
#my $physical=$dbh->qualify_schema('physical');



=head2 Constructor

=over 12

=item new($dbh)

  my $msearch = CXGN::Marker::Search->new($dbh);

Returns a search object, ready for searching. Required before any of the other methods are called. 

=back

=cut

sub new {

  my ($class, $dbh) = @_;

  $physical = $dbh->qualify_schema('physical');

  die "must provide a dbh as first argument: CXGN::Marker->new($dbh)\n" unless $dbh && ref($dbh) eq 'CXGN::DB::Connection';

  my $self = bless {dbh => $dbh},$class;
  #my @nullm2mfields = qw(marker.marker_id location_id lg_name lg_order position confidence_id subscript map_version_id map_id);
  $self->{m2mfields} = ' m2m.marker_id, m2m.location_id, m2m.lg_name, m2m.lg_order, m2m.position, m2m.confidence_id, m2m.subscript, m2m.map_version_id, m2m.map_id ';

  $self->{midqfields} = 'marker.marker_id, m2m.location_id, m2m.lg_name, m2m.lg_order, m2m.position, m2m.confidence_id, m2m.subscript, m2m.map_version_id, m2m.map_id';
  $self->{nom2m} = $self->{m2mfields};
  $self->{nom2m} =~ s/m2m\.//g;

  $self->{mlqfields} = $self->{m2mfields};
  $self->{mlqfields} =~ s/m2m\./mlq./g;

#  $self->{m2mfields_nom2m} = $self->{m2mfields};
#  $self->{m2mfields_nom2m} =~ s/m2m.//g;
  
  # yick
  #$self->{m2mfieldsnull} = join ',', map {" NULL as $_ "} grep {$_ ne 'marker_id'} @nullm2mfields;

  return $self;

}




########################################
# here are the search criteria thingies!

=head2 Search Criteria Methods

These methods can be called in any order. The search object
"remembers" what criteria you have asked for, and when you perform
the search, all of them are applied. As you are building the query,
you can call query_text() if you would like to see the SQL string, say for
debugging.

None of these methods have interesting return values.

=over 12

=item random()

Causes the query to return only a single marker, randomly selected
from those that fit the other criteria you provide. 

  $msearch->random();
  $msearch->perform_search();
  my ($random_marker) = $msearch->fetch_id_list();
  # returns a random random marker

  # OR

  $msearch->on_chromosome(5);
  $msearch->random();
  $msearch->in_collection('KFG');
  $msearch->perform_search();
  my ($random_marker) = $msearch->fetch_id_list();
  # randomly selects one of the KFG markers on chr 5.

=cut

sub random {

  my ($self) = @_;

  # really, we just have to special-case this. 
  $self->{random} = 1;

}


=item name_like($string) 

Limits the markers to those with a name like the one given. 
There is no need to run clean_marker_name; this function will
search for the name both cleaned and as originally input. 

The query is run with ILIKE. Asterisks are converted to percent
characters. If you know the marker name, please see name_exactly().

$msearch->name_like('TG*');

=cut

sub name_like {
  
  my ($self, $name) = @_;

  return unless $name;

  # convert * to % (but leave underscores alone)
  $name =~ s/\*/\%/g;

  # strip un-normal characters?
  $name =~ s|[^-_\w./%]||g;

  # clean the name to see what WE would call it. 
  # We'll search for both the input name and the cleaned name.
  my $clean_name = clean_marker_name($name);

  # also allow to search on marker SGN-M type identifiers in the name 
  # field. exact/starts with etc won't be supported for SGN-M ids.
  # (Lukas 4/2008).
  #
  my $id_name = "";
  if ($name =~ /SGN-?M(\d+)/i) { 
      $id_name=$1;

  }
  
  my $subquery = "";

  if ($id_name) { 
      $subquery = "SELECT marker_id FROM marker_alias WHERE alias ILIKE ? OR alias ILIKE ? OR marker_id=?";      
      $self->_add_marker_query($subquery, $name, $clean_name, $id_name);
  }
  else  { 
      $subquery = "SELECT marker_id FROM marker_alias WHERE alias ILIKE ? OR alias ILIKE ?";
      $self->_add_marker_query($subquery, $name, $clean_name);
  }

}


=item name_exactly($name)

Limits the search to markers that have the EXACT name specified.
See also name_like().

  $msearch->name_exactly('KG_E41/M49-F-285-P2');

=cut

sub name_exactly {
  my ($self, $name) = @_;

  return unless $name;

  # we do no cleaning on the name. If you didn't get what you wanted, 
  # well, you should have called name_like().

  my $subquery = "SELECT marker_id FROM marker_alias WHERE alias = ?";

  $self->_add_marker_query($subquery, $name);

}


=item marker_id($marker_id)

Limits the search to one particular marker that you know the id of. 
Can be useful when looking for many locations of one marker.

  $msearch->marker_id(518);

=cut

sub marker_id {
  my ($self, $marker_id) = @_;

  return unless $marker_id;

  # this looks really silly.
  my $subquery = "SELECT marker_id FROM marker WHERE marker_id = ?";

  $self->_add_marker_query($subquery, $marker_id);

}


=item in_collection(@colls)

Limit results to markers in a certain collection, or list of collections

 $msearch->in_collection('KFG');

 $msearch->in_collection('KFG', 'COS', 'COSII');

=cut

sub in_collection {

  my ($self, @colls) = @_;

  return unless @colls > 0;

  # collection name
  my $subq = "SELECT marker_id FROM marker_collectible INNER JOIN marker_collection USING(mc_id) WHERE " . join (' OR ', map {" mc_name ILIKE ? "} @colls);

    
  $self->_add_marker_query($subq, @colls);
}


=item derived_from(@source_names)

Limits markers to those derived from the given source.

  $msearch->derived_from('est-by-read', 'bac', 'unigene');

=cut

sub derived_from {

  my ($self, @sources) = @_;

  return unless @sources > 0;

  my $q = 'SELECT marker_id FROM marker_derived_from INNER JOIN derived_from_source USING(derived_from_source_id) WHERE ' . join (' OR ', map {' source_name ILIKE ? '} @sources);

  $self->_add_marker_query($q, @sources);

}




#################################################################
# more criteria thingies, but these have to do with map locations

=item must_be_mapped()

Limits the marker results to only markers that are mapped. 

You do not need to call this method if you are ALSO asking for a
particular chromosome, map, species, etc. Those methods will automatically
exclude unmapped markers.

  $msearch->must_be_mapped();

=cut

sub must_be_mapped {

  my ($self) = @_;

  push(@{$self->{query_parts}{marker_loc}}, ["SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE position IS NOT NULL AND current_version = 't'", []]);

}

=item in_species(@common_names);

Limits the search to markers mapped in the species whose common names
are given.

  $msearch->in_species('tomato', 'nipplefruit');


=cut


sub in_species {

  my ($self, @species) = @_;

  return unless @species > 0;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m INNER JOIN accession ON(parent_1 = accession.accession_id OR parent_2 = accession.accession_id) INNER JOIN organism using(organism_id) INNER JOIN common_name USING(common_name_id) WHERE "
    . join(' OR ', map {' common_name.common_name ILIKE ? '} @species);

  $self->_add_loc_query($q, @species);

}


=item on_map_version($mv_id)

Limits results to markers on the given map_version(s). 

  $msearch->on_map_version(1, 2, 3);

=cut

sub on_map_version {
  my ($self, @mvs) = @_;

  return unless @mvs > 0;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE " 
    .join(' OR ', map {return unless $_ > 0; ' map_version_id = ? '} @mvs);

  $self->_add_loc_query($q, @mvs);
  

}

=item on_map(@map_ids)

Limits results to makers on the given map(s).

  $msearch->on_map(9, 5);

=cut

sub on_map {
  my ($self, @maps) = @_;

  return unless @maps > 0;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE " 
    .join(' OR ', map {return unless $_ > 0; ' map_id = ? '} @maps);

  $self->_add_loc_query($q, @maps);
  

}

=item on_chr(@chrs)

Limits the marker results to only markers on a given chromosome or
linkage group. 

   $msearch->on_chr(5, 6, 7);

Bonus feature: if you search for (say) chromosome 4, the search will
automagically include linkage groups 4a and 4b in addition to 4.


=cut

sub on_chr {

  my ($self, @chrs) = @_;

  return unless @chrs > 0;

  # asking for "4" should also retrieve "4b".
  foreach my $chr (@chrs){
    return unless $chr > 0;
    if ($chr =~ /^\d+$/){ $chr .='[ABCabc]?' }
    $chr = '^'.$chr.'$';
  }

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE " 
    .join(' OR ', map {' lg_name ~ ? '} @chrs);
  
  $self->_add_loc_query($q, @chrs);

}

=item position_between($start, $end)

Limits the results to markers appearing between the given endpoints.

  $msearch->position_between(90,100);
  $msearch->on_chr(5);
  # returns only markers between 90-100 on chr 5

  $msearch->position_between(50, undef);
  # returns markers after 50 cM on any chromosome

=cut

sub position_between {

  my ($self, $start, $end) = @_; 

  # making sure our inputs are numbers
  # (pg barfs if you feed it a string; 
  # we want to fail gracefully)
  $start += 0;
  $end += 0;
  return unless ($start || $end);

  my @conds;
  push(@conds, 'position >= ?') if $start;
  push(@conds, 'position <= ?') if $end;

  my @places;
  push(@places, $start) if $start;
  push(@places, $end) if $end;

  my $subq = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE ". (join ' AND ', @conds);

  $self->_add_loc_query($subq, @places);

}


=item has_subscript()

Not very useful, except in testing. 
Limits the results to marker locations that have subscripts.
Remember that most markers do NOT have subscripts.

  $msearch->has_subscript();

=cut

sub has_subscript {

  my ($self) = @_;

  $self->_add_loc_query("SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE subscript IS NOT NULL");

}

=item confidence_at_least($conf)

Limits results to marker locations with a given confidence or greater. 
Remember that many maps have entirely uncalculated confidences, so this 
is not always appropriate. 

The only argument this method takes is the minimum confidence. This
can be supplied as a confidence_id OR as a confidence name. Using the
ID will result in a slightly more efficient query.

   $msearch->confidence_at_least(2);
   $msearch->confidence_at_least('F(LOD3)');

=cut

sub confidence_at_least {
  my ($self, $conf) = @_;

  return unless $conf;
  my $q;

  if($conf =~ /^-?\d+$/){
    
    # it's an ID
    $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE confidence_id >= ?";
    
  } else {
    
    # it's a confidence name
    $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m INNER JOIN marker_confidence USING(confidence_id) WHERE marker_confidence.confidence_id >= (select confidence_id from marker_confidence where confidence_name = ?)";


  }

  $self->_add_loc_query($q, $conf);

}


=item protocol(@protos)

Limit results to markers/locations mapped with a certain type of
experiment, for example CAPS or RFLP or AFLP.

   $msearch->protocol('CAPS', 'AFLP');

=cut

sub protocol {
  my ($self, @protos) = @_;
  return unless @protos > 0;

  my $subq = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE "
    . join(' OR ', map {' protocol ILIKE ? '} @protos);

  $self->_add_loc_query($subq, @protos);

}

=item with_bac_associations(@clone_ids)

Limit results to markers that have some sort of bac associations.
This is equivalent to running with_overgo_associations,
with_manual_associations, and with_computational_associations. As with
all three of those, the list of clone_id's is optional. If no
clone_id's are specified, the results will include all markers that
have any bacs at all.

  $msearch->with_bac_associations();
  $msearch->with_bac_associations(12345, 67890);

=cut

sub with_bac_associations {
  my ($self, @bacs) = @_; 
  my $q = "select $self->{m2mfields} from marker_to_map as m2m left join $physical.probe_markers as pm on(m2m.marker_id=pm.marker_id) left join $physical.overgo_associations as oa using(overgo_probe_id) left join $physical.oa_plausibility using(overgo_assoc_id) left join $physical.manual_associations as ma on(ma.marker_id=m2m.marker_id) left join $physical.computational_associations as ca on(ca.marker_id=m2m.marker_id) WHERE oa_plausibility.plausible = 1 OR oa.overgo_assoc_id IS NULL " . join(' OR ', map {' oa.bac_id = ? OR ca.clone_id=? OR ma.clone_id=?'} @bacs);

  my @placebacs;

  foreach my $bac(@bacs){
    # we need to do this in triplicate - see the query above, where each clone_id has to be in three different tests in the where clause. 

    push(@placebacs, $bac) for 1..3;

  }

  $self->_add_loc_query($q, @placebacs);

}

=item with_overgo_associations(@clone_ids)

Limit results to markers with PLAUSIBLE overgo_associations to bacs. 
Particular bacs may be specified by their clone_id\'s. 

  $msearch->with_overgo_associations();
  $msearch->with_overgo_associations(12345, 67890);  

=cut

sub with_overgo_associations {
  my ($self, @bacs) = @_;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m INNER JOIN $physical.probe_markers using(marker_id) INNER JOIN $physical.overgo_associations using(overgo_probe_id) INNER JOIN $physical.oa_plausibility using(overgo_assoc_id)";

  if(@bacs > 0){

    $q .= " WHERE " 
      . join(' OR ', map {' bac_id = ? '} @bacs);

  }
  
  $self->_add_loc_query($q, @bacs);

} 

=item with_manual_associations(@clone_ids)

Limits results to markers that have been manually associated with bacs. 

  $msearch->with_manual_associations();
  $msearch->with_manual_associations(12345, 67890);

=cut


sub with_manual_associations {
  my ($self, @bacs) = @_;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m INNER JOIN $physical.manual_associations using(marker_id)";

  if(@bacs > 0){

    $q .= " WHERE " 
      . join(' OR ', map {' bac_id = ? '} @bacs);

  }
  
$self->_add_loc_query($q, @bacs)

} 


=item with_computational_associations(@clone_ids)

Limits results to markers that have been computationally associated
with bacs (eg, with BLAST).

  $msearch->with_computational_associations();
  $msearch->with_computational_associations(12345, 67890);

=cut

sub with_computational_associations {
  my ($self, @bacs) = @_;

  my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m INNER JOIN $physical.computational_associations using(marker_id)";

  if(@bacs > 0){

    $q .= " WHERE " 
      . join(' OR ', map {' bac_id = ? '} @bacs);

  }

$self->_add_loc_query($q, @bacs)  

} 















##############################################
# what follows is all query processing bidness

sub _assemble_query {
  
  my ($self, $start, $end) = @_;
  
  # make a string out the query as we have it so far.
  # You can call this function to see how the query is doing,
  # but no $self->{query} will be stored until perform_search
  # is called.
  
  # This is where the heavy hitting happens. Assemble a query and 
  # figure out the placeholders. Remember to include the limit/offset.
  
  # check and assemble the queries on marker_id

  my $marker_id_query = "(SELECT $self->{midqfields} FROM marker left join marker_to_map as m2m using(marker_id) WHERE marker.marker_id is not null)";#WHERE m2m.marker_id is not null)";
  my $marker_loc_query = "(SELECT $self->{m2mfields} FROM marker inner join marker_to_map as m2m using(marker_id))";
  my @places;

  foreach my $querytype ('marker_loc', 'marker_id'){
    next unless $self->{query_parts}{$querytype} && @{$self->{query_parts}{$querytype}} > 0;
#   warn  " processing $querytype query\n";
    foreach ((@{$self->{query_parts}{$querytype}})) {
      next unless $_;
      my ($subq, $subplaces) = @$_;

      # check for the right number of placeholders
      my $slotcount = ($subq =~ tr/\?//);
      if ($slotcount != @$subplaces){
	# if somebody messed up, there's not much we can do.
	local $"=',';
	die "number of placeholders is wrong for query $subq (Placeholders: @$subplaces)\n";
      }
      
      # add this to the query
      if($querytype eq 'marker_id'){
	#$marker_id_query .= " INTERSECT (select $self->{m2mfields} from marker_to_map as m2m inner join ($subq) as subq1 using(marker_id)) ";
	$marker_id_query .= " INTERSECT (select $self->{midqfields} from marker inner join ($subq) as subq1 using(marker_id) left join marker_to_map as m2m using(marker_id)) ";
      } elsif ($querytype eq 'marker_loc'){
	$marker_loc_query .= "INTERSECT ($subq) ";
      } else { 
	next;
	#die "what the heck? no query type.";
      }
      
      # and the placeholders
      push(@places, @$subplaces);
      
    }
  }

  # final assembly
  my $query;
  if( $self->{query_parts}{marker_loc}){
    $query = "SELECT DISTINCT $self->{mlqfields} FROM ($marker_loc_query) as mlq INNER JOIN ($marker_id_query) as midq using(marker_id)";
  } else {
    # if we only have a marker_id query, or if we have none
    $query = $marker_id_query;
  }

  # how to order?
  if($self->{random}){
    $query = "SELECT * FROM ($query) AS rquery ORDER BY RANDOM() LIMIT 1";
  } elsif ($self->{query_parts}{marker_loc}){
    $query .= ' ORDER BY lg_order, position, subscript, confidence_id desc';
  }
  
  return $query, \@places;
  
}

=back

=head2 Queries

=over 12

=item query_text()

     my $debug_string = $msearch->query_text();
     warn $debug_string;

Returns a string for debugging purposes. This string contains the query and indicates the placeholder values. If perform_search() has already been called, this is the query that was run. If perform_search() has NOT yet been called, this is the query as it currently appears at this stage in the query-building process. It is preceded by the tag "[PROVISIONAL]".

=cut

sub query_text {

  my ($self) = @_;

  # assemble our query
  my ($query, $places) = $self->_assemble_query();
  my $retstring = $query . " [Placeholder values: ".(join ", ", @$places)."]\n";
  if (!defined($self->{query})){
    # if we don't have a query, make one up quick!
    warn "search has not been performed; this query may be incomplete.\n";
    $retstring = '[PROVISIONAL] '.$retstring;
  }
  
  return $retstring;
  
}

=item return_subquery_and_placeholders()

Instead of performing the search through this module, you may wish to
use the query we construct, perhaps as a subquery in some SQL you are
writing. This method returns the query as a string, and a reference to
an array of the required placeholders.

    my ($subquery, $places) = 
        $msearch->return_subquery_and_placeholders();

    my $sth = $dbh->prepare("SELECT * FROM BLAH 
       BLAH INNER JOIN ($subquery) WHERE BLAH = ?");

    $sth->execute(@$places, "blah");

This expects to be done INSTEAD of perform_search(), not in addition to it.

=cut

sub return_subquery_and_placeholders {
  
  my ($self) = @_;

  # yeah, it's a thin wrapper around _assemble_query(). So sue me.
  my ($query, $places) = $self->_assemble_query();
  return ($query, $places); 

}

=item perform_search()

Performs the search; this is like the execute() function in DBI. After
calling perform_search(), you will be ready to use the fetch_* methods (see below).

If you only want a subset of results, say the first 30, specify the start and end.

  $msearch->perform_search(); 
  # search includes all possible results

  $msearch->perform_search(1, 30); 
  # will only include first 30 results

Proceed immediately to one of the fetch_* methods.

=back

=cut

sub perform_search {

  my ($self, $start, $end) = @_;
  # assemble the query and run it
  my ($q, $places) = $self->_assemble_query($start, $end);

  #warn $self->query_text();

  $self->{sth} = $self->{dbh}->prepare($q);
  $self->{sth}->execute(@$places);

  # store the query for posterity
  $self->{query} = $q;

}


##########################
# result-getting functions


=head2 Fetch Methods

=over 12

=item fetch_id_list()

Returns a list of marker_id's that match your criteria. 

   $msearch->perform_search();
   my @marker_ids = $msearch->fetch_id_list();

=cut

sub fetch_id_list {

  my ($self) = @_;

  return @{$self->{idlist}} if exists $self->{idlist};

  # get results
  $self->{allref} =  $self->{sth}->fetchall_arrayref();

  # collapse one level of arrayrefs
  my @idlist =  map {$_->[0]} @{$self->{allref}};

  $self->{idlist} = \@idlist;
  my $c = @{$self->{idlist}};
#  warn ">>> idlist has $c items\n";
  return @idlist;

}

=item fetch_location_id_list()

Returns a list of marker location_ids that match your criteria.

  $msearch->perform_search();
  my @loc_ids = $msearch->fetch_location_id_list();

=cut

sub fetch_location_id_list {

  my ($self) = @_;

  return $self->{locidlist} if exists $self->{locidlist};

  my $results = $self->{sth}->fetchall_arrayref({});

  @{$self->{locidlist}} = map {$_->{location_id}} @$results;

  return @$results;

}

=item fetch_full_markers()

Returns a list of marker objects that match your criteria.

   $msearch->perform_search()
   my @marker_objs = $msearch->fetch_full_markers();

=cut


sub fetch_full_markers {

  my ($self) = @_;

  my @ids = $self->fetch_id_list();

  my @objs;
  for (@ids) {

    my $m = CXGN::Marker->new($self->{dbh},$_);
    push (@objs, $m);

  }

  return @objs;

}

=item fetch_location_markers()

Returns a list of CXGN::Marker::LocMarker objects that match your criteria.

   $msearch->perform_search();
   my @loc_objs = $msearch->fetch_location_markers();

WARNING: If your search could return more than a few dozen locations, the process of creating all these objects may take a VERY LONG TIME. This is not recommended in such cases; try one of the other fetch_* methods instead.

=cut


sub fetch_location_markers {

  my ($self) = @_;
  my $results = $self->{sth}->fetchall_arrayref({});
  my @list;

  foreach my $r (@$results){

    push(@list, CXGN::Marker::LocMarker->new($self->{dbh}, $r->{marker_id}, $r));

  }

  return @list;

}



# takes a query and list of placeholders; adds them to the marker id
# portion of the query

sub _add_marker_query {

  my ($self, $q, @rest) = @_;
  push(@{$self->{query_parts}{marker_id}}, [$q, [@rest]]);

}

# takes a query and list of placeholders; adds them to the marker loc
# portion of the query

sub _add_loc_query {

  my ($self, $q, @rest) = @_;
  push(@{$self->{query_parts}{marker_loc}}, [$q, [@rest]]);

}


=back

=head1 DEVELOPING SEARCH PIECES

Fortunately, new search criteria methods are pretty easy to write and
test. This module works by intersecting subqueries with each other, so
each search criterion simply adds a subquery. When you call
perform_search(), the subqueries are glued together into one big query,
and the placeholders are all merged into one list. This creates a
mega-query that the database can easily optimize as it pleases. In
practice, I find the resulting queries to be very fast.

So, let's say you want to add a new method, something along the lines
of $msearch->name_like($some_input_name). Here is how to develop that
subquery and how to integrate it with the search module.

There are two different types of subqueries that this module expects: 

(a) queries that relate to a marker by itself, and begin "SELECT
marker_id FROM..."

(b) queries that relate to a marker in a map location, and include the view called marker_to_map. These begin "SELECT $self->{m2mfields} FROM marker_to_map as m2m..." . So long as you include the marker_to_map view, you don't have to worry about what is in $self->{m2mfields}. 

Let's walk through an easy type (a) example. Say you want to write the name_exactly function: it selects markers whose name is exactly what the user inputs. First, sit down at your psql prompt and write an SQL query that selects the markers you want out of the whole entire database:

  SELECT marker_id FROM marker_alias WHERE alias = ?

That\'s your query, and there is one placeholder, for the marker name. Your subroutine will simply specify the subquery and the placeholders, and use the _add_marker_query() function to add itself to the growing query. This is the entire function:

  sub name_exactly {
    my ($self, $name) = @_;

    my $subquery = "SELECT marker_id FROM marker_alias WHERE alias = ?";

    $self->_add_marker_query($subquery, $name);

  }

_add_marker_query() takes a subquery and a list of placeholders, so if
you have many placeholders, just supply them one after the other (or
with an array):

  $self->_add_marker_query($subquery, $one, $two, $red, $blue);
  $self->_add_marker_query($subquery, @crapload_of_placeholders);


Pretty easy, huh? Let\'s try a type (b) example, where we have to join
through the marker_to_map table. The only difference is that you call _add_loc_query instead of _add_marker_query. 

  sub on_chr {
    my ($self, $chr) = @_;

    # asking for "4" should also retrieve "4b".
    if ($chr =~ /^\D+$/){ $chr .='[ABCabc]?' }

    my $q = "SELECT $self->{m2mfields} FROM marker_to_map as m2m WHERE lg_name ~ ? ";
  
    $self->_add_loc_query($q, $chr);

  }

That is all! Let\'s review: 

1. Write your query, at the psql prompt or otherwise

2. Rephrase in terms of placeholders

3. Stick it in a subroutine inside this module, using _add_marker_query() or _add_loc_query()

4. Test and document your subroutine.

5. The end! You don\'t have to understand or modify any of the other existing code. 

Where in the file should you put your new code? Well, all the type
(a)\'s are together, and all the type (b)\'s are together. It\'s like the
high school cafeteria: find your friends, and sit with them.

As you test the subroutine, if you don\'t get results you expect,
simply print query_text() and you will see the query as you have built
it, and the list of placeholders that go along with it (in order). You
can actually cut-and-paste this into your psql monitor if you like,
for debugging purposes. After debugging, you may still find it useful
to use query_text() in die statements, warnings, or even as a comment
in the html of your search-related page.

=head1 BUGS

Still in heavy development as of March 2006.

=head1 LICENSE

This is under the same license as the rest of the CXGN codebase. 
Questions? Contact sgn-feedback@sgn.cornell.edu

=head1 AUTHOR

Beth started it.

=head1 SEE ALSO

CXGN::Marker, CXGN::Map, Cview, etc.

=cut



# all good modules return true
1;



