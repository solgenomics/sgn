#!/usr/bin/perl
package CXGN::Page::DeveloperSettings;
use strict;

#use CXGN::Class::DBI;
use base qw/CXGN::Class::DBI CXGN::Page::Session/;

use CXGN::Cookie;
use CXGN::VHost;
use CXGN::Login;
use CXGN::Page::Session;  #we directly reference the constructor 

#These are acceptable keys, or a registry, for DeveloperSettings:
our @VALID_KEYS = 
qw/
	devel_type
	dt_localsite  
	dt_develsite  
	dt_livesite 
	toolbar_closed
	logging_pane_open 
	capture_stderr
	timestamp
/; 

our $COOKIE_NAME = 'developer_settings';
our $DB_SCHEMA = 'sgn_people';
our $DB_TABLE = 'sp_person';
our $DB_COLUMN = 'developer_settings';
our $ID_COLUMN = 'sp_person_id';
our $ID = undef;

=head1 Instance Methods

=head2 new([$dbh])

 Constructor takes optional database handle, determines settings 
 based on the following order of precedence:

 1) Local VHost Config, overrides everything
 2) Cookie
 3) Database, 'developer_settings' in logged-in sp_person

 Settings are not taken in whole from any one source.  A setting
 key from the database that doesn't exist in the cookie or VHost 
 config will not be clobbered

 Settings are then saved to the database and the cookie is set.
 Therefore the constructor and save() MUST be called BEFORE 
 headers on a page are sent.

=cut

sub new {
	my $class = shift;
	my $dbh = shift;
	my $user_type = undef;
	my $tid = undef;
	($tid, $user_type) = CXGN::Login->new($dbh)->has_session();
	$ID = $tid if $tid;
	my $self = CXGN::Page::Session::new($class, $dbh);
	$self->{user_type} = $user_type;

	#This is why we redefine the constructor:
	my $vhost = CXGN::VHost->new();
	$self->{vhost} = $vhost;
	if($vhost->get_conf('devel_type') eq "local"){
		foreach	my $k (@VALID_KEYS) {
			$self->alter_setting($k, $vhost->get_conf($k)) if $vhost->get_conf($k);
		}
	}
	$self->save();  
	return $self;
}

sub is_developer {
	my $self = shift;
	return 1 if $self->{user_type} eq "curator";
	return 0;
}

1;
