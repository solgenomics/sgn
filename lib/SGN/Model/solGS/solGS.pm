=head1 NAME

solGS::Model::solGS - Catalyst Model for solGS

=head1 DESCRIPTION

solGS Catalyst Model.

=head1 AUTHOR

Isaak Y Tecle, iyt2@cornell.edu

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

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
    my ($self, $trait, $page) = @_;
 
    $page = 1 if !$page;

    my $rs;
    if ($trait)
    {       
        $rs = $self->schema->resultset("Phenotype::Phenotype")
            ->search({})
            ->search_related('observable', 
                             {
                                 'observable.name' => {'iLIKE' => '%' . $trait . '%'}
                             },
                             { 
                                 distinct => 1,
                                 page     => $page,
                                 rows     => 10,
                                 order_by => 'name'              
                             },                                               
            );             
    }
    
    return $rs;      
}


sub all_gs_traits {
    my $self = shift;

    my $rs = $self->schema->resultset("Phenotype::Phenotype")
        ->search(
        {}, 
        {
            columns => 'observable_id', 
            distinct => 1
        }
        )
        ->search_related('observable', 
                         {},                        
        );

    return $rs;      
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
			   distinct => [ qw / project.project_id / ]
                         },			
	);

    return $rs; 

}
 

sub project_year {
    my ($self, $pr_id) =  @_;
    
    return $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'project year' })
        ->search_related('projectprops');
}


sub experimental_design {
    my ($self, $pr_id) =  @_;
    
    return $self->schema->resultset("Cv::Cvterm")
        ->search({'project_id' => $pr_id, 'me.name' => 'design' })
        ->search_related('projectprops');
}


sub project_location {
    my ($self, $pr_id) = @_;
  
    my $q = "SELECT description FROM projectprop 
                LEFT JOIN cvterm ON (type_id = cvterm_id) 
                LEFT JOIN  nd_geolocation ON (CAST(projectprop.value AS INT) = nd_geolocation.nd_geolocation_id) 
                WHERE project_id = ?
                      AND cvterm.name ilike ?";


   # my $q = "SELECT description FROM projectprop 
   #             LEFT JOIN cvterm ON (type_id = cvterm_id) 
   #             LEFT JOIN  nd_geolocation ON (CAST(projectprop.value AS INT) = nd_geolocation.nd_geolocation_id) 
   #             WHERE project_id = ?";

    print STDERR "\nckeck query :$q\n";
	   
    my $sth = $self->context->dbc->dbh()->prepare($q);

    print STDERR "\nckeck query :$sth\n";

    if ( $pr_id eq '' ) { 
        $pr_id = undef;
    }

    print STDERR "\nproject id  :$pr_id\n";

    $sth->execute($pr_id,'project location');
    
   # $sth->execute(699, 'project location');
   # $sth->execute($pr_id);

    my $loc = $sth->fetchrow_array;

    return $loc; 
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
     my ($self, $pr_id ) = @_; 
    
     my $has_phenotype;
     if ($pr_id) 
     {
	 my $file_cache  = Cache::File->new(cache_root => $self->context->stash->{solgs_cache_dir});
	 $file_cache->purge();
   
	 my $key        = "phenotype_data_" . $pr_id;
	 my $pheno_file = $file_cache->get($key);
        
	 if ( -s $pheno_file)
	 {  
	     $has_phenotype = 'has_phenotype';
	 }
	 else 
	 {
	     if ( !-e $pheno_file)
	     {
		 my $data = $self->phenotype_data($pr_id);
		 my ($header, $values) = split(/\n/, $data);
		 $header =~ s/uniquename|object_id|object_name|stock_id|stock_name|design|block|replicate|\t|\n//g;
             
		 $pheno_file = catfile($self->context->stash->{solgs_cache_dir}, "phenotype_data_" . $pr_id . ".txt");
	     
		 if($header) 
		 {
		     $data =  $self->context->controller("solGS::solGS")->format_phenotype_dataset($self->context, $data); 
		     write_file($pheno_file, $data);

		     $file_cache->set($key, $pheno_file, '30 days');
		     $has_phenotype = 'has_phenotype'; 
		 }
		 else 
		 {
		     write_file($pheno_file, "");
		     $file_cache->set($key, $pheno_file, '5 days');
		 }
	     }	    
	 }
     }
     
     return $has_phenotype;
}


