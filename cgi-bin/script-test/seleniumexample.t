use Test::More tests=>22;
use Test::WWW::Selenium;
    
my $server = $ENV{SELENIUM_TEST_SERVER} || die "Need the ENV SELENIUM_TEST_SERVER set";
my $host = $ENV{SELENIUM_HOST} || die "Need the ENV SELENIUM_HOST set";
my $browser = $ENV{SELENIUM_BROWSER} || die "Need the ENV SELENIUM_BROWSER set";

my $sel = Test::WWW::Selenium->new( host => $host, 
                                  port => 4444, 
                                  browser => $browser, 
                                  browser_url => $server."/content/",
                                );
@ORGANISM_IDS = ("Nicotiana attenuata","Capsicum annuum", "Solanum lycopersicoides","Solanum neorickii","Solanum lycopersicum", "Datura metel","Solanum melongena");
my $TABLEID= "id=xtratbl";

#check innerHTML of div when mouseover

$sel->start;
$sel->open_ok("http://sgn.localhost.localdomain/content/sgn_data.pl");
for my $orgid(@ORGANISM_IDS){
    $sel->mouse_over_ok("id=".$orgid);
    $sel->text_like($TABLEID,qr/$orgid/,"".$orgid."test");
    $sel->mouse_out_ok("id=".$orgid);
}
$sel->stop;
