use WWW::Selenium;
    
my $server = $ENV{SELENIUM_TEST_SERVER} || die "Need the ENV SELENIUM_TEST_SERVER set";
my $host = $ENV{SELENIUM_HOST} || die "Need the ENV SELENIUM_HOST set";
my $browser = $ENV{SELENIUM_BROWSER} || die "Need the ENV SELENIUM_BROWSER set";

my $sel = WWW::Selenium->new( host => $host, 
                                  port => 4444, 
                                  browser => $browser, 
                                  browser_url => $server."/content/",
                                );
@ORGANISM_IDS = ("Nicotiana attenuata","Capsicum annuum", "Solanum lycopersicoides","Solanum neorickii","Solanum lycopersicum", "Datura metel","Solanum melongena");
my $TABLEID= "id=xtratbl";

#check innerHTML of div when mouseover
$sel->start;
$sel->open("http://sgn.localhost.localdomain/content/sgn_data.pl");
  for (my $i=0;i<scalar(@ORGANISM_IDS);i++){
         print "\n \n Information for ".ORGANISM_IDS[i]."\n";
         $sel->mouse_over("id=".ORGANISM_IDS[i] );
         print $sel->get_text($TABLEID)."\n";
       }
#check if innerHTML is correct when mouseout
  foreach(my$i=0;i<scalar(@ORGANISM_IDS); i++){
         print "\n\n onmouseout for ".ORGANISM_IDS[i]."\n";
         $sel->mouse_out("id=".ORGANISM_IDS[i]);
         print $sel->get_text($TABLEID)."\n";
       }
$sel->stop;