sub has_genotype {
    my ($self, $pr_id) = @_;

    my $has_genotype;
    my $stock_subj_rs = $self->project_subject_stocks_rs($pr_id);    
    my $stock_obj_rs  = $self->stocks_object_rs($stock_subj_rs);
    my $stock_genotype_rs = $self->stock_genotypes_rs($stock_obj_rs)->search(undef, {page => 1, rows=> 10});
   
    while (my $stock = $stock_genotype_rs->next) 
    {
        if($stock) 
        {
            my $genotype_name = $stock->get_column('stock_name'); 
            if ($stock->get_column('value')) 
            { 
                $has_genotype = 'has_genotype';
                last;
            }
        }      
    }

    return $has_genotype;

}


sub project_details {
    my ($self, $pr_id) = @_;
    
    return $self->schema->resultset("Project::Project")
        ->search( {'me.project_id' => $pr_id});
}


sub project_details_by_name {
    my ($self, $pr_name) = @_;
    
    return $self->schema->resultset("Project::Project")
        ->search( {'me.name' => $pr_name});
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

    my $trait_name = $self->schema->resultset('Cv::Cvterm')
        ->search( {cvterm_id => $trait_id})
        ->single
        ->name;

    return $trait_name;

}


sub get_trait_id {
    my ($self, $trait) = @_;

    if ($trait) 
    {
        my $trait_id = $self->schema->resultset('Cv::Cvterm')
            ->search( {name => $trait})
            ->single
            ->id;

        return $trait_id;
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
        ->search_related('projectprops');

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
    if($pr_rs->next) 
    {
	$pr_type = $pr_rs->first()->value;
    }
    
    return $pr_type;
}


sub get_stock_owners {
    my ($self, $stock_id) = @_;
   
    my $owners; 
    
    unless ($stock_id =~ /uploaded/) 
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


sub genotype_data {
    my ($self, $project_id) = @_;
    
    my $stock_genotype_rs;
    my @genotypes;
    my $geno_data;
    my $header_markers;
    my @header_markers; 
    my $cnt_clones_diff_markers;
    my @stocks;

    if ($project_id) 
    {
        my $prediction_id = $self->context->stash->{prediction_pop_id};
        my $model_id      = $self->context->stash->{model_id};
       
        if ($prediction_id && $project_id == $prediction_id) 
        {    
            my $data_set_type = $self->context->stash->{data_set_type};
            my $trait_abbr    = $self->context->stash->{trait_abbr};
            
            $stock_genotype_rs = $self->prediction_genotypes_rs($project_id);
            my $stock_count = $stock_genotype_rs->count;
                
            unless ($header_markers) 
            {
                if ($stock_count)
                {
                    my $dir = $self->context->stash->{solgs_cache_dir};
                    
                    my $file = $data_set_type =~ /combined/ 
                        ? "genotype_data_${model_id}_${trait_abbr}" 
                        : "genotype_data_${model_id}.txt";
                    
                    my $training_geno_file = $self->context->controller("solGS::solGS")->grep_file($dir, $file);

                    open my $fh, $training_geno_file or die "couldnot open $training_geno_file: $!";    
                    my $header_markers = <$fh>;
                    $header_markers =~ s/^\s+|\s+$//g;
                                
                    @header_markers = split(/\t/, $header_markers);
                                           
                    $geno_data = $header_markers . "\n"; 
                }
            }
            
            my $cnt = 0;
            while (my $geno = $stock_genotype_rs->next)
            {  
                $cnt++;
		my $stock = $geno->get_column('stock_name');
		
		my $duplicate_stock;

		if ($cnt > 1)
		{
		    ($duplicate_stock) = grep(/$stock/, @stocks);
		}
                 
                if ( $cnt == 1  || ($cnt > 1 && !$duplicate_stock) )
                {
                    push @stocks, $stock;
                    
                    my $json_values  = $geno->get_column('value');
                    my $values       = JSON::Any->decode($json_values);
                    my @markers      = keys %$values;
                 
                    my $common_markers = scalar(intersect(@header_markers, @markers));
                    my $similarity = $common_markers / scalar(@header_markers);
                  
                    if ($similarity == 1)     
                    {
                        my $geno_values = $self->stock_genotype_values($geno);               
                        $geno_data     .= $geno_values;                       
                    }
                    else 
                    {                       
                        $cnt_clones_diff_markers++; 
                        print STDERR "\nstocks excluded:$stock  different markers $cnt_clones_diff_markers\n";
                    }                    
                } 
                else 
                { 
                    print STDERR "\nstocks excluded duplicate:$stock\n";
                }   
            } 
        }        
        else 
        {          
            $stock_genotype_rs = $self->project_genotype_data_rs($project_id);
           
            my $cnt = 0;
            while (my $geno = $stock_genotype_rs->next)
            { 
                $cnt++;
              	
		my $stock = $geno->get_column('stock_name');
		
		my $duplicate_stock;

		if ($cnt > 1)
		{
		    ($duplicate_stock) = grep(/$stock/, @stocks);
		}
                 
                if ( $cnt == 1  || ($cnt > 1 && !$duplicate_stock) )
                {
		    my $json_values = $geno->get_column('value');
		    my $values      = JSON::Any->decode($json_values);
		    my @markers     = keys %$values;

		    if ($cnt == 1) 
		    {
			@header_markers = @markers;   
			$header_markers = join("\t", @header_markers);
			$geno_data      = "\t" . $header_markers . "\n";
		    }
              
		    my $common_markers = scalar(intersect(@header_markers, @markers));

		    my $similarity = $common_markers / scalar(@header_markers);
                
		    if ($similarity == 1)     
		    {
			my $geno_values = $self->stock_genotype_values($geno);             
			$geno_data     .= $geno_values;
		    }
		    else 
		    {
			$cnt_clones_diff_markers++;                                     
		    }
		}
            }       
        }
        
        print STDERR "\n$cnt_clones_diff_markers clones were  genotyped using a 
                        different GBS markers than the ones on the header. 
                        They are excluded from the training set. \n\n";
    }

    return  $geno_data;   

}


sub format_user_list_genotype_data {
    my $self = shift;

    my $population_type = $self->context->stash->{population_type};
   
    my @genotypes;

    if ($population_type =~ /reference/)         
    {
	my  @plots = @{ $self->context->stash->{reference_population_plot_names} };
	my $genotypes_rs = $self->get_genotypes_from_plots(\@plots);
	
	while (my $genotype = $genotypes_rs->next) {
	    my $name = $genotype->uniquename;
	    push @genotypes, $name;

	}
    }
    else
    {
	@genotypes = @{$self->context->stash->{genotypes_list}};
	    
    }    
 
    @genotypes = uniq(@genotypes);
   
    my $geno_data;
    my $header_markers;
    my @header_markers;

    my $list_genotypes_rs = $self->accessions_list_genotypes_rs(\@genotypes);

    while (my $stock_genotype = $list_genotypes_rs->next) {

	my $stock_name = $stock_genotype->get_column('stock_name');

	unless ($header_markers) 
	{
	    $header_markers   = $self->extract_project_markers($stock_genotype);                
	    $geno_data = "\t" . $header_markers . "\n";
	    @header_markers = split(/\t/, $header_markers);
        }
      
	my $json_values  = $stock_genotype->get_column('value');
	my $values       = JSON::Any->decode($json_values);
	my @markers      = keys %$values;
            
	my $common_markers = scalar(intersect(@header_markers, @markers));
	my $similarity = $common_markers / scalar(@header_markers);
	
	if ($similarity == 1 )     
	{
	    my $geno_values = $self->stock_genotype_values($stock_genotype);               
	    $geno_data .= $geno_values;
	}       
    }

    if ($population_type =~ /reference/) 
    {
        $self->context->stash->{user_reference_list_genotype_data} = $geno_data;
    }
    else
    {
        $self->context->stash->{user_selection_list_genotype_data} = $geno_data;   
    }

}


sub project_genotype_data_rs {
    my ($self, $project_id) = @_;

    my $genotype_rs = $self->schema->resultset("Project::Project")
        ->search({'me.project_id' => $project_id, 
		  'type.name' => {'ilike' => 'snp genotyping'}
		 })
        ->search_related('nd_experiment_projects')
        ->search_related('nd_experiment') 
        ->search_related('nd_experiment_stocks')       
        ->search_related('stock')
        ->search_related('stock_relationship_subjects')
        ->search_related('object')
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment') 
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
	->search_related('type',
			 {},               
                         { 
			     select   => [qw / genotypeprops.genotypeprop_id genotypeprops.value 
                                            me.project_id me.name object.stock_id object.uniquename / ],
			     as       => [ qw / genotypeprop_id value project_id project_name stock_id stock_name / ],
			     distinct => [ qw / stock_name /]
                         }
        );

    return $genotype_rs;

}


sub individual_stock_genotypes_rs {
    my ($self, $stock_rs) = @_;
    
    my $genotype_rs = $stock_rs
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
	->search_related('type',
                         {'type.name' => {'ilike' => 'snp genotyping'}},
                         {  
                             select => [ qw / me.stock_id me.uniquename  genotypeprops.genotypeprop_id genotypeprops.value / ], 
                             as     => [ qw / stock_id stock_name  genotypeprop_id value/ ] 
                         }
        );

    return $genotype_rs;

}


sub accessions_list_genotypes_rs {
    my ($self, $accessions_list) = @_;
    my $genotype_rs = $self->schema->resultset("Stock::Stock")
        ->search({ 'me.uniquename' => {-in => $accessions_list} })
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
	->search_related('type',
                         {'type.name' => {'ilike' => 'snp genotyping'}},
                         {  
                             select => [ qw / me.stock_id me.uniquename  genotypeprops.genotypeprop_id genotypeprops.value / ], 
                             as     => [ qw / stock_id stock_name  genotypeprop_id value/ ] 
                         }
        );

    return $genotype_rs;

}


sub stock_genotypes_rs {
    my ($self, $stock_rs) = @_;
    
    my $genotype_rs = $stock_rs
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops')
        ->search_related('type',
                         {'type.name' =>{'ilike'=> 'snp genotyping'}}, 
                         { 
                             select => [ qw / me.project_id me.name object.stock_id object.uniquename  
                                                 genotypeprops.genotypeprop_id genotypeprops.value/ ], 
                             as     => [ qw / project_id project_name stock_id stock_name genotypeprop_id value / ] 
                         }
        );

    return $genotype_rs;

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
    
    my $genotype_rs = $self->schema->resultset("Project::Project")
        ->search({'me.project_id' => $pr_id, 
		  'type.name' => {'ilike' => 'snp genotyping'}
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
			     select   => [qw / genotypeprops.genotypeprop_id genotypeprops.value 
                                            me.project_id me.name stock.stock_id stock.uniquename/ ],
			     as       => [ qw / genotypeprop_id value project_id project_name stock_id stock_name / ],
			     distinct => [ qw / stock_name /]
                         }
        );

    return $genotype_rs;

}


sub extract_project_markers {
    my ($self, $geno_row) = @_;
 
    my $markers;

    my $genotype_json =  $geno_row->get_column('value');

    my $genotype_hash = JSON::Any->decode($genotype_json);

    my @markers = keys %$genotype_hash;
   
    foreach my $marker (@markers) 
    {
	$markers .= $marker;
	$markers .= "\t" unless $marker eq $markers[-1];
    }
 
    return $markers;  
}


sub stock_genotype_values {
    my ($self, $geno_row) = @_;
              
    my $json_values  = $geno_row->get_column('value');
    my $values       = JSON::Any->decode($json_values);
    my @markers      = keys %$values;
      
    my $round =  Math::Round::Var->new(0);
                      
    my $geno_values = $geno_row->get_column('stock_name') . "\t";
   
    foreach my $marker (@markers) 
    {        
        my $genotype =  $values->{$marker};
        $geno_values .= $genotype =~ /\d+/g ? $round->round($genotype) : $genotype;       
        $geno_values .= "\t" unless $marker eq $markers[-1];
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
  elsif( $training_pop_id =~ /uploaded/) 
  {
      my $user_id = $self->context->user->id;
      
      my $dir = $self->context->stash->{solgs_prediction_upload_dir};      
      opendir my $dh, $dir or die "can't open $dir: $!\n";
    
      my ($geno_file) = grep { /genotype_data_${user_id}_${training_pop_id}/ && -f "$dir/$_" }  readdir($dh); 
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
		  my $obj_name     = $first_geno->get_column('stock_name');
        
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


sub format_user_reference_list_phenotype_data {
    my $self = shift;

    my @plots_names;
    my $population_type = $self->context->stash->{population_type};
    
    if ($population_type =~ /reference/)         
    {
        @plots_names = @{ $self->context->stash->{reference_population_plot_names} };
    }

    my $stock_pheno_data_rs = $self->plots_list_phenotype_data_rs(\@plots_names);
  
    my $data = $self->structure_phenotype_data($stock_pheno_data_rs);
    $self->context->stash->{user_reference_list_phenotype_data} = $data;     
}


sub project_traits {
  my ($self, $pr_id) = @_;
  
  my $rs = $self->schema->resultset("Project::Project")
      ->search({"me.project_id"  => $pr_id })
      ->search_related("nd_experiment_projects")
      ->search_related("nd_experiment")
      ->search_related("nd_experiment_phenotypes")
      ->search_related("phenotype")
      ->search_related("observable",
		       {},
		       {
			   distinct => [qw / observable.name / ],
			   order_by => [qw / observable.name / ]
		       }
      );

  return $rs;

}

# sub project_trait_phenotype {
#   my ($self, $pr_id) = @_;
  
#   my $rs = $self->schema->resultset("Project::Project")
#       ->search({"me.project_id"  => $pr_id, observable.observable_id => $trait_id })
#        ->search_related("nd_experiment_projects")
#        ->search_related("nd_experiment")
#        ->search_related("nd_experiment_phenotypes")
#        ->search_related("phenotype")
#        ->search_related("observable",
#        {},
#        {
#            '+select' => [qw / phenotype.phenotype_id phenotype.uniquename phenotype.value /],
#            '+as' => [qw / phenotype_id phenotype_uniquename phenotype_value /],

#         order_by => [qw / observable.name / ]
#        }
#        );

#        return $rs;
# }

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
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description / ],
            as       => [ qw/ stock_id uniquename value observable observable_id project_description / ],
          
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
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description / ],
            as       => [ qw/ stock_id uniquename value observable observable_id project_description / ],
          
            order_by => [  'observable.name' ],
        }  );
          
    return $rs;
}


