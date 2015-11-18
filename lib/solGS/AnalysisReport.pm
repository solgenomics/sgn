package solGS::AnalysisReport;

use Moose;
use namespace::autoclean;

use Email::Sender::Simple qw /sendmail/;
use Email::Simple;
use Email::Simple::Creator;
use File::Spec::Functions qw /catfile catdir/;


sub check_analysis_status {   
    my ($self, $output_details) = @_;
 
    my $output_success = $self->check_success($output_details);
    
    $self->report_status($output_success); 
}


sub check_success {
    my ($self, $output_details) = @_;
    
    my $analysis_profile = $output_details->{analysis_profile};
  
    if ( $analysis_profile->{analysis_type} =~ /population download/ ) 
    {	
	$output_details = $self->check_population_download($output_details);
    }
    elsif ( $analysis_profile->{analysis_type} =~ /(single|multiple) model/ )
    {
	if ($output_details->{data_set_type} =~ /combined populations/) 
	{	
	    $output_details = $self->check_combined_pops_modeling($output_details);
	}
	elsif ($output_details->{data_set_type} =~ /single population/)
	{
	    $output_details = $self->check_trait_modeling($output_details);
	}
    }
    
    return $output_details;  
}


sub check_combined_pops_modeling {
    my ($self, $output_details) = @_;

    $output_details = $self->check_pops_data_combination($output_details);
    $output_details = $self->check_trait_modeling($output_details);
     
    return $output_details;
}


sub check_pops_data_combination {
    my ($self, $output_details) = @_;
  
    my $job_tempdir = $output_details->{r_job_tempdir};
    
    foreach my $k (keys %{$output_details})
    {
	my $pheno_file;
	my $geno_file;
	
	if (ref $output_details->{$k} eq 'HASH') 
	{
	   $pheno_file = $output_details->{$k}->{phenotype_file}; 
	   $geno_file  = $output_details->{$k}->{genotype_file}; 
	} 
	
	if ($geno_file || $pheno_file) 
	{
	    my $pheno_size;
	    my $geno_size;
	    my $died_file;
	
	    while (1) 
	    {
		sleep 5;
		$pheno_size = -s $pheno_file;
		$geno_size  = -s $geno_file;
	
		if ($pheno_size) 
		{
		    $output_details->{$k}->{pheno_success} = 'pheno success';
		   		
		}

		if ($geno_size) 
		{
		    $output_details->{$k}->{geno_success} = 'geno success';
		   		
		}

		if ($pheno_size && $geno_size) 
		{
		    $output_details->{$k}->{combine_success} = 1;
		    last;
		}
		else
		{
		    if ($job_tempdir) 
		    {
			$died_file = $self->get_file($job_tempdir, 'died');
			if ($died_file) 
			{
			    $output_details->{$k}->{pheno_success}   = 0;
			    $output_details->{$k}->{geno_success}    = 0;
			    $output_details->{$k}->{combine_success} = 0;
			    last;
			}
		    }
		}	    
	    }	   	    
	}
	else 
	{  
	    if (ref $output_details->{$k} eq 'HASH')	
	    {   	    
		$output_details->{$k}->{pheno_success}   = 0;
		$output_details->{$k}->{geno_success}    = 0;
		$output_details->{$k}->{combine_success} = 0;
	    }
	}  
    }

    return $output_details;  
}


sub check_trait_modeling {
    my ($self, $output_details) = @_;

    my $job_tempdir = $output_details->{r_job_tempdir};
          
    foreach my $k (keys %{$output_details})
    {
	my $gebv_file;
	if (ref $output_details->{$k} eq 'HASH') 
	{
	   $gebv_file = $output_details->{$k}->{gebv_file}; 
	} 
	
	if ($gebv_file) 
	{
	    my $gebv_size;
	    my $died_file;
	
	    while (1) 
	    {
		sleep 5;
		$gebv_size = -s $gebv_file;

		if ($gebv_size) 
		{
		    $output_details->{$k}->{success} = 1;
		    last;		
		}
		else
		{
		    if ($job_tempdir) 
		    {
			$died_file = $self->get_file($job_tempdir, 'died');
			if ($died_file) 
			{
			    $output_details->{$k}->{success} = 0;
			    last;
			}
		    }
		}	    
	    }	   	    
	}
	else 
	{  
	    if (ref $output_details->{$k} eq 'HASH')	
	    {   	    
		$output_details->{$k}->{success} = 0;
	    }
	}  
    }

    return $output_details;
}


sub check_population_download {
    my ($self, $output_details) = @_;

    my $job_tempdir = $output_details->{r_job_tempdir};
    
    foreach my $k (keys %{$output_details})
    {
	my $pheno_file;
	my $geno_file;

	if (ref $output_details->{$k} eq 'HASH') 
	{ 
	    if ($output_details->{$k}->{population_id})
	    { 
		$pheno_file = $output_details->{$k}->{phenotype_file}; 
		$geno_file  = $output_details->{$k}->{genotype_file}; 

		if ($pheno_file && $geno_file) 
		{
		    my $pheno_size;
		    my $geno_size;
		    my $died_file;
	
		    while (1) 
		    {
			sleep 5;
			$pheno_size = -s $pheno_file;
			$geno_size  = -s $geno_file;

			unless (!$pheno_size) 
			{
			    $output_details->{$k}->{pheno_success} = 1;	
			}

			unless (!$geno_size) 
			{
			    $output_details->{$k}->{geno_success} = 1;		
			}

			if ($pheno_size && $geno_size) 
			{		    
			    $output_details->{$k}->{success} = 1;
			    last;
			}		
			else
			{
			    if ($job_tempdir) 
			    {
				$died_file = $self->get_file($job_tempdir, 'died');
				if ($died_file) 
				{
				    $output_details->{$k}->{pheno_success}   = 0;
				    $output_details->{$k}->{geno_success}    = 0;
				    $output_details->{$k}->{success} = 0;
				    last;
				}
			    }
			}	    
		    }	   	    
		}
		else 
		{  
		    if (ref $output_details->{$k} eq 'HASH')	
		    {   
			$output_details->{$k}->{pheno_success}   = 0;
			$output_details->{$k}->{geno_success}    = 0;
			$output_details->{$k}->{success} = 0;
		    }
		} 
	    } 
	}
    }
    
    return $output_details;
    
}


