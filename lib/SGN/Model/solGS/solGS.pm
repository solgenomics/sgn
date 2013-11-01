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




sub search_trait {
    my ($self, $c, $trait) = @_;
    
    my $rs;
    if ($trait)
    {       
        $rs = $self->schema($c)->resultset("Phenotype::Phenotype")
            ->search({})
            ->search_related('observable', 
                             {
                                 'observable.name' => {'iLIKE' => '%' . $trait . '%'}
                             },
                             {
                                 columns => [ qw/ cvterm_id name definition / ] 
                             },    
                             { 
                                 distinct => 1,
                                 page     => $c->req->param('page') || 1,
                                 rows     => 10,
                                 order_by => 'name'              
                             },                                                        
            );             
    }

    return $rs;      
}


sub all_gs_traits {
    my ($self, $c) = @_;

    my $rs = $self->schema($c)->resultset("Phenotype::Phenotype")
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
    my ($self, $c, $trait_id) = @_;
  
    my $rs = $self->schema($c)->resultset("Phenotype::Phenotype")
        ->search({'me.observable_id' =>  $trait_id})
        ->search_related('nd_experiment_phenotypes')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock');

    my $pr_rs = $c->controller('solGS::solgsStock')->stock_projects_rs($rs);

    $pr_rs = $pr_rs->search(
        {},                                
        { 
            page     => $c->req->param('page') || 1,
            rows     => 10,
            order_by => 'name',
        }
        ); 

    return $pr_rs; 

}
 

sub project_year {
    my ($self, $c, $pr_id) =  @_;
    
    return $self->schema($c)->resultset("Project::Projectprop")
        ->search(
        {
            'me.project_id' => $pr_id
        }
        );
}


sub project_location {
    my ($self, $c, $pr_id) = @_;

    return $self->schema($c)->resultset("NaturalDiversity::NdExperimentProject")
        ->search({'me.project_id' => $pr_id})
        ->search_related('nd_experiment')
        ->search_related('nd_geolocation');

}


sub all_projects {
    my ($self, $c) = @_;

    my $rows = $c->stash->{get_selection_populations} ? 40 : 10;

    my $projects_rs =  $self->schema($c)->resultset("Project::Project")
        ->search({}, 
                 { 
                     distinct => 1,
                     page     => $c->req->param('page') || 1,
                     rows     => $rows,
                     order_by => 'name'              
                 },                       
        );

    return $projects_rs;
}


sub project_details {
    my ($self, $c, $pr_id) = @_;
    
    return $self->schema($c)->resultset("Project::Project")
        ->search( {'me.project_id' => $pr_id});
}

sub get_population_details {
    my ($self, $c, $pop_id) = @_;
   
    return $self->schema($c)->resultset("Stock::Stock")
        ->search(
        {
            'stock_id' => $pop_id
        }, 
        );
}


sub trait_name {
    my ($self, $c, $trait_id) = @_;

    my $trait_name = $self->schema($c)->resultset('Cv::Cvterm')
        ->search( {cvterm_id => $trait_id})
        ->single
        ->name;

    return $trait_name;

}


sub get_trait_id {
    my ($self, $c, $trait) = @_;

    if ($trait) 
    {
        my $trait_id = $self->schema($c)->resultset('Cv::Cvterm')
            ->search( {name => $trait})
            ->single
            ->id;
        return $trait_id;
    }
}


sub check_stock_type {
    my ($self, $c, $stock_id) = @_;

    my $type_id = $self->schema($c)->resultset("Stock::Stock")
        ->search({'stock_id' => $stock_id})
        ->single
        ->type_id;

    return $self->schema($c)->resultset('Cv::Cvterm')
        ->search({cvterm_id => $type_id})
        ->single
        ->name;
}


sub phenotype_data {
     my ($self, $c, $pop_id ) = @_; 
    
     if ($pop_id) 
     {
         my $results  = [];   
         my $stock_rs = $c->controller('solGS::solgsStock')->project_subject_stocks_rs($pop_id);
         $results     = $self->schema($c)->resultset("Stock::Stock")->recursive_phenotypes_rs($stock_rs, $results);
         my $data     = $self->phenotypes_by_trait($c, $results);
      
         $c->stash->{phenotype_data} = $data;               
    }
}


