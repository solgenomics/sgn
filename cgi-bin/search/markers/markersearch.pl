
package main;

use strict;
use warnings;
use CXGN::Page;
use CXGN::Search::CannedForms;
use CXGN::Page::FormattingHelpers qw/blue_section_html  page_title_html columnar_table_html/;
use CXGN::DB::Connection;
use CXGN::Marker::Search;
use CXGN::Marker::SearchJson;
use HTML::Entities;

our $page = CXGN::Page->new( "Marker Search", "Beth Skwarecki");

my %params=$page->cgi_params();
my $dbh=CXGN::DB::Connection->new();


my $form = CXGN::Search::CannedForms::MarkerSearch->new($dbh);
$form->set_data(%params);
$form->from_request(\%params);

$page->header('SGN: Marker search') unless $form->data('text');

if($form->data('submit') && ($form->data('submit') eq 'Search') || ($form->data('random') && $form->data('random') eq 'yes')) {

  #use Data::Dumper;
  #print '<pre>' .(Dumper \%params). '</pre>';

  # do the search!
  my $query;
  my @protos;
  my $protocol;
  my $marker_name;
  my $msearch = CXGN::Marker::Search->new($dbh);
  my $msearchJ = CXGN::Marker::SearchJson->new($dbh);

  if($marker_name = $form->data('marker_name')){

    if($form->data('nametype') eq 'exactly'){
      # using name_exactly would be more efficient, 
      # but we probably want to be case-insensitive.
      $msearch->name_like($marker_name);
      $msearchJ->name_like($marker_name);
    } elsif ($form->data('nametype') eq 'contains'){
      $msearch->name_like('%'.$marker_name.'%');
      $msearchJ->name_like('%'.$marker_name.'%');
    } elsif ($form->data('nametype') eq 'starts with'){
      $msearch->name_like($marker_name.'%');
      $msearchJ->name_like($marker_name.'%');
    }

  }
  
  if($form->data('mapped') && $form->data('mapped') eq 'on'){
      #warn "MUST BE MAPPED\n";
      $msearch->must_be_mapped();
  } elsif ($marker_name =~ /\w/) {
      print STDERR "marker_name = $marker_name\n";
  } else {
      print blue_section_html('Error',"You must enter a marker name.\n" );
      print '<br /><br />', blue_section_html('Search Again', form_html($form));
      return;
  }

  if($form->data('bac_assoc')){
    $msearch->with_bac_associations();
  }

  if($form->data('overgo_assoc')){
    $msearch->with_overgo_associations();
  }

  if($form->data('manual_assoc')){
    $msearch->with_manual_associations();
  }

  if($form->data('comp_assoc')){
    $msearch->with_computational_associations();
  }

  if(my @species = $form->data_multiple('species')){
    $msearch->in_species(@species) unless grep /^Any$/, @species;
  }

  if(my @species = $form->data_multiple('species')){
    $msearch->in_species(@species) unless grep /^Any$/, @species;
  }

  if(my @chromos = $form->data_multiple('chromos')){
    $msearch->on_chr(@chromos) unless grep /^Any$/, @chromos;
    $msearchJ->on_chr(@chromos) unless grep /^Any$/, @chromos;
  }

  my $pos_start = $form->data('pos_start') || '';
  my $pos_end = $form->data('pos_end') || '';

  if ($pos_start or $pos_end){
    $msearch->position_between($pos_start, $pos_end);
    $msearchJ->position_between($pos_start, $pos_end);
  }

  if(my @conf = $form->data_multiple('confs')){
    $msearch->confidence_at_least(@conf) unless grep /^Any|uncalculated|-1$/, @conf;
  }

  if(my @maps = $form->data_multiple('maps')){
    $msearch->on_map(@maps) unless grep /^Any$/, @maps;
  }

  if(my @colls = $form->data_multiple('colls')){
    $msearch->in_collection(@colls) unless grep /^Any$/, @colls;
  }

  if($form->data('random') eq 'yes'){
    $msearch->random();
  }

  #$msearch->perform_search();
  #my @marker_ids = $msearch->fetch_id_list();

  #use Data::Dumper;
  #print '<pre>'.(Dumper \@marker_ids).'</pre>';

  #print '<!-- '. $msearch->query_text() . ' -->';
 
  my ($subq, $places) = $msearch->return_subquery_and_placeholders();
  my ($subq2) = $msearchJ->return_subquery();


  my $resultstart;
  my $resultsize;
  if (defined $form->data('resultstart')) {
      $resultstart = abs($form->data('resultstart'));
  } else {
      $resultstart = 0;
  }
  if (defined $form->data('resultsize')) {
      $resultsize = abs($form->data('resultsize'));
  } else {
      $resultsize = 30;
  }

  my $limitclause = " LIMIT $resultsize OFFSET $resultstart";
   $limitclause = "" if $form->data('text') && $form->data('text') eq 'yes';


  use Time::HiRes;
  my $timestart = Time::HiRes::time;

  # This is our query.
  my $resultcount;
  my $countquery;
  my %protocol_list;
  my @protocol_set;
  my $protocol_str;
  my $protocol_name;
  my @row;

  $query = "select cvterm_id from cvterm where name = 'vcf_map_details_markers'";
  my $sth = $dbh->prepare($query);
  $sth->execute();
  my ($protocol_markers_cvterm) = $sth->fetchrow_array();

  if($form->data('mapped') && $form->data('mapped') eq 'on'){
    $query = "select distinct subq.lg_order, subq.confidence_id, subq.marker_id, alias, protocol, short_name, subq.lg_name, subq.position, confidence_name FROM ($subq) as subq inner join marker_alias using(marker_id) left join marker_location as ml on (ml.location_id=subq.location_id) left join marker_experiment as me on(me.location_id = subq.location_id) left join map_version as mv on (mv.map_version_id=ml.map_version_id) left join map on (map.map_id = mv.map_id) left join linkage_group as lg on(lg.lg_id = ml.lg_id) left join marker_confidence on(marker_confidence.confidence_id=ml.confidence_id) WHERE preferred = 't' ORDER BY subq.lg_order, position, subq.confidence_id desc, short_name";

    # See how many rows we should get back.
    $countquery = "select count(*) from ($query) as countq";
    ($resultcount) = $dbh->selectrow_array($countquery, undef, @$places);
  } else {
    if ((defined $protocol) && ($protocol =~ /\d/)) {
        push @protocol_set, $protocol;
    } else {
	$sth = $dbh->prepare("select nd_protocol_id, name from nd_protocol");
        $sth->execute();
        while (@row = $sth->fetchrow_array()) {
            $protocol_list{$row[0]} = $row[1];
        }
	$query = "select cvterm_id from cvterm where name = 'vcf_map_details'";
        $sth = $dbh->prepare($query);
        $sth->execute();
        my ($protocol_map_cvterm) = $sth->fetchrow_array();
	$query = "select nd_protocol_id from nd_protocolprop WHERE '$marker_name' IN (SELECT jsonb_array_elements_text(nd_protocolprop.value->'marker_names') where type_id = $protocol_map_cvterm)";
        $sth = $dbh->prepare($query);
        $sth->execute();
        while (@row = $sth->fetchrow_array()) {
            push @protocol_set, $row[0];
        }
    }
    my $protocolprop_marker_hash_select = ['name', 'chrom', 'pos', 'alt', 'ref']; #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
      push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';
    $query = "select nd_protocol_id, s.value->>'name' as alias ,s.value->>'chrom' as lg_name ,s.value->>'pos' as position, s.value->>'ref' as ref, s.value->>'alt' as alt from nd_protocolprop, jsonb_each(nd_protocolprop.value) as s";
    $countquery = "select count(*) as countq from nd_protocolprop, jsonb_each(nd_protocolprop.value) as s";
    if (scalar(@protocol_set) > 0) {
        $protocol_str = join(',', @protocol_set);
        $query .= " WHERE nd_protocol_id IN ($protocol_str) AND type_id = $protocol_markers_cvterm";
	$countquery .= " WHERE nd_protocol_id IN ($protocol_str) AND type_id = $protocol_markers_cvterm";
    } else {
        $query .= " WHERE nd_protocol_id IN (null) AND type_id = $protocol_markers_cvterm";
	$countquery .= " WHERE nd_protocol_id IN (NULL) AND type_id = $protocol_markers_cvterm";
    }
    #print STDERR "query = $query\n";
    if ($subq2 ne "") {
	$query .= " AND $subq2";
	#print STDERR "query = $query\n";
    }
    $query .= " ORDER by s.value->>'name'";
    if ($subq2 ne "") {
        $countquery .= " AND $subq2";
	#print STDERR "subq2 = $subq2\n";
    }
    $places = ();
    ($resultcount) = $dbh->selectrow_array($countquery, undef, @$places);
  }

  # Do the query (with limits for pagination)
  my $search_results = $dbh->prepare("$query $limitclause");
  $search_results->execute(@$places);
  my $resultset = $search_results->fetchall_arrayref({});

  my $timeend = Time::HiRes::time;
  my $timeelapsed = sprintf("%.2f", $timeend - $timestart);

    if($form->data('text')){
      # we're outputting a text file

      print "Content-type: text/plain\n\n";

      print "SGN id\tmarker\tprotocol\tmap\tchromosome\tposition\tconfidence\n";
      foreach my $r (@$resultset){
	my $pos = '';
	$pos = sprintf("%.2f", $r->{position}) if ($r->{position} > 0 || $r->{lg_name});
	print "$r->{marker_id}\t$r->{alias}\t$r->{protocol}\t$r->{short_name}\t$r->{lg_name}\t$pos\t$r->{confidence_name}\n";
      }
      exit; # so footer doesn't print

    } else {

      if (@$resultset == 0){ 
	print blue_section_html('No results',"Sorry, no results matched your search criteria.\n" ); 
	
	print '<br /><br />', blue_section_html('Search Again', form_html($form));
	
      } else {
	
	
	my $tabledata;
	my $headings;
	my $pos;

    if($form->data('mapped') && $form->data('mapped') eq 'on'){
      $headings = "headings => ['Marker', 'Protocol', 'Map', 'Chromosome', 'Position', 'Confidence']";
      foreach my $r (@$resultset){
	$pos = '';
	$pos = sprintf("%.2f", $r->{position}) if ($r->{position} > 0 || $r->{lg_name});
      
        push(@$tabledata, [qq{<a href="/search/markers/markerinfo.pl?marker_id=$r->{marker_id}">$r->{alias}</a>}, $r->{protocol}, $r->{short_name}, $r->{lg_name}, $pos, $r->{confidence_name}]);
      }
    } else {
      $headings = "headings => ['Marker', 'Protocol', 'Chromosome', 'Position', 'Ref', 'Alt']";
      foreach my $r (@$resultset){
	 $protocol_name = $protocol_list{$r->{nd_protocol_id}};
         push(@$tabledata, [qq{<a href="/search/markers/markerinfo.pl?marker_name=$r->{alias}">$r->{alias}}, $protocol_name, $r->{lg_name}, $r->{position}, $r->{ref}, $r->{alt}]);
      }
    }

	my ($prevparams, $nextparams, $textparams);
	{
	  my %nextparams = %params;
	  $nextparams{$form->uniqify_name('resultstart')} = 
	    $resultstart + $resultsize;
	  $nextparams{$form->uniqify_name('resultsize')} = $resultsize;

	  $nextparams = params_to_string(\%nextparams);
	  HTML::Entities::encode_entities($nextparams);
	}
	{
	  my %prevparams = %params;
	  my $resstart = $form->uniqify_name('resultstart');
	  $prevparams{$resstart} = 
	    $resultstart - $resultsize;
	  $prevparams{$resstart} = 0 if $prevparams{$resstart} < 0;
	  $prevparams{$form->uniqify_name('resultsize')} = $resultsize;

	  $prevparams = params_to_string(\%prevparams);
	  HTML::Entities::encode_entities($prevparams);
	}

	{
	  my %textparams = %params;
	  my $text = $form->uniqify_name('text');
	  $textparams{$text} = 'yes';

	  $textparams = params_to_string(\%textparams);
	  HTML::Entities::encode_entities($textparams);
	}
	
	my $link = $ENV{SCRIPT_NAME};
	my $prevlink = qq{<a href="$link?$prevparams">\&laquo; Prev $resultsize</a>};
	my $nextlink = qq{<a href="$link?$nextparams">Next $resultsize \&raquo;</a>};
	my $textlink = qq{[Or <a href="$link?$textparams">download these results as a text file</a>]};

	#warn "link was $link?$textparams\n";

	if ($form->data('random')){
	  $textlink = '';
	}
	
	my $resultend = $resultstart + $resultsize;
	$resultstart++;
	
	if ($resultend >= $resultcount){
	  # there's no next result
	  $nextlink = qq{<span class="ghosted">Next $resultsize \&raquo;</span>};
	}
	
	if ($resultstart<=1){
	  # there's no prev result
	  $prevlink = qq{<span class="ghosted">\&laquo; Prev $resultsize</span>};
	}
	
	$resultend = $resultcount if $resultend > $resultcount;
	my $resultsummary = "Showing results $resultstart to $resultend of $resultcount. $textlink<br />$prevlink | $nextlink<br /><br />";
	
	# the form was submitted, so we should present some results.
	if($form->data('mapped') && $form->data('mapped') eq 'on'){
        print blue_section_html('Marker search results',
                                "$resultcount results found in $timeelapsed seconds",
                                $resultsummary
                                . columnar_table_html(
                                                      headings => ['Marker', 'Protocol', 'Map', 'Chromosome', 'Position', 'Confidence'],
                                                      data => $tabledata));
	} else {
	    print blue_section_html('Marker search results for ' . $protos[0],
                                "$resultcount results found in $timeelapsed seconds",
                                $resultsummary
                                . columnar_table_html(
                                                      headings => ['Marker', 'Protocol', 'Chromosome', 'Position', 'Ref', 'Alt'],
                                                      data => $tabledata));
        }

	print '<br /><br />', blue_section_html('Search again', form_html($form));
	
      } # end of if-else text output
    } 
} else {
  print form_html($form);  
}

sub params_to_string {
  
  my ($phash) = @_;

  # if any of these are multiples, we need to split them up. 
  # That's basically the reason for this function.
  my @parampairs;
  while (my ($k, $v) = each %$phash){

    my @vals = split /\0/, $v;
    foreach my $singleval (@vals){
      push(@parampairs, "$k=$singleval");
    }
    
  }
  my $paramstring = join '&', @parampairs;
  return $paramstring;

}       

sub form_html {
   
  # as soon as we get in here, $form is something older.

  my ($form) = @_;

  return 
  '<form action="markersearch.pl">'
  . $form->to_html() .
    '</form>';
}

$page->footer();
