=head1 NAME

solGS::Model::solGS - Catalyst Model for solGS

=head1 DESCRIPTION

solGS Catalyst Model.

=head1 AUTHOR

Isaak Y Tecle, iyt2@cornell.edu

=head1 LICENSE

This library is free software. You can redistribute it and/or modifyi
t under the same terms as Perl itself.

=cut

package SGN::Model::solGS::solGS;

use Moose;

use namespace::autoclean;
use Array::Utils qw(:all);
use Bio::Chado::Schema;
use Bio::Chado::NaturalDiversity::Reports;
use File::Path qw / mkpath /;
use File::Spec::Functions;
use List::MoreUtils qw / uniq /;
use JSON::Any;
use Math::Round::Var;
use Scalar::Util qw(looks_like_number);
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use Math::Round::Var;
use CXGN::Genotype::Search;
use CXGN::Trial;
use CXGN::Dataset;
use CXGN::Phenotypes::PhenotypeMatrix;

extends 'Catalyst::Model';


__PACKAGE__->mk_accessors(qw/context schema/);




sub ACCEPT_CONTEXT {
    my ($self, $c ) = @_;
    my $new = $self->meta->clone_object($self, context => $c,
                                        schema => $c->dbic_schema("Bio::Chado::Schema")
        );

    return $new;

}


sub search_trait {
    my ($self, $trait) = @_;

    my $q = "SELECT distinct(cvterm.name) FROM genotyping_protocolsXtrials
                        LEFT JOIN traitsXtrials ON genotyping_protocolsXtrials.trial_id = traitsXtrials.trial_id
                        LEFT JOIN cvterm ON cvterm.cvterm_id = traitsXtrials.trait_id
                        LEFT JOIN locationsXtrials  ON traitsXtrials.trial_id = locationsXtrials.trial_id
                        LEFT JOIN locations ON locations.location_id = locationsXtrials.location_id
                        WHERE location_name NOT LIKE '[Computation]'
                            AND cvterm.name ILIKE ?
                        ORDER BY cvterm.name";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute("%$trait%");

    my @traits;

    while ( my $tr = $sth->fetchrow_array())
    {
        print STDERR "\ntrait: $trait - tr: $tr\n";
	push @traits, $tr;
    }

    return \@traits;

}


# sub search_trait {
#     my ($self, $trait) = @_;
#
#     my $q = "SELECT name FROM all_gs_traits
#                     WHERE name ilike ?
#                     ORDER BY name";
#
#     my $sth = $self->context->dbc->dbh->prepare($q);
#
#     $sth->execute("%$trait%");
#
#     my @traits;
#
#     while ( my $trait  = $sth->fetchrow_array())
#     {
# 	push @traits, $trait;
#     }
#
#     return \@traits;
#
# }


sub trait_details {
    my ($self, $trait_arrayref) =  @_;

    my $rs = $self->schema->resultset("Cv::Cvterm")
        ->search({'me.name' => {-in => $trait_arrayref} },
    		  {
    		      'select'   => [ qw / me.cvterm_id me.name me.definition / ],
    		      'as'       => [ qw / cvterm_id name definition / ]
    		  }
    	);

    return $rs;

}


sub all_gs_traits {
    my $self = shift;

    my $q =  "SELECT distinct(cvterm.name) FROM genotyping_protocolsXtrials
                        LEFT JOIN traitsXtrials ON genotyping_protocolsXtrials.trial_id = traitsXtrials.trial_id
                        LEFT JOIN cvterm ON cvterm.cvterm_id = traitsXtrials.trait_id
                        LEFT JOIN locationsXtrials  ON traitsXtrials.trial_id = locationsXtrials.trial_id
                        LEFT JOIN locations ON locations.location_id = locationsXtrials.location_id
                        WHERE location_name NOT LIKE '[Computation]'
                        ORDER BY cvterm.name";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute();

    my @traits;

    while ( my ($cvterm, $cvterm_id) = $sth->fetchrow_array())
    {
	    push @traits, $cvterm;
    }

    return \@traits;
}


sub materialized_view_all_gs_traits {
    my $self = shift;

    my $q = "CREATE MATERIALIZED VIEW public.all_gs_traits
                    AS SELECT observable.cvterm_id, observable.name
                    FROM phenotype me
                    JOIN cvterm observable ON observable.cvterm_id = me.observable_id
                    GROUP BY observable.cvterm_id, observable.name";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute();

}


sub insert_matview_public {
    my ($self, $name)  = @_;

    my $q = "INSERT INTO public.matviews (mv_name, last_refresh) VALUES (?, now())";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute($name);

}


sub update_matview_public {
    my ($self, $name)  = @_;

    my $q = "Update public.matviews SET last_refresh = now() WHERE mv_name ilike ? ";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute($name);

}


sub check_matview_exists {
    my ($self, $name) = @_;

    my $q = "SELECT mv_name FROM public.matviews WHERE mv_name ilike ?";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute($name);

    my $exists =$sth->fetchrow_array();

    return $exists;

}


sub refresh_materialized_view_all_gs_traits {
    my $self = shift;

    my $q = "REFRESH MATERIALIZED VIEW public.all_gs_traits";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute();

}


sub search_trait_trials {
    my ($self, $trait_id, $protocol_id) = @_;

    #my $q = "SELECT distinct(trial_id) FROM traitsXtrials ORDER BY trial_id";
    my $protocol_detail = $self->protocol_detail($protocol_id);
    my $protocol = $protocol_detail->{name};

    my $q = "SELECT distinct(trial_id)
                 FROM materialized_phenoview
                 JOIN genotyping_protocolsXtrials USING (trial_id)
                 JOIN genotyping_protocols USING (genotyping_protocol_id)
		 WHERE genotyping_protocols.genotyping_protocol_name ILIKE ?
                 AND trait_id = ?";

    my $sth = $self->context->dbc->dbh->prepare($q);

    $sth->execute($protocol, $trait_id);

    my @trials;

    while ( my $trial_id = $sth->fetchrow_array())
    {
	push @trials, $trial_id;
    }

    return \@trials;

}


sub search_populations {
    my ($self, $trait_id, $page) = @_;

    my $rs = $self->schema->resultset("Phenotype::Phenotype")
        ->search({'me.observable_id' =>  $trait_id, 'me.value' => {'!=', undef}})
        ->search_related('nd_experiment_phenotypes')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock')
	    ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_projects')
        ->search_related('project',
			 {},
			 {
			   page     => $page,
			   rows     => 10,
			   order_by => 'CASE WHEN project.name ~ \'^[0-9]+\' THEN 1 ELSE 0 END, project.name',

			   'select'   => [ qw / project.project_id project.name project.description / ],
			   'as'       => [ qw / project_id name description / ],
			   distinct   => [ qw / project.project_id / ]
                         },
	);

    return $rs;

}


