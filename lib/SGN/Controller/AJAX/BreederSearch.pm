
package SGN::Controller::AJAX::BreederSearch;

use Moose;

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use Try::Tiny;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub get_data : Path('/ajax/breeder/search') Args(0) {
  my $self = shift;
  my $c = shift;
  my $j = JSON::Any->new;

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
    if (! any { $select eq $_ } ('accessions', 'breeding_programs', 'genotyping_protocols', 'locations', 'plants', 'plots', 'trait_components', 'traits', 'trials', 'trial_designs', 'trial_types', 'years', undef)) {
      $error = "Valid keys are accessions, breeding_programs, 'genotyping_protocols', locations, 'plants', plots, 'trait_components', traits, trials, trial_designs, trial_types and years or undef";
      $c->stash->{rest} = { error => $error };
      return;
    }
  }

  print STDERR "Validating query types\n";
  foreach my $binary_number (@querytypes) {# ensure querytype arguments are 0 or 1
    chomp($binary_number);
    if (! any { $binary_number == $_ } ( 0 , 1 )) {
      $error = "Valid querytypes are '1' for intersect or '0' for union";
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

  print STDERR "RESULTS: ".Data::Dumper::Dumper($results_ref);
  my @results =@{$results_ref->{results}};


  if (@results >= 100_000) {
    $c->stash->{rest} = { list => [], message => scalar(@results).' matches. This is too many to display, please narrow your search' };
    return;
  }
  elsif (@results >= 10_000) {
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

sub refresh_matviews : Path('/ajax/breeder/refresh') Args(0) {
  my $self = shift;
  my $c = shift;

  print STDERR "dbname=" . $c->config->{dbname} ."\n";

  my $dbh = $c->dbc->dbh();
  my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
  my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});

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
