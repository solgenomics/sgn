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
use Bio::Chado::Schema;
use Bio::Chado::NaturalDiversity::Reports;
use File::Path qw / mkpath /;
use File::Spec::Functions;
use List::MoreUtils qw / uniq /;
use JSON::Any;
use Math::Round::Var;

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
        ->search({'me.observable_id' =>  $trait_id})
        ->search_related('nd_experiment_phenotypes')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock');

    my $pr_rs = $self->stock_projects_rs($rs);

    $pr_rs = $pr_rs->search(
        {},                                
        { 
            page     => $page,
            rows     => 10,
            order_by => 'name',
        }
        ); 

    return $pr_rs; 

}
 

sub project_year {
    my ($self, $pr_id) =  @_;
    
    return $self->schema->resultset("Project::Projectprop")
        ->search(
        {
            'me.project_id' => $pr_id
        }
        );
}


sub project_location {
    my ($self, $pr_id) = @_;

    return $self->schema->resultset("NaturalDiversity::NdExperimentProject")
        ->search({'me.project_id' => $pr_id})
        ->search_related('nd_experiment')
        ->search_related('nd_geolocation');

}


sub all_projects {
    my ($self, $page, $rows) = @_;

    $rows =  10 if !$rows;
    $page = 1 if !$page;
    
    my $projects_rs =  $self->schema->resultset("Project::Project")
        ->search({}, 
                 { 
                     distinct => 1,
                     page     => $page,
                     rows     => $rows,
                     order_by => 'name'              
                 },                      
                 
        );

    return $projects_rs;
}