sub genotype_data {
    my ($self, $c, $project_id) = @_;
    
    if ($project_id) 
    {
        my $stock_subj_rs = $c->controller('solGS::solgsStock')->project_subject_stocks_rs($project_id);
        my $stock_obj_rs  = $c->controller('solGS::solgsStock')->stocks_object_rs($stock_subj_rs);
      
        my $stock_genotype_rs = $self->stock_genotypes_rs($c, $stock_obj_rs);
   
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

        $c->stash->{genotype_data} = $geno_data; 
        
        print STDERR "\n$cnt_clones_diff_markers clones were  genotyped using a 
                        different GBS markers than the ones on the header. 
                        They are excluded from the training set.\n\n";
    } 
     
   

}


sub stock_genotypes_rs {
    my ($self, $c, $stock_rs) = @_;
    
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

    my $genotype_json = $row->value;
    my $genotype_hash = JSON::Any->decode($genotype_json);

    my $markers;
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
       
    my $geno_values .= $geno_row->get_column('stock_name') . "\t";    
    my $json_values  = $geno_row->value;
    my $values       = JSON::Any->decode($json_values);
    my @markers      = keys %$values;
       
    my $round =  Math::Round::Var->new(0);
    
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
  my ($self, $c, $training_pop_id) = @_;
 
  my @tr_pop_markers;
  
  $c->stash->{get_selection_populations} = 1;
 
  if ($training_pop_id) 
  {
      my $dir = $c->stash->{solgs_cache_dir};
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
 
  my $projects_rs = $self->all_projects($c);

  while (my $row = $projects_rs->next) 
  {
     
      my $project_id = $row->id; 
       
      if ($project_id && $training_pop_id != $project_id) 
      {
          my $stock_subj_rs = $c->controller('solGS::solgsStock')->project_subject_stocks_rs($project_id);
          my $stock_obj_rs  = $c->controller('solGS::solgsStock')->stocks_object_rs($stock_subj_rs);
      
          my $stock_genotype_rs = $self->stock_genotypes_rs($c, $stock_obj_rs);
        
          if($stock_genotype_rs)
          {
              my $markers   = $self->extract_project_markers($stock_genotype_rs);

              my @pred_pop_markers = split(/\t/, $markers);
           
              print STDERR "\ncheck if prediction populations are genotyped using the same set of markers as for the training population : " . scalar(@pred_pop_markers) .  ' vs ' . scalar(@tr_pop_markers) . "\n";

              if (@pred_pop_markers ~~ @tr_pop_markers) 
              {
                  
                  $cnt++;
                  push @sample_pred_projects, $project_id; 
       
              }
          }
      }
       
          last if $cnt == 3;
  }

  return \@sample_pred_projects;
  
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
    my $c    = shift;
    my $phenotypes = shift;
    
    my $phen_hashref; #hashref of hashes for the phenotype data

    my %cvterms ; #hash for unique cvterms
    my $replicate = 1;
    my $cvterm_name;
 
    no warnings 'uninitialized';

    foreach my $rs (@$phenotypes) 
    {
        while ( my $r =  $rs->next )  
        {
            my $observable = $r->get_column('observable');
            next if !$observable;
           
            if ($cvterm_name eq $observable) { $replicate ++ ; } else { $replicate = 1 ; }
            $cvterm_name = $observable;
            my $accession = $r->get_column('accession');
            my $db_name = $r->get_column('db_name');
            my $project = $r->get_column('project_description') ;

            my $hash_key = $project . "|" . $replicate;
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
        my $stock_object_row = $c->controller('solGS::solgsStock')->map_subject_to_object($c, $subject_id)->single;       
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


sub schema {
    my ($self, $c) = @_;
    return  $c->dbic_schema("Bio::Chado::Schema");
} 



__PACKAGE__->meta->make_immutable;



#####
1;
#####