sub project_year {
    my ($self, $pr_id) =  @_;

    return $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'project year' })
        ->search_related('projectprops',
			 {},
			 {
			     select => [qw /projectprops.value/]
			 }
	);
}


sub experimental_design {
    my ($self, $pr_id) =  @_;

    return $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'design' })
        ->search_related('projectprops',
			 {},
			 {
			     select => [qw /projectprops.value/]
			 });

}


sub project_location {
    my ($self, $pr_id) = @_;

    my $q = "SELECT location_name
                    FROM locationsXtrials
                    JOIN locations USING (location_id)
                    WHERE trial_id = ?";

    my $sth = $self->context->dbc->dbh()->prepare($q);

    $sth->execute($pr_id);

    my $loc = $sth->fetchrow_array;

    return $loc;
}


sub all_gs_projects {
    my ($self, $limit) = @_;

    my $protocol = $self->genotyping_protocol();
    $limit = 'LIMIT ' . $limit if $limit;

    my $order_by = 'CASE WHEN trials.trial_name ~ \'\\m[0-9]+\' THEN 1 ELSE 0 END, trials.trial_name DESC';

    my $q = "SELECT trials.trial_name, trials.trial_id
                 FROM traits
                 JOIN traitsXtrials USING (trait_id)
                 JOIN trials USING (trial_id)
                 JOIN genotyping_protocolsXtrials USING (trial_id)
                 JOIN genotyping_protocols USING (genotyping_protocol_id)
		 WHERE genotyping_protocols.genotyping_protocol_name ILIKE ?
                       GROUP BY trials.trial_id, trials.trial_name
                       ORDER BY $order_by
                       $limit";

    my $sth = $self->context->dbc->dbh()->prepare($q);

    $sth->execute($protocol);

    my @gs_trials;

    while (my ($trial_name, $trial_id) = $sth->fetchrow_array())
    {
	push @gs_trials, $trial_id;
    }

    return \@gs_trials;

}


sub all_projects {
    my ($self, $page, $rows) = @_;

    $rows = 10 if !$rows;
    $page = 1 if !$page;

    if ($rows eq 'all') {  $rows = undef; $page = undef;};

    my $projects_rs =  $self->schema->resultset("Project::Project")
        ->search({},
                 {
                     distinct => 1,
                     page     => $page,
                     rows     => $rows,
                     order_by => 'CASE WHEN name ~ \'^[0-9]+\' THEN 1 ELSE 0 END, name'
                 }

        );

    return $projects_rs;
}


sub has_phenotype {
    my ($self, $pr_id) = @_;

    my $has_phenotype;

    if ($pr_id)
    {
    	my $q = "SELECT distinct(trait_id)
                     FROM materialized_phenoview
                     WHERE trial_id = ?
                     AND trait_id IS NOT NULL";

    	my $sth = $self->context->dbc->dbh->prepare($q);
    	$sth->execute($pr_id);

	   while ($has_phenotype  = $sth->fetchrow_array())
       {
          last if $has_phenotype;
       }
   }

    return $has_phenotype;

}


sub has_genotype {
    my ($self, $pr_id, $protocol_id) = @_;

    my $protocol_detail = $self->protocol_detail($protocol_id);
    my $protocol_name = $protocol_detail->{name};

    my $q = "SELECT genotyping_protocol_name, genotyping_protocol_id
                 FROM genotyping_protocolsXtrials
                 JOIN genotyping_protocols USING (genotyping_protocol_id)
                 WHERE trial_id = ?
                 AND genotyping_protocols.genotyping_protocol_name ILIKE ?";

    my $sth = $self->context->dbc->dbh->prepare($q);
    $sth->execute($pr_id, $protocol_name);

    ($protocol_name, $protocol_id)  = $sth->fetchrow_array();

    return $protocol_id;

}


sub project_details {
    my ($self, $pr_id) = @_;

   if (ref $pr_id eq 'SCALAR') {
        $pr_id = [$pr_id];
   }

    my $pr_rs = $self->schema->resultset("Project::Project")
        ->search( {'me.project_id' => {-in => $pr_id} });

    return $pr_rs;

}


sub project_details_by_name {
    my ($self, $pr_name) = @_;

    return $self->schema->resultset("Project::Project")
        ->search( {'me.name' => {'iLIKE' => '%' . $pr_name . '%'}});
}


sub project_details_by_exact_name {
    my ($self, $pr_name) = @_;

    return $self->schema->resultset("Project::Project")
        ->search( {'me.name' => {-in => $pr_name }});
}


sub get_population_details {
    my ($self, $pop_id) = @_;

    return $self->schema->resultset("Stock::Stock")
        ->search(
        {
            'stock_id' => $pop_id
        },
	);
}


sub trait_name {
    my ($self, $trait_id) = @_;

	my $trait_name;
	if ($trait_id)
	{
	   	$trait_name = $self->schema->resultset('Cv::Cvterm')
	        ->search( {cvterm_id => $trait_id})
	        ->single
	        ->name;
	}

    return $trait_name;

}


sub get_trait_id {
    my ($self, $trait) = @_;

    if ($trait)
    {
        my $trait_rs = $self->schema->resultset('Cv::Cvterm')
            ->search({name => $trait});

	if ($trait_rs->single)
	{
         return $trait_rs->single->id;
	}
	else
	{
	    return;
	}
   }

}


sub check_stock_type {
    my ($self, $stock_id) = @_;

    my $type_id = $self->schema->resultset("Stock::Stock")
        ->search({'stock_id' => $stock_id})
        ->first()
        ->type_id;

    return $self->schema->resultset('Cv::Cvterm')
        ->search({cvterm_id => $type_id})
        ->first()
        ->name;
}


sub set_project_genotypeprop {
    my ($self, $prop) = @_;

    my $cv_id= $self->schema->resultset("Cv::Cv")
	->find_or_create({ 'name' => 'project_property'})
	->cv_id;

    my $db_id = $self->schema->resultset("General::Db")
	->find_or_new({ 'name' => 'null'})
	->db_id;

    my $dbxref_id = $self->schema->resultset("General::Dbxref")
	->find_or_create({'accession' => 'marker_count', 'db_id' => $db_id})
	->dbxref_id;

    my $cvterm_id = $self->schema->resultset("Cv::Cvterm")
	->find_or_create({ name => 'marker_count', cv_id => $cv_id, dbxref_id => $dbxref_id,})
	->cvterm_id;

    my $marker_rs = $self->schema->resultset("Project::Projectprop")
	->search({project_id => $prop->{'project_id'}, type_id => $cvterm_id});

    my $marker;

    while (my $row = $marker_rs->next)
    {
	$marker = $row->value;
    }

    if ($marker)
    {
	my $project_rs = $self->schema->resultset("Project::Projectprop")
	    ->search({ project_id => $prop->{'project_id'}, type_id => $cvterm_id})
	    ->update({ value => $prop->{'marker_count'} });
    }
    else
    {
	my $project_rs = $self->schema->resultset("Project::Projectprop")
	    ->create({
		project_id => $prop->{'project_id'},
		type_id => $cvterm_id,
		value => $prop->{'marker_count'}
	    });
    }

}


