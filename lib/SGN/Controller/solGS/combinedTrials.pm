package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;


use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
use Cache::File;
use CXGN::Tools::Run;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use JSON;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Try::Tiny;
use String::CRC;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' }


sub get_combined_pops_id :Path('/solgs/get/combined/populations/id') Args() {
    my ($self, $c) = @_;

    my @pops_ids = $c->req->param('trials[]');
   
    my $combo_pops_id;
    my $ret->{status} = 0;

    if (@pops_ids > 1) 
    {
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	my $combo_pops_id = $c->stash->{combo_pops_id};

	my $ids = join(',', @pops_ids);
	my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $c->controller("solGS::solGS")->catalogue_combined_pops($c, $entry);

	$ret->{combo_pops_id} = $combo_pops_id;
	$ret->{status} = 1;
    }

    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;
  
    my @pops_ids = $c->req->param('trials[]');
 
    my $combo_pops_id;
    my $ret->{status} = 0;

    my $solgs_controller = $c->controller('solGS::solGS');
    my $not_matching_pops;
    my @g_files;
    
    if (scalar(@pops_ids) > 1)
    {  
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	my $combo_pops_id = $c->stash->{combo_pops_id};
	
	my $ids = join(',', @pops_ids);
        my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $solgs_controller->catalogue_combined_pops($c, $entry);
	
	$self->prepare_multi_pops_data($c);

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
        my $pop_id = $pops_ids[0];
        
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

    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;
    
    $self->save_common_traits_acronyms($c);

    my $solgs_controller = $c->controller('solGS::solGS');
    
    $solgs_controller->get_all_traits($c);
    #$solgs_controller->select_traits($c);
    $solgs_controller->get_acronym_pairs($c);
  
    $self->combined_trials_desc($c);
  
    $c->stash->{template} = $solgs_controller->template('/population/combined/combined.mas');
    
}


sub model_combined_trials_trait :Path('/solgs/model/combined/trials') Args(3) {
    my ($self, $c, $combo_pops_id, $trait_txt, $trait_id) = @_;

    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{trait_id}      = $trait_id;
    
    $self->combine_trait_data($c); 
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
   
    my @traits_ids = $c->req->param('trait_id[]');
    my $req = $c->req->param('source');
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
            $solgs_controller->get_trait_details($c, $trait_id);
            my $tr_abbr = $c->stash->{trait_abbr};
	    
	    $self->combine_trait_data($c);  
            $self->build_model_combined_trials_trait($c);
         
            $solgs_controller->get_model_accuracy_value($c, $combo_pops_id, $tr_abbr);
            my $accuracy_value = $c->stash->{accuracy_value};
     
	    $c->controller("solGS::Heritability")->get_heritability($c);
	    my $heritability = $c->stash->{heritability};

            push @traits_pages, 
            [ qq | <a href="/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id" onclick="solGS.waitPage()">$tr_abbr</a>|, $accuracy_value, $heritability];
	    
        }
    }  
  
    if ($req =~ /AJAX/) 
    {
	my $ret->{status} = 'success';
        $ret = to_json($ret);
        
        $c->res->content_type('application/json');
        $c->res->body($ret);       	
    } 
    else 
    {
	$solgs_controller->analyzed_traits($c);
	my $analyzed_traits = $c->stash->{analyzed_traits};
	
	$c->stash->{trait_pages} = \@traits_pages;
	$c->stash->{template}    = $solgs_controller->template('/population/combined/multiple_traits_output.mas');
	
	$self->combined_trials_desc($c);
        
	my $project_name = $c->stash->{project_name};
	my $project_desc = $c->stash->{project_desc};
        
	my @model_desc = ([qq | <a href="/solgs/populations/combined/$combo_pops_id">$project_name</a> |, $project_desc, \@traits_pages]);
	$c->stash->{model_data} = \@model_desc;
	$c->stash->{pop_id} = $combo_pops_id;
	$solgs_controller->get_acronym_pairs($c);  
    }
}


