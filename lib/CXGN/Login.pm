
=head1 NAME

CXGN::Login - deal with browser site login

=head1 DESCRIPTION

This is an object which handles logging users in and out of our sites.

This class inherits from L<CXGN::DB::Object>.

=head1 EXAMPLES

    #example 1
    #kick user out if they are not logged in. if they are not logged in, your code will exit here and they will be sent to the login page.
    #if they are logged in, you will get their person id and your code will continue to execute.
    my $person_id=CXGN::Login->new()->verify_session();

    #example 2
    #kick user out if they are not logged in. if they are not logged in, your code will exit here and they will be sent to the login page.
    #if they are logged in, you will get their person id and user type and your code will continue to execute.
    my($person_id,$user_type)=CXGN::Login->new($dbh)->verify_session();

    #example 3
    #let everyone view this page, but if they are logged in, get their person id so you can give them a customized page. your code will
    #continue execution after this line no matter what.
    my $person_id=CXGN::Login->new($dbh)->has_session();

    #example 4
    #let everyone view this page, but if they are logged in, get their person id and user type so you can give them a customized page.
    #your code will continue execution after this line no matter what.
    my($person_id,$user_type)=CXGN::Login->new($dbh)->has_session();

=head1 AUTHOR

John Binns <zombieite@gmail.com>

=cut

package CXGN::Login;
use strict;
use warnings;

use Digest::MD5 qw(md5);
use String::Random;
use CXGN::Cookie;

use CatalystX::GlobalContext '$c';

use base qw | CXGN::DB::Object |;

our $LOGIN_COOKIE_NAME = 'sgn_session_id';
our $LOGIN_PAGE        = '/user/login';
our $LOGIN_TIMEOUT     = 7200;                    #seconds for login to timeout
our $DBH;
our $EXCHANGE_DBH = 1;

=head2 constructor new()

 Usage:        my $login = CXGN::Login->new($dbh)
 Desc:         creates a new login object
 Ret:          
 Args:         a database handle
 Side Effects: connects to database
 Example:

=cut

sub new {
    my $class = shift;
    my $dbh   = shift;
    my $self  = $class->SUPER::new($dbh);
    $self->set_sql()
      ;    #### This SQL should really be in the CXGN::People::Person object!

    foreach (@_) {
        if ( ref($_) eq "HASH" ) {

            #Process hash args here
            $self->{no_redirect} = $_->{NO_REDIRECT};
            last;
        }
    }
    $self->{conf_object} = $c || do{ require SGN::Context; SGN::Context->new };
    return $self;
}

=head2 get_login_status

 Usage:        my %logged_in_status = $login -> get_login_status();
 Desc:         a member function. This was changed on 5/1/2009.
 Ret:          a hash with user_type as a key and count of logins as a value
 Args:         none
 Side Effects: accesses the database
 Example:

=cut

sub get_login_status {
    my $self = shift;

    my $sth = $self->get_sql("stats_aggregate");
    $sth->execute($LOGIN_TIMEOUT);

    my %logins = ();
    while ( my ( $user_type, $count ) = $sth->fetchrow_array() ) {
        $logins{$user_type} = $count;
    }
    if ( !$logins{curator} )   { $logins{curator}   = "none"; }
    if ( !$logins{submitter} ) { $logins{submitter} = "none"; }
    if ( !$logins{user} )      { $logins{user}      = "none"; }

    $sth = $self->get_sql("stats_private");
    $sth->execute($LOGIN_TIMEOUT);

    $logins{detailed} = {};
    while ( my ( $user_type, $username, $contact_email ) =
        $sth->fetchrow_array() )
    {
        $logins{detailed}->{$user_type}->{$username}->{contact_email} =
          $contact_email;
    }

    if (wantarray) {
        return %logins;
    }
    else {
        return \%logins;
    }
}

=head2 get_login_info

 Usage:         $login->get_login_info()
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_login_info {
    my $self = shift;
    return $self->{login_info};
}

