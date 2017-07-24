=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DESCRIPTION

SGN::Controller::solGS::List - Controller for list based training and selection populations

=cut


package SGN::Controller::solGS::List;

use Moose;
use namespace::autoclean;

use List::MoreUtils qw /uniq/;
use CXGN::Tools::Run;
use JSON;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use String::CRC;
use Try::Tiny;
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller' }



sub generate_check_value :Path('/solgs/generate/checkvalue') Args(0) {
    my ($self, $c) = @_;
    
    my $file_name = $c->req->param('string');
    my $check_value = crc($file_name);

    my $ret->{status} = 'failed';
    
    if ($check_value) 
    {
        $ret->{status} = 'success';
        $ret->{check_value} = $check_value;
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_predicted_list_selection :Path('/solgs/check/predicted/list/selection') Args(0) {
    my ($self, $c) = @_;
    
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
    
    my $training_pop_id  = $args->{training_pop_id};
    my $selection_pop_id = $args->{selection_pop_id};
    
    $c->stash->{uploaded_prediction} = 1;
   
    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id);
   
    my $ret->{output} = $c->stash->{download_prediction};

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub load_genotypes_list_selection :Path('/solgs/load/genotypes/list/selection') Args(0) {
    my ($self, $c) = @_;
 
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
    
    $c->stash->{list}                = $args->{list};
    $c->stash->{list_name}           = $args->{list_name};
    $c->stash->{list_id}             = $args->{list_id};
    $c->stash->{data_set_type}       = $args->{data_set_type}; 
    $c->stash->{training_pop_id}     = $args->{training_pop_id};
    $c->stash->{model_id}            = $args->{training_pop_id}; 
    $c->stash->{pop_id}              = $args->{training_pop_id}; 
    $c->stash->{selection_pop_id}    = $args->{selection_pop_id};  
    $c->stash->{uploaded_prediction} = $args->{population_type};
    $c->stash->{trait_id}            = $args->{trait_id};

    if ($args->{data_set_type} =~ /combined populations/) 
    {
	 $c->stash->{combo_pops_id}  = $args->{training_pop_id};
    }
    
    $self->get_selection_genotypes_list($c);
    my $genotypes_list = $c->stash->{genotypes_list};
   
    my $data = $c->model('solGS::solGS')->genotypes_list_genotype_data($genotypes_list);
    $c->stash->{genotypes_list_genotype_data} = $data;
  
    my $selection_pop_id = $args->{selection_pop_id}; 

    $self->genotypes_list_genotype_data_file($c, $selection_pop_id);   
    my $genotype_file = $c->stash->{genotypes_list_genotype_data_file};

    $self->create_list_population_metadata_file($c, $selection_pop_id);
 
    my $ret->{status} = 'failed';
    
    if (-s $genotype_file) 
    {
	$self->predict_list_selection_gebvs($c);

        $ret->{status} = $c->stash->{status};
	$ret->{output} = $c->stash->{download_prediction};
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub solgs_list_login_message :Path('/solgs/list/login/message') Args(0) {
    my ($self, $c) = @_;

    my $page = $c->req->param('page');

    my $message = "This is a private data. If you are the owner, "
	. "please <a href=\"/solpeople/login.pl?goto_url=$page\">login</a> to view it.";

    $c->stash->{message} = $message;

    $c->stash->{template} = "/generic_message.mas"; 
   
}


sub get_trial_id :Path('/solgs/get/trial/id') Args(0) {
    my ($self, $c) = @_;
    
    my @trials_names = $c->req->param('trials_names[]');

    my $tr_rs = $c->model('solGS::solGS')->project_details_by_exact_name(\@trials_names);

    my @trials_ids;
    
    while (my $rw = $tr_rs->next) 
    {
	push @trials_ids, $rw->project_id;
    }
 
    my $ret->{trials_ids} = \@trials_ids;
           
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_selection_genotypes_list_from_file {
    my ($self, $file) = @_;
    my @clones;

    open my $fh, $file or die "Can't open file $file: $!";

    while (<$fh>) 
    {
        $_ =~ s/\n//;
        push @clones, $_;
    }

    return \@clones;

}


sub get_selection_genotypes_list {
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
    
    my @stocks_names = ();  
    foreach my $stock (@$list)
    {
        push @stocks_names, $stock->[1];
    }
    
    @stocks_names = uniq(@stocks_names);
    $c->stash->{genotypes_list} = \@stocks_names;
    
}


sub genotypes_list_genotype_data_file {
    my ($self, $c, $list_pop_id) = @_;
    
    my $geno_data = $c->stash->{genotypes_list_genotype_data};
    my $dir = $c->stash->{solgs_prediction_upload_dir};
        
    my $files = $self->create_list_pop_tempfiles($dir, $list_pop_id);
    my $geno_file = $files->{geno_file};
    write_file($geno_file, $geno_data);

    $c->stash->{genotypes_list_genotype_data_file} = $geno_file;
  
}


sub create_list_pop_tempfiles {
    my ($self, $dir, $list_pop_id) = @_;

    my $pheno_name = "phenotype_data_${list_pop_id}.txt";
    my $geno_name  = "genotype_data_${list_pop_id}.txt";  
    my $pheno_file = catfile($dir, $pheno_name);
    my $geno_file  = catfile($dir, $geno_name);
      
    my $files = { pheno_file => $pheno_file, geno_file => $geno_file};
    
    return $files;

}


sub create_list_population_metadata {
    my ($self, $c) = @_;
    my $metadata = 'key' . "\t" . 'value';
    $metadata .= "\n" . 'user_id' . "\t" . $c->user->id;
    $metadata .= "\n" . 'list_name' . "\t" . $c->{stash}->{list_name};
    $metadata .= "\n" . 'description' . "\t" . 'Uploaded on: ' . strftime "%a %b %e %H:%M %Y", localtime;
    
    $c->stash->{user_list_population_metadata} = $metadata;
  
}


sub create_list_population_metadata_file {
    my ($self, $c, $list_pop_id) = @_;
    
    my $user_id = $c->user->id;
    my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
              
    my $file = catfile ($tmp_dir, "metadata_${user_id}_${list_pop_id}");
 
    $self->create_list_population_metadata($c);
    my $metadata = $c->stash->{user_list_population_metadata};
    
    write_file($file, $metadata);
 
    $c->stash->{user_list_population_metadata_file} = $file;
  
}


sub predict_list_selection_pop_single_pop_model {
    my ($self, $c) = @_;

    my $trait_id         = $c->stash->{trait_id};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    
    $c->stash->{uploaded_prediction} = 1;

    my $identifier = $training_pop_id . '_' . $selection_pop_id;
    $c->controller('solGS::solGS')->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
   
    if (!-s $prediction_pop_gebvs_file)
    {
	$c->controller('solGS::solGS')->phenotype_file_name($c, $training_pop_id);
	$c->stash->{phenotype_file} =$c->stash->{phenotype_file_name};

	$c->controller('solGS::solGS')->genotype_file_name($c, $training_pop_id);
	$c->stash->{genotype_file} =$c->stash->{genotype_file_name};

	$self->user_prediction_population_file($c, $selection_pop_id); 

	$c->stash->{pop_id} = $c->stash->{training_pop_id};
	$c->controller("solGS::solGS")->get_trait_details($c, $trait_id);
	$c->controller("solGS::solGS")->get_rrblup_output($c);
	$c->stash->{status} = 'success';
    }
    else 
    {
	$c->stash->{status} = 'success';	
    }   

}


sub predict_list_selection_pop_multi_traits {
    my ($self, $c) = @_;
    
    my $data_set_type    = $c->stash->{data_set_type};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
  
    $c->stash->{pop_id} = $training_pop_id;    
    $c->controller('solGS::solGS')->traits_with_valid_models($c);
    my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};

    foreach my $trait_abbr (@traits_with_valid_models) 
    {
	$c->stash->{trait_abbr} = $trait_abbr;
	$c->controller('solGS::solGS')->get_trait_details_of_trait_abbr($c);
	$self->predict_list_selection_pop_single_pop_model($c);
    }

    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id );
    my $download_prediction = $c->stash->{download_prediction};
    
}


sub predict_list_selection_pop_combined_pops_model {
    my ($self, $c) = @_;
         
    my $data_set_type     = $c->stash->{data_set_type}; 
    my $combo_pops_id     = $c->stash->{combo_pops_id};
    my $training_pop_id   = $c->stash->{training_pop_id};                          
    my $selection_pop_id  = $c->stash->{selection_pop_id};
    my $trait_id          = $c->stash->{trait_id};
   
    $c->stash->{prediction_pop_id} = $c->stash->{selection_pop_id};
    $c->stash->{pop_id} = $training_pop_id;
    $c->stash->{uploaded_prediction} = 1;

    my $identifier = $training_pop_id . '_' . $selection_pop_id;
    $c->controller("solGS::solGS")->prediction_pop_gebvs_file($c, $identifier, $trait_id);        
    my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
  
    if (!-s $prediction_pop_gebvs_file)
    {    
	$c->controller("solGS::solGS")->get_trait_details($c, $trait_id); 
	
	$c->controller("solGS::solGS")->cache_combined_pops_data($c);
	    
	my $pheno_file = $c->stash->{trait_combined_pheno_file};
	my $geno_file  = $c->stash->{trait_combined_geno_file};
	
	$self->user_prediction_population_file($c, $selection_pop_id);
	
	$c->controller("solGS::solGS")->get_rrblup_output($c);
	$c->stash->{status} = 'success';
    } 
    else
    {
	$c->stash->{status} = 'success';
    }
    
    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id ); 
  
}


sub predict_list_selection_gebvs {
    my ($self, $c) = @_;

    my $referer = $c->req->referer;

    if ($referer =~ /solgs\/trait\//) 
    {
	$self->predict_list_selection_pop_single_pop_model($c);
    }
    elsif ($referer =~ /solgs\/traits\/all\//) 
    {
	$self->predict_list_selection_pop_multi_traits($c);
    }
    elsif ($referer =~ /solgs\/models\/combined\/trials\//) 
    {
	$c->stash->{pop_id} = $c->stash->{training_pop_id};
	$c->controller("solGS::solGS")->traits_with_valid_models($c);
	my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};
   
	foreach my $trait_abbr (@traits_with_valid_models) 
	{
	    $c->stash->{trait_abbr} = $trait_abbr;
	    $c->controller("solGS::solGS")->get_trait_details_of_trait_abbr($c);
     
	    $self->predict_list_selection_pop_combined_pops_model($c); 
	}
    }
    elsif ($referer =~ /solgs\/model\/combined\/populations\//)
    {
	$self->predict_list_selection_pop_combined_pops_model($c); 	
    }
    else 
    {
	$c->stash->{status} = "calling predict_list_selection_gebvs..no matching type analysis.";
    }
}


sub user_prediction_population_file {
    my ($self, $c, $pred_pop_id) = @_;
 
    my $upload_dir = $c->stash->{solgs_prediction_upload_dir};
   
    my ($fh, $tempfile) = tempfile("prediction_population_${pred_pop_id}-XXXXX", 
                                   DIR => $upload_dir
        );

    
    $c->controller("solGS::solGS")->genotype_file_name($c, $pred_pop_id);
    my $pred_pop_file = $c->stash->{genotype_file_name};

    $c->stash->{genotypes_list_genotype_data_file} = $pred_pop_file;
   
    $fh->print($pred_pop_file);
    $fh->close; 

    $c->stash->{prediction_population_file} = $tempfile;
  
}


sub get_list_elements_names {
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
 
    my @names = ();  
   
    foreach my $id_names (@$list)
    {
        push @names, $id_names->[1];
    }

    $c->stash->{list_elements_names} = \@names;

}


sub get_list_elements_ids {
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
 
    my @ids = ();  
   
    foreach my $id_names (@$list)
    {
        push @ids, $id_names->[0];
    }

    $c->stash->{list_elements_ids} = \@ids;

}


sub map_genotypes_plots {
    my ($self, $c) = @_;
  
    my  $plots = $c->stash->{plots_names};
   
    if (!@$plots) 
    { 
	die "No plots list provided $!\n"; 
    }
    else
    {
	my $genotypes_rs = $c->model('solGS::solGS')->get_genotypes_from_plots($plots);
	
	my @genotypes;
	while (my $genotype = $genotypes_rs->next) 
	{
	    my $name = $genotype->uniquename;
	    push @genotypes, $name;
	}

	@genotypes = uniq(@genotypes); 
	
	$c->stash->{genotypes_list} = \@genotypes;
    }	    
        
}


sub load_plots_list_training :Path('/solgs/load/plots/list/training') Args(0) {
    my ($self, $c) = @_;
     
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
  
    $c->stash->{list_name}       = $args->{list_name};
    $c->stash->{list}            = $args->{list};
    $c->stash->{model_id}        = $args->{training_pop_id};
    $c->stash->{population_type} = $args->{population_type};

    my $model_id = $c->stash->{model_id};
    $self->plots_list_phenotype_file($c);
    
    $self->genotypes_list_genotype_file($c, $model_id);
    
    my $tmp_dir  = $c->stash->{solgs_prediction_upload_dir};
      
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $model_id);
    my $pheno_file = $files->{pheno_file};
    my $geno_file  = $files->{geno_file};

    $self->create_list_population_metadata_file($c, $model_id);
 
    my $ret->{status} = 'failed';
    
    if (-s $geno_file && -s $pheno_file) 
    {
        $ret->{status} = 'success';
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genotypes_list_genotype_data {
    my ($self, $args) = @_;
   
    my $list_pop_id  = $args->{model_id} || $args->{list_pop_id} || $args->{selection_pop_id};
    my $genotypes    = $args->{genotypes_list};
    my $tmp_dir      = $args->{list_data_dir};
    
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")
					      });

    my $geno_data = $model->genotypes_list_genotype_data($genotypes);
   
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $list_pop_id);

    my $geno_file = $files->{geno_file};
    write_file($geno_file, $geno_data);
      
}


sub genotypes_list_genotype_file {
    my ($self, $c, $list_pop_id) = @_;

    my $list     = $c->stash->{list}; 
   
    if (!$c->stash->{selection_pop_id}) 
    {
	$self->get_list_elements_names($c); 
	$c->stash->{plots_names} = $c->stash->{list_elements_names};

	$self->get_list_elements_ids($c);
	$c->stash->{plots_ids} = $c->stash->{list_elements_ids};

	$self->map_genotypes_plots($c);	
    }
    else
    {
	$self->get_selection_genotypes_list($c);
    }
    
    my $genotypes = $c->stash->{genotypes_list}; 
    my $data_dir  = $c->stash->{solgs_prediction_upload_dir};

    my $args = {
	'list_pop_id'    => $list_pop_id,
	'genotypes_list' => $genotypes,	        
	'list_data_dir'  => $data_dir,
    };

    $c->stash->{r_temp_file} = 'genotypes-list-genotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $report_file = $c->controller('solGS::solGS')->create_tempfile($temp_dir, 'geno-data-query-report-args');
    $c->stash->{report_file} = $report_file;

    my $status;
    try 
    { 
        my $geno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::List" => "genotypes_list_genotype_data"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::List', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $geno_job->tempdir();
	$c->stash->{geno_data_query_job_id} = $geno_job->job_id();
	$c->stash->{cluster_job} = $geno_job;

	unless ($background_job)
	{
	    $geno_job->wait();
	}
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    }; 

}


sub plots_list_phenotype_data {
    my ($self, $args) = @_;
   
    my $model_id    = $args->{model_id};
    my $plots_names = $args->{plots_names};
    my $plots_ids   = $args->{plots_ids};
    my $traits_file = $args->{traits_file};
    my $tmp_dir     = $args->{list_data_dir};
   
    my $model = SGN::Model::solGS::solGS->new({schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
    my $pheno_data = $model->plots_list_phenotype_data($plots_names);
  
    $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $traits_file);
    
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $model_id);

    my $pheno_file = $files->{pheno_file};
    
    write_file($pheno_file, $pheno_data);
      
}


sub plots_list_phenotype_file {
    my ($self, $c) = @_;

    my $model_id = $c->stash->{model_id};
    my $list     = $c->stash->{list}; 

    $self->get_list_elements_names($c);
    my $plots_names = $c->stash->{list_elements_names};

    $self->get_list_elements_ids($c);
    my $plots_ids = $c->stash->{list_elements_ids};

    $c->stash->{pop_id} = $model_id;
    $c->controller("solGS::solGS")->traits_list_file($c);    
    my $traits_file =  $c->stash->{traits_list_file};
  
    my $data_dir = $c->stash->{solgs_prediction_upload_dir};

    my $args = {
	'model_id'      => $model_id,
	'plots_names'   => $plots_names,
	'plots_ids'     => $plots_ids,
	'traits_file'   => $traits_file,
	'list_data_dir' => $data_dir,
    };

    $c->stash->{r_temp_file} = 'plots-phenotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 
    try 
    { 
        my $pheno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::List" => "plots_list_phenotype_data"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::List', 'SGN::Controller::solGS::solGS', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $pheno_job->tempdir();
	$c->stash->{pheno_data_query_job_id} = $pheno_job->job_id();
	$c->stash->{cluster_job} = $pheno_job;

	unless ($background_job)
	{
	    $pheno_job->wait();
	}
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    }; 

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;