sub stock_phenotype_data_rs {
    my $self = shift;
    my $stock = shift;
    my $stock_id = $stock->single->stock_id;
  
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
            select   => [ qw/ me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id project.description / ],
            as       => [ qw/ stock_id uniquename value observable observable_id project_description / ],
          
            order_by => [  'observable.name' ],
        }  );
          
    return $rs;
}


sub phenotype_data {
     my ($self, $pop_id ) = @_; 
    
     my $data;
     if ($pop_id) 
     {
         my  $phenotypes = $self->project_phenotype_data_rs($pop_id);
         $data           = $self->structure_phenotype_data($phenotypes);                   
    }
            
     return  $data; 
}


sub structure_phenotype_data {
    my $self = shift;
    my $phenotypes = shift;
    
    my $phen_hashref= {}; #hashref of hashes for the phenotype data

    my %cvterms ; #hash for unique cvterms
    my $replicate = 1;
    my $cvterm_name;
   
    no warnings 'uninitialized';

    while ( my $r =  $phenotypes->next )  
    {
        my $observable = $r->get_column('observable');
        next if !$observable;

        if ($cvterm_name eq $observable) { $replicate ++ ; } else { $replicate = 1 ; }
        $cvterm_name = $observable;
           
        my $project = $r->get_column('project_description') ;

	my $hash_key = $r->get_column('uniquename');

        $phen_hashref->{$hash_key}{$observable} = $r->get_column('value');
        $phen_hashref->{$hash_key}{stock_id} = $r->get_column('stock_id');
        $phen_hashref->{$hash_key}{stock_name} = $r->get_column('uniquename');
        $cvterms{$observable} =  'NA';
             
    }

    my $d;

    if (keys %cvterms) 
    {
	$d = "uniquename\tobject_name\tobject_id\tstock_id\tstock_name\tdesign\tblock\treplicate";
	foreach my $term_name (sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )  
	{
	    $d .=  "\t" . $term_name;
	}

	$d .= "\n";

	my @project_genotypes;

	foreach my $key ( sort keys %$phen_hashref ) 
	{        
	    my $subject_id       = $phen_hashref->{$key}{stock_id};
	    my $stock_object_row = $self->map_subject_to_object($subject_id)->single;

	    my ($object_name, $object_id);
	    if ($stock_object_row) 
	    {
		$object_name      = $stock_object_row->uniquename;
		$object_id        = $stock_object_row->stock_id;
        
		push @project_genotypes, $object_name;
	    }

	    $d .= $key . "\t" .$object_name . "\t" . $object_id . "\t" . $phen_hashref->{$key}{stock_id} . 
              "\t" . $phen_hashref->{$key}{stock_name};

	    my $block     = 'NA';
	    my $replicate = 'NA';
	    my $design    = 'NA';
	    my $trial_id  = $self->context->stash->{pop_id};
	    my $design_rs = $self->experimental_design($trial_id);

	    if ($design_rs->next)       
	    {
		$design = $design_rs->first->value();
	    } 
        
	    my $block_rs = $self->search_plotprop($subject_id, 'block');
	    if($block_rs->next)      
	    {
		$block = $block_rs->first->value();
	    } 
        
	    my $replicate_rs = $self->search_plotprop($subject_id, 'replicate');     
	    if($replicate_rs->next)       
	    {
		$replicate = $replicate_rs->first->value();
	    }

	    $d .= "\t". $design . "\t" . $block .  "\t" . $replicate;

	    foreach my $term_name ( sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms ) 
	    {    
		my $val = $phen_hashref->{$key}{$term_name};
		unless (looks_like_number($val)) 
		{ 
		    $val = "NA";		  
		}
		$d .= "\t" . $val;
	    }
	    $d .= "\n";
	}
   
	@project_genotypes = uniq(@project_genotypes);
	$self->context->stash->{project_genotypes} = \@project_genotypes;
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
    no warnings 'uninitialized';

    foreach my $rs (@$phenotypes) 
    {
        $cnt++;
        while ( my $r =  $rs->next )  
        {
             my $observable = $r->get_column('observable');
             next if !$observable;

             if ($cvterm_name eq $observable) { $replicate ++ ; } else { $replicate = 1 ; }
             $cvterm_name = $observable;
             # my $accession = $r->get_column('accession');
             # my $db_name = $r->get_column('db_name');
             my $project = $r->get_column('project_description') ;

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
        my $trial_id  = $self->context->stash->{pop_id};
        my $design_rs = $self->experimental_design($trial_id);

        if($design_rs->next)       
        {
            $design = $design_rs->first->value();
        } 
        
        my $block_rs = $self->search_plotprop($subject_id, 'block');
        if($block_rs->next)
        
        {
            $block = $block_rs->first->value();
        } 
        
        my $replicate_rs = $self->search_plotprop($subject_id, 'replicate');     
        if($replicate_rs->next)       
        {
            $replicate = $replicate_rs->first->value();
        }

        $d .= "\t". $design . "\t" . $block .  "\t" . $replicate;

        foreach my $term_name ( sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms ) 
        { 
	    	my $val = $phen_hashref->{$key}{$term_name};
	
		unless (looks_like_number($val)) 
		{ 
		    $val = "NA";
		}
		$d .= "\t" . $val;
            $d .= "\t" . $phen_hashref->{$key}{$term_name};
        }

        $d .= "\n";
    }
   
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


sub get_genotyping_markers {
    my ($self, $pr_id) = @_;

    my $stock_genotype_rs = $self->project_genotype_data_rs($pr_id);   
    my $markers           = $self->extract_project_markers($stock_genotype_rs->first);
   
    return $markers;
}



__PACKAGE__->meta->make_immutable;



#####
1;
#####