=head2 verify_session

 Usage:        $login->verify_session($user_type)
 Desc:         checks whether a user is logged in currently and 
               is of the minimum user type $user_type. 
               user types have the following precedence:
               user < submitter < sequencer < curator
 Ret:          the person_id, if a session exists
 Args:         a minimum user type required to access the page
 Side Effects: redirects the website to the login page if no login
               is currently defined.
 Example:

=cut

sub verify_session {
    my $self = shift;
    my ($user_must_be_type) = @_;
    my ( $person_id, $user_type ) = $self->has_session();
    if ($person_id) {    #if they have a session
        if ($user_must_be_type)
        {                #if there is a type that they must be to view this page

            if ( $user_must_be_type ne $user_type )
            {            #if they are not the required type, send them away

                return;;
            }
        }
    }
    else {               #else they do not have a session, so send them away

        return;
    }
    if (wantarray)
    { #if they are trying to get both pieces of info, give it to them, in array context

        return ( $person_id, $user_type );
    }
    else {    #else they just care about the login id

        return $person_id;
    }
}

=head2 has_session ()

if the user is not logged in, the return value is false;
else it's the person ID if in scalar context, or (person ID, user type) in array context

=cut

sub has_session {
    my $self = shift;

    #if people are not allowed to be logged in, return
    if ( !$self->login_allowed() ) {
        return;
    }

    my $cookie = $self->get_login_cookie();

    #if they have no cookie, they are not logged in
    unless ($cookie) {
        return;
    }

    my ( $person_id, $user_type, $user_prefs, $expired ) =
      $self->query_from_cookie($cookie);

    #if cookie string is not found, they are not logged in
    unless ( $person_id and $user_type ) {
        return;
    }

    #if their cookie is good but their timestamp is old, they are not logged in
    if ($expired) {
        return;
    }

    ################################
    # Ok, they are logged in! yay! #
    ################################

    $self->{login_info}->{person_id}     = $person_id;
    $self->{login_info}->{cookie_string} = $cookie;
    $self->{login_info}->{user_type}     = $user_type;
    $self->{login_info}->{user_prefs}    = $user_prefs;
    $self->update_timestamp();

#if they are trying to get both pieces of info, give it to them, in array context
    if (wantarray) {
        return ( $person_id, $user_type );
    }

    #or they just care about the login id
    else {
        return $person_id;
    }
}

sub query_from_cookie {
    my $self          = shift;
    my $cookie_string = shift;

    my $sth = $self->get_sql("user_from_cookie");
    return undef unless $sth;
    if ( !$sth->execute( $LOGIN_TIMEOUT, $cookie_string ) ) {
        print STDERR "Cookie Query Error: " . $DBH->errstr;
        return undef;
    }
    my @result = $sth->fetchrow_array();

    return undef unless scalar(@result);

    #if TWO rows are found with the SAME cookie_string, scream!
    if ( scalar(@result) && $sth->fetchrow_array() ) {
        die
"Duplicate cookie_string entries found for cookie string '$cookie_string'";
    }

#Return info, or just the person_id, depending on array/scalar context of function
    if (wantarray) {
        return @result;
    }
    else {
        return $result[0];
    }
}

sub login_allowed {
    my $self = shift;

#conditions for allowing logins:
#
#    1. configuration 'disable_login' must be 0 or undef
#    2. configuration 'is_mirror' must be 0 or undef
#    3. configuration 'dbname' must not be 'sandbox' if configuration 'production_server' is 1
#     -- the reason for this is that if users can log in, they must be able to log in to the REAL database,
#        not some mirror or some sandbox, because logged-in users can CHANGE data in the database and we
#        don't want to lose or ignore those changes.
    if (
            !$self->{conf_object}->get_conf('disable_login')
        and !$self->{conf_object}->get_conf('is_mirror')

#we haven't decided whether it's a good idea to comment this next line by default -- Evan
        and !(
                $self->{conf_object}->get_conf('dbname') =~ /sandbox/
            and $self->{conf_object}->get_conf('production_server')
        )
      )
    {
        return 1;
    }
    else {
	print STDERR "Login is disabled if dbname contains 'sandbox' and production_server is set to 1\n";
        return 0;
    }
}

