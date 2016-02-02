
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

has 'dbh' => ( 
    is  => 'rw',
    required => 1,
    );


=head2 metadata_query

 Usage:        my %info = $bs->metadata_query($criteria_list, $dataref, $genotypes, $intersect);
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
               intersect: 1 if where clause arguments should find intersect rather than union
 Side Effects: will create a materialized view of the ontology corresponding to 
               $db_name
 Example:

=cut

sub metadata_query { 
    my $self = shift;
    my $criteria_list = shift;
    print STDERR "criteria_list=" . Dumper($criteria_list);
    my $dataref = shift;
    print STDERR "dataref=" . Dumper($dataref);
    my $queryref = shift;
    print STDERR "queryref=" . Dumper($queryref);

    my $h;

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
    } else {
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
		#print STDERR "intersect=" . $intersect ."\n";
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
		} else {
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


=head2 get_phenotype_info

parameters: comma-separated lists of accession, trial, and trait IDs. May be empty.

returns: an array with phenotype information

=cut


sub get_phenotype_info {  
    my $self = shift;
    my $accession_sql = shift;
    my $trial_sql = shift;
    my $trait_sql = shift;

    print STDERR "GET_PHENOTYPE_INFO: $accession_sql - $trial_sql - $trait_sql \n\n";

    my $rep_type_id = $self->get_stockprop_type_id("replicate");
    my $block_number_type_id = $self -> get_stockprop_type_id("block");
    my $year_type_id = $self->get_projectprop_type_id("project year");


    my @where_clause = ();
    if ($accession_sql) { push @where_clause,  "stock.stock_id in ($accession_sql)"; }
    if ($trial_sql) { push @where_clause, "project.project_id in ($trial_sql)"; }
    if ($trait_sql) { push @where_clause, "cvterm.cvterm_id in ($trait_sql)"; }

    my $where_clause = "";
   
    if (@where_clause>0) {
	$where_clause .= $rep_type_id ? "WHERE (stockprop.type_id = $rep_type_id OR stockprop.type_id IS NULL) " : "WHERE stockprop.type_id IS NULL";
	$where_clause .= $block_number_type_id  ? " AND (block_number.type_id = $block_number_type_id OR block_number.type_id IS NULL)" : " AND block_number.type_id IS NULL";
	$where_clause .= $year_type_id ? " AND projectprop.type_id = $year_type_id" :"" ;
	$where_clause .= " AND " . (join (" AND " , @where_clause));

	#$where_clause = "where (stockprop.type_id=$rep_type_id or stockprop.type_id IS NULL) AND (block_number.type_id=$block_number_type_id or block_number.type_id IS NULL) AND  ".(join (" and ", @where_clause));
    }

    my $order_clause = " order by project.name, plot.uniquename";

    my $q = "SELECT projectprop.value, project.name, stock.uniquename, nd_geolocation.description, cvterm.name, phenotype.value, plot.uniquename, db.name, db.name ||  ':' || dbxref.accession AS accession, stockprop.value, block_number.value AS rep
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
    
    print STDERR "QUERY: $q\n\n";
    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $result = [];
    while (my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number) = $h->fetchrow_array()) { 
	push @$result, [ $year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number ];
	
    }
    print STDERR "QUERY returned ".scalar(@$result)." rows.\n";
    return $result;
}

