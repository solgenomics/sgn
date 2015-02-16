
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


=head2 get_intersect

 Usage:        my %info = $bs->get_intersect($criteria_list, $dataref, $db_name);
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
               db_name: the db name of the ontology used
 Side Effects: will create a materialized view of the ontology corresponding to 
               $db_name
 Example:

=cut

sub get_intersect { 
    my $self = shift;
    my $criteria_list = shift;
    my $dataref = shift;
    my $traits_db_name = shift;
    
    if (!$traits_db_name) { die "Need a db_name for the ontology!"; }

    $self->create_materialized_cvterm_view($traits_db_name);
    $self->create_materialized_cvalue_ids_view();

    #print STDERR "CRITERIA LIST: ".(join ",", @$criteria_list)."\n";
    print STDERR Data::Dumper::Dumper($dataref);

    my $type_id = $self->get_type_id('project year');
    my $accession_id = $self->get_stock_type_id('accession');
    my $plot_id = $self->get_stock_type_id('plot');
    
    my %queries;
    { 
	no warnings;
	%queries = ( 
	accessions => {
	    location => "SELECT distinct(accession.uniquename), accession.uniquename FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and nd_geolocation.nd_geolocation_id in ($dataref->{accessions}->{locations}) ",
	    
	    years     => "SELECT distinct(accession.uniquename), accession.uniquename FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and projectprop.value in ($dataref->{accessions}->{years}) ",
	    
	    projects  => "SELECT distinct(accession.uniquename), accession.uniquename FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and project.project_id in ($dataref->{accessions}->{projects}) ",
	    
	    traits    => "SELECT distinct(accession.uniquename), accession.uniquename FROM phenotype JOIN nd_experiment_phenotype using(phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and phenotype.cvalue_id in ($dataref->{accessions}->{traits}) ",
	    
	    accessions    => "SELECT distinct(stock.uniquename), stock.uniquename FROM stock WHERE stock.type_id=$accession_id ",

	    #genotype => "SELECT distinct(uniquename), stock.uniquename FROM stock as plot JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) nd_experiment_stock USING(stock_id) JOIN nd_experiment_genotype USING (nd_experiment_id) JOIN ",
	    
	    order_by      => " ORDER BY 2 ",
	},

	plots => {
	    locations => "SELECT distinct(stock.uniquename), stock.uniquename FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE stock.type_id=$plot_id and nd_geolocation.nd_geolocation_id in ($dataref->{plots}->{locations}) ",
	    
	    years     => "SELECT distinct(stock.uniquename), stock.uniquename FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE  stock.type_id=$plot_id and projectprop.value in ($dataref->{plots}->{years}) ",
	    
	    projects  => "SELECT distinct(stock.uniquename), stock.uniquename FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE  stock.type_id=$plot_id and project.project_id in ($dataref->{plots}->{projects}) ",
	    
	    traits    => "SELECT distinct(stock.uniquename), stock.uniquename FROM phenotype JOIN nd_experiment_phenotype using(phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock USING(stock_id) WHERE  stock.type_id=$plot_id and phenotype.cvalue_id in ($dataref->{plots}->{traits}) ",
	    
	    plots    => "SELECT distinct(stock.uniquename), stock.uniquename FROM stock WHERE  stock.type_id=$plot_id ",
	    
	    accessions => "SELECT distinct(plot.uniquename), plot.uniquename FROM stock JOIN stock_relationship ON (stock.stock_id=stock_relationship.object_id)  JOIN stock as plot ON (stock_relationship.subject_id=plot.stock_id) WHERE plot.type_id=$plot_id and stock.stock_id in ($dataref->{plots}->{accessions}) ",

	    #genotype => "SELECT distinct(uniquename), stock.uniquename FROM stock JOIN nd_experiment_stock USING(stock_id) JOIN nd_experiment_genotype USING (nd_experiment_id) JOIN ",

            order_by => " ORDER BY 2",
	    
	},

	locations => { 
	    years     => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN projectprop using(project_id) where projectprop.value in ($dataref->{locations}->{years}) ",

	    projects  => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{locations}->{projects}) ",
	    
	    locations => "SELECT nd_geolocation_id, description FROM nd_geolocation ",
	    
	    plots    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock USING (nd_experiment_id) WHERE stock in ($dataref->{locations}->{plots}) ",
	    
	    traits    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment USING (nd_geolocation_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) WHERE cvalue_id in ($dataref->{locations}->{traits}) ",

	    accessions => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment USING (nd_geolocation_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE stock.type_id=$accession_id and stock.stock_id in ($dataref->{locations}->{accessions}) ",
	    #genotype => "",
	    
	    order_by => " ORDER BY 2 ",
	},
	
	years => {
	    locations => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING (project_id) JOIN nd_experiment using(nd_experiment_id) JOIN nd_geolocation USING (nd_geolocation_id) where nd_geolocation_id in ($dataref->{years}->{locations}) ",
	    
	    projects  => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN  project using(project_id) WHERE project.project_id in ($dataref->{years}->{projects}) ",
	    
	    years     => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id ",
	    
            plots    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE type_id=$type_id AND stock_id IN ($dataref->{years}->{plots}) ",
	    
	    traits    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING(phenotype_id) WHERE type_id=$type_id AND cvalue_id IN ($dataref->{years}->{traits}) ",

	    accessions => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock USING(stock_id) WHERE type_id=$accession_id and stock.stock_id in ($dataref->{years}->{accessions}) ",
	    #genotype => "",
	    
	    order_by => " ORDER BY 1 ",
	    
	},
		
	projects => { 
	    locations => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id) WHERE nd_geolocation_id in ($dataref->{projects}->{locations}) ",
	    
	    years     => "SELECT distinct(project_id), project.name FROM project JOIN projectprop USING (project_id) WHERE projectprop.value in ($dataref->{projects}->{years}) ",
	    
	    projects  => "SELECT project_id, project.name FROM project ", 
	    
	    plots    => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id in ($dataref->{projects}->{plots}) ",
	    
	    traits    => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) WHERE cvalue_id in ($dataref->{projects}->{traits}) ",

	    accessions => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE stock.type_id=$accession_id and stock.stock_id in ($dataref->{projects}->{accessions}) ",
	    #genotype => "",
	    
	    order_by => " ORDER BY 2 ",
	},
	
	traits  => { 

	   # prereq   => "DROP TABLE IF EXISTS cvalue_ids; CREATE TEMP TABLE cvalue_ids AS SELECT distinct(cvalue_id), phenotype_id FROM phenotype",

	    locations => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM materialized_traits JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id)  WHERE nd_geolocation.nd_geolocation_id in ($dataref->{traits}->{locations}) ",
	    
	    years => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM materialized_traits JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN projectprop USING(project_id) WHERE projectprop.type_id=$type_id and projectprop.value IN ($dataref->{traits}->{years}) ", 
	    
	    projects => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM materialized_traits JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN project USING(project_id) WHERE project.project_id in ($dataref->{traits}->{projects}) ",
	    
	    traits => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM cvalue_ids JOIN  materialized_traits on (cvalue_id=cvterm_id)",

	    plots => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM nd_experiment_stock JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN materialized_traits ON (cvalue_id=cvterm_id) WHERE stock_id IN ($dataref->{traits}->{plots}) ",

	    accessions => "SELECT distinct(materialized_traits.cvterm_id), materialized_traits.name FROM nd_experiment_stock JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN materialized_traits ON (cvalue_id=cvterm_id) WHERE stock_id IN ($dataref->{traits}->{plots}) ",

	    order_by => " ORDER BY 2 ",
	    #genotype => "",
	    
	},
	);
    }
    my @query;
    my $item = $criteria_list->[-1];
    
    if (exists($queries{$item}->{prereq})) { 
	my $h = $self->dbh->prepare($queries{$item}->{prereq});
	$h->execute();
    }
    
    push @query, $queries{$item}->{$item}; # make the empty query work

    foreach my $criterion (@$criteria_list) { 
	if (exists($queries{$item}->{$criterion}) && $queries{$item}->{$criterion} && $dataref->{$item}->{$criterion}) { 
       	    push @query, $queries{$item}{$criterion};
	}
    }
    my $query = join (" INTERSECT ", @query). $queries{$item}{order_by};
    
    print STDERR "QUERY: $query\n";
    
    my $h = $self->dbh->prepare($query);
    $h->execute();
    
    my @results;
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @results, [ $id, $name ];
    }    
    
    if (@results <= 10_000) { 
	return { results => \@results };
    }
    else { 
	return { message => 'Too many items to display ('.(scalar(@results)).')' };
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

    #print STDERR "$accession_sql - $trial_sql - $trait_sql \n\n";

    my $rep_type_id = $self->get_stockprop_type_id("replicate");
    my $block_number_type_id = $self -> get_stockprop_type_id("block");


    my @where_clause = ();
    if ($accession_sql) { push @where_clause,  "stock.stock_id in ($accession_sql)"; }
    if ($trial_sql) { push @where_clause, "project.project_id in ($trial_sql)"; }
    if ($trait_sql) { push @where_clause, "cvterm.cvterm_id in ($trait_sql)"; }

    my $where_clause = "";
   
    if (@where_clause>0) { 
	$where_clause = "where (stockprop.type_id=$rep_type_id or stockprop.type_id IS NULL) AND (block_number.type_id=$block_number_type_id or block_number.type_id IS NULL) AND  ".(join (" and ", @where_clause));
    }

    my $order_clause = " order by project.name, plot.uniquename";

    my $q = "SELECT project.name, stock.uniquename, nd_geolocation.description, cvterm.name, phenotype.value, plot.uniquename, db.name, cvterm.name, stockprop.value, block_number.value AS rep
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
             $where_clause
             $order_clause";
    
    print STDERR "QUERY: $q\n\n";
    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $result = [];
    while (my ($project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number) = $h->fetchrow_array()) { 
	push @$result, [ $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number ];
	
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
	my $cvterm = $d->[6].":".$d->[7];
	my $trait_data = $d->[4];
	my $plot = $d->[5];
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

	my ($project_name, $stock_name, $location, $trait, $trait_data, $plot, $cv_name, $cvterm_accession, $rep, $block_number) = @$d;
	
	my $cvterm = $d->[6].":".$d->[7];
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
	    trait_data => $trait_data 
	};
	$traits{$cvterm}++;
    }
    
    my @info = ();
    my $line = join "\t", qw | trial_name location accession plot rep block_number |;

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
	my $plot = $d->[5];
	if ($plot ne $previous_plot) { 
	    push @unique_plot_list, $plot;
	}
	$previous_plot = $plot;
    }


    foreach my $p (@unique_plot_list) { 
	$line = join "\t", map { $plot_data{$p}->{metadata}->{$_} } ( "trial_name", "location", "accession", "plot", "rep", "block_number" );
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

returns: an array with phenotype information

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

    my $q = "SELECT genotype_id,value FROM public.genotypeprop join nd_experiment_genotype USING (genotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) WHERE stock.stock_id in ($accession_sql)";


    print "QUERY: $q\n\n";

    print "before\n\n";
    print STDERR "QUERY: $q\n\n";
    print "after\n\n";

    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $result = [];

  #  while (my ($genotype_id,$name,$uniquename,$description,$type_id) = $h->fetchrow_array()) { 
#	push @$result, [ $genotype_id,$name,$uniquename,$description,$type_id ];
#	
#    }


    while (my ($genotype_id,$value) = $h->fetchrow_array()) { 
	push @$result, [ $genotype_id,$value ];
	
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

sub create_materialized_cvterm_view { 
    my $self = shift;
    my $db_name = shift;

    # change this to materialized view once we use 9.4.
    #
    eval { 
	my $q = "CREATE TABLE public.materialized_traits
               AS SELECT cvterm_id,  db.name ||':'|| cvterm.name AS name FROM db JOIN dbxref using(db_id) JOIN cvterm using(dbxref_id) WHERE db.name=?";
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