=head2 login_user

 Usage:        $login->login_user($username, $password);
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub login_user {
    my $self = shift;
    my ( $username, $password ) = @_;
    my $login_info
      ;    #information about whether login succeeded, and if not, why not
    if ( $self->login_allowed() ) {
        my $sth = $self->get_sql("user_from_uname_pass");

	print STDERR "NOW LOGGING IN USER $username\n";
        my $num_rows = $sth->execute( $username, $password );

        my ( $person_id, $disabled, $user_prefs, $first_name, $last_name ) = $sth->fetchrow_array();

	print STDERR "FOUND: $person_id\n";
        if ( $num_rows > 1 ) {
            die "Duplicate entries found for username '$username'";
        }
        if ($disabled) {
            $login_info->{account_disabled} = $disabled;
        }

        else {
            $login_info->{user_prefs} = $user_prefs;
            if ($person_id) {
                my $new_cookie_string =
                  String::Random->new()
                  ->randpattern(
"ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
                  );
                $sth = $self->get_sql("cookie_string_exists");
                $sth->execute($new_cookie_string);
                if ( $sth->fetchrow_array()
                  )    #very unlikely--or we need a new random string generator
                {
                    $login_info->{duplicate_cookie_string} = 1;
                }
                else {
                    $sth = $self->get_sql("login");
                    $sth->execute( $new_cookie_string, $person_id );
                    CXGN::Cookie::set_cookie( $LOGIN_COOKIE_NAME,
                        $new_cookie_string );
                    CXGN::Cookie::set_cookie( "user_prefs", $user_prefs );
                    $login_info->{person_id}     = $person_id;
                    $login_info->{first_name}     = $first_name;
                    $login_info->{last_name}     = $last_name;
                    $login_info->{cookie_string} = $new_cookie_string;
                }
            }
            else {
                $login_info->{incorrect_password} = 1;
            }
        }
    }
    else {
        $login_info->{logins_disabled} = 1;
    }
    $self->{login_info} = $login_info;
    return $login_info;
}

=head2 function logout_user()

 Usage:        $login->logout_user();
 Desc:         log out the current logged in user
 Ret:          nothing  
 Args:         none
 Side Effects: resets the cookie to empty
 Example:

=cut

sub logout_user {
    my $self   = shift;
    my $cookie = $self->get_login_cookie();
    if ($cookie) {
        my $sth = $self->get_sql("logout");
        $sth->execute($cookie);
        CXGN::Cookie::set_cookie( $LOGIN_COOKIE_NAME, "" );
    }
}

=head2 update_timestamp

 Usage:        $login->update_timestamp();
 Desc:         updates the timestamp, such that users don't 
               get logged out when they are active on the site.
 Ret:          nothing
 Args:         none
 Side Effects: accesses the database to change the timeout status.
 Example:

=cut

sub update_timestamp {
    my $self   = shift;
    my $cookie = $self->get_login_cookie();
    if ($cookie) {
        my $sth = $self->get_sql("refresh_cookie");
        $sth->execute($cookie);
    }
}

=head2 get_login_cookie

 Usage:        my $cookie = $login->get_login_cookie();
 Desc:         returns the cookie for the current login
 Args:         none
 Side Effects: 
 Example:

=cut

sub get_login_cookie {
    my $self = shift;
    return CXGN::Cookie::get_cookie($LOGIN_COOKIE_NAME);
}

=head2 login_page_and_exit
##DEPRECATED: redirect should happen in a catalyst controller, not in an object like CXGN::Login

 Usage:        $login->login_page_and_exit();
 Desc:         redirects to the login page.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

#sub login_page_and_exit {
#    my $self = shift;
    #CGI redirect crashes server when used from a catalyst controller.
    #Redirecting should happen in controller, not in an object like CXGN::Login
    #print CGI->new->redirect( -uri => $LOGIN_PAGE, -status => 302 );
    #exit;
