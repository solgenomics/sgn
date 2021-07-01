
package main;


use strict;
use CXGN::Page;
use CXGN::Search::CannedForms;
use CXGN::Page::FormattingHelpers qw/blue_section_html  page_title_html columnar_table_html/;
use CXGN::DB::Connection;
use CXGN::Marker::Search;
use HTML::Entities;

our $page = CXGN::Page->new( "Marker Search", "Beth Skwarecki");

my %params=$page->cgi_params();
#use Data::Dumper
#warn Dumper \%params;
my $dbh=CXGN::DB::Connection->new();


my $form = CXGN::Search::CannedForms::MarkerSearch->new($dbh);
$form->set_data(%params);
$form->from_request(\%params);

#warn "name param is $params{w822_marker_name}\n";
#warn "name param is ". $form->data('marker_name');

$page->header('SGN: Marker search') unless $form->data('text');


if($form->data('submit') && ($form->data('submit') eq 'Search') || ($form->data('random') && $form->data('random') eq 'yes')) {


  #use Data::Dumper;
  #print '<pre>' .(Dumper \%params). '</pre>';


  # do the search!

  my $msearch = CXGN::Marker::Search->new($dbh);

  if(my $marker_name = $form->data('marker_name')){

    if($form->data('nametype') eq 'exactly'){
      # using name_exactly would be more efficient, 
      # but we probably want to be case-insensitive.
      $msearch->name_like($marker_name);
    } elsif ($form->data('nametype') eq 'contains'){
      $msearch->name_like('%'.$marker_name.'%');
    } elsif ($form->data('nametype') eq 'starts with'){
      $msearch->name_like($marker_name.'%');
    }

  }
  

  if($form->data('mapped') && $form->data('mapped') eq 'on'){
    #warn "MUST BE MAPPED\n";
    $msearch->must_be_mapped();
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

  if(my @protos = $form->data_multiple('protos')){
    $msearch->protocol(@protos) unless grep /^Any$/, @protos;
  }

  if(my @chromos = $form->data_multiple('chromos')){
    $msearch->on_chr(@chromos) unless grep /^Any$/, @chromos;
  }

  my $pos_start = $form->data('pos_start') || '';
  my $pos_end = $form->data('pos_end') || '';

  if ($pos_start or $pos_end){
    $msearch->position_between($pos_start, $pos_end);
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
  #warn $msearch->query_text();

  my $resultstart = abs($form->data('resultstart')) || 0;
  my $resultsize = abs($form->data('resultsize')) || 30;

  my $limitclause = " LIMIT $resultsize OFFSET $resultstart";
   $limitclause = "" if $form->data('text') && $form->data('text') eq 'yes';


  use Time::HiRes;
  my $timestart = Time::HiRes::time;

  # This is our query.
  my $query = "select distinct subq.lg_order, subq.confidence_id, subq.marker_id, alias, protocol, short_name, subq.lg_name, subq.position, confidence_name FROM ($subq) as subq inner join marker_alias using(marker_id) left join marker_location as ml on (ml.location_id=subq.location_id) left join marker_experiment as me on(me.location_id = subq.location_id) left join map_version as mv on (mv.map_version_id=ml.map_version_id) left join map on (map.map_id = mv.map_id) left join linkage_group as lg on(lg.lg_id = ml.lg_id) left join marker_confidence on(marker_confidence.confidence_id=ml.confidence_id) WHERE preferred = 't' ORDER BY subq.lg_order, position, subq.confidence_id desc, short_name";

  # See how many rows we should get back.
  my $countquery = "select count(*) from ($query) as countq";
  my ($resultcount) = $dbh->selectrow_array($countquery, undef, @$places);

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
	
    foreach my $r (@$resultset){
	my $pos = '';
	$pos = sprintf("%.2f", $r->{position}) if ($r->{position} > 0 || $r->{lg_name});
      
      push(@$tabledata, [qq{<a href="/search/markers/markerinfo.pl?marker_id=$r->{marker_id}">$r->{alias}</a>}, $r->{protocol}, $r->{short_name}, $r->{lg_name}, $pos, $r->{confidence_name}]);
      
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
	print blue_section_html('Marker search results', 
				"$resultcount results found in $timeelapsed seconds", 
				$resultsummary
				. columnar_table_html(
						      headings => ['Marker', 'Protocol', 'Map', 'Chromosome', 'Position', 'Confidence'],
						      data => $tabledata));
	
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