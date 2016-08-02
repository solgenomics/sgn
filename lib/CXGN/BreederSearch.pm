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
    $status = $self->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'basic');
    %response_hash = %$status;
  };

  if (%response_hash && $response_hash{'message'} eq 'Wizard update completed!') {
    print STDERR "Populated views, now proceeding with query . . . .\n";
  } elsif (%response_hash && $response_hash{'message'} eq 'Wizard update initiated.') {
    return { error => "The search wizard is temporarily unavailable while database indexes are being repopulated. Please try again later. Depending on the size of the database, it will be ready within a few minutes to an hour."};
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
      my $dbh = $self->dbh;
      if ($refresh_type eq 'concurrent') {
        #print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -c";
        $async_refresh = CXGN::Tools::Run->run_async("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -c");
      } else {
        #print STDERR "Using CXGN::Tools::Run to run perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass";
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

sub get_phenotype_info {
    my $self = shift;
    my $accession_sql = shift;
    my $trial_sql = shift;
    my $trait_sql = shift;

    print STDERR "GET_PHENOTYPE_INFO: $accession_sql - $trial_sql - $trait_sql \n\n";

    my $rep_type_id = $self->get_stockprop_type_id("replicate");
    my $block_number_type_id = $self -> get_stockprop_type_id("block");
    my $year_type_id = $self->get_projectprop_type_id("project year");
    my $plot_type_id = $self->get_stock_type_id("plot");
    my $accession_type_id = $self->get_stock_type_id("accession");

    my @where_clause = ();
    if ($accession_sql) { push @where_clause,  "stock.stock_id in ($accession_sql)"; }
    if ($trial_sql) { push @where_clause, "project.project_id in ($trial_sql)"; }
    if ($trait_sql) { push @where_clause, "cvterm.cvterm_id in ($trait_sql)"; }

    my $where_clause = "";

    if (@where_clause>0) {
	$where_clause .= $rep_type_id ? "WHERE (stockprop.type_id = $rep_type_id OR stockprop.type_id IS NULL) " : "WHERE stockprop.type_id IS NULL";
	$where_clause .= "AND plot.type_id = $plot_type_id AND stock.type_id = $accession_type_id";
	$where_clause .= $block_number_type_id  ? " AND (block_number.type_id = $block_number_type_id OR block_number.type_id IS NULL)" : " AND block_number.type_id IS NULL";
	$where_clause .= $year_type_id ? " AND projectprop.type_id = $year_type_id" :"" ;
	$where_clause .= " AND " . (join (" AND " , @where_clause));

	#$where_clause = "where (stockprop.type_id=$rep_type_id or stockprop.type_id IS NULL) AND (block_number.type_id=$block_number_type_id or block_number.type_id IS NULL) AND  ".(join (" and ", @where_clause));
    }

    my $order_clause = " order by project.name, plot.uniquename";
    my $q = "SELECT projectprop.value, project.name, stock.uniquename, nd_geolocation.description, cvterm.name, phenotype.value, plot.uniquename, db.name, db.name ||  ':' || dbxref.accession AS accession, stockprop.value, block_number.value AS rep, cvterm.cvterm_id, project.project_id, nd_geolocation.nd_geolocation_id, stock.stock_id, plot.stock_id, phenotype.uniquename
             FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id)
             JOIN stock ON (object_id=stock.stock_id)
             LEFT JOIN stockprop ON (plot.stock_id=stockprop.stock_id)
             LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id)
             JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id)
             JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN nd_geolocation USING(nd_geolocation_id)
             JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN phenotype USING(phenotype_id) JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
             JOIN cv USING(cv_id)
             JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
             JOIN db USING(db_id)
             JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN project USING(project_id)
  JOIN projectprop USING(project_id)
             $where_clause
             $order_clause";

    #print STDERR "QUERY: $q\n\n";
    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $result = [];
    while (my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename) = $h->fetchrow_array()) {
	push @$result, [ $year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename ];

    }
    #print STDERR Dumper $result;
    print STDERR "QUERY returned ".scalar(@$result)." rows.\n";
    return $result;
}

sub get_phenotype_info_matrix {
    my $self = shift;
    my $accession_sql = shift;
    my $trial_sql = shift;
    my $trait_sql = shift;

    my $data = $self->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
    #data contains [$year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id]

    my %plot_data;
    my %traits;

    foreach my $d (@$data) {
	print STDERR "PRINTING TRAIT DATA FOR TERM " . $d->[4] . "\n\n";
	my $cvterm = $d->[4]."|".$d->[8];
	my $trait_data = $d->[5];
	my $plot = $d->[6];
	$plot_data{$plot}->{$cvterm} = $trait_data;
	$traits{$cvterm}++;
    }

    my @info = ();
    my $line = "";

    # generate header line
    #
    my @sorted_traits = sort keys(%traits);
    foreach my $trait (@sorted_traits) {
	$line .= "\t".$trait;  # first header has to be empty (plot name column)
    }
    push @info, $line;

    # dump phenotypic values
    #
    my $count2 = 0;
    foreach my $plot (sort keys (%plot_data)) {
	$line = $plot;

	foreach my $trait (@sorted_traits) {
	    my $tab = $plot_data{$plot}->{$trait}; # ? "\t".$plot_data{$plot}->{$trait} : "\t";
	    $line .= defined($tab) ? "\t".$tab : "\t";

	}
	push @info, $line;
    }

    return @info;
}