sub get_project_genotypeprop {
    my ($self, $pr_id) = @_;

    my $cvterm_rs = $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'marker_count' })
        ->search_related('projectprops');

    my $marker_count;
    if($cvterm_rs->next)
    {
	$marker_count = $cvterm_rs->first()->value;
    }

    my $genoprop = {'marker_count' => $marker_count};

    return $genoprop;
}


sub set_project_type {
    my ($self, $prop) = @_;

    my $cv_id= $self->schema->resultset("Cv::Cv")
	->find_or_create({ 'name' => 'project_property'})
	->cv_id;

    my $db_id = $self->schema->resultset("General::Db")
	->find_or_new({ 'name' => 'null'})
	->db_id;

    my $dbxref_id = $self->schema->resultset("General::Dbxref")
	->find_or_create({'accession' => 'genomic selection',
			  'db_id'     => $db_id
			 })
	->dbxref_id;

    my $cvterm_id = $self->schema->resultset("Cv::Cvterm")
	->find_or_create({ name      => 'genomic selection',
			   cv_id     => $cv_id,
			   dbxref_id => $dbxref_id,
			 })
	->cvterm_id;

    my $project_rs = $self->schema->resultset("Project::Projectprop")
	->find_or_create({ project_id   => $prop->{'project_id'},
			   type_id      => $cvterm_id,
			   value        => $prop->{'project_type'},
	});
}


sub get_project_type {
    my ($self, $pr_id) = @_;

    my $pr_rs = $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'genomic selection' })
        ->search_related('projectprops',{},
			 {
			     select => [qw /projectprops.value/]
			 });

    my $pr_type;
    if($pr_rs->next)
    {
	$pr_type = $pr_rs->first()->value;
    }

    return $pr_type;
}


sub set_population_type {
    my ($self, $prop) = @_;

    my $cv_id= $self->schema->resultset("Cv::Cv")
	->find_or_create({ 'name' => 'project_property'})
	->cv_id;

    my $db_id = $self->schema->resultset("General::Db")
	->find_or_new({ 'name' => 'null'})
	->db_id;

    my $dbxref_id = $self->schema->resultset("General::Dbxref")
	->find_or_create({'accession' => 'population type',
			  'db_id'     => $db_id
			 })
	->dbxref_id;

    my $cvterm_id = $self->schema->resultset("Cv::Cvterm")
	->find_or_create({ name      => 'population type',
			   cv_id     => $cv_id,
			   dbxref_id => $dbxref_id,
			 })
	->cvterm_id;

    my $project_rs = $self->schema->resultset("Project::Projectprop")
	->find_or_create({ project_id   => $prop->{'project_id'},
			   type_id      => $cvterm_id,
			   value        => $prop->{'population type'},
	});
}


sub get_population_type {
    my ($self, $pr_id) = @_;

    my $pr_rs = $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'population type' })
        ->search_related('projectprops');

    my $pr_type;
    if ($pr_rs->next)
    {
	$pr_type = $pr_rs->first()->value;
    }

    return $pr_type;
}


sub get_stock_owners {
    my ($self, $stock_id) = @_;

    my $owners;

    no warnings 'uninitialized';

    unless ($stock_id =~ /list/)
    {
        my $q = "SELECT sp_person_id, first_name, last_name
                        FROM phenome.stock_owner
                        JOIN sgn_people.sp_person USING (sp_person_id)
                        WHERE stock_id = ? ";


        my $sth = $self->context->dbc->dbh()->prepare($q);
        $sth->execute($stock_id);


        while (my ($id, $fname, $lname) = $sth->fetchrow_array)
        {
            push @$owners, {'id'         => $id,
                            'first_name' => $fname,
                            'last_name'  => $lname
                           };

        }
    }

    return $owners;

}


sub search_stock {
    my ($self, $stock_name) = @_;

    my $rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.uniquename' => $stock_name});

    return $rs;

}


sub search_plotprop {
    my ($self, $plot_id, $type) = @_;

    my $rs = $self->schema->resultset("Cv::Cvterm")
        ->search({'stock_id' => $plot_id, 'name'     => $type })
        ->search_related('stockprops');

    return $rs;

}


sub search_stock_using_plot_name {
    my ($self, $plot_name) = @_;

    my $rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.uniquename' => {-in =>   $plot_name}});

    return $rs;

}


# sub first_stock_genotype_data {
#     my ($self, $pr_id) = @_;

#     my $protocol_id = $self->protocol_id();

#     my $geno_data = {};

#     my $geno_search = CXGN::Genotype::Search->new({
# 		bcs_schema => $self->schema,
# 		trial_list => [$pr_id],
# 		protocol_id_list => [$protocol_id],
# 		genotypeprop_hash_select=> ['DS'],
# 		protocolprop_top_key_select=>[],
# 		protocolprop_top_key_select=>[],
# 		return_only_first_genotypeprop_for_stock=> 1,
# 		});

#     $geno_search->init_genotype_iterator();
#     my $count = 0;
#     while (my $geno = $geno_search->get_next_genotype_info())
#     {
#     	$count++;
#     	$geno_data  = $self->structure_genotype_data($geno, $count);
#     	last if $$geno_data;
#     }

#     return $geno_data;

# }


sub genotype_data {
    my ($self, $args) = @_;

    my $trial_id  = $args->{trial_id};
    my $protocol_id = $args->{genotyping_protocol_id};

    if (!$protocol_id)
    {
	my $protocol_detail= $self->protocol_detail();
	$protocol_id = $protocol_detail->{protocol_id};
    }

    my $geno_search = CXGN::Genotype::Search->new({
	bcs_schema => $self->schema(),
	people_schema => $self->people_schema,
	trial_list => [$trial_id],
	protocol_id_list => [$protocol_id],
	genotypeprop_hash_select=> ['DS'],
	protocolprop_top_key_select=>[],
	protocolprop_top_key_select=>[],
	return_only_first_genotypeprop_for_stock=> 1,
						  });

    $geno_search->init_genotype_iterator();
    return $geno_search;

}


sub structure_genotype_data {
    my ($self, $dataref, $markers, $iter_no) =@_;

    my $geno_data;

    if ($dataref)
    {
	my $geno_hash = $dataref->{selected_genotype_hash};

	if ($iter_no == 1)
	{
	    my $headers   = $self->create_genotype_dataset_headers($markers);
	    $geno_data = "\t" . $headers . "\n";

	}

	$geno_data .= $dataref->{germplasmName} . "\t";

	$geno_data .= ${$self->create_genotype_row($markers, $geno_hash)};
	$geno_data .= "\n";
    }

    return \$geno_data;

}


