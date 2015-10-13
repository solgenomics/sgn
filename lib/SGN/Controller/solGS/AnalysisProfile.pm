package SGN::Controller::solGS::AnalysisProfile;

use Moose;
use namespace::autoclean;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;
use CXGN::Tools::Run;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller' }


sub check_user_login :Path('/solgs/check/user/login') Args(0) {
  my ($self, $c) = @_;

  my $user = $c->user();
  my $ret->{loggedin} = 0;

  if ($user) 
  { 
      my $salutation = $user->get_salutation();
      my $first_name = $user->get_first_name();
      my $last_name  = $user->get_last_name();
          
      my $private_email = $user->get_private_email();
      my $public_email  = $user->get_contact_email();
     
      my $email = $public_email 
	  ? $public_email 
	  : $private_email;

      $ret->{loggedin} = 1;
      my $contact = { 'name' => $first_name, 'email' => $email};
     
      $ret->{contact} = $contact;
  }
   
  $ret = to_json($ret);
       
  $c->res->content_type('application/json');
  $c->res->body($ret);  
  
}


sub save_analysis_profile :Path('/solgs/save/analysis/profile') Args(0) {
    my ($self, $c) = @_;
   
    my $analysis_profile = $c->req->params;
    $c->stash->{analysis_profile} = $analysis_profile;
   
    my $analysis_page = $analysis_profile->{analysis_page};
    $c->stash->{analysis_page} = $analysis_page;
   
    my $ret->{result} = 0;
   
    $self->save_profile($c);
    my $error_saving = $c->stash->{error};
    
    if (!$error_saving) 
    {
	$ret->{result} = 1;	
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);  
    
}


sub save_profile {
    my ($self, $c) = @_;
        
    $self->analysis_profile_file($c);
    my $profile_file = $c->stash->{analysis_profile_file};

    $self->add_headers($c);

    $self->format_profile_entry($c);
    my $formatted_profile = $c->stash->{formatted_profile};
    
    my $analysis_page= $c->stash->{analysis_page};

    my @contents = read_file($profile_file);
 
    write_file($profile_file, {append => 1}, $formatted_profile);
   
}


sub add_headers {
  my ($self, $c) = @_;

  $self->analysis_profile_file($c);
  my $profile_file = $c->stash->{analysis_profile_file};

  my $headers = read_file($profile_file);
  
  unless ($headers) 
  {  
      $headers = 'User name' . 
	  "\t" . 'User email' . 
	  "\t" . 'Analysis name' . 
	  "\t" . "Analysis page" . 
	  "\t" . "Arguments" .
	  "\t" . "Status" .
	  "\n";

      write_file($profile_file, $headers);
  }
  
}


sub format_profile_entry {
    my ($self, $c) = @_; 
    
    my $profile = $c->stash->{analysis_profile};
   
    my $entry = join("\t", 
		     ($profile->{user_name}, 
		      $profile->{user_email}, 
		      $profile->{analysis_name}, 
		      $profile->{analysis_page}, 
		      $profile->{arguments}, 
		      'running')
	);

    $entry .= "\n";
	
   $c->stash->{formatted_profile} = $entry; 
}


sub run_saved_analysis :Path('/solgs/run/saved/analysis/') Args(0) {
    my ($self, $c) = @_;
   
    my $analysis_profile = $c->req->params;
    $c->stash->{analysis_profile} = $analysis_profile;

    $self->parse_arguments($c);
    
    $self->run_analysis($c);  
     
    $self->structure_output_details($c); 
    
    my $output_details = $c->stash->{bg_job_output_details};
      
    $c->stash->{r_temp_file} = 'analysis-status';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};
   
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $status;

    try 
    { 
        my $job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["solGS::AnalysisReport" => "check_analysis_status"],
    	    args          => [$output_details],
    	    load_packages => ['solGS::AnalysisReport'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    };

    if (!$status) 
    { 
	$status = $c->stash->{status}; 
    }
   
    my $ret->{result} = $status;	

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);  

} 


