package solGS::AnalysisReport;

use Moose;
use namespace::autoclean;

use Email::Sender::Simple qw /sendmail/;
use Email::Simple;
use Email::Simple::Creator;
use File::Spec::Functions qw /catfile catdir/;


sub check_analysis_status {
   
    my ($self, $output_files, $analysis_profile) = @_;
 
    #my $output_file = $output_files->{output_file};

   # sleep 10;
    my $size = $self->check_output_file_size($output_files);
    
   # my $died_file;
    
    # if (!$size) 
    # {
    # 	my $job_tempdir = $output_files->{job_tempdir};    
    # 	$died_file  = $self->get_file($job_tempdir, 'died');
    # }
    
   # my $died = $self->check_died_file($died_file);

    $self->report_status($size, $analysis_profile);
 
}


sub check_died_file {
    my ($self, $died_file)  = @_;

    
    if (-e $died_file) 
    {
	return 1;
    } 
    else 
    {	
	return;
    }


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


sub check_output_file_size {
    my ($self, $output_files) = @_;
  
    my $result_file = $output_files->{output_file};
    my $job_tempdir = $output_files->{job_tempdir};
    
    if (-e $result_file) 
    {
	my $result_size;
	my $died_file;
	
	while (1) 
	{
	    sleep 5;
	    $result_size = -s $result_file;
	    if (! $result_size)
	    {
		$died_file = $self->get_file($job_tempdir, 'died');
	    }

	    if ($result_size || $died_file) 
	    {
		last;		
	    }
	}	   
	return $result_size ;
    }
    else 
    {	    	    
	return;
    }  
}


sub report_status {
    my ($self, $result_file, $analysis_profile) = @_;

    my $user_email = $analysis_profile->{user_email};
    my $user_name  = $analysis_profile->{user_name};

    my $analysis_page = $analysis_profile->{analysis_page};
    my $analysis_name = $analysis_profile->{analysis_name};
        
    my $analysis_result;

    if ($result_file) 
    {
	$analysis_result = "Your analysis, $analysis_name, is done. " 
	    . "You can view the analysis result here:"  
	    . "\n\n$analysis_page";
    }
    else 
    {
	$analysis_result = "The $analysis_name analysis failed. "
	    . "\n\nWe are troubleshooting the cause. " 
	    . "We will contact you when we find out more.";
    }
    
    my $closing = "Please email us to sgn-feedback\@sgn.cornell.edu, " 
	. "if you have any remarks."
	. "\n\nThanks and regards,\nWebmaster";

    my $body = "Dear $user_name,"
	. "\n\n$analysis_result" 
	. "\n\n$closing";
   
    my $email = Email::Simple->create(
	header => [
	    To      => '"Isaak" <isaak@localhost.localdomain>',
	    From    => '"Isaak Tecle" <isaak@localhost.localdomain',
	    Subject => "Analysis result of $analysis_name",
	],
	body => $body,
	);

    sendmail($email); 

}




__PACKAGE__->meta->make_immutable;







####
1;
####