sub genotypes_list_genotype_data {
    my ($self, $genotypes_ids, $protocol_id) = @_;

    if (!$protocol_id)
    {
	my $protocol_detail= $self->protocol_detail() if !$protocol_id;
	$protocol_id = $protocol_detail->{protocol_id};
    }

    my $geno_search = CXGN::Genotype::Search->new(
	bcs_schema => $self->schema(),
	people_schema => $self->people_schema,
	accession_list => $genotypes_ids,
	protocol_id_list => [$protocol_id],
	genotypeprop_hash_select=> ['DS'],
	protocolprop_top_key_select=>[],
	protocolprop_top_key_select=>[],
	return_only_first_genotypeprop_for_stock=> 1,
	);

    $geno_search->init_genotype_iterator();
    return $geno_search;

}


sub project_genotypes_rs {
    my ($self, $project_id) = @_;

    my $pr_genotypes_rs = $self->schema->resultset("Project::Project")
    	->search({'me.project_id' => $project_id })
    	->search_related('nd_experiment_projects')
    	->search_related('nd_experiment')
    	->search_related('nd_experiment_stocks')
    	->search_related('stock')
    	->search_related('stock_relationship_subjects')
    	->search_related('object',
    		     {},
    		     {select   => [ 'object.uniquename' ],
    		      distinct => 1
    		     }
    	);

    # my $protocol = $self->genotyping_protocol();

    # my $pr_genotypes_rs = $self->schema->resultset('NaturalDiversity::NdExperiment')
    # 	->search(
    #  {      'nd_experiment_projects.project_id' => $project_id,
    # 	    'nd_protocol.name' => $protocol,
    # 	    'type.name'  => 'snp genotyping',
    # 	    'cv.name' => 'genotype_property',
    # 	},
    # 	{
    # 	    join => [
    # 		{'nd_experiment_genotypes' => {'genotype' => {'genotypeprops'=> {'type' => 'cv'}}}},
    # 		{'nd_experiment_protocols' => 'nd_protocol'},
    # 		'nd_experiment_projects',
    # 		{'nd_experiment_stocks' => 'stock'}
    # 		],

    # 	    select => [ qw / stock.stock_id stock.uniquename / ],
    # 	    as     => [ qw / stock_id stock_name/ ],
    # 	    distinct => 1,
    # 	});




    return $pr_genotypes_rs;

}


sub genotypes_nd_experiment_ids_rs {
    my ($self, $genotypes_ids) = @_;

    my $protocol = $self->genotyping_protocol();

    my $nd_experiment_rs = $self->schema->resultset("NaturalDiversity::NdExperimentStock")
	->search({'me.stock_id' => { -in => $genotypes_ids},
		  'nd_protocol.name' => {'ilike' => $protocol}
		 })
	->search_related('nd_experiment')
	->search_related('nd_experiment_protocols')
	->search_related('nd_protocol', {},
			 {
			     select   => [ 'me.nd_experiment_id' ],
			     as       => [ 'nd_experiment_id' ],
			     distinct => 1
			 });

    return $nd_experiment_rs;

}


sub project_genotype_data_rs {
    my ($self, $project_id) = @_;

    my $trial = CXGN::Trial->new({'bcs_schema' =>$self->schema, 'trial_id' =>$project_id});
    my $trial_accessions = $trial->get_accessions();

    my @accessions;

    foreach my $st  (@$trial_accessions){
	push @accessions, $st->{stock_id};
    }

    my $genotype_rs = $self->accessions_list_genotypes_rs(\@accessions);


    return $genotype_rs;

}


sub individual_stock_genotypes_rs {
    my ($self, $stock_rs) = @_;

    my $stock_id = $stock_rs->first()->stock_id;

    my $nd_exp_rs = $self->genotypes_nd_experiment_ids_rs([$stock_id]);

    my @nd_exp_ids;

    while (my $row = $nd_exp_rs->next)
    {
	push @nd_exp_ids, $row->get_column('nd_experiment_id');
    }

    my $genotype_rs = $stock_rs
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
	->search_related('type',
                         {'type.name' => {'ilike' => 'snp genotyping'},
			  'nd_experiment_genotypes.nd_experiment_id' => {-in => \@nd_exp_ids}
			 },
                         {
                             select => [ qw / me.stock_id me.uniquename  genotypeprops.genotypeprop_id genotypeprops.value / ],
                             as     => [ qw / stock_id stock_name  genotypeprop_id value/ ]
                         }
        );


    return $genotype_rs;

}


sub accessions_list_genotypes_rs {
    my ($self, $genotypes_ids) = @_;


    my $protocol = $self->genotyping_protocol();
    my $genotype_rs = $self->schema->resultset('NaturalDiversity::NdExperiment')
	->search(
	{
	    'nd_protocol.name' => $protocol,
	    'stock.stock_id' => {-in =>$genotypes_ids},
	    'type.name'  => 'snp genotyping',
	    'cv.name' => 'genotype_property',
	},
	{
	    join => [
		{'nd_experiment_genotypes' => {'genotype' => {'genotypeprops'=> {'type' => 'cv'}}}},
		{'nd_experiment_protocols' => 'nd_protocol'},
		{'nd_experiment_stocks' => 'stock'}
		],

	    select => [ qw / stock.stock_id stock.uniquename  genotypeprops.genotypeprop_id genotypeprops.value / ],
	    as     => [ qw / stock_id stock_name  genotypeprop_id value/ ],
	    distinct => 1,
	});

    return $genotype_rs;

}


sub get_stocks_rs {
    my ($self, $stock_names) = @_;

     my $stocks_rs = $self->schema->resultset("Stock::Stock")
	 ->search({ 'me.uniquename' => {-in => $stock_names} },
		  {
		      select   => [ 'me.stock_id', 'me.uniquename' ],
		      as       => [ 'stock_id', 'uniquename'],
		      distinct => 1,
		  }
	 );

    return $stocks_rs;

}


sub genotyping_trials_rs {
    my $self = shift;

    my $geno_pr_rs = $self->schema->resultset("Project::Project")
        ->search({"genotypeprops.value" =>  {"!=",  undef},
		  'type.name' =>{'ilike' => 'snp genotyping'}
		 })
        ->search_related('nd_experiment_projects')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock')
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
	->search_related('type',
                         {},

                         {
                             select   => [ qw / me.project_id me.name / ],
                             as       => [ qw / project_id project_name  / ],
                             distinct => [ qw / me.project_id/ ],
			     order_by => 'CASE WHEN me.name ~ \'^[0-9]+\' THEN 1 ELSE 0 END, me.name',

                         }
        );

    return $geno_pr_rs;

}


sub prediction_genotypes_rs {
    my ($self, $pr_id) = @_;

    my $genotypes_rs = $self->project_genotype_data_rs($pr_id);

    return $genotypes_rs;

}