#}

###
### helper function. SQL should probably be moved to the CXGN::People::Login class
###

sub set_sql {
    my $self = shift;

    $self->{queries} = {

        user_from_cookie =>    #send: session_time_in_secs, cookiestring

          "	SELECT 
				sp_token.sp_person_id,
				sgn_people.sp_roles.name as user_type,
				user_prefs,
				extract (epoch FROM current_timestamp-sp_token.last_access_time)>? AS expired 
			FROM 
				sgn_people.sp_person JOIN sgn_people.sp_person_roles using(sp_person_id) join sgn_people.sp_roles using(sp_role_id) JOIN sgn_people.sp_token on(sgn_people.sp_person.sp_person_id = sgn_people.sp_token.sp_person_id)
			WHERE 
				sp_token.cookie_string=?
                        ORDER BY sp_role_id
                        LIMIT 1",

        user_from_uname_pass =>

          "	SELECT 
				sp_person_id, disabled, user_prefs, first_name, last_name
			FROM 
				sgn_people.sp_person 
			WHERE 
				UPPER(username)=UPPER(?) 
				AND (sp_person.password = crypt(?, sp_person.password))",

        cookie_string_exists =>

          "	SELECT 
				sgn_people.sp_token.cookie_string 
			FROM 
				sgn_people.sp_person JOIN sgn_people.sp_token using(sp_person_id) 
			WHERE 
				sp_token.cookie_string=?",

        login =>    #send: cookie_string, sp_person_id

          "	INSERT INTO
				sgn_people.sp_token(cookie_string, sp_person_id, last_access_time) 
			VALUES ( 
				?,
				?, 
				current_timestamp
            )",
            

        logout =>    #send: cookie_string

          "	UPDATE 
				sgn_people.sp_token 
			SET 
				cookie_string=null,
				last_access_time=current_timestamp 
			WHERE 
				cookie_string=?",

        refresh_cookie =>    #send: cookie_string  (updates the timestamp)

          "	UPDATE 
				sgn_people.sp_token
			SET 
				last_access_time=current_timestamp 
			WHERE 
				cookie_string=?",

        stats_aggregate => #send:  session_timeout_in_secs (gets aggregate login data)

          "	SELECT  
				sp_roles.name, count(*) 
			FROM 
				sgn_people.sp_person
                        JOIN    sgn_people.sp_person_roles USING(sp_person_id)
                        JOIN    sgn_people.sp_roles USING(sp_role_id)
                        JOIN    sgn_people.sp_token on(sgn_people.sp_person.sp_person_id=sgn_people.sp_token.sp_person_id)
           
			WHERE 
				sp_token.last_access_time IS NOT NULL 
				AND sp_token.cookie_string IS NOT NULL 	
				AND extract(epoch from now()-sp_token.last_access_time)<? 
			GROUP BY 	
				sp_roles.name",

        stats_private => #send: session_timeout_in_secs (gets all logged-in users)

          "	SELECT 
				sp_roles.name as user_type, username, contact_email 
			FROM 
				sgn_people.sp_person JOIN sgn_people.sp_person_roles using(sp_person_id) JOIN sgn_people.sp_roles using (sp_role_id) JOIN sgn_people.sp_token on (sgn_people.sp_person.sp_person_id=sgn_people.sp_token.sp_person_id)
			WHERE 
				sp_token.last_access_time IS NOT NULL 
				AND sp_token.cookie_string IS NOT NULL	
				AND extract(epoch from now()-sp_token.last_access_time)<?",

    };

    while ( my ( $name, $sql ) = each %{ $self->{queries} } ) {
        $self->{query_handles}->{$name} = $self->get_dbh()->prepare($sql);
    }

}

sub get_sql {
    my $self = shift;
    my $name = shift;
    return $self->{query_handles}->{$name};
}

###
1;    #do not remove
###

