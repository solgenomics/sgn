package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Array::Utils qw(:all);
use CXGN::Tools::Run;
use JSON;


BEGIN { extends 'Catalyst::Controller' }



sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;
   
    my $ids = $c->req->param('trials');
    my  @pop_ids = split(/,/, $ids);

    my $combo_pops_id;
    my $ret->{status} = 0;

    my $solgs_controller = $c->controller('solGS::solGS');
    my $not_matching_pops;
    my @g_files;
    
    if (scalar(@pop_ids) > 1 )
    {  
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
      
        $solgs_controller->multi_pops_phenotype_data($c, \@pop_ids);
        $solgs_controller->multi_pops_genotype_data($c, \@pop_ids);

        $solgs_controller->multi_pops_pheno_files($c, \@pop_ids);
        my $all_pheno_files = $c->stash->{multi_pops_pheno_files};
        
        my @all_pheno_files = split(/\t/, $all_pheno_files);
        $self->find_common_traits($c, \@all_pheno_files);
        
        my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $solgs_controller->catalogue_combined_pops($c, $entry);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        @g_files = split(/\t/, $geno_files);

        $solgs_controller->compare_genotyping_platforms($c, \@g_files);
        $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {
            $self->save_common_traits_acronyms($c);
        }
        else 
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }

        $ret->{combined_pops_id} = $combo_pops_id;
    }
    else 
    {
        my $pop_id = $pop_ids[0];
        
        $c->stash->{pop_id} = $pop_id;
        $solgs_controller->phenotype_file($c);
        $solgs_controller->genotype_file($c);
        
        $ret->{redirect_url} = "/solgs/population/$pop_id";
    }
      
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub combined_trials_page :Path('/solgs/populations/combined') Args(1) {
    my ($self, $c, $combo_pops_id) = @_;

    $c->stash->{combo_pops_id} = $combo_pops_id;
    $self->combined_trials_desc($c);

    my $solgs_controller = $c->controller('solGS::solGS');
    $c->stash->{template} = $solgs_controller->template('/population/combined/combined.mas');
    
    $c->stash->{pop_id} = $combo_pops_id;
    
    $solgs_controller->all_traits_file($c);
    $solgs_controller->select_traits($c);
    $solgs_controller->get_acronym_pairs($c);

}


sub model_combined_trials_trait :Path('/solgs/model/combined/trials') Args(3) {
    my ($self, $c, $combo_pops_id, $trait_txt, $trait_id) = @_;

    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{trait_id}      = $trait_id;
 
    $self->build_model_combined_trials_trait($c);
    
    $c->controller('solGS::solGS')->gebv_kinship_file($c);
    
    my $gebv_file = $c->stash->{gebv_kinship_file};

    if ( -s $gebv_file ) 
    {
        $c->res->redirect("/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id");
        $c->detach();
    }           

}