sub display_combined_pops_result :Path('/solgs/model/combined/populations/') Args(3){
    my ($self, $c,  $combo_pops_id, $trait_key,  $trait_id,) = @_;

    $c->stash->{data_set_type} = 'combined populations';
    $c->stash->{combo_pops_id} = $combo_pops_id;
    
    my $pops_cvs = $c->req->param('combined_populations');
    my $solgs_controller = $c->controller('solGS::solGS');

    if ($pops_cvs)
    {
	my @pops = split(',', $pops_cvs);
        $c->stash->{trait_combo_pops} = \@pops;
    }
    else
    {
        $self->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{trait_combo_pops} = $c->stash->{combined_pops_list}; 
    }

    $self->combined_pops_summary($c);
   
    $solgs_controller->get_trait_details($c, $trait_id);
    $solgs_controller->trait_phenotype_stat($c);    
    $solgs_controller->validation_file($c);
    $solgs_controller->model_accuracy($c);
    $solgs_controller->gebv_kinship_file($c);
    $solgs_controller->blups_file($c);
    $solgs_controller->download_urls($c);
    $c->controller(solGS::Files)->marker_effects_file($c);
    $solgs_controller->top_markers($c);
    $solgs_controller->model_parameters($c);
    
    $c->stash->{template} = $solgs_controller->template('/model/combined/populations/trait.mas');
}


sub selection_combined_pops_trait :Path('/solgs/selection/') Args(6) {
    my ($self, $c, $selection_pop_id, 
        $model_key, $combined_key, $model_id, 
        $trait_key, $trait_id) = @_;

    $c->stash->{combo_pops_id}        = $model_id;
    $c->stash->{trait_id}             = $trait_id;
    $c->stash->{prediction_pop_id}    = $selection_pop_id;
    $c->stash->{data_set_type}        = 'combined populations';
    $c->stash->{combined_populations} = 1;
        
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);   
  
    if ($selection_pop_id =~ /uploaded/) 
    {
	$c->controller('solGS::solGS')->uploaded_population_summary($c, $selection_pop_id);
	$c->stash->{selection_pop_id} = $c->stash->{project_id};
	$c->stash->{selection_pop_name} = $c->stash->{project_name};
	$c->stash->{selection_pop_desc} = $c->stash->{project_desc};
	$c->stash->{selection_pop_owner} = $c->stash->{owner}; 
    }
    else 
    {
	$c->controller('solGS::solGS')->get_project_details($c, $selection_pop_id); 
	$c->stash->{selection_pop_id} = $c->stash->{project_id};
	$c->stash->{selection_pop_name} = $c->stash->{project_name};
	$c->stash->{selection_pop_desc} = $c->stash->{project_desc};

        $c->controller('solGS::solGS')->get_project_owners($c, $selection_pop_id);       
        $c->stash->{selection_pop_owner} = $c->stash->{project_owners}; 
    }  

    my $mr_cnt_args = {'selection_pop' => 1,  'selection_pop_id' => $selection_pop_id};
    my $sel_pop_mr_cnt = $c->controller('solGS::solGS')->get_markers_count($c, $mr_cnt_args);
    $c->stash->{selection_markers_cnt} = $sel_pop_mr_cnt;

    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;
    $c->stash->{protocol} = $protocol;
    
    my $identifier    = $model_id . '_' . $selection_pop_id;
    $c->controller('solGS::solGS')->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $gebvs_file = $c->stash->{prediction_pop_gebvs_file};

    my @stock_rows = read_file($gebvs_file);
    $c->stash->{selection_stocks_cnt} = scalar(@stock_rows) - 1;
   
    $c->controller('solGS::solGS')->top_blups($c, $gebvs_file);
 
    $c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$model_id/prediction/$selection_pop_id/$trait_id">Download all GEBVs</a>|; 

    $c->stash->{template} = $c->controller('solGS::solGS')->template('/selection/combined/selection_trait.mas');
} 


