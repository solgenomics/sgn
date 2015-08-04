package solGS::AnalysisReport;

use Moose;
use namespace::autoclean;

use Email::Sender::Simple;
use Email::Simple;
use Email::Simple::Creator;

sub check_analysis_status {
   
    my ($self, $file) = @_;
 
    my $size = $self->check_output_file_size($file);
    print STDERR "\nfile size: $file -- $size\n";
    $self->report_status($size);
 
}


sub check_output_file_size {
    my ($self, $file) = @_;
  
    if (-e $file) 
    {
	while (1) 
	{
	     my $size = -s $file;
	     print STDERR "\n file size: $size\n";
	    last if -s $file; 
	    sleep 5;
	   
	}	   
	return 1 if -s $file;
    }
    else 
    {	    	    
	return;
    }
  
}


sub report_status {
    my ($self, $status) = @_;

    print STDERR "\nreporting status: $status\n";
  
    my $email = Email::Simple->create(
	header => [
	    To      => '"Isaak" <iyt2@cornell.edu>',
	    From    => '"solGS app" <sgn-db-curation@sgn.cornell.edu>',
	    Subject => "testing analysis report",
	],
	body => "analysis report 1.\n",
	);

    Email::Sender::Simple->send($email);

}




__PACKAGE__->meta->make_immutable;







####
1;
####
