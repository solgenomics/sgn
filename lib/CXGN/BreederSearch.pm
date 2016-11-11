=head1 NAME

CXGN::BreederSearch - class for retrieving breeder information for the breeder search wizard

=head1 AUTHORS

Lukas Mueller <lam87@cornell.edu>
Aimin Yan <ay247@cornell.edu>

=head1 METHODS

=cut

package CXGN::BreederSearch;

use Moose;
use Data::Dumper;
use Try::Tiny;

has 'dbh' => (
    is  => 'rw',
    required => 1,
    );
has 'dbname' => (
    is => 'rw',
    isa => 'Str',
    );

=head2 metadata_query

 Usage:        my %info = $bs->metadata_query($criteria_list, $dataref, $queryref);
 Desc:
 Ret:          returns a hash with a key called results that contains
               a listref of listrefs specifying the matching list with ids
               and names.
 Args:         criteria_list: a comma separated string called a criteria_list,
               listing all the criteria that need to be applied. Possible
               criteria are trials, years, traits, and locations. The last
               criteria in the list is the return type.
               dataref: The dataref is a hashref of hashrefs. The first key
               is the target of the transformation, and the second is the
               source type of the transformation, containing comma separated
               values of the source type.
               queryref: same structure as dataref, but instead of storing ids it stores a
               1 if user requested intersect, or 0 for default union
 Side Effects: will run refresh_matviews() if matviews aren't already populated
 Example:

=cut

sub metadata_query {
  my $self = shift;
  my $c = shift;
  my $criteria_list = shift;
  my $dataref = shift;
  my $queryref = shift;
  my $h;
  print STDERR "criteria_list=" . Dumper($criteria_list);
  print STDERR "dataref=" . Dumper($dataref);
  print STDERR "queryref=" . Dumper($queryref);

  # Check if matviews are populated, and run refresh if they aren't. Which, as of postgres 9.5, will be the case when our databases are loaded from a dump. This should no longer be necessary once this bug is fixed in newer postgres versions
  my ($status, %response_hash);
  try {
    my $populated_query = "select * from materialized_phenoview limit 1";
    my $sth = $self->dbh->prepare($populated_query);
    $sth->execute();
  } catch { #if test query fails because views aren't populated
    print STDERR "Using basic refresh to populate views . . .\n";
    $status = $self->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'basic');
    %response_hash = %$status;
  };

  if (%response_hash && $response_hash{'message'} eq 'Wizard update completed!') {
    print STDERR "Populated views, now proceeding with query . . . .\n";
  } elsif (%response_hash && $response_hash{'message'} eq 'Wizard update initiated.') {
    return { error => "The search wizard is temporarily unavailable while database indexes are being repopulated. Please try again later. Depending on the size of the database, it will be ready within a few seconds to an hour."};
  } elsif (%response_hash && $response_hash{'error'}) {
    return { error => $response_hash{'error'} };
  }

  my $target_table = $criteria_list->[-1];
  print STDERR "target_table=". $target_table . "\n";
  my $target = $target_table;
  $target =~ s/s$//;

  my $select = "SELECT ".$target."_id, ".$target."_name ";
  my $group = "GROUP BY ".$target."_id, ".$target."_name ";

  my $full_query;
  if (!$dataref->{"$target_table"}) {
    my $from = "FROM public.". $target_table;
    my $where = " WHERE ".$target."_id IS NOT NULL";
	  $full_query = $select . $from . $where;
  }
  else {
	  my @queries;
	  foreach my $category (@$criteria_list) {

      if ($dataref->{$criteria_list->[-1]}->{$category}) {
        my $query;
		    my @categories = ($target_table, $category);
	      @categories = sort @categories;
	      my $from = "FROM public.". $categories[0] ."x". $categories[1] . " JOIN public." . $target_table . " USING(" . $target."_id) ";
        my $criterion = $category;
        $criterion =~ s/s$//;
        my $intersect = $queryref->{$criteria_list->[-1]}->{$category};

        if ($intersect) {
          my @parts;
          my @ids = split(/,/, $dataref->{$criteria_list->[-1]}->{$category});
          foreach my $id (@ids) {
            my $where = "WHERE ". $criterion. "_id IN (". $id .") ";
            my $statement = $select . $from . $where . $group;
            push @parts, $statement;
          }
          $query = join (" INTERSECT ", @parts);
          push @queries, $query;
        }
        else {
          my $where = "WHERE ". $criterion. "_id IN (" . $dataref->{$criteria_list->[-1]}->{$category} . ") ";
          $query = $select . $from . $where . $group;
          push @queries, $query;
        }
      }
    }
    $full_query = join (" INTERSECT ", @queries);
  }
  $full_query .= " ORDER BY 2";
  print STDERR "QUERY: $full_query\n";
  $h = $self->dbh->prepare($full_query);
  $h->execute();

  my @results;
  while (my ($id, $name) = $h->fetchrow_array()) {
    push @results, [ $id, $name ];
  }

  if (@results >= 10_000) {
    return { error => scalar(@results).' matches. Too many results to display' };
  }
  elsif (@results < 1) {
    return { error => scalar(@results).' matches. No results to display' };
  }
  else {
    return { results => \@results };
  }
}