sub combine_populations :Path('/solgs/combine/populations/trait') Args(1) {
    my ($self, $c, $trait_id) = @_;
   
    my (@pop_ids, $ids);
  
    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param($trait_id);
        @pop_ids = split(/,/, $ids);

        $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    } 
   
    my $combo_pops_id;
    my $ret->{status} = 0;

    if (scalar(@pop_ids) > 1 )
    {  
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
        $c->stash->{trait_combo_pops} = $ids;
    
        $c->stash->{trait_combine_populations} = \@pop_ids;

        $self->multi_pops_phenotype_data($c, \@pop_ids);
        $self->multi_pops_genotype_data($c, \@pop_ids);
	$self->multi_pops_geno_files($c, \@pop_ids);
	$self->multi_pops_pheno_files($c, \@pop_ids);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        my @g_files = split(/\t/, $geno_files);

        $c->controller('solGS::solGS')->compare_genotyping_platforms($c, \@g_files);
        my $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {
            $self->cache_combined_pops_data($c);

            my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
            my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
             
            unless (-s $combined_pops_geno_file  && -s $combined_pops_pheno_file ) 
            {
                $self->r_combine_populations($c);
                
                $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
                $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
            }
                       
            if (-s $combined_pops_pheno_file > 1 && -s $combined_pops_geno_file > 1) 
            {
                my $tr_abbr = $c->stash->{trait_abbr};  
                $c->stash->{data_set_type} = 'combined populations';                
                $c->controller('solGS::solGS')->get_rrblup_output($c); 
                my $analysis_result = $c->stash->{combo_pops_analysis_result};
                  
                $ret->{pop_ids}       = $ids;
                $ret->{combo_pops_id} = $combo_pops_id; 
                $ret->{status}        = $analysis_result;
	  
                my $entry = "\n" . $combo_pops_id . "\t" . $ids;
                $c->controller('solGS::solGS')->catalogue_combined_pops($c, $entry);
              }           
        }
        else 
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }
    }
    else 
    {
        my $pop_id = $pop_ids[0];
        $ret->{redirect_url} = "/solgs/trait/$trait_id/population/$pop_id";
    }
       
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub combine_populations_confrim  :Path('/solgs/combine/populations/trait/confirm') Args(1) {
    my ($self, $c, $trait_id) = @_;
  
    my (@pop_ids, $ids);
   
    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param('confirm_populations');
        @pop_ids = split(/,/, $ids);        
        if (!@pop_ids) {@pop_ids = $ids;}

        $c->stash->{trait_id} = $trait_id;
    } 

    my $pop_links;
    my @selected_pops_details;

    foreach my $pop_id (@pop_ids) 
    {
        my $markers     = $c->model("solGS::solGS")->get_project_genotyping_markers($pop_id);                   
        my @markers     = split(/\t/, $markers);
        my $markers_num = scalar(@markers);
       
        $c->controller('solGS::solGS')->trial_compatibility_table($c, $markers_num);
        my $match_code = $c->stash->{trial_compatibility_code};

        my $pop_rs = $c->model('solGS::solGS')->project_details($pop_id);
       
	$c->controller('solGS::solGS')->get_projects_details($c, $pop_rs);
	#my $pop_details  = $self->get_projects_details($c, $pop_rs);
	my $pop_details  = $c->stash->{projects_details};
        my $pop_name     = $pop_details->{$pop_id}{project_name};
        my $pop_desc     = $pop_details->{$pop_id}{project_desc};
        my $pop_year     = $pop_details->{$pop_id}{project_year};
        my $pop_location = $pop_details->{$pop_id}{project_location};
               
        my $checkbox = qq |<form> <input style="background-color: $match_code;" type="checkbox" checked="checked" name="project" value="$pop_id" /> </form> |;
        
        $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;
    push @selected_pops_details, [$checkbox,  qq|<a href="/solgs/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$pop_name</a>|, 
                               $pop_desc, $pop_location, $pop_year, $match_code
        ];
  
    }
    
    $c->stash->{selected_pops_details} = \@selected_pops_details;    
    $c->stash->{template} = $c->controller('solGS::solGS')->template('/search/result/confirm/populations.mas');

}