sub models_combined_trials :Path('/solgs/models/combined/trials') Args(1) {
    my ($self, $c, $combo_pops_id) = @_;
  
    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{model_id} = $combo_pops_id;
    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{data_set_type} = 'combined populations';
    
    my @traits_ids = $c->req->param('trait_id');
    my @traits_pages;
  
    my $solgs_controller = $c->controller('solGS::solGS');

    if (!@traits_ids) {
    
        $solgs_controller->analyzed_traits($c);
	my @analyzed_traits  = @{ $c->stash->{analyzed_traits} };

	foreach my $tr (@analyzed_traits)
	{	 
	    my $acronym_pairs = $solgs_controller->get_acronym_pairs($c);
	    my $trait_name;
	    if ($acronym_pairs)
	    {
		foreach my $r (@$acronym_pairs) 
		{
		    if ($r->[0] eq $tr) 
		    {
			$trait_name = $r->[1];
			$trait_name =~ s/\n//g;
			$c->stash->{trait_name} = $trait_name;
			$c->stash->{trait_abbr} = $r->[0];   
		    }
		}
	    }
         
	    my $trait_id   = $c->model('solGS::solGS')->get_trait_id($trait_name);
	    my $trait_abbr = $c->stash->{trait_abbr}; 

	    $solgs_controller->get_model_accuracy_value($c, $combo_pops_id, $trait_abbr);
	    my $accuracy_value = $c->stash->{accuracy_value};
	
	    $c->controller("solGS::Heritability")->get_heritability($c);
	    my $heritability = $c->stash->{heritability};
	    
	    push @traits_pages, 
	    [ qq | <a href="/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id" onclick="solGS.waitPage()">$trait_abbr</a>|, $accuracy_value, $heritability];
	}
    }  
    elsif (scalar(@traits_ids) == 1) 
    {
        my $trait_id = $traits_ids[0];
        $c->res->redirect("/solgs/model/combined/trials/$combo_pops_id/trait/$trait_id");
        $c->detach();
    }
    elsif (scalar(@traits_ids) > 1) 
    {
        foreach my $trait_id (@traits_ids) 
        {
            $c->stash->{trait_id} = $trait_id;
            $solgs_controller->get_trait_name($c, $trait_id);
            my $tr_abbr = $c->stash->{trait_abbr};

            $self->build_model_combined_trials_trait($c);
          
            $solgs_controller->get_model_accuracy_value($c, $combo_pops_id, $tr_abbr);
            my $accuracy_value = $c->stash->{accuracy_value};
     
	    $c->controller("solGS::Heritability")->get_heritability($c);
	    my $heritability = $c->stash->{heritability};

            push @traits_pages, 
            [ qq | <a href="/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id" onclick="solGS.waitPage()">$tr_abbr</a>|, $accuracy_value, $heritability];
	    
        }
    }  
    
    $solgs_controller->list_of_prediction_pops($c, $combo_pops_id);

    $solgs_controller->analyzed_traits($c);
    my $analyzed_traits = $c->stash->{analyzed_traits};
   
    $c->stash->{trait_pages}  = \@traits_pages;
    $c->stash->{template}     = $solgs_controller->template('/population/combined/multiple_traits_output.mas');
       
    $self->combined_trials_desc($c);
        
    my $project_name = $c->stash->{project_name};
    my $project_desc = $c->stash->{project_desc};
        
    my @model_desc = ([qq | <a href="/solgs/populations/combined/$combo_pops_id">$project_name</a> |, $project_desc, \@traits_pages]);
    $c->stash->{model_data} = \@model_desc;
    $c->stash->{pop_id} = $combo_pops_id;
    $solgs_controller->get_acronym_pairs($c);  

}


sub build_model_combined_trials_trait {
    my ($self, $c) = @_;
  
    my $solgs_controller = $c->controller('solGS::solGS');
    $c->stash->{data_set_type} = 'combined populations';
    
    $solgs_controller->gebv_kinship_file($c);
    my $gebv_file = $c->stash->{gebv_kinship_file};

    unless  ( -s $gebv_file ) 
    {
    
        $self->combine_trait_data($c);
    
        my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
        my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
        
        if (-s $combined_pops_pheno_file  && -s $combined_pops_geno_file ) 
        { 
            $c->controller('solGS::solGS')->get_rrblup_output($c); 
        }
    }
}


sub combine_trait_data {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
   
    my $solgs_controller = $c->controller('solGS::solGS');

    $solgs_controller->get_trait_name($c, $trait_id);

    $solgs_controller->get_combined_pops_list($c, $combo_pops_id);
    my $pops_list = $c->stash->{combined_pops_list};
    $c->stash->{trait_combo_pops} = $pops_list; 
   
    my @pops_list = split(/,/, $pops_list);
    $c->stash->{trait_combine_populations} = \@pops_list;

    $solgs_controller->multi_pops_phenotype_data($c, \@pops_list);
    $solgs_controller->multi_pops_genotype_data($c, \@pops_list);

    $solgs_controller->cache_combined_pops_data($c);

    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
             
    unless (-s $combined_pops_geno_file  && -s $combined_pops_pheno_file ) 
    {
        $solgs_controller->r_combine_populations($c);
    }
                       
}