=head2 avg_phenotypes_query

parameters: trait_id, trial_id, allow_missing

returns: values, the avg pheno value of each accession in a trial for the given trait, and column_names, an array of the trait names

Side Effects: none

=cut

sub avg_phenotypes_query {
  my $self = shift;
  my $trial_id = shift;
  my $trait_ids = shift;
  my $weights = shift;
  my $controls = shift;
  my @trait_ids = @$trait_ids;
  my @weights = @$weights;
  my @controls = @$controls;
  my $allow_missing = shift;

  my $select = "SELECT table0.accession_id, table0.accession_name";
  my $from = " FROM (SELECT accession_id, accession_name FROM materialized_phenoview WHERE trial_id = $trial_id GROUP BY 1,2) AS table0";
  for (my $i = 1; $i <= scalar @trait_ids; $i++) {
    $select .= ",  ROUND( CAST(table$i.trait$i AS NUMERIC), 2)";
    $from .= " JOIN (SELECT accession_id, accession_name, AVG(phenotype_value::REAL) AS trait$i FROM materialized_phenoview WHERE trial_id = $trial_id AND trait_id = ? GROUP BY 1,2) AS table$i USING (accession_id)";
  }
  my $query = $select . $from . " ORDER BY 2";
  if ($allow_missing eq 'true') { $query =~ s/JOIN/FULL OUTER JOIN/g; }

  print STDERR "QUERY: $query\n";

  my $h = $self->dbh->prepare($query);
  $h->execute(@$trait_ids);

  my (@raw_avg_values, @reference_values, @rows_to_scale, @weighted_values);

  if (grep { defined($_) } @controls) {
  while (my @row = $h->fetchrow_array()) {
    push @rows_to_scale, @row;
    my ($id, $name, @avg_values) = @row;
    for my $i (0..$#controls) {
      my $control = $controls[$i] || 0;
      if ($id == $control) {
        #print STDERR "Matched control accession $name with values @avg_values\n";
        if (!defined(@avg_values[$i])) {
          return { error => "Can't scale values using control $name, it has a zero or undefined value for trait with id @$trait_ids[$i] in this trial. Please select a different control for this trait." };
        }
        $reference_values[$i] = $avg_values[$i];
      }
    }
  }
    for my $i (0..$#trait_ids) {
        $reference_values[$i] = 1 unless defined $reference_values[$i];
    }

    #print STDERR "reference values = @reference_values\n";
    $h->execute(@$trait_ids);
    while (my ($id, $name, @avg_values) = $h->fetchrow_array()) {

      my @scaled_values = map {sprintf("%.2f", $avg_values[$_] / $reference_values[$_])} 0..$#avg_values;
      my @scaled_and_weighted = map {sprintf("%.2f", $scaled_values[$_] * $weights[$_])} 0..$#scaled_values;
      unshift @scaled_values, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
      push @raw_avg_values, [@scaled_values];

      my $sum;
      map { $sum += $_ } @scaled_and_weighted;
      my $rounded_sum = sprintf("%.2f", $sum);
      push @scaled_and_weighted, $rounded_sum;
      unshift @scaled_and_weighted, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
      push @weighted_values, [@scaled_and_weighted];
    }

  } else {

  while (my ($id, $name, @avg_values) = $h->fetchrow_array()) {

    my @values_to_weight = @avg_values;
    unshift @avg_values, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
    push @raw_avg_values, [@avg_values];

    @values_to_weight = map {$values_to_weight[$_] * $weights[$_]} 0..$#values_to_weight;
    my $sum;
    map { $sum += $_ } @values_to_weight;
    unshift @values_to_weight, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
    my $rounded_sum = sprintf("%.2f", $sum);
    push @values_to_weight, $rounded_sum;
    push @weighted_values, [@values_to_weight];
  }

}

  my @weighted_values2 = sort { $b->[-1] <=> $a->[-1] } @weighted_values;
  my @weighted_values3;
  for (my $i = 0; $i < scalar @weighted_values2; $i++ ) {
    my $temp_array = $weighted_values2[$i];
    my @temp_array = @$temp_array;
    push @temp_array, $i+1;
    push @weighted_values3, [@temp_array];
  }

  #print STDERR "avg_phenotypes: ".Dumper(@raw_avg_values);
  #print STDERR "avg_phenotypes: ".Dumper(@weighted_values3);

  return {
    raw_avg_values => \@raw_avg_values,
    weighted_values => \@weighted_values3
  };

}

