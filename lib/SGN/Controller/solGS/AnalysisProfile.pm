package SGN::Controller::solGS::AnalysisProfile;

use Moose;
use namespace::autoclean;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;

use CXGN::Tools::Run;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller' }


sub login_user :Path('/solgs/check/user/login') Args(0) {
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
      my $user_profile = { 'name' => $first_name, 'email' => $email};
      $ret->{user_profile} = $user_profile;
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
    
    if (!$error_saving) {
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
 
    my $exists = map{ $contents[$_] =~ /$analysis_page/  } 0..$#contents; 
    
    if (!$exists)
    {
	write_file($profile_file, {append => 1}, $formatted_profile);
    }   
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

    $self->run_analysis($c);
    
    my $output_file = $c->stash->{gebv_kinship_file};
    my $job_tempdir = $c->stash->{job_tempdir};
    
    my $output_files = { 
	'output_file' => $output_file, 
	'job_tempdir' => $job_tempdir
    };

    $c->stash->{r_temp_file} = 'analysis-status';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};
   
    $self->create_profiles_dir($c);
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};

    try 
    { 
        my $r_process = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["solGS::AnalysisReport" => "check_analysis_status"],
    	    args          => [$output_files, $analysis_profile],
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
	my $err = $_;
	$err =~ s/\n at .+//s; 
        
      	try
        {  
            $err .= "\n=== R output ===\n"
    		.file($out_temp_file)->slurp
    		."\n=== end R output ===\n"; 
	};            
    };
} 


sub run_analysis {
    my ($self, $c) = @_;
 
    #test if analysis completed?
    # test on combining populations..

    my $analysis_profile = $c->stash->{analysis_profile};
    my $analysis_page    = $analysis_profile->{analysis_page};

    my $base =   $c->req->base;
    $analysis_page =~ s/$base/\//;
  
    $self->create_profiles_dir($c);
    $c->stash->{background_job} = 1;
    
    $c->req->path($analysis_page);
    $c->prepare_action;
    $c->action ? $c->forward( $c->action ) : $c->dispatch;
    my @error = @{$c->error};
    
    if ($error[0]) 
    {
	$c->stash->{status} = 'Error';
    }
    else 
    {    
	$c->stash->{status} = 'OK';
    }
 
}


sub update_analysis_progress {
    my ($self, $c) = @_;
     
    #read entry for the analysis, grep it and replace status with analysis outcome
    my $analysis_page= $c->stash->{analysis_page};
    my $status = $c->stash->{status};
    $self->analysis_profile_file($c);
    my $profile_file = $c->stash->{analysis_profile_file};
  
    print STDERR "\n updating  analysis progress....status: $status\n";
    
    my @contents = read_file($profile_file);
   
    map{ $contents[$_] =~ /$analysis_page/ 
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










__PACKAGE__->meta->make_immutable;


####
1;
####