sub extract_project_markers {
    my ($self, $geno_row) = @_;

    my $markers;

    my $genotype_json = $geno_row->get_column('value');
    my $genotype_hash = JSON::Any->decode($genotype_json);
    my @markers       = keys %$genotype_hash;

    foreach my $marker (@markers)
    {
	$markers .= $marker;
	$markers .= "\t" unless $marker eq $markers[-1];
    }

    return $markers;
}


sub get_dataset_markers {
    my ($self, $geno_hash) = @_;

    my @markers  = keys %$geno_hash;

    return \@markers;

}


sub create_genotype_dataset_headers {
    my ($self, $markers) = @_;

    my $headers = join("\t", @$markers);

    return $headers;
}


sub create_genotype_row {
    my ($self, $markers, $genotype_hash) = @_;

    my $geno_values;

    foreach my $marker (@$markers)
    {
	no warnings 'uninitialized';

	$geno_values .= $genotype_hash->{$marker}->{'DS'};
        $geno_values .= "\t" unless $marker eq $markers->[-1];
    }

    return \$geno_values;

}


sub round_allele_dosage_values {
    my ($self, $geno_values) = @_;

    my $round = Math::Round::Var->new(0);

    $geno_values = $geno_values =~ /\d+/g
	? $round->round($geno_values)
	: $geno_values;

    return $geno_values;
}


sub stock_genotype_values {
    my ($self, $header_markers, $geno_row) = @_;

    my $json_values  = $geno_row->get_column('value');
    my $values       = JSON::Any->decode($json_values);


    my $stock_name = $geno_row->get_column('stock_name');


    my $geno_values = $stock_name . "\t";

    foreach my $marker (@$header_markers)
    {
	no warnings 'uninitialized';

        my $genotype =  $values->{$marker};
	$geno_values .= $genotype;
        $geno_values .= "\t" unless $marker eq $header_markers->[-1];
    }

    $geno_values .= "\n";

    return $geno_values;
}


sub prediction_pops {
  my ($self, $training_pop_id) = @_;

  my @tr_pop_markers;
  $self->context->stash->{get_selection_populations} = 1;

  if ($training_pop_id =~ /^\d+$/)
  {
      my $dir = $self->context->stash->{solgs_cache_dir};
      opendir my $dh, $dir or die "can't open $dir: $!\n";

      my ($geno_file) =   grep { /genotype_data_${training_pop_id}/ && -f "$dir/$_" }
                            readdir($dh);
      closedir $dh;

      $geno_file = catfile($dir, $geno_file);
      open my $fh, "<", $geno_file or die "can't open genotype file: $!";

      my $markers = <$fh>;
      chomp($markers);

      $fh->close;

      @tr_pop_markers = split(/\t/, $markers);
      shift(@tr_pop_markers);
  }
  elsif( $training_pop_id =~ /list/)
  {
     # my $user_id = $self->context->user->id;

      my $dir = $self->context->stash->{solgs_lists_dir};
      opendir my $dh, $dir or die "can't open $dir: $!\n";

      my ($geno_file) = grep { /genotype_data_${training_pop_id}/ && -f "$dir/$_" }  readdir($dh);
      closedir $dh;

      $geno_file = catfile($dir, $geno_file);
      open my $fh, "<", $geno_file or die "can't open genotype file: $!";

      my $markers = <$fh>;
      chomp($markers);

      $fh->close;

      @tr_pop_markers = split(/\t/, $markers);
      shift(@tr_pop_markers);
  }

  my @sample_pred_projects;
  my $cnt = 0;
  my $projects_rs = $self->genotyping_trials_rs();
  my $count = $projects_rs->count;

  while (my $row = $projects_rs->next)
  {
      my $project_id = $row->get_column('project_id');
      if ($project_id && $training_pop_id != $project_id)
      {
	  my $pop_type = $self->get_population_type($project_id);

	  if ($pop_type !~ /training population/)
	  {
	      my $pred_marker_cnt =  $self->get_project_genotypeprop($project_id);
	      $pred_marker_cnt = $pred_marker_cnt->{'marker_count'};

	      my $potential_selection;

	      if ($pred_marker_cnt)
	      {
		  if ( scalar(@tr_pop_markers) / $pred_marker_cnt  > 0.5  )
		  {
		      $potential_selection = 'yes';
		  }
	      }

	      if (!$pred_marker_cnt || ($pred_marker_cnt && $potential_selection))
	      {
		  my $stock_genotype_rs = $self->prediction_genotypes_rs($project_id);
		  my $stocks_count = $stock_genotype_rs->count;
		  my $first_geno   =  $stock_genotype_rs->single;

		  if ($stocks_count > 10 &&  $first_geno)
		  {
		      my $pop_prop = {'project_id' => $project_id,
				  'population type' => 'selection population',
		      };

		      $self->set_population_type($pop_prop);

		      my $obj_name = $first_geno->get_column('stock_name');
		      my $stock_rs = $self->search_stock($obj_name);
		      $stock_genotype_rs = $self->individual_stock_genotypes_rs($stock_rs);

		      my $markers   = $self->extract_project_markers($stock_genotype_rs->first);

		      if ($markers)
		      {
			  my @pred_pop_markers = split(/\t/, $markers);

			  unless ($pred_marker_cnt)
			  {
			      my $genoprop = {'project_id' => $project_id, 'marker_count' => scalar(@pred_pop_markers)};
			      $self->set_project_genotypeprop($genoprop);
			  }

			  print STDERR "\ncheck if prediction populations are genotyped using the same
                                 set of markers as for the training population : "
                                 . scalar(@pred_pop_markers) .  ' vs ' . scalar(@tr_pop_markers) . "\n";

			  my $common_markers = scalar(intersect(@pred_pop_markers, @tr_pop_markers));
			  my $similarity = $common_markers / scalar(@tr_pop_markers);

			  if ($similarity > 0.5 )
			  {
			      $cnt++;
			      push @sample_pred_projects, $project_id;
			  }
		      }
		  }
	      }
	  }
      }

      last if $cnt == 5;
  }

  return \@sample_pred_projects;

}



sub plots_list_phenotype_data {
    my ($self, $plots_ids) = @_;

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	bcs_schema  =>$self->schema,
	data_level  => 'plot',
	search_type =>'MaterializedViewTable',
	plot_list   => $plots_ids,
	);

    my @data = $phenotypes_search->get_phenotype_matrix();
    my $clean_data = $self->structure_phenotype_data(\@data);

    return \$clean_data;

}


sub trial_traits {
    my ($self, $pr_id) = @_;

    my $trial = CXGN::Trial->new({bcs_schema => $self->schema,
				  trial_id => $pr_id});

    return $trial->get_traits_assayed();

}


sub project_trait_phenotype_data_rs {
    my ($self, $project_id, $trait_id) = @_;

    my $rs = $self->schema->resultset("Stock::Stock")->search(
        {
            'observable.cvterm_id' => $trait_id ,
            'project.project_id'   => $project_id,
        }, {
            join => [
                {  nd_experiment_stocks => {
		    nd_experiment => {
			nd_experiment_phenotypes => {
			    phenotype => 'observable'
			},
				nd_experiment_projects => 'project',
		    },
		   }
		},
                ],

	    select  => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description project.project_id / ],
	    as      => [ qw/ stock_id uniquename value observable observable_id project_description project_id / ],

        });

    return $rs;

}