sub multi_pops_pheno_files {
    my ($self, $c, $pop_ids) = @_;
 
    my $trait_id = $c->stash->{trait_id};
    my $dir = $c->stash->{solgs_cache_dir};
    my $files;
   
    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids) 
        {
	    my $exp = 'phenotype_data_' . $pop_id . '.txt';
            $files .= catfile($dir, $exp);
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id); 		
        }

        $c->stash->{multi_pops_pheno_files} = $files;

    }
    else 
    {
        my $exp = 'phenotype_data_' . ${pop_ids} . '.txt';
        $files = catfile($dir, $exp);
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_pheno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $c->controller('solGS::solGS')->create_tempfile($temp_dir, $name);
        write_file($tempfile, $files);
    }
 
}


sub multi_pops_geno_files {
    my ($self, $c, $pop_ids) = @_;
 
    my $trait_id = $c->stash->{trait_id};
    my $dir = $c->stash->{solgs_cache_dir};
    my $files;
    
    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids) 
        {
            my $exp = 'genotype_data_' . $pop_id . '.txt';
            $files .= catfile($dir, $exp);        
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);    
        }
        $c->stash->{multi_pops_geno_files} = $files;
    }
    else 
    {
        my $exp = 'genotype_data_' . ${pop_ids} . '.txt';
        $files = catfile($dir, $exp);
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_geno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $c->controller('solGS::solGS')->create_tempfile($temp_dir, $name);
        write_file($tempfile, $files);
    }
    
}


sub multi_pops_phenotype_data {
    my ($self, $c, $pop_ids) = @_;
   
    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)        
        { 
            $c->stash->{pop_id} = $pop_id;
            $c->controller('solGS::solGS')->phenotype_file($c);
	    push @job_ids, $c->stash->{r_job_id};
        }
	
	if (@job_ids)
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_pheno_jobs_ids} = \@job_ids;
	}
    }
    
   
  #  $self->multi_pops_pheno_files($c, $pop_ids);
    
}


sub multi_pops_genotype_data {
    my ($self, $c, $pop_ids) = @_;
   
    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)        
        {
            $c->stash->{pop_id} = $pop_id;
            $c->controller('solGS::solGS')->genotype_file($c);	    
	    push @job_ids, $c->stash->{r_job_id};
        }

	if (@job_ids) 
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_geno_jobs_ids} = \@job_ids;
	}
    }    
#  $self->multi_pops_geno_files($c, $pop_ids);
 
}


sub combined_pops_catalogue_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'combined_pops_catalogue_file',
                      file      => 'combined_pops_catalogue_file',
                      stash_key => 'combined_pops_catalogue_file'
    };

    $c->controller('solGS::solGS')->cache_file($c, $cache_data);

}


sub catalogue_combined_pops {
    my ($self, $c, $entry) = @_;
    
    $self->combined_pops_catalogue_file($c);
    my $file = $c->stash->{combined_pops_catalogue_file};
  
    if (! -s $file) 
    {
        my $header = 'combo_pops_id' . "\t" . 'population_ids';
        write_file($file, ($header, $entry));    
    }
    else 
    {
        $entry =~ s/\n//;
        my @combo = ($entry);
       
        my (@entries) = map{ $_ =~ s/\n// ? $_ : undef } read_file($file);
        my @intersect = intersect(@combo, @entries);
        unless( @intersect ) 
        {
            write_file($file, {append => 1}, "\n" . "$entry");
        }
    }
    
}


sub get_combined_pops_list {
    my ($self, $c, $combined_pops_id) = @_;

    $self->combined_pops_catalogue_file($c);
    my $combo_pops_catalogue_file = $c->stash->{combined_pops_catalogue_file};
    
    my @combos = uniq(read_file($combo_pops_catalogue_file));
    
    foreach my $entry (@combos)
    {
        if ($entry =~ m/$combined_pops_id/)
        {
	    chomp($entry);
            my ($combo_pops_id, $pops)  = split(/\t/, $entry);
	    my @pops_list = split(',', $pops);
	    $c->stash->{combined_pops_list} = \@pops_list;
            $c->stash->{trait_combo_pops} = \@pops_list;
        }   
    }     

}


sub combined_pops_summary {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
 
    $self->get_combined_pops_list($c, $combo_pops_id);
    my @pops_ids = @{$c->stash->{trait_combo_pops}};
  
    my $desc = 'This training population is a combination of ';    
    my $projects_owners;

    foreach my $pop_id (@pops_ids)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);

        while (my $row = $pr_rs->next)
        {        
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name </a>|; 
            $desc .= $pop_id == $pops_ids[-1] ? '.' : ' and ';
        } 

        $c->controller('solGS::solGS')->get_project_owners($c, $_);
        my $project_owners = $c->stash->{project_owners};

        unless (!$project_owners)
        {
             $projects_owners.= $projects_owners ? ', ' . $project_owners : $project_owners;
        }
    }
   
    my $trait_abbr = $c->stash->{trait_abbr};
    my $trait_id   = $c->stash->{trait_id};
  
    $c->controller('solGS::Files')->filtered_training_genotype_file($c);
    my $filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

    $self->cache_combined_pops_data($c);
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
    my @unfiltered_geno_rows = read_file($combined_pops_geno_file);
 
    my $markers_no;
    my @geno_lines;

    if (-s $filtered_geno_file) {
	my @rows = read_file($filtered_geno_file);
	$markers_no = scalar(split('\t', $rows[0])) - 1;
    } 
    else 
    {
	$markers_no = scalar(split ('\t', $unfiltered_geno_rows[0])) - 1;	
    }

    my $stocks_no   =  scalar(@unfiltered_geno_rows) - 1;
    my $training_pop = "Training population $combo_pops_id";
    
    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;

    $c->stash(
	markers_no   => $markers_no,
	stocks_no    => $stocks_no,
	project_desc => $desc,
	project_name => $training_pop,
	owner        => $projects_owners,
	protocol     => $protocol,
        );

}