sub project_details {
    my ($self, $pr_id) = @_;
    
    return $self->schema->resultset("Project::Project")
        ->search( {'me.project_id' => $pr_id});
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
        ->single
        ->type_id;

    return $self->schema->resultset('Cv::Cvterm')
        ->search({cvterm_id => $type_id})
        ->single
        ->name;
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


sub genotype_data {
    my ($self, $project_id) = @_;
    
    if ($project_id) 
    {
        my $stock_subj_rs = $self->project_subject_stocks_rs($project_id);
        my $stock_obj_rs  = $self->stocks_object_rs($stock_subj_rs);
      
        my $stock_genotype_rs = $self->stock_genotypes_rs($stock_obj_rs);
   
        my $markers   = $self->extract_project_markers($stock_genotype_rs);
        my $geno_data = "\t" . $markers . "\n";
    
        my $markers_no = scalar(split(/\t/, $markers));

        my @stocks = ();
        my $cnt_clones_diff_markers;
        while (my $geno = $stock_genotype_rs->next)
        {
            my $stock = $geno->get_column('stock_name');
            $stock =~s/[\(\)]/-/g;

            unless (grep(/^$stock$/, @stocks)) 
            {
                my $geno_values = $self->stock_genotype_values($geno);
                my $geno_values_no = scalar(split(/\t/, $geno_values));
               
                if($geno_values_no - 1 == $markers_no )
                {
                    $geno_data .=  $geno_values;
                    push @stocks, $stock;
                }
                else 
                {
                    $cnt_clones_diff_markers++;                                     
                }
               
            }  
        }

     return  $geno_data; 
        
        print STDERR "\n$cnt_clones_diff_markers clones were  genotyped using a 
                        different GBS markers than the ones on the header. 
                        They are excluded from the training set.\n\n";
    } 
     
   

}


sub search_stock {
    my ($self, $stock_name) = @_;
  
    my $rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.name' =>  $stock_name});
   
    return $rs; 

}


sub search_stock_using_plot_name {
    my ($self, $plot_name) = @_;
  
    my $rs = $self->schema->resultset("Stock::Stock")
        ->search({'me.uniquename' =>  $plot_name});
         
    return $rs; 

}


sub format_user_list_genotype_data {
    my $self = shift;

    my @genotypes = ();

    my $population_type = $self->context->stash->{population_type};
    
    if($population_type =~ /reference/) 
        
    {
       my  @plots_names = @{ $self->context->stash->{reference_population_plot_names} };
         
        foreach my $plot_name (@plots_names)
        {
            my $stock_plot_rs = $self->search_stock_using_plot_name($plot_name);
            my $stock_id = $stock_plot_rs->single->stock_id;
            my $stock_obj_rs = $self->map_subject_to_object($stock_id);
            my $genotype_name = $stock_obj_rs->single->name;
            push @genotypes, $genotype_name;
        }
    }
    else
    {
        @genotypes = @{ $self->context->stash->{selection_genotypes_list_stocks_names} };
    }    
              
    @genotypes = uniq(@genotypes);

    my $geno_data;
    my $header_markers;

    foreach my $genotype (@genotypes) 
    { 
        my $stock_rs = $self->search_stock($genotype);     
        my $stock_genotype_rs = $self->individual_stock_genotypes_rs($stock_rs);
       
        unless ($header_markers) 
        {
            if($stock_genotype_rs->single)
            {
                $header_markers   = $self->extract_project_markers($stock_genotype_rs);                
                $geno_data = "\t" . $header_markers . "\n";
            }
        }

        my @header_markers = split(/\t/, $header_markers);
           
        while (my $geno = $stock_genotype_rs->next)
        {  
            my $json_values  = $geno->value;
            my $values       = JSON::Any->decode($json_values);
            my @markers      = keys %$values;

            if (@header_markers && @markers ~~ @header_markers)
                
            { 
                my $geno_values = $self->stock_genotype_values($geno);               
                $geno_data .= $geno_values;
            }       
        }       
    }

    if($population_type =~ /reference/) 
    {
        $self->context->stash->{user_reference_list_genotype_data} = $geno_data;
    }
    else
    {
        $self->context->stash->{user_selection_list_genotype_data} = $geno_data;   
    }

}


sub individual_stock_genotypes_rs {
    my ($self, $stock_rs) = @_;
    
    my $genotype_rs = $stock_rs
        ->search_related('nd_experiment_stocks')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_genotypes')
        ->search_related('genotype')
        ->search_related('genotypeprops',
                         {},
                         { 
                             '+select' => [ qw /  me.stock_id me.name / ], 
                             '+as'     => [ qw / stock_id stock_name / ] 
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
        ->search_related('genotypeprops',
                         {},
                         { 
                             '+select' => [ qw / me.project_id me.name object.stock_id object.name / ], 
                             '+as'     => [ qw / project_id project_name stock_id stock_name / ] 
                         }
        );

    return $genotype_rs;

}


sub extract_project_markers {
    my ($self, $genopropvalue_rs) = @_;
   
    my $row = $genopropvalue_rs->single;
    my $markers;

    if (defined $row)    
    {
        my $genotype_json = $row->value;
        my $genotype_hash = JSON::Any->decode($genotype_json);

        my @markers = keys %$genotype_hash;
   
        foreach my $marker (@markers) 
        {
            $markers .= $marker;
            $markers .= "\t" unless $marker eq $markers[-1];
        }
    }
    
    return $markers;  
}


sub stock_genotype_values {
    my ($self, $geno_row) = @_;
              
    my $json_values  = $geno_row->value;
    my $values       = JSON::Any->decode($json_values);
    my @markers      = keys %$values;
   
    my $stock_name = $geno_row->get_column('stock_name');
    my $size = scalar(@markers);
   
    my $round =  Math::Round::Var->new(0);
        
    my $geno_values;
              
        $geno_values .= $geno_row->get_column('stock_name') . "\t";
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
 
  if ($training_pop_id) 
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
 
  my @sample_pred_projects;
  my $cnt = 0;
 
  my $projects_rs = $self->all_projects(1, 40);

  while (my $row = $projects_rs->next) 
  {
     
      my $project_id = $row->id; 
       
      if ($project_id && $training_pop_id != $project_id) 
      {
          my $stock_subj_rs = $self->project_subject_stocks_rs($project_id);
          my $stock_obj_rs  = $self->stocks_object_rs($stock_subj_rs);
      
          my $stock_genotype_rs = $self->stock_genotypes_rs($stock_obj_rs);
        
          if ($stock_genotype_rs)
          {
              my $markers   = $self->extract_project_markers($stock_genotype_rs);

              if ($markers) 
              {
                 my @pred_pop_markers = split(/\t/, $markers);
           
                 print STDERR "\ncheck if prediction populations are genotyped using the same set of markers as for the training population : " . scalar(@pred_pop_markers) .  ' vs ' . scalar(@tr_pop_markers) . "\n";

                 if (@pred_pop_markers ~~ @tr_pop_markers) 
                 {
                  
                     $cnt++;
                     push @sample_pred_projects, $project_id; 
       
                 }
             }
          }
      }
       
          last if $cnt == 3;
  }

  return \@sample_pred_projects;
  
}



sub format_user_reference_list_phenotype_data {
    my $self = shift;

    my @plots_names  = ();
    my $population_type = $self->context->stash->{population_type};
    
    if($population_type =~ /reference/) 
        
    {
        @plots_names = @{ $self->context->stash->{reference_population_plot_names} };
    }

    my $results = [];
    my $data;
    
    foreach my $plot_name (@plots_names) {
        my $stock_rs = $self->search_stock_using_plot_name($plot_name);
        my $stock_pheno_data_rs = $self->stock_phenotype_data_rs($stock_rs);
        push @$results, $stock_pheno_data_rs;
    }

    $data     = $self->phenotypes_by_trait($results);
    
    $self->context->stash->{user_reference_list_phenotype_data} = $data;     


}


sub phenotype_data {
     my ($self, $pop_id ) = @_; 
    
     my $data;
     if ($pop_id) 
     {
         my $results  = [];   
         my $stock_rs = $self->project_subject_stocks_rs($pop_id);
 
         while (my $st = $stock_rs->next) 
         {
                 my $plot = $st->get_column('uniquename');
              
                 my $stock_plot_rs = $self->search_stock_using_plot_name($plot);
                 my $stock_pheno_data_rs = $self->stock_phenotype_data_rs($stock_plot_rs);
                 push @$results, $stock_pheno_data_rs;
             
         }

         $data     = $self->phenotypes_by_trait($results);
         
         return  $data;               
    }
}




sub stock_phenotype_data_rs {
    my $self = shift;
    my $stock = shift;
    my $stock_id = $stock->single->stock_id;
   
    my $rs = $stock->result_source->schema->resultset("Stock::Stock")->search_rs(
        {
            'observable.name' => { '!=', undef } ,
            'me.stock_id'     => $stock_id,
        } , {
            join => [
                { nd_experiment_stocks => {
                    nd_experiment => {
                        nd_experiment_phenotypes => {
                            phenotype  => {
                                observable        => { dbxref   => 'db' },
                                phenotypeprops    => 'type',
                                phenotype_cvterms => { cvterm =>  'cv' }
                            },
                        },
                        nd_experiment_projects => 'project',
                    },
                  }
                } ,
                ],
            select    => [ qw/  me.stock_id me.uniquename phenotype.value observable.name observable.cvterm_id observable.definition phenotypeprops.value type.name dbxref.accession db.name  project.description  cv.name cvterm.name   / ],
            as        => [ qw/ stock_id uniquename value observable observable_id definition method_name type_name  accession db_name project_description cv_name unit_name / ],
            distinct  => 1,
            order_by  => [ 'project.description' , 'observable.name' ],
        }  );
   
    return $rs;
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
             my $accession = $r->get_column('accession');
             my $db_name = $r->get_column('db_name');
             my $project = $r->get_column('project_description') ;

            # my $hash_key = $project . "|" . $replicate;
            # if($c->{stash}->{population_type} =~ /reference/) {$hash_key =$project . "|" . $r->get_column('uniquename');}
            
             my $hash_key = $project . "|" . $r->get_column('uniquename');
            
             $phen_hashref->{$hash_key}{accession} = $db_name . ":" . $accession ;
             $phen_hashref->{$hash_key}{$observable} = $r->get_column('value');
             $phen_hashref->{$hash_key}{stock_id} = $r->get_column('stock_id');
             $phen_hashref->{$hash_key}{stock_name} = $r->get_column('uniquename');
             $cvterms{$observable} =  $db_name . ":" . $accession ;
             
        }
    }

    my @data;
    my $d = "uniquename\tobject_name\tobject_id\tstock_id\tstock_name";
    foreach my $term_name (sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms )  
    {# sort ontology terms
        my $ontology_id = $cvterms{$term_name};
        $d .=  "\t" . $ontology_id . "|" . $term_name;
    }
    $d .= "\n";

    foreach my $key ( sort keys %$phen_hashref ) 
    {        
        #print the unique key (row header)
        # print some more columns with metadata
        # print the value by cvterm name

        my $subject_id       = $phen_hashref->{$key}{stock_id};
        my $stock_object_row = $self->map_subject_to_object($subject_id)->single;       
        my $object_name      = $stock_object_row->name;
        my $object_id        = $stock_object_row->stock_id;
              
        $d .= $key . "\t" .$object_name . "\t" . $object_id . "\t" . $phen_hashref->{$key}{stock_id} . 
              "\t" . $phen_hashref->{$key}{stock_name};
        
        foreach my $term_name ( sort { $cvterms{$a} cmp $cvterms{$b} } keys %cvterms ) 
        {           
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
                         {
                             order_by => {-desc => [qw /me.name/ ]} 
                         }
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





__PACKAGE__->meta->make_immutable;



#####
1;
#####