sub get_extended_phenotype_info_matrix {
    my $self = shift;
    my $accession_sql = shift;
    my $trial_sql = shift;
    my $trait_sql = shift;
    my $include_timestamp = shift // 0;

    my $data = $self->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
    #data contains [$year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename]

    my %plot_data;
    my %traits;

    print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
    foreach my $d (@$data) {

        my ($year, $project_name, $stock_name, $location, $trait, $trait_data, $plot, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename) = @$d;

        my $cvterm = $d->[4]."|".$d->[8];
        if ($include_timestamp) {
            my ($p1, $p2) = split /date: /, $phenotype_uniquename;
            my ($timestamp, $p3) = split /  operator/, $p2;
            if( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                $plot_data{$plot}->{$cvterm} = "$trait_data,$timestamp";
            } else {
                $plot_data{$plot}->{$cvterm} = $trait_data;
            }
        } else {
            $plot_data{$plot}->{$cvterm} = $trait_data;
        }

        if (!defined($rep)) { $rep = ""; }
        $plot_data{$plot}->{metadata} = {
            rep => $rep,
            studyName => $project_name,
            germplasmName => $stock_name,
            locationName => $location,
            blockNumber => $block_number,
            plotName => $plot,
            cvterm => $cvterm,
            trait_data => $trait_data,
            year => $year,
            cvterm_id => $trait_id,
            studyDbId => $project_id,
            locationDbId => $location_id,
            germplasmDbId => $stock_id,
            plotDbId => $plot_id
        };
        $traits{$cvterm}++;
    }

    my @info = ();
    my $line = join "\t", qw | studyYear studyDbId studyName locationDbId locationName germplasmDbId germplasmName plotDbId plotName rep blockNumber |;

    # generate header line
    #
    my @sorted_traits = sort keys(%traits);
    foreach my $trait (@sorted_traits) {
	$line .= "\t".$trait;
    }
    push @info, $line;

    # dump phenotypic values
    #
    my $count2 = 0;

    my @unique_plot_list = ();
    my $previous_plot = "";
    foreach my $d (@$data) {
	my $plot = $d->[6];
	if ($plot ne $previous_plot) {
	    push @unique_plot_list, $plot;
	}
	$previous_plot = $plot;
    }

    foreach my $p (@unique_plot_list) {
      #$line = join "\t", map { $plot_data{$p}->{metadata}->{$_} } ( "year", "trial_name", "location", "accession", "plot", "rep", "block_number" );
      $line = join "\t", map { $plot_data{$p}->{metadata}->{$_} } ( "year", "studyDbId", "studyName", "locationDbId", "locationName", "germplasmDbId", "germplasmName", "plotDbId", "plotName", "rep", "blockNumber" );

      #print STDERR "Adding line for plot $p\n";
      foreach my $trait (@sorted_traits) {
        my $tab = $plot_data{$p}->{$trait};
        $line .= defined($tab) ? "\t".$tab : "\t";
      }
      push @info, $line;
    }

    return @info;
}



=head2 get_genotype_info

parameters: comma-separated lists of accession, trial, and trait IDs. May be empty.

returns: an array with genotype information

=cut

sub get_genotype_info {

    my $self = shift;
    my $accession_idref = shift;
    my $protocol_id = shift;
    my $snp_genotype_id = shift || '76434';
    my @accession_ids = @$accession_idref;
    my ($q, @result, $protocol_name);

    if (@accession_ids) {
      $q = "SELECT name, uniquename, value FROM (SELECT nd_protocol.name, stock.uniquename, genotypeprop.value, row_number() over (partition by stock.uniquename order by genotypeprop.genotype_id) as rownum from genotypeprop join nd_experiment_genotype USING (genotype_id) JOIN nd_experiment_protocol USING(nd_experiment_id) JOIN nd_protocol USING(nd_protocol_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE genotypeprop.type_id = ? AND stock.stock_id in (@{[join',', ('?') x @accession_ids]}) AND nd_experiment_protocol.nd_protocol_id=?) tmp WHERE rownum <2";
    }
    print STDERR "QUERY: $q\n\n";

    my $h = $self->dbh()->prepare($q);
    $h->execute($snp_genotype_id, @accession_ids,$protocol_id);


    while (my($name,$uniquename,$genotype_string) = $h->fetchrow_array()) {
      push @result, [ $uniquename, $genotype_string ];
      $protocol_name = $name;
    }

    return {
      protocol_name => $protocol_name,
      genotypes => \@result
    };
}


sub get_type_id {
    my $self = shift;
    my $term = shift;
    my $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm on (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='$term'";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}


sub get_stock_type_id {
    my $self = shift;
    my $term =shift;
    my $q = "SELECT stock.type_id FROM stock JOIN cvterm on (stock.type_id=cvterm.cvterm_id) WHERE cvterm.name='$term'";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

sub get_stockprop_type_id {
    my $self = shift;
    my $term = shift;
    my $q = "SELECT stockprop.type_id FROM stockprop JOIN cvterm on (stockprop.type_id=cvterm.cvterm_id) WHERE cvterm.name=?";
    my $h = $self->dbh->prepare($q);
    $h->execute($term);
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

sub get_projectprop_type_id {
    my $self = shift;
    my $term = shift;
    my $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm ON (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name=?";
    my $h = $self->dbh->prepare($q);
    $h->execute($term);
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

1;
