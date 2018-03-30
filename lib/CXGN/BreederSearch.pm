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
use Scalar::Util qw(looks_like_number);
use CXGN::Stock::StockLookup;


has 'bcs_schema' => (
    isa => "Bio::Chado::Schema",
    is => 'ro',
    required => 1,
    );
has 'dbh' => (
    is  => 'rw',
    required => 1,
    );
has 'dbname' => (
    is => 'rw',
    isa => 'Str',
    );

=head2 metadata_query

 Usage:        my $results_ref = $bs->metadata_query($criteria_list, $dataref, $queryref);

 Ret:          returns a hash with a list of ids and names that were matched.

 Args:         criteria_list: a comma separated string of criteria categories. Possible
               criteria include accessions, breeding programs, genotyping protocols,
               locations, plots, plants, trials, trial_designs, traits, and years. The last
               criteria in the list is the return type.

               dataref: The dataref is a hashref of hashrefs. The first key
               is the target of the transformation, and the second is the
               source type of the transformation, containing comma separated
               values of the source type.

               queryref: same structure as dataref, but instead of storing ids it stores a
               1 if user to retrieve an intersection of matches, or 0 for the default union

 Side Effects: none
 Example:   retrieving all the trials from location 'test_location' (location_id = 23) and year '2014' in the fixture db:

 my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
 my $criteria_list = [
                'years',
                'locations',
                'trials'
              ];
 my $dataref = {
                'trials' => {
                            'locations' => '\'23\'',
                            'years' => '\'2014\''
                          }
              };
 my $queryref = {
                'trials' => {
                            'locations' => 0,
                            'years' => 0
                          }
              };

 my $results_ref = $bs ->metadata_query($criteria_list, $dataref, $queryref);

 print Dumper($results);
 will give you:

            {
                'results' => [
                               [
                                 139,
                                 'Kasese solgs trial'
                               ],
                               [
                                 137,
                                 'test_trial'
                               ],
                               [
                                 141,
                                 'trial2 NaCRRI'
                               ]
                             ]
              },
=cut

sub metadata_query {
  my $self = shift;
  my $criteria_list = shift;
  my $dataref = shift;
  my $queryref = shift;
  my $h;
  print STDERR "criteria_list=" . Dumper($criteria_list);
  print STDERR "dataref=" . Dumper($dataref);
  print STDERR "queryref=" . Dumper($queryref);

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

  return { results => \@results };

}

=head2 avg_phenotypes_query

parameters: trait_id, trial_id, allow_missing

returns: values, the avg pheno value of each accession in a trial for the given trait, and column_names, an array of the trait names

Side Effects: none

=cut