sub combined_trials_desc {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    
    my $solgs_controller = $c->controller('solGS::solGS');
    $solgs_controller->get_combined_pops_list($c, $combo_pops_id);
    
    my $pops_list = $c->stash->{combined_pops_list};      
    my @pops = split(/,/, $pops_list);
      
    my $desc = 'This training population is a combination of ';
    
    my $projects_owners;
    my $s_pop_id;

    foreach my $pop_id (@pops)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);

        while (my $row = $pr_rs->next)
        {
         
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name </a>|; 
            $desc .= $pop_id == $pops[-1] ? '.' : ' and ';
        } 

        $solgs_controller->get_project_owners($c, $_);
        my $project_owners = $c->stash->{project_owners};

        unless (!$project_owners)
        {
             $projects_owners.= $projects_owners ? ', ' . $project_owners : $project_owners;
        }
         $s_pop_id = $pop_id;
    }
   
    my $dir = $c->{stash}->{solgs_cache_dir};

    my $geno_exp  = "genotype_data_${s_pop_id}\.txt";
    my $geno_file = $solgs_controller->grep_file($dir, $geno_exp);  
   
    my @geno_lines = read_file($geno_file);
    my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

    my $trait_exp        = "traits_acronym_pop_${combo_pops_id}";
    my $traits_list_file = $solgs_controller->grep_file($dir, $trait_exp);  
    
    my @traits_list = read_file($traits_list_file);
    my $traits_no   =  scalar(@traits_list) - 1;

    my $training_pop = "Training population $combo_pops_id";

    $c->stash(markers_no   => $markers_no,
              traits_no    => $traits_no,
              project_desc => $desc,
              project_name => $training_pop,
              owner        => $projects_owners
        );

}


sub find_common_traits {
    my ($self, $c, $all_pheno_files) = @_;
    
    my @common_traits;    
    
    foreach my $pheno_file (@$all_pheno_files)
    {     
        open my $ph, "<", $pheno_file or die "$pheno_file:$!\n";
        my $traits = <$ph>;
        $ph->close;
        
        my @trial_traits = split(/\t/, $traits);
       
        if (@common_traits)        
        {
            @common_traits = intersect(@common_traits, @trial_traits);
        }
        else 
        {    
            @common_traits = @trial_traits;
        }
    }
   
    $c->stash->{common_traits} = \@common_traits;
}


sub save_common_traits_acronyms {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $solgs_controller = $c->controller('solGS::solGS');
    
    $c->stash->{pop_id} = $combo_pops_id;
    
    $self->find_common_traits_acronyms($c);
    my $acronyms_table = $c->stash->{common_traits_acronyms};

    $solgs_controller->traits_acronym_file($c);
    my $traits_acronym_file = $c->stash->{traits_acronym_file};
    write_file($traits_acronym_file, $acronyms_table);

    $solgs_controller->all_traits_file($c);
    my $common_traits_file = $c->stash->{all_traits_file};
    
    $self->create_common_traits_data($c);
    my $common_traits_data = $c->stash->{common_traits_data};
    write_file($common_traits_file, $common_traits_data);
      
}


sub create_common_traits_data {
    my ($self, $c) = @_;   
       
    my $acronym_table = $c->stash->{common_traits_acronyms};  
    my @acronym_pairs =  split (/\n/, $acronym_table);
    shift(@acronym_pairs);

    my $table = 'trait_id' . "\t" . 'trait_name' . "\t" . 'acronym' . "\n";  
    
    for (my $i=0; $i < scalar(@acronym_pairs); $i++)
    {
        my $trait_acronym = $acronym_pairs[$i];
        $trait_acronym =~ s/\n//g;

        my ($acronym, $trait_name) = split (/\t/, $trait_acronym);
        
        my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
        $table .= $trait_id . "\t" . $trait_name . "\t" . $acronym . "\n";
       
    }

    $c->stash->{common_traits_data} = $table;
  
}    


sub find_common_traits_acronyms {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $solgs_controller = $c->controller('solGS::solGS');
    my @common_traits_acronyms;
    
    if ($combo_pops_id)
    {
        $solgs_controller->get_combined_pops_list($c, $combo_pops_id);
        my $pops_list = $c->stash->{combined_pops_list};
      
        my @pops_list = split(/,/, $pops_list);

        foreach my $pop_id (@pops_list)
        {
            $c->stash->{pop_id} = $pop_id;
          
            $solgs_controller->traits_acronym_file($c);
            my $traits_acronym_file = $c->stash->{traits_acronym_file};
            my @traits_acronyms = read_file($traits_acronym_file);

            if (@common_traits_acronyms)        
            {
                @common_traits_acronyms = intersect(@common_traits_acronyms, @traits_acronyms);
            }
            else 
            {    
                @common_traits_acronyms = @traits_acronyms;
            }

        }
        
        $c->stash->{pop_id} = $combo_pops_id;
        my $acronym_table = join("", @common_traits_acronyms);
        $c->stash->{common_traits_acronyms} = $acronym_table;

    }
    else 
    {   
        die "An id for the combined trials is missing.";
    }


}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;
