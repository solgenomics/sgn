#!/usr/bin/perl

package CXGN::Page::Session;

use strict;
no strict 'refs';
use Carp;
use CXGN::Cookie;
use CXGN::VHost;
use CXGN::Login;
use CXGN::DB::Connection;
#use CXGN::Class::DBI;
use URI::Escape qw/uri_escape uri_unescape/;
#use base qw/CXGN::Class::DBI/;

use base qw | CXGN::DB::Object |;

#Re-define these in your subclass:
our @VALID_KEYS = ();
our $COOKIE_NAME = "";
our $DB_SCHEMA = "";
our $DB_TABLE = "";
our $DB_COLUMN = ""; #name of settings-containing column
our $ID_COLUMN = ""; #name of column to match against ID
our $ID = "";  #i.e:  $ID = CXGN::Login->new()->has_login();
#our $DBH;
#our $EXCHANGE_DBH;

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
	my $class = shift; #this should be your subclass classname
	my $dbh = shift or croak "must pass a dbh as second argument";
	my $self = $class->SUPER::new($dbh);
	$self->{settings} = {};	

	#Grab SubClass Package Variables
	#It is important to set $self->{globals}->{lc(PKG_VAR)} = $val
	#for the benefit of other functions, since the eval{} statements
	#are a pain to do twice
	my %valid_keys = ();
	my @vk = @{$class."::VALID_KEYS"};
	$valid_keys{$_} = 1 foreach @vk;
	$self->{globals}->{valid_keys} = \@vk;
	foreach my $var (qw/id id_column cookie_name db_table db_column db_schema/){ #scalars only
		$self->{globals}->{$var} = ${$class."::".uc($var)};
	}
	my $id = $self->{globals}->{id};

	unless($id) {
		eval {
			$id = CXGN::Login->new($self->get_dbh())->has_session();
		};
	}
	#If ID for database is set, collect settings
	if($id) {
	    #my $dbh = __PACKAGE__->DBH();
	#	$self->{dbh} = $dbh;
		my $sth = $self->get_dbh()->prepare(
			"	SELECT $self->{globals}->{db_column} 
				FROM $self->{globals}->{db_schema}.$self->{globals}->{db_table} 
				WHERE $self->{globals}->{id_column}=?");
		$sth->execute($id);
		if (my $row = $sth->fetchrow_hashref) {
			$self->parse_settings_string($row->{$self->{globals}->{db_column}});
		}
	}

	#Stuff in your cookie will overwrite whatever is in the database
	my $cookie_string = CXGN::Cookie::get_cookie($self->{globals}->{cookie_name});
	if($cookie_string){
		my $cookie_based = {};
		parse_settings_string($cookie_based, $cookie_string, {validate=>0});
		my ($ts) = $cookie_based->{setting}->{timestamp};
		my $db_ts = $self->get_setting('timestamp');
		if(($db_ts && $ts && $ts > $db_ts) || (!$db_ts) || (!$ts)){
			$self->parse_settings_string($cookie_string);
		}
		else {
			print STDERR "Time lag:\n
				 Cookie:  $ts\n
				 DB:      $db_ts\n";
		}
	}
	$self->save();
	return $self;
}

sub parse_settings_string {
	my $self = shift;
	my $cookie_string = shift;
	my $args = shift;
	my %valid_keys = ();
	foreach(@{$self->{globals}->{valid_keys}}){
		$valid_keys{$_} = 1;
	}
	$cookie_string = uri_unescape($cookie_string);
	my @kvs = split /:/, $cookie_string;
	foreach my $kv (@kvs) {
		my ($k, $v) = split /=/, $kv;
		$k = uri_unescape($k);
		$v = uri_unescape($v);
		next if $k eq "null"; #javascript cookie-setter does weird things sometimes
		
		unless(!$args->{validate} || $valid_keys{$k}){
			die "$k is not a valid key, according to " . __PACKAGE__  . "\n" . $cookie_string . "\n";
		}
		$self->{settings}->{$k} = $v;
	}
}

=head2 alter_setting($key,$value)

 Given a key, sets the value for a developer setting.  Since key/values are uri-encoded,
 you can specify any kind of key or value that you want.

=cut

sub alter_setting {
	my $self = shift;
	my ($k, $v) = @_;
	$self->{settings}->{$k} = $v;
}

=head2 get_setting($key)

 Gets the value of the setting key from this object

=cut

sub get_setting {
	my $self = shift;
	my $key = shift;
	return $self->{settings}->{$key};
}

sub delete_setting {
	my $self = shift;
	my $key = shift;
	delete($self->{settings}->{$key});
}

=head2 save

 Takes $this->{settings}, does uri-escaping, sets the cookie
 and the value in the database for $this->{sp_person_id}

=cut

sub save {
	my $self = shift;
	$self->alter_setting('timestamp', time()*1000);
	my @kvs = ();
	my $cookie_string = "";
	while(my($k,$v) = each %{$self->{settings}}){
		$k = uri_escape($k);
		$v = uri_escape($v);
		push(@kvs, $k . '=' . $v);
	}
	$cookie_string = join ":", @kvs;
	$cookie_string = uri_escape($cookie_string);
	CXGN::Cookie::set_cookie($self->{globals}->{cookie_name}, $cookie_string);
	if($self->{dbh}){
		my ($s, $t, $c, $id_c, $id) = map { $self->{globals}->{$_} } qw/ db_schema db_table db_column id_column id / ;
		
		my $sth = $self->{dbh}->prepare("UPDATE $s.$t SET $c=? WHERE $id_c=?");
		$sth->execute($cookie_string, $id);
	}
}

sub store { save(@_) } #alias

sub validate_key {
	my $class = shift;
	my $key = shift;
	my @vk = ();
	eval '@vk = @' . $class . '::VALID_KEYS';
	my %vk = ();
	$vk{$_} = 1 foreach @vk;

	die "Key '$key' not registered with Session Module '$class' (not in its VALID_KEYS array)\n"
		unless $vk{$key};
}

1;