sub avg_phenotypes_query {
  my $self = shift;
  my $trial_ids = shift;
  my $trait_ids = shift;
  my $weights = shift;
  my $controls = shift;
  my @trait_ids = @$trait_ids;
  my @weights = @$weights;
  my @controls = @$controls;
  my $allow_missing = shift;

  my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
      bcs_schema=>$self->bcs_schema(),
      search_type=>'Native',
      data_level=>'plot',
      trait_list=>$trait_ids,
      trait_component_list=>'',
      trial_list=>$trial_ids,
      year_list=>[],
      location_list=>[],
      accession_list=>[],
      plot_list=>[],
      plant_list=>[],
      include_timestamp=>0,
      include_row_and_column_numbers=>0,
      exclude_phenotype_outlier=>0,
      trait_contains=>[""],
      phenotype_min_value=>'',
      phenotype_max_value=>'',
  );
  my @data = $phenotypes_search->get_phenotype_matrix();

  # reduce matrix to just accession name and trait values
  splice(@$_, 0, 7) foreach @data;
  splice(@$_, 1, 7) foreach @data;
  print STDERR "Data is: " . Dumper(@data);

  # combine plot level measurements into accession averages.
  my %hash;
  my $length;
  foreach my $row (@data) {
      my @row = @{$row};
      my $name = shift @row;
      $length = scalar @row - 1;
      for my $i (0 .. $#row) {
          if (looks_like_number($row[$i])) {
              $hash{$name}{$i}{'count'} += 1;
              $hash{$name}{$i}{'sum'} += $row[$i];
          }
      }
  }

  my @averages;
  #print STDERR "Length is $length\n";
  foreach my $key (keys %hash) {
      #print STDERR "First sum is: ". $hash{$key}{0}{'sum'} . "and count is: ". $hash{$key}{0}{'count'};
      #print STDERR "Second sum is: ". $hash{$key}{1}{'sum'} . "and count is: ". $hash{$key}{1}{'count'};
      #print STDERR "Third sum is: ". $hash{$key}{2}{'sum'} . "and count is: ". $hash{$key}{2}{'count'};
      my @means = map {
          if ( $hash{$key}{$_}{'sum'} && $hash{$key}{$_}{'count'} ) {
              $hash{$key}{$_}{'sum'} / $hash{$key}{$_}{'count'};
          } else {
              'missing data';
          }
      } (0 ..$length);
      unshift @means, $key;
      print STDERR "Means are @means\n";

      my %means = map { $_ => 1 } @means;
      if (exists($means{'missing data'})) {
          print STDERR "Skipping clone due to incomplete data";
      } {
          my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $self->bcs_schema(), stock_name=>$key);
          my $stock_id = $stock_lookup->get_stock_exact()->stock_id();
          print STDERR "Stock $key has id ".$stock_id."\n";
          unshift @means, $stock_id;
          push @averages, [@means];
      }

  }

  #print STDERR "Averages are: " . Dumper(@averages);
  print STDERR "Averages are calculated!\n";

  # my $select = "SELECT table0.accession_id, table0.accession_name";
  # my $from = " FROM (SELECT accession_id, accession_name FROM materialized_phenoview JOIN accessions USING (accession_id) WHERE trial_id = $trial_id GROUP BY 1,2) AS table0";
  # for (my $i = 1; $i <= scalar @trait_ids; $i++) {
  #   $select .= ",  ROUND( CAST(table$i.trait$i AS NUMERIC), 2)";
  #   $from .= " JOIN (SELECT accession_id, accession_name, AVG(value::REAL) AS trait$i FROM materialized_phenoview JOIN accessions USING (accession_id) JOIN phenotype USING (phenotype_id) WHERE trial_id = $trial_id AND trait_id = ? GROUP BY 1,2) AS table$i USING (accession_id)";
  # }
  # my $query = $select . $from . " ORDER BY 2";
  # if ($allow_missing eq 'true') { $query =~ s/JOIN/FULL OUTER JOIN/g; }
  #
  # print STDERR "QUERY: $query\n";
  #
  # my $h = $self->dbh->prepare($query);
  # $h->execute(@$trait_ids);

  my (@raw_avg_values, @reference_values, @rows_to_scale, @weighted_values);

  if (grep { defined($_) } @controls) {
      foreach my $row (@averages) {
  # while (my @row = $h->fetchrow_array()) {
    my @row = @{$row};
    push @rows_to_scale, @row;
    my ($id, $name, @avg_values) = @row;
    for my $i (0..$#controls) {
      my $control = $controls[$i] || 0;
      if ($id == $control) {
        #print STDERR "Matched control accession $name with values @avg_values\n";
        if (!defined($avg_values[$i])) {
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
    # $h->execute(@$trait_ids);
    # while (my ($id, $name, @avg_values) = $h->fetchrow_array()) {
        foreach my $row (@averages) {
    # while (my @row = $h->fetchrow_array()) {
      my @avg_values = @{$row};
        my $id = shift @avg_values;
        my $name = shift @avg_values;

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

  # while (my ($id, $name, @avg_values) = $h->fetchrow_array()) {
  foreach my $row (@averages) {
# while (my @row = $h->fetchrow_array()) {
    my @avg_values = @{$row};
    my $id = shift @avg_values;
    my $name = shift @avg_values;
    print STDERR "Separating values. Id is $id and name is $name\n";

    my @values_to_weight = @avg_values;
    unshift @avg_values, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
    push @raw_avg_values, [@avg_values];

    print STDERR "Weighting values\n";
    @values_to_weight = map {$values_to_weight[$_] * $weights[$_]} 0..$#values_to_weight;
    my $sum;
    map { $sum += $_ } @values_to_weight;
    unshift @values_to_weight, '<a href="/stock/'.$id.'/view">'.$name.'</a>';
    my $rounded_sum = sprintf("%.2f", $sum);
    push @values_to_weight, $rounded_sum;
    push @weighted_values, [@values_to_weight];
  }

}
    print "Sorting values by total weighted value\n";
  my @weighted_values2 = sort { $b->[-1] <=> $a->[-1] } @weighted_values;
  print STDERR "Adding order numbers to values\n";
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

=head2 test_matviews

parameters: db parameters

returns: message detailing matview status

Side Effects: If they are unavailable, it will use the refresh_matviews method to populate the materialized views

=cut


sub test_matviews {

  my $self = shift;
  my $dbhost = shift;
  my $dbname = shift;
  my $dbuser = shift;
  my $dbpass = shift;
  my ($status, %response_hash);

  try {
    my $populated_query = "select * from materialized_phenoview limit 1";
    my $sth = $self->dbh->prepare($populated_query);
    $sth->execute();
  } catch { #if test query fails because views aren't populated
    print STDERR "Using basic refresh to populate views . . .\n";
    $status = $self->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'basic');
    %response_hash = %$status;
  };

  if (%response_hash && $response_hash{'message'} eq 'Wizard update completed!') {
    print STDERR "Populated views, now proceeding with query . . . .\n";
    return { status => "Populated views, query can proceed." };
  } elsif (%response_hash && $response_hash{'message'} eq 'Wizard update initiated.') {
    return { error => "The search wizard is temporarily unavailable while database indexes are being repopulated. Please try again later." };
  } elsif (%response_hash && $response_hash{'error'}) {
    return { error => $response_hash{'error'} };
  } else {
    return { success => "Test successful, query can proceed." };
  }
}

=head2 refresh_matviews

parameters: db parameters, and a string to specify desired refresh type, basic or concurrent. defaults to concurrent

returns: message detailing success or error

Side Effects: Refreshes materialized views

=cut

sub refresh_matviews {

  my $self = shift;
  my $dbhost = shift;
  my $dbname = shift;
  my $dbuser = shift;
  my $dbpass = shift;
  my $materialized_view = shift || 'fullview'; #Can be 'fullview' or 'stockprop'
  my $refresh_type = shift || 'concurrent';
  my $refresh_finished = 0;
  my $async_refresh;

  my $q = "SELECT currently_refreshing FROM public.matviews WHERE mv_id=?";
  my $h = $self->dbh->prepare($q);
  $h->execute(1);

  my $refreshing = $h->fetchrow_array();

  if ($refreshing) {
    return { error => $materialized_view.' update already in progress . . . ' };
  }
  else {
    try {
      my $dbh = $self->dbh();
      if ($refresh_type eq 'concurrent') {
        print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -m $materialized_view -c\n";
        $async_refresh = CXGN::Tools::Run->run_async("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -m $materialized_view -c");
      } else {
        print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -m $materialized_view\n";
        $async_refresh = CXGN::Tools::Run->run_async("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -m $materialized_view");
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
        return { message => $materialized_view.' update completed!' };
      } else {
        return { message => $materialized_view.' update initiated.' };
      }
    } catch {
      print STDERR 'Error initiating '.$materialized_view.' update.' . $@ . "\n";
      return { error => 'Error initiating '.$materialized_view.' update.' . $@ };
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
    print STDERR "materialized views last updated $timestamp\n";
    return { timestamp => "<p id='wizard_status'>Wizard last updated: $timestamp</p>" };
  }
}



1;