=head2 refresh_matviews

parameters: string to specify desired refresh type, basic or concurrent. defaults to concurrent

returns: message detailing success or error

Side Effects: Refreshes materialized views

=cut

sub refresh_matviews {

  my $self = shift;
  my $dbhost = shift;
  my $dbname = shift;
  my $dbuser = shift;
  my $dbpass = shift;
  my $refresh_type = shift || 'concurrent';
  my $refresh_finished = 0;
  my $async_refresh;

  my $q = "SELECT currently_refreshing FROM public.matviews WHERE mv_id=?";
  my $h = $self->dbh->prepare($q);
  $h->execute(1);

  my $refreshing = $h->fetchrow_array();

  if ($refreshing) {
    return { error => 'Wizard update already in progress . . . ' };
  }
  else {
    try {
      my $dbh = $self->dbh();
      if ($refresh_type eq 'concurrent') {
        #print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -c";
        $async_refresh = CXGN::Tools::Run->run_async("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -c");
      } else {
        print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass";
        $async_refresh = CXGN::Tools::Run->run_async("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");
      }

      for (my $i = 1; $i < 10; $i++) {
        sleep($i/5);
        if ($async_refresh->alive) {
          next;
        } else {
          $refresh_finished = 1;
        }
      }

      if ($refresh_finished) {
        return { message => 'Wizard update completed!' };
      } else {
        return { message => 'Wizard update initiated.' };
      }
    } catch {
      print STDERR 'Error initiating wizard update.' . $@ . "\n";
      return { error => 'Error initiating wizard update.' . $@ };
    }
  }
}

=head2 matviews_status

Desc: checks tracking table to see if materialized views are updating, and if not, when they were last updated.

parameters: None.

returns: refreshing message or timestamp

Side Effects: none

=cut

sub matviews_status {
  my $self = shift;
  my $q = "SELECT currently_refreshing, last_refresh FROM public.matviews WHERE mv_id=?";
  my $h = $self->dbh->prepare($q);
  $h->execute(1);

  my ($refreshing, $timestamp) = $h->fetchrow_array();

  if ($refreshing) {
    print STDERR "Wizard is already refreshing, current status: $refreshing \n";
    return { refreshing => "<p id='wizard_status'>Wizard update in progress . . . </p>"};
  }
  else {
    print STDERR "materialized fullview last updated $timestamp\n";
    return { timestamp => "<p id='wizard_status'>Wizard last updated: $timestamp</p>" };
  }
}



1;