sub cache_combined_pops_data {
    my ($self, $c) = @_;

    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $combo_pops_id = $c->stash->{combo_pops_id};

    my  $cache_pheno_data = {key       => "phenotype_data_${trait_id}_${combo_pops_id}_combined",
                             file      => "phenotype_data_${combo_pops_id}_${trait_abbr}_combined",
                             stash_key => 'trait_combined_pheno_file'
    };
      
    my  $cache_geno_data = {key       => "genotype_data_${trait_id}_${combo_pops_id}_combined",
                            file      => "genotype_data_${combo_pops_id}_${trait_abbr}_combined",
                            stash_key => 'trait_combined_geno_file'
    };
    
    $c->controller('solGS::solGS')->cache_file($c, $cache_pheno_data);
    $c->controller('solGS::solGS')->cache_file($c, $cache_geno_data);

}


sub build_model_combined_trials_trait {
    my ($self, $c) = @_;
  
    my $solgs_controller = $c->controller('solGS::solGS');
    $c->stash->{data_set_type} = 'combined populations';
  
    $solgs_controller->gebv_kinship_file($c);
    my $gebv_file = $c->stash->{gebv_kinship_file};

    unless  ( -s $gebv_file ) 
    {   
        my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
        my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
        	 
	$c->stash->{pop_id} = $c->stash->{combo_pops_id};	    
	$solgs_controller->get_rrblup_output($c);
    }
}


sub predict_selection_pop_combined_pops_model {
    my ($self, $c) = @_;
         
    my $data_set_type     = $c->stash->{data_set_type}; 
    my $combo_pops_id     = $c->stash->{combo_pops_id};
    my $model_id          = $c->stash->{model_id};                          
    my $prediction_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    my $trait_id          = $c->stash->{trait_id};
        
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $identifier = $combo_pops_id . '_' . $prediction_pop_id;
    $c->controller('solGS::solGS')->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
    my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
     
    if (!-s $prediction_pop_gebvs_file)
    {    
	$self->cache_combined_pops_data($c);
 
	$self->prediction_population_file($c, $prediction_pop_id);
  
	$c->controller('solGS::solGS')->get_rrblup_output($c); 
    }

}