sub get_file {
    my ($self, $dir, $exp) = @_;

    opendir my $dh, $dir 
        or die "can't open $dir: $!\n";

    my ($file)  = grep { /$exp/ && -f "$dir/$_" }  readdir($dh);
    close $dh;
   
    if ($file)    
    {
        $file = catfile($dir, $file);
    }

    return $file;
}


sub report_status {
    my ($self, $output_details) = @_;

    my $analysis_profile = $output_details->{analysis_profile};
    my $user_email = $analysis_profile->{user_email};
    my $user_name  = $analysis_profile->{user_name};

    my $analysis_page = $analysis_profile->{analysis_page};
    my $analysis_name = $analysis_profile->{analysis_name};
    my $analysis_type = $analysis_profile->{analysis_type};    
    
    my $analysis_result;
  
    if ($analysis_type =~ /multiple models/) 
    {
	$analysis_result = $self->multi_modeling_message($output_details);
    }
    elsif ($analysis_type =~ /single model/) 
    {
    	$analysis_result = $self->single_modeling_message($output_details);
    }
    elsif ($analysis_type =~ /population download/  ) 
    {
    	$analysis_result = $self->population_download_message($output_details);
    }
   
    my $closing = "If you have any remarks, please contact us:\n"
	. $output_details->{contact_page}
	."\n\nThanks and regards,\nWebmaster";

    my $body = "Dear $user_name,"
	. "\n\n$analysis_result" 
	. "\n\n$closing";
   
    my $email = Email::Simple->create(
	header => [
	    To      => '"Isaak" <isaak@localhost.localdomain>',
	    From    => '"Isaak Tecle" <isaak@localhost.localdomain>',
	    Subject => "Analysis result of $analysis_name",
	],
	body => $body,
	);

    sendmail($email); 
}


sub multi_modeling_message {
    my ($self, $output_details) = @_;
    
    my $message;
    my $cnt = 0;

    foreach my $k (keys %{$output_details}) 
    {
	my $all_success;
	
	if (ref $output_details->{$k} eq 'HASH')
	{
	    if ($output_details->{$k}->{trait_id})
	    {	  
		if ($output_details->{$k}->{success})
		{
		    $cnt++;
		    $all_success = 1;
		    my $trait_name = uc($output_details->{$k}->{trait_name});
		    my $trait_page = $output_details->{$k}->{trait_page};
		    $message .= "The analysis for $trait_name is done."
			." You can view the output here:\n"
			."$trait_page.\n\n";
		}
		else 
		{  
		    $all_success = 0; 
		    my $trait_name = uc($output_details->{$k}->{trait_name});
		    $message .= "The analysis for $trait_name failed.\n";	 
		}		
	    }
	}
    }
    if ($cnt > 1 ) 
    {
	$message .= "You can also view the summary of all the analyses in the page below."
	    ." \nAdditionally, you may find the analytical features in the page useful.\n"
	    . $output_details->{analysis_profile}->{analysis_page};
    }

    return  $message;
}


sub single_modeling_message {
    my ($self, $output_details) = @_;
    
    my $message;
    foreach my $k (keys %{$output_details}) 
    {
	if (ref $output_details->{$k} eq 'HASH')
	{
	    if ($output_details->{$k}->{trait_id})
	    {
		my $trait_name = uc($output_details->{$k}->{trait_name});
		my $trait_page = $output_details->{$k}->{trait_page};
		
		if ($output_details->{$k}->{success})		
		{		
		    $message = "The analysis for $trait_name is done."
			." You can view the output here:\n"
			."$trait_page.\n";
		}
		else 
		{  
		    $message = "The analysis for $trait_name failed."
			."\n\nWe are troubleshooting the cause. " 
			. "We will contact you when we find out more.";	 
		}		
	    }
	}
    }

    return  $message;
}


sub population_download_message {
    my ($self, $output_details) = @_;
    
    my $message;
     
    foreach my $k (keys %{$output_details}) 
    {
	if (ref $output_details->{$k} eq 'HASH')
	{
	     if ($output_details->{$k}->{population_id})
	    {
		my $pop_name = uc($output_details->{$k}->{population_name});
		my $pop_page = $output_details->{$k}->{population_page};
		
		if ($output_details->{$k}->{success})		
		{		
		    $message = "The phenotype and genotype data for $pop_name is ready for analysis."
			."\nYou can view population page here:\n"
			."\n$pop_page.\n";
		}
		else 
		{  
		    $message = "Downloading phenotype and genotype data for $pop_name failed."
			."\nWe are troubleshooting the cause. " 
			. "We will contact you when we find out more.";	 
		}
	    }		
	}
    }
  
    return  $message;
}




__PACKAGE__->meta->make_immutable;







####
1; #
####