sub get_plot_phenotype_rs {
    my ($self, $plot_id, $trait_id) = @_;

    my $pheno_rs = $self->schema->resultset("Phenotype::Phenotype")
        ->search(
        {
            'me.uniquename' => {"iLIKE" => "Stock: $plot_id, %"},
        },
        {
            join      => 'observable',
            '+select' => [ qw / observable.name / ],
            '+as'     => [ qw / cvterm_name / ],
            distinct  => 1,
            order_by  => ['observable.name']
        }
        );

    return $pheno_rs;
}



sub get_plot_phenotype_data {
    my ($self, $plot_id) = @_;

    my $project_desc    = $self->context->stash->{project_description};
    my $plot_uniquename = $self->context->stash->{plot_uniquename};

    my $object_rs = $self->map_subject_to_object($plot_id);
    my ($object_name, $object_id);

    while (my $ob_r = $object_rs->next) {
        $object_name = $ob_r->name;
        $object_id   = $ob_r->stock_id;
    }

    my $uniquename = $project_desc . "|" . $plot_uniquename;

    my $block     = 'NA';
    my $replicate = 'NA';

    my $design = $self->context->stash->{design};
    $design    = $design ? $design : 'NA';

    my $block_rs = $self->search_plotprop($plot_id, 'block');
    if ($block_rs->next)

    {
        $block = $block_rs->single->value();
    }

    my $replicate_rs = $self->search_plotprop($plot_id, 'replicate');
    if($replicate_rs->next)
    {
        $replicate = $replicate_rs->single->value();
    }

    my $dh = " ";
    my $d  = "$uniquename\t$object_name\t$object_id\t$plot_id\t$plot_uniquename\t$design\t$block\t$replicate";

    my $plot_pheno_rs = $self->get_plot_phenotype_rs($plot_id);
    my $cnt=0;

    while (my $pl_r = $plot_pheno_rs->next)
    {
        my $trait = $pl_r->get_column('cvterm_name');
        my $value = $pl_r->value;

        $dh .= "\t" . $trait;
        $d  .= "\t" . $value;

        $cnt++;
    }

    return $d, $dh;
}


sub project_phenotype_data_rs {
    my ($self, $project_id) = @_;

    my $rs = $self->schema->resultset("Stock::Stock")->search(
        {
            'observable.name' => { '!=', undef } ,
            'project.project_id'     => $project_id,
        }, {
            join => [
                { nd_experiment_stocks => {
                    nd_experiment => {
                        nd_experiment_phenotypes => {
                            phenotype => 'observable'
                        },
                                nd_experiment_projects => 'project',
                    },
                  }
                } ,
                ],
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description project.project_id / ],
            as       => [ qw/ stock_id uniquename value observable observable_id project_description project_id / ],

            order_by => [  'observable.name' ],
        });

    return $rs;

}


sub plots_list_phenotype_data_rs {
    my ($self, $plots) = @_;

    my $rs = $self->schema->resultset("Stock::Stock")->search(
        {
            'observable.name' => { '!=', undef } ,
            'me.uniquename'   => { -in => $plots },
        } , {
            join => [
                { nd_experiment_stocks => {
                    nd_experiment => {
                        nd_experiment_phenotypes => {
                            phenotype => 'observable'
                        },
                                nd_experiment_projects => 'project',
                    },
                  }
                } ,
                ],
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.project_id project.name / ],
            as       => [ qw/ germplasmDbId germplasmName value observable observable_id studyDbId studyName / ],

            order_by => [  'observable.name' ],
        }  );

    return $rs;

}




sub stock_phenotype_data_rs {
    my $self = shift;
    my $stock_rs = shift;

    my $stock_id;
    if ($stock_rs->first)
    {
	$stock_id = $stock_rs->first->stock_id;
    }

    die "Can't get stock phenotype data with out stock_id" if !$stock_id;

    my $rs = $self->schema->resultset("Stock::Stock")->search(
        {
            'observable.name' => { '!=', undef } ,
            'me.stock_id'     => $stock_id,
        } , {
            join => [
                { nd_experiment_stocks => {
                    nd_experiment => {
                        nd_experiment_phenotypes => {
                            phenotype => 'observable'
                        },
                                nd_experiment_projects => 'project',
                    },
                  }
                } ,
                ],
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description project.project_id/ ],
            as       => [ qw/ stock_id uniquename value observable observable_id project_description project_id / ],

            order_by => [  'observable.name' ],
        }  );

    return $rs;
}


sub phenotype_data {
    my ($self, $project_id) = @_;

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	bcs_schema=>$self->schema,
	search_type=>'MaterializedViewTable',
	trial_list=>[$project_id],
	data_level=>'plot',
	);

    my @data = $phenotypes_search->get_phenotype_matrix();

    my $clean_data = $self->structure_phenotype_data(\@data);

    return \$clean_data;

}


sub project_trait_phenotype_data {
     my ($self, $pop_id, $trait_id ) = @_;

     my $data;
     if ($pop_id && $trait_id)
     {
	 my  $phenotypes = $self->project_trait_phenotype_data_rs($pop_id, $trait_id);
	 $data           = $self->structure_phenotype_data($phenotypes);
     }

     return  $data;
}


sub structure_phenotype_data {
    my ($self, $data) = @_;

    my $round = Math::Round::Var->new(0.001);

    my $formatted_data;

    no warnings 'uninitialized';

    for (my $i =0; $i < @$data; $i++)
    {
	my $row = $data->[$i];
	$row = join("\t", @$row);
	$formatted_data .=  $row . "\n";
    }

    return $formatted_data;
}


sub trial_metadata  {
    my ($self) = @_;

    my @headers =   ('studyYear', 'programDbId', 'programName', 'programDescription', 'studyDbId', 'studyName', 'studyDescription', 'studyDesign', 'plotWidth', 'plotLength', 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross', 'plantingDate',    'harvestDate', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber' ,  'colNumber',  'entryType', 'plantNumber', 'plantedSeedlotStockDbId',  'plantedSeedlotStockUniquename', 'plantedSeedlotCurrentCount', 'plantedSeedlotCurrentWeightGram', 'plantedSeedlotBoxName', 'plantedSeedlotTransactionCount', 'plantedSeedlotTransactionWeight', 'plantedSeedlotTransactionDescription', 'availableGermplasmSeedlotUniquenames', 'notes');


    return \@headers;

}