sub get_phenotype_info_matrix { 
    my $self = shift;
    my $accession_sql = shift;
    my $trial_sql = shift;
    my $trait_sql = shift;
    
    my $data = $self->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
    
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
	    $line .= $tab ? "\t".$tab : "\t";

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

    my $data = $self->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
    
    my %plot_data;
    my %traits;

    print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
    foreach my $d (@$data) { 

	my ($year, $project_name, $stock_name, $location, $trait, $trait_data, $plot, $cv_name, $cvterm_accession, $rep, $block_number) = @$d;
	
	my $cvterm = $d->[4]."|".$d->[8];
	if (!defined($rep)) { $rep = ""; }
	$plot_data{$plot}->{$cvterm} = $trait_data;
	$plot_data{$plot}->{metadata} = {
	    rep => $rep,
	    trial_name => $project_name,
	    accession => $stock_name,
	    location => $location,
	    block_number => $block_number,
	    plot => $plot, 
	    rep => $rep, 
	    cvterm => $cvterm, 
	    trait_data => $trait_data,
	    year => $year
	};
	$traits{$cvterm}++;
    }
    
    my @info = ();
    my $line = join "\t", qw | year trial_name location accession plot rep block_number |;

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
	$line = join "\t", map { $plot_data{$p}->{metadata}->{$_} } ( "year", "trial_name", "location", "accession", "plot", "rep", "block_number" );
	print STDERR "Adding line for plot $p\n";
	foreach my $trait (@sorted_traits) { 
	    my $tab = $plot_data{$p}->{$trait}; 
	    
	    $line .= $tab ? "\t".$tab : "\t";

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
    my $accession_sql = shift;
    my $trial_sql = shift;
   # my $trait_sql = shift;

    #my $q = "SELECT project.name, stock.uniquename, nd_geolocation.description, cvterm.name, phenotype.value FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id) JOIN stock ON (object_id=stock.stock_id) JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id) JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id) JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id) JOIN phenotype USING(phenotype_id) JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id) JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id) JOIN project USING(project_id)  WHERE cvterm.cvterm_id in ($trait_sql) and project.project_id in ($trial_sql) and stock.stock_id in ($accession_sql)";

   # my $q ="select genotype_id from genotype where name ilike '$accession_sql' ";
    #my $q ="select genotype_id,value from genotypeprop where genotype_id in (select genotype_id from genotype where name in ($accession_sql)";

   # my $q="select genotype_id,name,uniquename,description,type_id from genotype where name ilike ('WEMA_6x1017_MARS-WEMA_270239%')";

    print "$accession_sql \n";

    #my $q="select genotype_id,name,uniquename,description,type_id from genotype where name in ($accession_sql)";

   #my $q="select stock.stock_id,stock.uniquename from stock where stock.stock_id in ($accession_sql)";

#    my $q="select genotype_id,value from genotypeprop where genotype_id in (select genotype_id from genotype where genotype_id in (select genotype_id from nd_experiment_genotype where nd_experiment_id in (select nd_experiment_id from nd_experiment_stock where stock_id in (select stock_id from stock where stock.stock_id in ($accession_sql)))))";

    #my $q = "SELECT genotype_id FROM genotype join nd_experiment_genotype USING (genotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE stock.stock_id in ($accession_sql)";

        my $result = [];
    if ($accession_sql) { 
	my $q = "SELECT genotype_id,value FROM public.genotypeprop join nd_experiment_genotype USING (genotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE stock.stock_id in ($accession_sql)";

    #if ($trait_sql) { 
#	push @qs, "";
 #   }

  #  my $q = join " INTERSECT ", @qs;

    print "QUERY: $q\n\n";

    print "before\n\n";
    print STDERR "QUERY: $q\n\n";
    print "after\n\n";

    my $h = $self->dbh()->prepare($q);
    $h->execute();



  #  while (my ($genotype_id,$name,$uniquename,$description,$type_id) = $h->fetchrow_array()) { 
#	push @$result, [ $genotype_id,$name,$uniquename,$description,$type_id ];
#	
#    }


    while (my ($genotype_id,$value) = $h->fetchrow_array()) { 
	push @$result, [ $genotype_id,$value ];
	
    }

    }
   
#    while (my ($genotype_id) = $h->fetchrow_array()) { 
#	push @$result, [ $genotype_id ];
#	
#    }


    return $result;


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

sub create_materialized_cvterm_view { 
    my $self = shift;
    my $db_name = shift;

    # change this to materialized view once we use 9.4.
    #
    eval { 
	my $q = "CREATE TABLE public.materialized_traits
               AS SELECT cvterm_id, cvterm.name || '|' || db.name || ':' || dbxref.accession AS name FROM db JOIN dbxref using(db_id) JOIN cvterm using(dbxref_id) WHERE db.name=?";
	my $h = $self->dbh()->prepare($q);
	$h->execute($db_name);
	$q = "GRANT ALL ON public.materialized_traits TO web_usr";
	$h = $self->dbh()->prepare($q);
	$h->execute();
    };
    if ($@) {
	if ($@!~/relation.*already exists/) { 
	    die "Materialized trait view: $@\n";
	}
    }
    

}

sub create_materialized_cvalue_ids_view { 
    my $self = shift;
    
    eval { 
       my $q = "CREATE TABLE public.cvalue_ids 
              AS SELECT distinct(cvalue_id), phenotype_id FROM phenotype";
       my $h = $self->dbh->prepare($q);
       $h->execute();
       $q = "GRANT ALL ON cvalue_ids TO web_usr";
       $h->execute();
    };
    if ($@) { 
       if ($@!~/relation.*already exists/) { 
	    die "Materialized cvalue view $@\n";
	}
    }
}

1;
