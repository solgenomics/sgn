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

    my $pr_rs = $self->stock_projects_rs($rs);

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
    my $projects_rs =  $self->schema($c)->resultset("Project::Project")
        ->search({}, 
                 { 
                     distinct => 1,
                     page     => $c->req->param('page') || 1,
                     rows     => 10,
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
         my $stock_rs = $self->project_subject_stocks_rs($c, $pop_id);
         $results     = $self->schema($c)->resultset("Stock::Stock")->recursive_phenotypes_rs($stock_rs, $results);
         my $data     = $self->phenotypes_by_trait($c, $results);
      
         $c->stash->{phenotype_data} = $data;               
    }
}


sub genotype_data {
    my ($self, $c, $project_id) = @_;
    
    if ($project_id) 
    {
        my $stock_subj_rs = $self->project_subject_stocks_rs($c, $project_id);
        my $stock_obj_rs  = $self->stocks_object_rs($c, $stock_subj_rs);
      
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
                my $geno_values = $self->stock_genotype_values($c, $geno);
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


sub search_stock {
    my ($self, $c, $stock_name) = @_;
  
    my $rs = $self->schema($c)->resultset("Stock::Stock")
        ->search({'me.name' =>  $stock_name});
         
    return $rs; 

}


sub format_user_list_genotype_data {
    my ($self, $c) = @_;

    my @stocks_names = ();
    my $population_type = $c->stash->{population_type};
    
    if($population_type =~ /reference/) 
    {
        @stocks_names = @{ $c->stash->{reference_genotypes_list_stocks_names} };
    }
    else
    {
        @stocks_names = @{ $c->stash->{selection_genotypes_list_stocks_names} };
    }    
    
    my $cnt1 = 0;
    my $cnt2=0;
    my $cnt3 = 0;
    my $header_markers;
    my $geno_data;
    my @sts = ();

my @prototype_stocks = ('CB-10(80411)','I95D069','MM961751','MM961871','MM964496','MM965280','MM96JW1','O8400275','O8800695','O8900003','TMS-B9100455','TMS-I30001','TMS-I30040','TMS-I30211','TMS-I30555','TMS-I30555P3-2','TMS-I30572','TMS-I40764','TMS-I42025','TMS-I4(2)1425','TMS-I60142','TMS-I60506','TMS-I63397','TMS-I71673','TMS-I8101635','TMS-I8200058','TMS-I8400353','TMS-I84537','TMS-I8500680','TMS-I8700052','TMS-I8802090','TMS-I8802343','TMS-I8900250','TMS-I8900963','TMS-I8902195','TMS-I9001554','TMS-I9100416','TMS-I9100420','TMS-I9100459','TMS-I9101730','TMS-I9102312','TMS-I9102322','TMS-I9102324','TMS-I9102325','TMS-I91934','TMS-I920057','TMS-I920067','TMS-I920110','TMS-I920325','TMS-I920326','TMS-I920342','TMS-I920397','TMS-I920398','TMS-I920427','TMS-I920429','TMS-I930007','TMS-I930084','TMS-I930098','TMS-I930114','TMS-I930134','TMS-I930184','TMS-I930223','TMS-I930248','TMS-I930265','TMS-I930266','TMS-I930272','TMS-I940006','TMS-I940018','TMS-I940026','TMS-I940039','TMS-I940237','TMS-I940239','TMS-I940263','TMS-I940270','TMS-I940330','TMS-I940459','TMS-I940561','TMS-I950041','TMS-I950058','TMS-I950061','TMS-I950063','TMS-I950104','TMS-I950166','TMS-I950211','TMS-I950248','TMS-I950269','TMS-I950279','TMS-I950289','TMS-I950306','TMS-I950379','TMS-I950528','TMS-I950645','TMS-I950902','TMS-I950925','TMS-I950947','TMS-I950971','TMS-I951038','TMS-I960011','TMS-I960016','TMS-I960023','TMS-I960035','TMS-I960062','TMS-I960102','TMS-I960249','TMS-I960304','TMS-I960409','TMS-I960532','TMS-I960557','TMS-I960565','TMS-I960590','TMS-I960595','TMS-I960596','TMS-I960603','TMS-I960619','TMS-I960860','TMS-I960869','TMS-I960963','TMS-I960986','TMS-I961039','TMS-I961087','TMS-I961165','TMS-I961317','TMS-I961427','TMS-I961431','TMS-I961439','TMS-I961551','TMS-I961556','TMS-I961569','TMS-I961613','TMS-I961630','TMS-I961632','TMS-I961642','TMS-I961708','TMS-I970103','TMS-I970162','TMS-I970211','TMS-I970255','TMS-I970286','TMS-I970296','TMS-I970299','TMS-I970335','TMS-I970425','TMS-I971149','TMS-I971228','TMS-I972205','TMS-I974013','TMS-I974580','TMS-I974763','TMS-I974766','TMS-I974769','TMS-I974779','TMS-I980002','TMS-I980196','TMS-I980378','TMS-I980406','TMS-I980505','TMS-I980510','TMS-I982101','TMS-I982132','TMS-I982226','TMS-I990111','TMS-I990114','TMS-I990119','TMS-I990222','TMS-I990304','TMS-I990411','TMS-I990503','TMS-I990543','TMS-I990554','TMS-I990564','TMS-I990621','TMS-I991579','TMS-I991590','TMS-I991702','TMS-I991734','TMS-I991903','TMS-I992123','TMS-I993073','TMS-I993151','TMS-I996012','TMS-I996016','TMS-I996017','TMS-I996069','TMS-I996076','TMS-I997533','TMS-J920253','TMS-K950286','TMS-K950562','TMS-K950671','TMS-K950725','TMS-M940583','TMS-M980004','TMS-M980028','TMS-M980040','TMS-M980057','TMS-M980068','TMS-M980115','TMS-O8500066','TMS-O8700813','TMS-O920168','TMS-W940102','TMS-Z920250','TMS-Z960058','TMS-Z970002','W4092','W820249','W940009','W940017','W940727','Z930151','Z940033','Z940153','Z940394','Z950415','Z950432','Z950680','Z960012','Z970474');


#     print STDERR "\nformat_user_list_genotype_data size: $size\tcnt: $cnt1\t cnt2: $cnt2\tcnt3: $cnt3\n";
   @stocks_names = @prototype_stocks; 
    foreach my $stock_name (@stocks_names)
    {
        #print STDERR "\nformat_user_list_genotype_data: stock_name: $stock_name\n";
        my $stock_rs = $self->search_stock($c, $stock_name);
        my $stock_genotype_rs = $self->individual_stock_genotypes_rs($stock_rs);
       
       
      #  while ( my $st = $stock_rs->next) {
            
            $cnt1++;
      #      push @sts, $st->id;
      #  }
       # if($cnt == 1)
       # {
        unless ($header_markers) {
            $header_markers   = $self->extract_project_markers($stock_genotype_rs);
           # print STDERR "\nformat_user_list_genotype_data header_markers : $header_markers\n";
            $geno_data = "\t" . $header_markers . "\n";
        }
           
       # }

        my @header_markers = split(/\t/, $header_markers);
           
        while (my $geno = $stock_genotype_rs->next)
        {  $cnt2++; 
           # if ($geno) 
           # {
               
           # print STDERR "\nformat_user_list_genotype_data geno : $geno\n";
            my $json_values  = $geno->value;
            my $values       = JSON::Any->decode($json_values);
            my @markers      = keys %$values;

            if (@header_markers && @markers ~~ @header_markers)
                
            { $cnt3++;
                 my $size1 = scalar(@header_markers); my $size2 = scalar(@markers);
                 print STDERR "\nformat_user_list_genotype_data marker no: count: $cnt3\t $size1 vs $size2 \n";
                 my $size1 = scalar(@prototype_stocks); my $size2 = scalar(@stocks_names);
               
                my $geno_values = $self->stock_genotype_values($c, $geno);               
                $geno_data .= $geno_values;
            }

            if($values) {
               # $cnt2++;
            }
           # }
        }       
    }
    my $size1 = scalar(@prototype_stocks); my $size2 = scalar(@stocks_names);
  print STDERR "\nformat_user_list_genotype_data cnt1: $cnt1\t cnt2: $cnt2\tcnt3: $cnt3\t $size1 vs $size2 \n"; 
   # $cnt1=0;



    if($population_type =~ /reference/) 
    {
        $c->stash->{user_reference_list_genotype_data} = $geno_data;
    }
    else
    {
        $c->stash->{user_selection_list_genotype_data} = $geno_data;   
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

    my $genotype_json = $row->value;
    my $genotype_hash = JSON::Any->decode($genotype_json);
           
    my @markers = keys %$genotype_hash;
    my $markers;
    foreach my $marker (@markers) 
    {
        $markers .= $marker;
        $markers .= "\t" unless $marker eq $markers[-1];
    }
            
  
    return $markers;  
}


sub stock_genotype_values {
    my ($self, $c, $geno_row) = @_;
       
       
    my $json_values  = $geno_row->value;
    my $values       = JSON::Any->decode($json_values);
    my @markers      = keys %$values;
   
    my $stock_name = $geno_row->get_column('stock_name');
    my $size = scalar(@markers);
    print STDERR "\n marker count: $stock_name : $ size\n"; 
 
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
  my ($self, $c, $training_pop_id) = @_;
 
  my @tr_pop_markers;
  
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
          my $stock_subj_rs = $self->project_subject_stocks_rs($c, $project_id);
          my $stock_obj_rs  = $self->stocks_object_rs($c, $stock_subj_rs);
      
          my $stock_genotype_rs = $self->stock_genotypes_rs($stock_obj_rs);
   
          my $markers   = $self->extract_project_markers($stock_genotype_rs);

          my @pred_pop_markers = split(/\t/, $markers);
           
          print STDERR "\ncheck if prediction populations are genotyped using the same set of markers as for the training population : " . scalar(@pred_pop_markers) .  ' vs ' . scalar(@tr_pop_markers) . "\n";

          if (@pred_pop_markers ~~ @tr_pop_markers) 
          {
                  
              $cnt++;
              push @sample_pred_projects, $project_id; 
       
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
        my $stock_object_row = $self->map_subject_to_object($c, $subject_id)->single;       
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
    my ($self, $c, $project_id) = @_;
  
    my $stock_rs =  $self->schema($c)->resultset("Project::Project")
        ->search({'me.project_id' => $project_id})
        ->search_related('nd_experiment_projects')
        ->search_related('nd_experiment')
        ->search_related('nd_experiment_stocks')
        ->search_related('stock')
        ->search_related('stock_relationship_subjects')
        ->search_related('subject', 
                         {},
                         { 
                             '+select' => [ qw /me.project_id me.name/ ], 
                             '+as'     => [ qw /project_id project_name/ ] 
                         },
                         {
                             order_by => {-desc => [qw /me.name/ ]} 
                         }
        );

    return $stock_rs;
}


sub stocks_object_rs {
    my ($self, $c, $stock_subj_rs) = @_;

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
    my ($self, $c, $stock_id) = @_;

    my $stock_obj_rs = $self->schema($c)->resultset("Stock::Stock")
        ->search({'me.stock_id' => $stock_id})
        ->search_related('stock_relationship_subjects')
        ->search_related('object');
         
    return $stock_obj_rs;
}


sub schema {
    my ($self, $c) = @_;
    return  $c->dbic_schema("Bio::Chado::Schema");
} 



__PACKAGE__->meta->make_immutable;



#####
1;
#####