sub combine_trait_data {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
  
    my $solgs_controller = $c->controller('solGS::solGS');
    $solgs_controller->get_trait_details($c, $trait_id);
 
    $self->cache_combined_pops_data($c);

    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
  
    my $geno_cnt  = (split(/\s+/, qx / wc -l $combined_pops_geno_file /))[0];
    my $pheno_cnt = (split(/\s+/, qx / wc -l $combined_pops_pheno_file /))[0];

    unless ( $geno_cnt > 10  && $pheno_cnt > 10 ) 
    {   	
	$self->get_combined_pops_arrayref($c);
	my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
	$c->stash->{trait_combine_populations} = $combined_pops_list;

	$self->prepare_multi_pops_data($c);
	
	my $background_job = $c->stash->{background_job};
	my $prerequisite_jobs = $c->stash->{prerequisite_jobs};
	
	if ($background_job) 
	{	    
	    if ($prerequisite_jobs =~ /^:+$/) 
	    { 
		$prerequisite_jobs = undef;
	    }

	    if ($prerequisite_jobs) 
	    {
		$c->stash->{dependency}      =  $prerequisite_jobs;
		$c->stash->{dependency_type} = 'download_data';
	    }
	}	

	$self->r_combine_populations($c);         
    }
                       
}


sub combine_data_build_model {
    my ($self, $c) = @_;

    my $trait_id = $c->stash->{trait_id};
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
	
    $self->combine_trait_data($c); 
  
    my $combine_job_id = $c->stash->{combine_pops_job_id};
   
    if ($combine_job_id) 
    {
	$c->stash->{dependency} = "'" . $combine_job_id . "'";
	
	if (!$c->stash->{dependency_type}) 
	{
	    $c->stash->{dependency_type} = 'combine_populations';
	}
    }
      
    $self->build_model_combined_trials_trait($c);
	
}


sub combined_trials_desc {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
        
    $self->get_combined_pops_arrayref($c);
    my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
    
    my $solgs_controller = $c->controller('solGS::solGS');
          
    my $desc = 'This training population is a combination of ';
    
    my $projects_owners;
    my $s_pop_id;

    foreach my $pop_id (@$combined_pops_list)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);

        while (my $row = $pr_rs->next)
        {         
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name</a>|; 
            $desc .= $pop_id == $combined_pops_list->[-1] ? '.' : ' and ';
        } 

        $solgs_controller->get_project_owners($c, $_);
        my $project_owners = $c->stash->{project_owners};

        unless (!$project_owners)
        {
             $projects_owners.= $projects_owners ? ', ' . $project_owners : $project_owners;
        }
	
	$s_pop_id = $pop_id;
	$s_pop_id =~ s/\s+//;
    }
   
    $c->stash->{pop_id} = $s_pop_id;
    $solgs_controller->filtered_training_genotype_file($c);
    my $filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

    my $markers_no;
    my @geno_lines;
    my $dir = $c->{stash}->{solgs_cache_dir};
    
    if (-s $filtered_geno_file) 
    {
	@geno_lines = read_file($filtered_geno_file);
	$markers_no = scalar(split('\t', $geno_lines[0])) - 1;
    } 
    else 
    {
	my $geno_exp  = "genotype_data_${s_pop_id}.txt";
        my $geno_file = $solgs_controller->grep_file($dir, $geno_exp);
        @geno_lines   = read_file($geno_file);
        $markers_no   = scalar(split ('\t', $geno_lines[0])) - 1;
    }
  
    my $trait_exp        = "traits_acronym_pop_${combo_pops_id}";
    my $traits_list_file = $solgs_controller->grep_file($dir, $trait_exp);  

    my @traits_list = read_file($traits_list_file);
    my $traits_no   = scalar(@traits_list) - 1;

    my $stock_no  = scalar(@geno_lines) - 1;

    my $training_pop = "Training population $combo_pops_id";
    
    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;

    $c->stash(stocks_no    => $stock_no,
	      markers_no   => $markers_no,
              traits_no    => $traits_no,
              project_desc => $desc,
              project_name => $training_pop,
              owner        => $projects_owners,
	      protocol     => $protocol,
        );
}


