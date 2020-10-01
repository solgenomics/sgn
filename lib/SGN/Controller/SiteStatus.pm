
package SGN::Controller::SiteStatus;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }


sub login_status :Path('/about/status/logins') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    if (! ($c->user())) { 
	$c->res->redirect('/user/login');
	return;
    }
    if (!$c->user()->check_roles("curator")) { 
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message} = 'You do not have the required privileges to view this page';
	return;
    }
	
    my $login = CXGN::Login->new($c->dbc->dbh());
    
    my %logins = $login->get_login_status();

    my $summary = {};
    foreach my $user_type (qw/curator submitter user/){
	my $count = $logins{$_};
	$count = 0 if $count eq "none";
	$summary->{$user_type}=$count;
    }
    $c->stash->{logins} = \%logins;
    my $detailed = "";
    my @usernames;

    foreach my $user_type (keys %{$logins{detailed}}) {

	@usernames = (keys %{$logins{detailed}->{$user_type}});
	

	
    }
    $c->stash->{usernames} = \@usernames;
    $c->stash->{template} = '/site/status.mas';
}

1;