sub structure_plots_list_phenotype_data {
    my $self = shift;
    my $phenotypes = shift;

    my $phen_hashref= {}; #hashref of hashes for the phenotype data

    my %cvterms ; #hash for unique cvterms
    my $replicate = 1;
    my $cvterm_name;

    no warnings 'uninitialized';

    my $trial_id;
    my $project;

    my $round = Math::Round::Var->new(0.001);

    while ( my $r =  $phenotypes->next )
    {
        my $observable = $r->get_column('observable');
        next if !$observable;

        if ($cvterm_name eq $observable) { $replicate ++ ; } else { $replicate = 1 ; }
        $cvterm_name = $observable;

        $project = $r->get_column('studyName');

	$trial_id   = $r->get_column('studyDbId') if $replicate == 1;

	my $hash_key = $r->get_column('germplasmName');

        $phen_hashref->{$hash_key}{$observable} = $r->get_column('value');
        $phen_hashref->{$hash_key}{germplasmDbId} = $r->get_column('germplasmDbId');
        $phen_hashref->{$hash_key}{germplasmName} = $r->get_column('germplasmName');
	$phen_hashref->{$hash_key}{studyName} = $r->get_column('studyName');
        $cvterms{$observable} =  'NA';

    }

    my $d;

    if (keys %cvterms)
    {
	$d = "germplasmName\tgermplasmDbId\tstudyName\tstudyYear\tlocationName\tstudyDesign\tblockNumber\treplicate";

	foreach my $term_name (sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )
	{
	    $d .=  "\t" . $term_name;
	}

	$d .= "\n";

	my @project_genotypes;

	foreach my $key ( sort keys %$phen_hashref )
	{
	    my $subject_id       = $phen_hashref->{$key}{germplasmDbId};
	    my $stock_object_row = $self->map_subject_to_object($subject_id)->single;

	    my ($object_name, $object_id);
	    if ($stock_object_row)
	    {
		$object_name      = $stock_object_row->uniquename;
		$object_id        = $stock_object_row->stock_id;

		push @project_genotypes, $object_name;
	    }

	    $d .= $object_name . "\t" . $object_id . "\t" . $phen_hashref->{$key}{studyName};

	    my $location_name = 'NA';
	    my $study_year    = 'NA';
	    my $design        = 'NA';
	    my $block         = 'NA';
	    my $replicate     = 'NA';

	    my $design_rs = $self->experimental_design($trial_id);

	    if ($design_rs->next)
	    {
		$design = $design_rs->first->value();
	    }

	    my $block_rs = $self->search_plotprop($subject_id, 'block');
	    if ($block_rs->next)
	    {
		$block = $block_rs->first->value();
	    }

	    my $replicate_rs = $self->search_plotprop($subject_id, 'replicate');
	    if ($replicate_rs->next)
	    {
		$replicate = $replicate_rs->first->value();
	    }

	    $d .= "\t". $study_year .  "\t" . $location_name ."\t". $design .  "\t" . $replicate ."\t" . $block;

	    foreach my $term_name ( sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )
	    {
		my $val = $phen_hashref->{$key}{$term_name};
		if (looks_like_number($val))
		{
		    $val = $round->round($val);
		}
		else
		{
		    $val = "NA";
		}

		$d .= "\t" . $val;
	    }
	    $d .= "\n";
	}

#	@project_genotypes = uniq(@project_genotypes);
#	$self->context->stash->{project_genotypes} = \@project_genotypes;
    }

    return $d;
}




=head2 phenotypes_by_trait

  Usage: $self->phenotypes_by_trait($phenotype_rs , { %args } )
  Desc:  generate a report of phenotype values by trait name/accession
  Args:  an arrayref of L<Bio::Chado::Schema::Result::Phenotype::Phenotype> ResultSets
         [optional] list of args to filter the report. Currently supported args are

  Ret:   arrayref of tab delimited data

=cut

sub phenotypes_by_trait {
    my $self = shift;
    my $phenotypes = shift;

    my $phen_hashref= {}; #hashref of hashes for the phenotype data

    my %cvterms ; #hash for unique cvterms
    my $replicate = 1;
    my $cvterm_name;
    my $cnt = 0;

    my $trial_id;

    no warnings 'uninitialized';

    my $round = Math::Round::Var->new(0.001);

    foreach my $rs (@$phenotypes)
    {
        $cnt++;
        while ( my $r =  $rs->next )
        {
             my $observable = $r->get_column('observable');
             next if !$observable;

             if ($cvterm_name eq $observable) { $replicate ++ ; } else { $replicate = 1 ; }
             $cvterm_name = $observable;

             my $project  = $r->get_column('project_description') ;
	     $trial_id    = $r->get_column('project_id') if $replicate == 1;
	     my $hash_key = $r->get_column('uniquename');

             # $phen_hashref->{$hash_key}{accession} = $db_name . ":" . $accession ;
             $phen_hashref->{$hash_key}{$observable} = $r->get_column('value');
             $phen_hashref->{$hash_key}{stock_id} = $r->get_column('stock_id');
             $phen_hashref->{$hash_key}{stock_name} = $r->get_column('uniquename');
             $cvterms{$observable} =  'NA';
        }
    }

    my @data;
    my $d = "uniquename\tobject_name\tobject_id\tstock_id\tstock_name\tdesign\tblock\treplicate";
    foreach my $term_name (sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )
    {# sort ontology terms
      #  my $ontology_id = $cvterms{$term_name};
        #  $d .=  "\t" . $ontology_id . "|" . $term_name;
        $d .=  "\t" . $term_name;
    }
    $d .= "\n";

    foreach my $key ( sort keys %$phen_hashref )
    {
        #print the unique key (row header)
        # print some more columns with metadata
        # print the value by cvterm name

        my $subject_id       = $phen_hashref->{$key}{stock_id};
        my $stock_object_row = $self->map_subject_to_object($subject_id)->single;
        my $object_name      = $stock_object_row->uniquename;
        my $object_id        = $stock_object_row->stock_id;

        $d .= $key . "\t" .$object_name . "\t" . $object_id . "\t" . $phen_hashref->{$key}{stock_id} .
              "\t" . $phen_hashref->{$key}{stock_name};

        my $block     = 'NA';
        my $replicate = 'NA';
        my $design    = 'NA';

        my $design_rs = $self->experimental_design($trial_id);

        if ($design_rs->next)
        {
            $design = $design_rs->first->value();
        }

        my $block_rs = $self->search_plotprop($subject_id, 'block');
        if ($block_rs->next)
        {
            $block = $block_rs->first->value();
        }

        my $replicate_rs = $self->search_plotprop($subject_id, 'replicate');
        if ($replicate_rs->next)
        {
            $replicate = $replicate_rs->first->value();
        }

        $d .= "\t". $design . "\t" . $block .  "\t" . $replicate;

        foreach my $term_name ( sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )
        {
	    	my $val = $phen_hashref->{$key}{$term_name};

		if (looks_like_number($val))
		{
		    $val = $round->round($val);
		}
		else
		{
		    $val = "NA";
		}

		$d .= "\t" . $val;
		$d .= "\t" . $phen_hashref->{$key}{$term_name};
        }

        $d .= "\n";
    }

    $d = undef if $d eq '';

    return $d;
}


