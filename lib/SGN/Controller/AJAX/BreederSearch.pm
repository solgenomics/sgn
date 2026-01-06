
package SGN::Controller::AJAX::BreederSearch;

use Moose;

use List::MoreUtils qw | any all |;
use JSON;
use Data::Dumper;
use Try::Tiny;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

sub get_data : Path('/ajax/breeder/search') Args(0) {
  my $self = shift;
  my $c = shift;
  my $j = JSON->new;

  my @criteria_list = $c->req->param('categories[]');
  my @querytypes = $c->req->param('querytypes[]');

  #print STDERR "criteria list = " . Dumper(@criteria_list);
  #print STDERR "querytypes = " . Dumper(@querytypes);

  my $dataref = {};
  my $queryref = {};

  my $error = '';

  print STDERR "Validating criteria_list\n";
  foreach my $select (@criteria_list) { #ensure criteria list arguments are one of the possible categories
    chomp($select);
    if (! any { $select eq $_ } ('accessions', 'accessions_ids','organisms','breeding_programs', 'genotyping_protocols', 'genotyping_projects', 'locations', 'plants', 'plots', 'subplots','tissue_sample','populations','seedlots', 'trait_components', 'traits', 'trials', 'trial_designs', 'trial_types', 'years', undef)) {
      $error = "Valid keys are accessions, organisms, breeding_programs, genotyping_protocols, genotyping_projects, locations, plants, plots, subplots,tissue_sample, seedlots, trait_components, traits, trials, trial_designs, trial_types and years or undef";
      $c->stash->{rest} = { error => $error };
      return;
    }
  }

  print STDERR "Validating query types\n";
  foreach my $binary_number (@querytypes) {# ensure querytype arguments are 0 or 1
    chomp($binary_number);
    if ( $binary_number < 0 || $binary_number > 1 ) {
      $error = "Valid querytypes are '1' for intersect or '0' for union or between 0 and 1 for percent match";
      $c->stash->{rest} = { error => $error };
      return;
    }
  }

  my $criteria_list = \@criteria_list;
  for (my $i=0; $i<scalar(@$criteria_list); $i++) {
    my @data;
    my $param = $c->req->param("data[$i][]");
    if (defined($param) && ($param ne '')) { @data =  $c->req->param("data[$i][]"); }

    if (@data) {
      print STDERR "Validating dataref ids\n";
      for (my $i=0; $i<@data; $i++) { # ensure dataref arguements (ids) are numeric
        if (m/\D/) {
          $error = "Valid values for dataref are numeric ids";
          $c->stash->{rest} = { error => $error };
          return;
        }
      }
      my @cdata = map {"'$_'"} @data;
      my $qdata = join ",", @cdata;
      $dataref->{$criteria_list->[-1]}->{$criteria_list->[$i]} = $qdata;
      $queryref->{$criteria_list->[-1]}->{$criteria_list->[$i]} = $querytypes[$i];
    }
  }

  my $dbh = $c->dbc->dbh();
  my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
  my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
  if ($status->{'error'}) {
      $c->stash->{rest} = { error => $status->{'error'}};
      return;
  }
  my $results_ref = $bs->metadata_query(\@criteria_list, $dataref, $queryref);

  #print STDERR "RESULTS: ".Data::Dumper::Dumper($results_ref);
  my @results =@{$results_ref->{results}};


##  if (@results >= 100_000) {
##    $c->stash->{rest} = { list => [], message => scalar(@results).' matches. This is too many to display, please narrow your search' };
##    return;
##  }
  if (@results >= 10_000) {
    $c->stash->{rest} = { list => \@results, message => 'Over 10,000 matches. Speeds may be affected, consider narrowing your search' };
    return;
  }
  elsif (@results < 1) {
    $c->stash->{rest} = { list => \@results, message => scalar(@results).' matches. Nothing to display' };
    return;
  }
  else {
    $c->stash->{rest} = { list => \@results };
    return;
  }

}

sub get_avg_phenotypes : Path('/ajax/breeder/search/avg_phenotypes') Args(0) {
  my $self = shift;
  my $c = shift;

  my $trial_id = $c->req->param('trial_id');
  my @trait_ids = $c->req->param('trait_ids[]');
  my @weights = $c->req->param('coefficients[]');
  my @controls = $c->req->param('controls[]');
  my $allow_missing = $c->req->param('allow_missing');

  my $dbh = $c->dbc->dbh();
  my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );

  my $results_ref = $bs->avg_phenotypes_query($trial_id, \@trait_ids, \@weights, \@controls, $allow_missing);

  $c->stash->{rest} = {
    error => $results_ref->{'error'},
    raw_avg_values => $results_ref->{'raw_avg_values'},
    weighted_values => $results_ref->{'weighted_values'}
  };

  return;

}


sub get_genotyping_protocol_chromosomes : Path('/ajax/breeder/search/genotyping_protocol_chromosomes') Args(0) {
  my $self = shift;
  my $c = shift;
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

  my $genotyping_protocol_id = $c->req->param('genotyping_protocol');
  
  # Prtocol ID not defined, use the default genotyping protocol
  if ( !defined($genotyping_protocol_id) || $genotyping_protocol_id eq "" ) {
    my $genotyping_protocol_name = $c->config->{default_genotyping_protocol};
    if ( defined($genotyping_protocol_name) ) {
      my $genotyping_protocol_rs = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$genotyping_protocol_name});
      if ( defined($genotyping_protocol_rs) ) {
        $genotyping_protocol_id = $genotyping_protocol_rs->nd_protocol_id();
      } 
    }
  }

  # Get chromosome names for the specified protocol
  my @names=();
  if ( defined($genotyping_protocol_id) && $genotyping_protocol_id ne "" ) {
    my $vcf_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "vcf_map_details_markers", "protocol_property")->cvterm_id();
    my $q = "SELECT DISTINCT(s.value->>'chrom') AS chrom 
            FROM nd_protocolprop, jsonb_each(nd_protocolprop.value) AS s 
            WHERE nd_protocol_id = ? AND type_id = ? ORDER BY chrom ASC;";
    my $dbh = $c->dbc->dbh();
    my $h = $dbh->prepare($q);
    $h->execute($genotyping_protocol_id, $vcf_cvterm_id);

    while(my ($chrom) = $h->fetchrow_array()){
      push @names, $chrom;
    }
  }

  $c->stash->{rest} = {
    genotyping_protocol => $genotyping_protocol_id,
    chromosome_names => \@names
  };

  return;
}


sub refresh_matviews : Path('/ajax/breeder/refresh') Args(0) {
  my $self = shift;
  my $c = shift;
  my $matviews = $c->req->param('matviews') || 'fullview'; #can be "fullview" or "stockprop"

  print STDERR "dbname=" . $c->config->{dbname} ."\n";

  my $dbh = $c->dbc->dbh();
  my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
  my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, $matviews, 'concurrent', $c->config->{basepath});

  if ($refresh->{error}) {
    print STDERR "Returning with error . . .\n";
    $c->stash->{rest} = { error => $refresh->{'error'} };
    return;
  }
  else {
    $c->stash->{rest} = { message => $refresh->{'message'} };
    return;
  }
}

sub check_status : Path('/ajax/breeder/check_status') Args(0) {
  my $self = shift;
  my $c = shift;

  my $dbh = $c->dbc->dbh();

  my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
  my $status = $bs->matviews_status();

  if ($status->{refreshing}) {
    $c->stash->{rest} = { refreshing => $status->{'refreshing'} };
    return;
  }
  else {
    $c->stash->{rest} = { timestamp => $status->{'timestamp'} };
    return;
  }
}
