use strict;
use warnings;

use CXGN::People::Person;

use CGI qw/ param /;

use CXGN::DB::Connection;
use CXGN::Phenome::Locus;

use CatalystX::GlobalContext qw( $c );

my $cgi = CGI->new();

my $locus_id = $cgi->param("locus_id") + 0;

unless ($locus_id =~m /^\d+$/) {
    $c->throw( is_error=>0,
               message => "Invalid locus identifier $locus_id",
        );
}
print $cgi->redirect("/locus/$locus_id/view", 301);


#############

