
use strict;

use CXGN::DB::Connection;
use CXGN::Login;


CXGN::DB::Connection->verbose(0);
my $dbh = CXGN::DB::Connection->new();

#print STDERR "Calling get_login_info...\n";
my $login = CXGN::Login->new($dbh);
my %logins = $login->get_login_status();

my $summary = "";
foreach(qw/curator submitter user/){
	my $count = $logins{$_};
	$count = 0 if $count eq "none";
	$summary .= "&nbsp;&nbsp;" . ucfirst($_) . "s: <b>$count</b>";
}

my $detailed = "";
foreach my $user_type (keys %{$logins{detailed}}) {
	$detailed .= ucfirst($user_type) . "s: ";
	my @usernames = (keys %{$logins{detailed}->{$user_type}});
	$detailed .= join ", ", @usernames;	
	$detailed .= "<br />";
}

print <<HTML;

<html>
<body>

    <span style="font-size:1.3em"><b>Logins:</b></span> 
	<span style="font-size:1.2em">$summary</span><br /><br />
	$detailed
</body>
</html>

HTML