sub stock_projects_rs {
    my ($self, $stock_rs) = @_;

    my $project_rs = $stock_rs->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_projects')
        ->search_related('project',
                         {},
                         {
                             distinct => 1,
                         }
        );

    return $project_rs;

}


sub project_subject_stocks_rs {
    my ($self, $project_id) = @_;

    my $stock_rs =  $self->schema->resultset("Project::Project")
        ->search({'me.project_id' => $project_id})
        ->search_related('nd_experiment_projects')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock')
        ->search_related('stock_relationship_subjects')
        ->search_related('subject',
                         {},

        );

    return $stock_rs;
}


sub stocks_object_rs {
    my ($self, $stock_subj_rs) = @_;

    my $stock_obj_rs = $stock_subj_rs
        ->search_related('stock_relationship_subjects')
        ->search_related('object',
                         {},
                         {
                             '+select' => [ qw /me.project_id me.name/ ],
                             '+as'     => [ qw /project_id project_name/ ]
                         }
        );

    return $stock_obj_rs;
}


sub map_subject_to_object {
    my ($self, $stock_id) = @_;

    my $stock_obj_rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.stock_id' => $stock_id})
        ->search_related('stock_relationship_subjects')
        ->search_related('object');

    return $stock_obj_rs;
}


sub get_genotypes_from_plots {
    my ($self, $plots) = @_;

    my $genotypes_rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.uniquename' =>{-in =>  $plots}})
        ->search_related('stock_relationship_subjects')
        ->search_related('object');

    return $genotypes_rs;
}

sub trial_breeding_program_id {
	my ($self, $trial_id) = @_;

	my $type_id = $self->schema->resultset('Cv::Cvterm')->search({'name' => 'breeding_program_trial_relationship'})->single->id;

	my $breeding_id = $self->schema->resultset("Project::ProjectRelationship")
	->search({'me.subject_project_id' => $trial_id, 'me.type_id' => $type_id})->single->object_project_id;

	return $breeding_id;
}

sub get_project_genotyping_markers {
    my ($self, $pr_id) = @_;

    my $stock_genotype_rs = $self->project_genotype_data_rs($pr_id);

    my $markers;

    if ($stock_genotype_rs->first)
    {
	$markers = $self->extract_project_markers($stock_genotype_rs->first);
    }

    return $markers;

}


sub genotyping_protocol {
    my ($self, $protocol) = @_;

    unless ($protocol)
    {
	$protocol = $self->context->config->{default_genotyping_protocol};
    }

    return $protocol;

}


sub protocol_detail {
    my ($self, $protocol) = @_;

    unless ($protocol)
    {
	$protocol = $self->context->config->{default_genotyping_protocol};
    }

    my $where;
    if ($protocol =~ /\D+/)
    {
	$where = 'WHERE name = ?';
    }
    else
    {
	$where = 'WHERE nd_protocol_id = ?';
    }

    my $q = 'SELECT nd_protocol_id, name, description FROM nd_protocol ' .  $where;
    my $sth = $self->context->dbc->dbh->prepare($q);
    $sth->execute($protocol);
    my ($protocol_id, $name, $desc) = $sth->fetchrow_array();

    return {
	'protocol_id' => $protocol_id,
	'name'        => $name,
	'description' => $desc
    };

}


sub get_all_genotyping_protocols {
    my ($self, $trial_id) = @_;

    my $where = ' WHERE genotyping_protocol_id > 0';
    if ($trial_id)
    {
	$where = ' WHERE trial_id = ?';
    }

    my $q = 'SELECT distinct(genotyping_protocol_id)
                    FROM genotyping_protocolsXtrials' . $where;


    my $sth = $self->context->dbc->dbh->prepare($q);

    $trial_id ? $sth->execute($trial_id) : $sth->execute();

    my @protocol_ids;

    while ( my $protocol_id = $sth->fetchrow_array())
    {
	push @protocol_ids, $protocol_id;
    }

    return \@protocol_ids;
}


sub get_genotypes_from_dataset {
    my ($self, $dataset_id) = @_;

	my $data = $self->get_dataset_data($dataset_id);
	my $genotypes_ids;
	if ($data->{categories}->{accessions}->[0])
	{
		$genotypes_ids = $data->{categories}->{accessions};
	}
	else
	{
	    my $dataset = CXGN::Dataset->new({
		people_schema => $self->people_schema,
		schema  => $self->schema,
		sp_dataset_id =>$dataset_id});

	    $genotypes_ids  = $dataset->retrieve_accessions();
	    my @genotypes_ids = uniq(@$genotypes_ids) if $genotypes_ids;
		$genotypes_ids = \@genotypes_ids;
	}

    return $genotypes_ids;
}


sub get_dataset_data {
    my ($self, $dataset_id) = @_;

    my $dataset = CXGN::Dataset->new({
	people_schema => $self->people_schema,
	schema  => $self->schema,
	sp_dataset_id =>$dataset_id});

    my  $dataset_data = $dataset->get_dataset_data();

    return $dataset_data;
}


sub get_dataset_plots_list {
    my ($self, $dataset_id) = @_;

    my $dataset = CXGN::Dataset->new({
	people_schema => $self->people_schema,
	schema  => $self->schema,
	sp_dataset_id =>$dataset_id});

    my  $plots = $dataset->retrieve_plots();

    return $plots;
}


sub get_dataset_name {
    my ($self, $dataset_id) = @_;

    my $dataset = CXGN::Dataset->new({
	people_schema => $self->people_schema,
	schema  => $self->schema,
	sp_dataset_id => $dataset_id});

    return $dataset->name();
}


sub get_dataset_owner {
    my ($self, $dataset_id) = @_;

    my $dataset = CXGN::Dataset->new({
	people_schema => $self->people_schema,
	schema  => $self->schema,
	sp_dataset_id => $dataset_id});

    return $dataset->sp_person_id();
}


sub get_dataset_genotype_data {
    my ($self, $dataset_id, $protocol_id) = @_;

    my $protocol_detail = $self->protocol_detail($protocol_id);
    $protocol_id = $protocol_detail->{protocol_id};

    my $geno_search = CXGN::Genotype::Search->new(
	bcs_schema => $self->schema(),
	people_schema => $self->people_schema,
	sp_dataset_id => $dataset_id,
	protocol_id_list => [$protocol_id],
	genotypeprop_hash_select=> ['DS'],
	protocolprop_top_key_select=>[],
	protocolprop_top_key_select=>[],
	return_only_first_genotypeprop_for_stock=> 1,
	);

    $geno_search->init_genotype_iterator();
    return $geno_search;

 }




sub people_schema {
    my $self = shift;
    return $self->context->dbic_schema("CXGN::People::Schema");
}

__PACKAGE__->meta->make_immutable;



#####
1;
#####