sub parse_arguments {
  my ($self, $c) = @_;
 
  my $analysis_data =  $c->stash->{analysis_profile};
  my $arguments = $analysis_data->{arguments};

  if ($arguments) 
  {
      my $json = JSON->new();
      $arguments = $json->decode($arguments);
      
      foreach my $k ( keys %{$arguments} ) 
      {
	  if ($k eq 'population_id') 
	  {
	      my @pop_ids = @{ $arguments->{$k} };
	      $c->stash->{pop_ids} = \@pop_ids;
	      
	      if (scalar(@pop_ids) == 1) 
	      {		  
		  $c->stash->{pop_id}  = $pop_ids[0];
	      }
	  }

	  if ($k eq 'trait_id') 
	  {
	      my @selected_traits = @{ $arguments->{$k} };
	      $c->stash->{selected_traits} = \@selected_traits;
	  } 
	  
	  if ($k eq 'analysis_type') 
	  {
	      $c->stash->{analysis_type} = $arguments->{$k};
	  }	 

	  if ($k eq 'data_set_type') 
	  {
	      $c->stash->{data_set_type} =  $arguments->{$k};
	  }	 
      }
  }
	    
}


sub structure_output_details {
    my ($self, $c) = @_;

    my $analysis_data =  $c->stash->{analysis_profile};
    my $arguments = $analysis_data->{arguments};
 
    $self->parse_arguments($c);
   
    my @traits_ids;
    
    if ($c->stash->{selected_traits}) 
    {
	@traits_ids = @{ $c->stash->{selected_traits}};
    }
   
    my $pop_id =  $c->stash->{pop_id}; 

    my %output_details = (); 
    
    my $base    = $c->req->base;
    my $referer = $c->req->referer;
    
    my $analysis_page = $analysis_data->{analysis_page};
    
    my $geno_file;
    my $pheno_file;
    
    if ($analysis_page =~ m/[(solgs\/analyze\/traits\/) | (solgs\/trait\/) | (solgs\/model\/combined\/trials\/)]/) 
    {
	foreach my $trait_id (@traits_ids)
	{
	    my $solgs_controller = $c->controller('solGS::solGS');
	    
	    $c->stash->{cache_dir} = $c->stash->{solgs_cache_dir};

	    $solgs_controller->get_trait_name($c, $trait_id);	    
	    $solgs_controller->gebv_kinship_file($c);
	 	  
	    my$trait_abbr = $c->stash->{trait_abbr};
	  
	    my $trait_page;

	    if ( $referer =~ m/solgs\/population\// ) 
	    {
		$trait_page = $base . "solgs/trait/$trait_id/population/$pop_id";
	    }
	    
	    if ( $referer =~ m/solgs\/populations\/combined\// ) 
	    {
		$trait_page = $base . "solgs/model/combined/trials/$pop_id/trait/$trait_id";
	    }

	    if ( $analysis_page =~ m/solgs\/model\/combined\/trials\// ) 
	    {
		$trait_page = $base . "solgs/model/combined/trials/$pop_id/trait/$trait_id";

		$c->stash->{combo_pops_id} = $pop_id;

		$solgs_controller->cache_combined_pops_data($c);

		$pheno_file = $c->stash->{trait_combined_pheno_file};
		$geno_file  = $c->stash->{trait_combined_geno_file};  
		
	    }
	    
	    $output_details{$trait_abbr} = {
		'trait_id'      => $trait_id, 
		'trait_name'    => $c->stash->{trait_name}, 
		'trait_page'    => $trait_page,
		'gebv_file'     => $c->stash->{gebv_kinship_file},
		'pop_id'        => $pop_id,
		'pheno_file'    => $pheno_file,
		'geno_file'     => $geno_file,
		'data_set_type' => $c->stash->{data_set_type},
	    }
	}
    }

    $output_details{analysis_profile} = $analysis_data;
    $output_details{r_job_tempdir}    = $c->stash->{r_job_tempdir};
    $output_details{contact_page}     = $base . 'contact/form';
    $output_details{data_set_type}    = $c->stash->{data_set_type};
    
    $c->stash->{bg_job_output_details} = \%output_details;
   
}


sub run_analysis {
    my ($self, $c) = @_;
 
    my $analysis_profile = $c->stash->{analysis_profile};
    my $analysis_page    = $analysis_profile->{analysis_page};

    my $base =   $c->req->base;
    $analysis_page =~ s/$base/\//;

    $c->stash->{background_job} = 1;
  
    my @selected_traits = @{$c->stash->{selected_traits}};
    
    if ($analysis_page =~ /solgs\/analyze\/traits\//) 
    {   
	if ($c->stash->{data_set_type} =~ /combined populations/)
	{
	    $c->stash->{combo_pops_id} = $c->stash->{pop_id};
	   
	    foreach my $trait_id (@selected_traits)		
	    {		
		$c->controller('solGS::solGS')->get_trait_name($c, $trait_id);   	
		$c->controller('solGS::combinedTrials')->combine_data_build_model($c);
	    }
	}
	else 
	{
	    $c->controller('solGS::solGS')->build_multiple_traits_models($c);
	}	
    } 
    elsif ($analysis_page =~ /solgs\/models\/combined\/trials\// )	  
    {
	$c->stash->{combo_pops_id} = $c->stash->{pop_id};
	my $trait_id = $c->stash->{selected_traits}->[0];		
	
	$c->controller('solGS::solGS')->get_trait_name($c, $trait_id);
	$c->controller('solGS::combinedTrials')->combine_data_build_model($c);
       
    }
    elsif ($analysis_page =~ /solgs\/trait\//) 
    {
	$c->stash->{trait_id} = $selected_traits[0];
	$c->controller('solGS::solGS')->build_single_trait_model($c);
    }
    else 
    {
	$c->stash->{status} = 'Error';
	print STDERR "\n I don't know what to analyze\n";
    }

    my @error = @{$c->error};
    
    if ($error[0]) 
    {
	$c->stash->{status} = 'Error';
    }
    else 
    {    
	$c->stash->{status} = 'OK';
    }
 
    $self->update_analysis_progress($c);
 
}





sub update_analysis_progress {
    my ($self, $c) = @_;
     
    my $analysis_data =  $c->stash->{analysis_profile};
    my $analysis_name= $analysis_data->{analysis_name};
    my $status = $c->stash->{status};
    
    $self->analysis_profile_file($c);
    my $profile_file = $c->stash->{analysis_profile_file};
  
    my @contents = read_file($profile_file);
   
    map{ $contents[$_] =~ /$analysis_name/ 
	     ? $contents[$_] =~ s/error|running/$status/ig 
	     : $contents[$_] } 0..$#contents; 
   
    write_file($profile_file, @contents);

}


sub analysis_profile_file {
    my ($self, $c) = @_;

    $self->create_profiles_dir($c);   
    my $profiles_dir = $c->stash->{profiles_dir};
    
    $c->stash->{cache_dir} = $profiles_dir;

    my $cache_data = {
	key       => 'analysis_profiles',
	file      => 'analysis_profiles',
	stash_key => 'analysis_profile_file'
    };

    $c->controller('solGS::solGS')->cache_file($c, $cache_data);

}


sub confirm_request :Path('/solgs/confirm/request/') Args(0) {
    my ($self, $c) = @_;
    
    my $referer = $c->req->referer;
    
    $c->stash->{message} = "<p>Your analysis is running.</p>
                            <p>You will receive an email when it is completed.
                             </p><p><a href=\"$referer\">[ Go back ]</a></p>";

    $c->stash->{template} = "/generic_message.mas"; 

}


sub create_profiles_dir {
    my ($self, $c) = @_;
        
    my $analysis_profile = $c->stash->{analysis_profile};
    my $user_email = $analysis_profile->{user_email};
      
    $user_email =~ s/(\@|\.)//g;

    $c->controller('solGS::solGS')->get_solgs_dirs($c);

    my $profiles_dir = $c->stash->{profiles_dir};

    $profiles_dir = catdir($profiles_dir, $user_email);
    mkpath ($profiles_dir, 0, 0755);

    $c->stash->{profiles_dir} = $profiles_dir;
  
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}




__PACKAGE__->meta->make_immutable;


####
1;
####