sub find_common_traits {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
   
    $self->get_combined_pops_arrayref($c);
    my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};

    my $solgs_controller = $c->controller('solGS::solGS');
    
    my @common_traits;  
    foreach my $pop_id (@$combined_pops_list)
    {  
	$c->stash->{pop_id} = $pop_id;

	$solgs_controller->get_single_trial_traits($c);
	$solgs_controller->traits_list_file($c);
	my $traits_list_file = $c->stash->{traits_list_file};

	my $traits = read_file($traits_list_file);
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
    
    $self->find_common_traits($c);
    my $common_traits = $c->stash->{common_traits};
       
    $c->stash->{pop_id} = $combo_pops_id;
    $c->controller('solGS::solGS')->traits_list_file($c);
    my $traits_file = $c->stash->{traits_list_file};
    write_file($traits_file, join("\t", @$common_traits)) if $traits_file;
  
}


sub get_combined_pops_arrayref {
   my ($self, $c) = @_;
   
   my $combo_pops_id = $c->stash->{combo_pops_id};
 
   $self->get_combined_pops_list($c, $combo_pops_id);
   my $pops_list = $c->stash->{combined_pops_list};
 
   $c->stash->{arrayref_combined_pops_ids} = $pops_list;

}


sub prepare_multi_pops_data {
   my ($self, $c) = @_;
   
   $self->get_combined_pops_arrayref($c);
   my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
 
   my $solgs_controller = $c->controller('solGS::solGS');
  
   $self->multi_pops_phenotype_data($c, $combined_pops_list);
   $self->multi_pops_genotype_data($c, $combined_pops_list);
   $self->multi_pops_geno_files($c, $combined_pops_list);
   $self->multi_pops_pheno_files($c, $combined_pops_list);

   my @all_jobs = (@{$c->stash->{multi_pops_pheno_jobs_ids}}, 
		   @{$c->stash->{multi_pops_geno_jobs_ids}});
   
   my $prerequisite_jobs;

   if (@all_jobs && scalar(@all_jobs) > 1) 
   {
       $prerequisite_jobs = join(':', @all_jobs);
       
   } 
   else 
   {
       if (@all_jobs && scalar(@all_jobs) == 1) { $prerequisite_jobs = $all_jobs[0];}
   }

   if ($prerequisite_jobs =~ /^:+$/) {$prerequisite_jobs = undef;}
  
   $c->stash->{prerequisite_jobs} = $prerequisite_jobs;

}


sub r_combine_populations  {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
 
    my $combo_pops_list = $c->stash->{combined_pops_list};
    my $pheno_files = $c->stash->{multi_pops_pheno_files};  
    my $geno_files  = $c->stash->{multi_pops_geno_files};
    
    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
    
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $trait_info  = $trait_id . "\t" . $trait_abbr;
    my $trait_file  = $$c->controller('solGS::solGS')->create_tempfile($temp_dir, "trait_info_${trait_id}");
    write_file($trait_file, $trait_info); 
  
    my $input_files = join ("\t",
                            $pheno_files,
                            $geno_files,
                            $trait_file,   
        );
    
    my $output_files = join ("\t", 
                             $combined_pops_pheno_file,
                             $combined_pops_geno_file,
        );
                             
    my $tempfile_input = $c->controller('solGS::solGS')->create_tempfile($temp_dir, "input_files_${trait_id}_combine"); 
    write_file($tempfile_input, $input_files);

    my $tempfile_output = $c->controller('solGS::solGS')->create_tempfile($temp_dir, "output_files_${trait_id}_combine"); 
    write_file($tempfile_output, $output_files);
        
    die "\nCan't call combine populations R script without a trait id." if !$trait_id;
    die "\nCan't call combine populations R script without input files." if !$input_files;
    die "\nCan't call combine populations R script without output files." if !$output_files;    
    
    $c->stash->{input_files}  = $tempfile_input;
    $c->stash->{output_files} = $tempfile_output;
    $c->stash->{r_temp_file}  = "combine-pops-${trait_id}";
    $c->stash->{r_script}     = 'R/solGS/combine_populations.r';
    
    $c->controller('solGS::solGS')->run_r_script($c);
  
}


sub create_combined_pops_id {    
    my ($self, $c) = @_;
    
    $c->stash->{combo_pops_id} = crc(join('', @{$c->stash->{pops_ids_list}}));

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}


#####
1;
#####
