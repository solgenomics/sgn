## Everything a scrap does should be enclosed in an eval{} statement to catch errors (so the AJAX request doesn't receive an SGN error page, which is difficult to parse)
use CXGN::Page;
use CXGN::Scrap;
use Carp;

eval {
	my $scrap = CXGN::Scrap->new();
	my %args = $scrap->get_all_encoded_arguments();

	## Put all scrap code here

};
if($@) {
	#insert new line so that Javascript can more easily separate sent error message from stack trace
	$@ =~ s/(.*?) at \/data\/local/$1\n\/data\/local/;  
	print "E: $@";
	##Everytime a scrap dies, confesses, or croaks, the AJAX response will begin with "E: " (for Error), followed by the die message.  
	#This allows JavaScript-side error-catching to be handled in a "f-error-ly" simple manner
}

