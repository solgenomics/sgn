
package SGN::Controller::AJAX::User;

use Moose;
use IO::File;
use Data::Dumper;
use HTML::Entities;
use CXGN::People::Roles;
use CXGN::BreedingProgram;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub login : Path('/ajax/user/login') Args(0) {
    my $self = shift;
    my $c = shift;

    my $username = $c->req->param("username");
    my $password = $c->req->param("password");
    my $goto_url = $c->req->param("goto_url");

    $goto_url = $c->req->referer if $goto_url eq '/';
    print STDERR "Goto URL = $goto_url\n";

    my $login = CXGN::Login->new($c->dbc->dbh());
    my $login_info = $login->login_user($username, $password);

    if (exists($login_info->{incorrect_password}) && $login_info->{incorrect_password} == 1) {
	$c->stash->{rest} = { error => "Login credentials are incorrect. Please try again." };
	return;
    }
    elsif (exists($login_info->{account_disabled}) && $login_info->{account_disabled}) {
	$c->stash->{rest} = { error => "This account has been disabled due to $login_info->{account_disabled}. Please contact the database to fix this problem." };
	return;
    }
    else {
	$c->stash->{rest} = {
	    message => "Login successful",
	    goto_url => $goto_url
	};
    }
}

sub logout :Path('/ajax/user/logout') Args(0) {
    my $self = shift;
    my $c = shift;

    my $login = CXGN::Login->new($c->dbc->dbh());
    $login->logout_user();

    $c->stash->{rest} = { message => "User successfully logged out." };
}

sub new_account :Path('/ajax/user/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    print STDERR "Adding new account...\n";
    if ($c->config->{is_mirror} || $c->config->{reject_new_users}) {
	$c->stash->{template} = '/system_message.mas';
	$c->stash->{message} = "This site is a mirror site and does not support adding users. Please go to the main site to create an account.";
	return;
    }


    my ($first_name, $last_name, $username, $password, $confirm_password, $email_address, $organization, $breeding_program_ids)
	= map { $c->req->params->{$_} } (qw|first_name last_name username password confirm_password email_address organization breeding_programs|);

    # Set organization from breeding programs, if provided
    if ($breeding_program_ids && ref($breeding_program_ids) ne 'ARRAY') {
        $breeding_program_ids = [$breeding_program_ids];
    }
    my @breeding_program_names;
    if ( !$organization && $breeding_program_ids ) {
        foreach my $breeding_program_id (@$breeding_program_ids) {
            my $breeding_program = CXGN::BreedingProgram->new({ schema=> $schema , program_id => $breeding_program_id });
            push(@breeding_program_names, $breeding_program->get_name());
        }
        $organization = join(', ', @breeding_program_names);
    }

    if ($username) {
	#
	# check password properties...
	#
	my @fail = ();
	if (length($username) < 7) {
	    push @fail, "Username is too short. Username must be 7 or more characters";
	} elsif ( $username =~ /\s/ ) {
        push @fail, "Username must not contain spaces";
    } else {
	    # does user already exist?
	    #
	    my $existing_login = CXGN::People::Login -> get_login($c->dbc()->dbh(), $username);

	    if ($existing_login->get_username()) {
		push @fail, "Username \"$username\" is already in use. Please pick a different username.";
	    }

	}
	if (length($password) < 7) {
	    push @fail, "Password is too short. Password must be 7 or more characters";
	}
	if ("$password" ne "$confirm_password") {
	    push @fail, "Password and confirm password do not match.";
	}

	if ($password eq $username) {
	    push @fail, "Password must not be the same as your username.";
	}
	if ($email_address !~ m/[^\@]+\@[^\@]+/) {
	    push @fail, "Email address is invalid.";
	}
    if ( $email_address ) {
        my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc()->dbh(), $email_address);
        if ( scalar(@person_ids) > 0 ) {
            push @fail, "Email address is already associated with an account.";
        }
    }
	unless($first_name) {
	    push @fail,"You must enter a first name or initial.";
	}
	unless($last_name) {
	    push @fail,"You must enter a last name.";
	}

	if (@fail) {
	    $c->stash->{rest} = { error => "Account creation failed for the following reason(s): ".(join ", ", @fail) };
	    return;
	}
    }

    my $confirm_code = $self->tempname();
    my $new_user = CXGN::People::Login->new($c->dbc->dbh());
    $new_user -> set_username($username);
    $new_user -> set_pending_email($email_address);
    $new_user -> set_disabled('unconfirmed account');
    $new_user -> set_organization($organization);
    $new_user -> store();

    print STDERR "Generated sp_person_id ".$new_user->get_sp_person_id()."\n";
    print STDERR "Update password and confirm code...\n";
    $new_user->update_password($password);
    $new_user->update_confirm_code($confirm_code);

    print STDERR "Store Person object...\n";
    #this is being added because the person object still uses two different objects, despite the fact that we've merged the tables
    my $person_id=$new_user->get_sp_person_id();
    my $new_person=CXGN::People::Person->new($c->dbc->dbh(),$person_id);
    $new_person->set_first_name($first_name);
    $new_person->set_last_name($last_name);
    $new_person->store();

    # Add user to breeding programs
    if ( $c->config->{user_registration_join_breeding_programs} ) {
        my $person_roles = CXGN::People::Roles->new({ people_schema => $people_schema });
        my $sp_roles = $person_roles->get_sp_roles();
        my %roles = map {$_->[0] => $_->[1]} @$sp_roles;
        foreach my $breeding_program_name (@breeding_program_names) {
            my $role_id = $roles{$breeding_program_name};
            if ( !$role_id ) {
		        my $error = $person_roles->add_sp_role($breeding_program_name);
                if ( $error ) {
                    print STDERR "ERROR: Could not create role $breeding_program_name [$error]\n";
                }
                else {
                    my $new_sp_roles = $person_roles->get_sp_roles();
                    my %new_roles = map {$_->[0] => $_->[1]} @$new_sp_roles;
                    $role_id = $new_roles{$breeding_program_name};
                }
            }
            if ( $role_id ) {
                my $add_role = $person_roles->add_sp_person_role($person_id, $role_id);
            }
        }
    }

    # Add additional user details for admin confirmation
    my $user_details = '';
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        $user_details .= "Name: $first_name $last_name\n";
        $user_details .= "Email: $email_address\n";
        $user_details .= "Organization(s): $organization\n";
    }

    my $host = $c->config->{main_production_site_url};
    my $project_name = $c->config->{project_name};
    my $subject="[$project_name] Email Address Confirmation Request";
    my $body=<<END_HEREDOC;

This message is sent to confirm the email address for community user
\"$username\"
$user_details

Please click (or cut and paste into your browser) the following link to
confirm your account and email address:

$host/user/confirm?username=$username&confirm_code=$confirm_code

Thank you,
$project_name Team

Please do *NOT* reply to this message. If you have any trouble confirming your
email address or have any other questions, please use the contact form instead:
$host/contact/form

END_HEREDOC

    # Send confirmation email to admin
    my $message = "";
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        CXGN::Contact::send_email($subject,$body,'user_registration_admin_confirmation_email');
        $message = "Your account has been created but first must be confirmed by the site administrators.  You will receive an email once your account has been confirmed.";
    }

    # Send confirmation email to user
    else {
        CXGN::Contact::send_email($subject,$body,$email_address);
        $message = "To continue, you must confirm that we can reach you via email address \"$email_address\". An email has been sent with a URL to confirm this address. Please check your email for this message and use the link to confirm your email address.";
    }

    $c->stash->{rest} = {
        message => "Account was created with username \"$username\".\n\n$message\n\nYou will be able to login once your account has been confirmed."
    };
}


sub change_account_info_action :Path('/ajax/user/update') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user() ) {
        $c->stash->{rest} = { error => "You must be logged in to use this page." };
	return;
    }

    my $person = CXGN::People::Login->new($c->dbc->dbh(), $c->user->get_sp_person_id());

#    my ($current_password, $change_username, $change_password, $change_email) = $c->req->param({qw(current_password change_username change_password change_email)});

    my $args = $c->req->params();

    if (!$args->{change_password} && ! $args->{change_username} && !$args->{change_email}) {
	my $error = "No actions were requested. Please select which fields you would like to update by checking the appropriate checkbox(es) on the form and entering your new information.";
	print STDERR $error;
	$c->stash->{rest} =  { error => $error };
	return;
    }

    chomp($args->{current_password});
    if (! $person->verify_password($args->{current_password})) {
	my $error = "Your current password does not match SGN records.";
	print STDERR $error;
	$c->stash->{rest} = { error => "$error" };
	return;
    }

    # Check for error conditions in all changes, before making any of them.
    # Otherwise, we could end up making some changes and then failing on later
    # ones. The user would then push the back button and their information may
    # be different now but they will probably assume no changes were made. This
    # is most troublesome if the current password changes.
    #
    if ($args->{change_username}) {
	#unless change_username is set, new_username won't be in the args hash because of the prestore test
	my $new_username = $args->{new_username};
	if(length($new_username) < 7) {
	    my $error = "Username must be at least 7 characters long.";
	    print STDERR $error;
	    $c->stash->{rest} = { error => $error  };
	    return;
	}

	my $other_user = CXGN::People::Login->get_login($c->dbc->dbh(), $new_username);
	if (defined $other_user->get_sp_person_id() &&
	    ($person -> get_sp_person_id() != $other_user->get_sp_person_id())) {
	    print STDERR "Username alread in use.\n";
	    $c->stash->{rest} = { error =>  "Username \"$new_username\" is already in use. Please select a different username." };
	    return;
	}

	$person->set_username($new_username);
	$person->store();
    }

    if ($args->{change_password}) {
	#unless change_password is set, new_password won't be in the args hash because of the prestore test
	my ($new_password, $confirm_password) = ($args->{new_password}, $args->{confirm_password});
	if(length($args->{new_password}) < 7) {
	    print STDERR "Password too short\n";
	    $c->stash->{rest} = { error => "Passwords must be at least 7 characters long. Please try again." };
	    return;
	}
	#format check
	if($args->{new_password} !~ /^[a-zA-Z0-9~!@#$^&*_.=:;<>?]+$/) {
	    print STDERR "Illegal characters in password\n";
	    $c->stash->{rest} = { error => "An error occurred. Please use your browser's back button to try again.. The Password can't contain spaces or these symbols: <u><b>` ( ) [ ] { } - + ' \" / \\ , |</b></u>." };
	    return;
	}
	if($args->{new_password} ne $args->{confirm_password}) {
	    print STDERR "Password don't match.\n";
	    $c->stash->{rest} = { error => "New password entries do not match. You must enter your new password twice to verify accuracy." };
	    return;
	}

	print STDERR "Saving new password to the database\n";
	$person->update_password($args->{new_password});
    }

    my $user_private_email = $c->user->get_private_email();
    if($args->{change_email}) {
	#unless change_email is set, private_email won't be in the args hash because of the prestore test
	my ($private_email, $confirm_email) = ($args->{private_email}, $args->{confirm_email});
	if($private_email !~ m/^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$/) {
	    print STDERR "Invalid email address\n";
	    $c->stash->{rest} = { error => "An error occurred. Please use your browser's back button to try again. The E-mail address \"$private_email\" does not appear to be a valid e-mail address." };
	    return;
	}
	if($private_email ne $confirm_email) {
	    print STDERR "Emails don't match\n";
	    $c->stash->{rest} = { error => "An error occurred. Please use your browser's back button to try again. New e-mail address entries do not match. You must enter your new e-mail address twice to verify accuracy." };
	    return;
	}

	print STDERR "Saving private email '$private_email' to the database\n";
	$person->set_private_email($private_email);
	my $confirm_code = $self->tempname();
	$person->set_confirm_code($confirm_code);
	$person->store();

	$user_private_email = $private_email;

	$self->send_confirmation_email($args->{username}, $user_private_email, $confirm_code, $c->config->{main_production_site_url});

    }

    $c->stash->{rest} = { message => "Update successful" };

}

sub send_confirmation_email {
    my ($self, $username, $private_email, $confirm_code, $host) = @_;
    my $subject = "[SGN] E-mail Address Confirmation Request";

    my $body = <<END_HEREDOC;

You requested an account on the site $host.

Please do *NOT* reply to this message. The return address is not valid.
Use the contact form at $host/contact/form instead.

This message is sent to confirm the private e-mail address for community user
\"$username\".

Please click (or cut and paste into your browser) the following link to
confirm your account and e-mail address:

  $host/user/confirm?username=$username&confirm=$confirm_code

Thank you.
Sol Genomics Network
END_HEREDOC

   CXGN::Contact::send_email($subject, $body, $private_email);
}


sub forgot_username : Path('/ajax/user/forgot_username') Args(0) {
    my $self = shift;
    my $c = shift;

    my $email = $c->req->param('forgot_username_email');
    my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc->dbh(), $email);
    $self->send_forgot_username_email_message($c, $email, \@person_ids);

    $c->stash->{rest} = {
        message => "Username email sent. Please check your email for a message containing the username(s) of any accounts associated with your email address."
    };
}


sub reset_password :Path('/ajax/user/reset_password') Args(0) {
    my $self = shift;
    my $c = shift;

    my $email = $c->req->param('password_reset_email');

    my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc->dbh(), $email);

    if (!@person_ids) {
	$c->stash->{rest} = { error => "The provided email ($email) is not associated with any account." };
	return;
    }

    if (@person_ids > 1) {
	$c->stash->{rest} = { message => "The provided email ($email) is associated with multiple accounts. An email is sent for each account. Please notify the database team using the contact form to consolidate the accounts." };
    }

    my @reset_links;
    my @reset_tokens;
    foreach my $pid (@person_ids) {
        my $email_reset_token = $self->tempname();
        my $reset_link = $c->config->{main_production_site_url}."/user/reset_password_form?reset_password_token=$email_reset_token";
        my $person = CXGN::People::Login->new( $c->dbc->dbh(), $pid);
        $person->update_confirm_code($email_reset_token);
        print STDERR "Sending reset link $reset_link\n";
        $self->send_reset_email_message($c, $pid, $email, $reset_link, $person->{username});
        push @reset_links, $reset_link;
        push @reset_tokens, $email_reset_token;
    }

    $c->stash->{rest} = {
        message => "Reset link sent. Please check your email and click on the link.",
        reset_links => \@reset_links,
        reset_tokens => \@reset_tokens
    };
}

sub process_reset_password_form :Path('/ajax/user/process_reset_password') Args(0) {
    my $self = shift;
    my $c = shift;

    my $token = $c->req->param("token");
    my $confirm_password = $c->req->param("confirm_password");
    my $new_password = $c->req->param("new_password");

    if (length($new_password) < 7) {
        $c->stash->{rest} = { error => "Password is too short. Password must be 7 or more characters" };
        $c->detach();
    }

    if ($confirm_password ne $new_password){
        $c->stash->{rest} = { error => "Please enter the same password in the confirm password field!" };
        $c->detach();
    }

    eval {
        my $q = "SELECT sp_person_id FROM sgn_people.sp_person WHERE confirm_code=?;";
        my $h = $c->dbc->dbh()->prepare($q);
        $h->execute($token);
        my ($person_id) = $h->fetchrow_array();
        my $login = CXGN::People::Login->new($c->dbc->dbh(), $person_id);
        $login->update_password($new_password);
        $login->update_confirm_code("");
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
    }
    else {
        $c->stash->{rest} = { message => "The password was successfully updated." };
    }
}


sub send_forgot_username_email_message {
    my $self = shift;
    my $c = shift;
    my $email = shift;
    my $person_ids = shift;

    my @usernames;
    foreach my $pid (@$person_ids) {
        my $person = CXGN::People::Login->new( $c->dbc->dbh(), $pid);
        push(@usernames, $person->get_username());
    }
    my $username_message = @usernames > 0 ? "The following username(s) are associated with your email address: " . join(', ', @usernames)
        : "There are no accounts associated with your email address.";

    my $project_name = $c->config->{project_name};
    my $subject = "[$project_name] Forgot Username Request";
    my $main_url = $c->config->{main_production_site_url};

    my $body = <<END_HEREDOC;

Hi,

You have requested the username(s) for accounts associated with this email address on $main_url.

$username_message

If this request did not come from you, please let us know.

To contact us, please do NOT reply to this message; rather, use the contact form ($main_url/contact/form) instead.

Thank you.

Your friends at $project_name

END_HEREDOC

   CXGN::Contact::send_email($subject, $body, $email);
}

sub send_reset_email_message {
    my $self = shift;
    my $c = shift;
    my $pid = shift;
    my $private_email = shift;
    my $reset_link = shift;
    my $person = shift;

    my $project_name = $c->config->{project_name};
    my $subject = "[$project_name] Password Reset Request";
    my $main_url = $c->config->{main_production_site_url};

    my $body = <<END_HEREDOC;

Hi,

The user $person has requested a password reset on $main_url.

If this request did not come from you, please let us know.

To contact us, please do NOT reply to this message; rather, use the contact form ($main_url/contact/form) instead.

Your password can be reset using the following link, which you can either click or cut and paste into your browser:

$reset_link

Thank you.

Your friends at $main_url

END_HEREDOC

   CXGN::Contact::send_email($subject, $body, $private_email);
}

sub tempname {
    my $self = shift;
    my $rand_string = "";
    my $dev_urandom = IO::File->new("</dev/urandom") || print STDERR "Can't open /dev/urandom";
    $dev_urandom->read( $rand_string, 16 );
    my @bytes = unpack( "C16", $rand_string );
    $rand_string = "";
    foreach (@bytes) {
        $_ %= 62;
        if ( $_ < 26 ) {
            $rand_string .= chr( 65 + $_ );
        }
        elsif ( $_ < 52 ) {
            $rand_string .= chr( 97 + ( $_ - 26 ) );
        }
        else {
            $rand_string .= chr( 48 + ( $_ - 52 ) );
        }
    }
    return $rand_string;
}

sub get_login_button_html :Path('/ajax/user/login_button_html') Args(0) {
    my $self = shift;
    my $c = shift;
    eval {
	my $production_site = $c->config->{main_production_site_url};
	my $html = "";
	# if the site is a mirror, gray out the login/logout links
	if( $c->config->{'is_mirror'} ) {
	    print STDERR "generating login button for mirror site...\n";
	    $html = <<HTML;
	    <a style="line-height: 1.2; text-decoration: underline; background: none" href="$production_site" title="log in on main site">main site</a>
	} elsif ( $c->config->{disable_login} ) {
	    <li class="dropdown">
		<div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
		<button class="btn btn-primary disabled" type="button" style="margin: 7px 7px 0px 0px">Login</button>
		</div>
		</li>

HTML

    } elsif ( $c->req->uri->path_query =~ "logout=yes") {
	print STDERR "generating login button for logout...\n";
	$html = <<HTML;
  <li class="dropdown">
      <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
	<a href="/user/login">
          <button class="btn btn-primary" type="button" style="margin: 7px 7px 0px 0px">Login</button>
	</a>
      </div>
  </li>
HTML

} elsif ( $c->user_exists ) {
    print STDERR "Generate login button for logged in user...\n";
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $username = $c->user->get_username();
    $html = <<HTML;
      <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 3px 0px 0px">
	<button id="navbar_profile" class="btn btn-primary" type="button" onclick='location.href="/solpeople/profile/$sp_person_id"' style="margin: 7px 0px 0px 0px" title="My Profile">$username</button>
	<button id="navbar_lists" name="lists_link" class="btn btn-info" style="margin:7px 0px 0px 0px" type="button" title="Lists" onClick="show_lists();">
        Lists <span class="glyphicon glyphicon-list-alt" ></span></button>
	<button id="navbar_datasets" name="lists_link" class="btn btn-info" style="margin:7px 0px 0px 0px" type="button" title="Datasets" onClick="window.location='/search/datasets';">
              <span class="glyphicon glyphicon-list-alt" ></span>&nbsp;<span class="hidden-sm">Datasets</span></button>
	<button id="navbar_personal_calendar" name="personal_calendar_link" class="btn btn-primary" style="margin:7px 0px 0px 0px" type="button" title="Your Calendar">Calendar&nbsp;<span class="glyphicon glyphicon-calendar" ></span></button>
	<button id="navbar_logout" class="btn btn-default glyphicon glyphicon-log-out" style="margin:6px 0px 0px 0px" type="button" onclick="logout();" title="Logout"></button>
      </div>
HTML

  } else {
      print STDERR "generating regular login button..\n";
      $html = qq |
      <li class="dropdown">
        <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
            <button id="site_login_button" name="site_login_button" class="btn btn-primary" type="button" style="margin: 7px 7px 0px 0px; position-absolute: 10,10,100,10">Login</button>
        </div>
      </li>
 |;

};
	if ($@) {
	    print STDERR "ERROR: $@\n";
	    $c->stash->{rest} = { error => $@ };
	}
	return $c->stash->{rest} = { html => $html, logged_in => $c->user_exists };
    }
}

sub quick_create_user :Path('/ajax/user/quick_create_account') Args(0) {
    my $self = shift;
    my $c = shift;

     if (!$c->user()) {
	$c->stash->{rest} = { error => "Need to be logged in to use feature." };
	return;
    }

    if (!$c->user()->check_roles("curator")) {
	$c->stash->{rest} = { error => "You don't have the privileges to use this feature" };
	return;
    }
    my $logged_in_person_id = $c->user()->get_sp_person_id();

    my $logged_in_user=CXGN::People::Person->new($c->dbc->dbh(), $logged_in_person_id);
    $logged_in_person_id=$logged_in_user->get_sp_person_id();
    my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
    my $logged_in_user_type=$logged_in_user->get_user_type();

    my ($username, $password, $confirm_password, $email_address, $new_user_type, $first_name, $last_name) =
	map { print STDERR $_." ".$c->req->param($_)."\n"; $c->req->param($_) } qw | username password confirm_password confirm_email user_type first_name last_name |;

    print STDERR "$username, $password, $confirm_password, $email_address, $new_user_type, $first_name, $last_name\n";

    my $new_user_login=CXGN::People::Login->new($c->dbc->dbh);

    if ($username) {
        my @fail=();

	if(length($username)<7){push @fail,"Username is too short. Username must be 7 or more characters";}
        my $existing_login=CXGN::People::Login->get_login($c->dbc->dbh, $username);

        if($existing_login->get_username()){push @fail,"Username \"$username\" is already in use. Please pick a different us
ername.";}

	if(length($password)<7){push @fail,"Password is too short. Password must be 7 or more characters";}

	if("$password" ne "$confirm_password"){push @fail,"Password and confirm password do not match.";}

	if($password eq $username){push @fail,"Password must not be the same as your username.";}

	if($new_user_type ne 'user' and $new_user_type ne 'sequencer' and $new_user_type ne 'submitter'){
	    push @fail,"Sorry, but you cannot create user of type \"$new_user_type\" with web interface.";}
        if(@fail)
        {
            my $fail_str="";
            foreach(@fail)
            {
                $fail_str .= "<li>$_</li>\n"
            }
	    $c->stash->{rest} = { error => $fail_str };
	    return;

        }
    }

    my $encoded_username = encode_entities($username);
    print STDERR "USERNAME: $username. ENCODED: $encoded_username\n";
    $new_user_login->set_username($encoded_username);
    $new_user_login->set_private_email(encode_entities($email_address));
    $new_user_login->set_pending_email(encode_entities($email_address));
    $new_user_login->set_password($password);

    $new_user_login->store();

    my $new_user_person_id=$new_user_login->get_sp_person_id();
    my $new_user = CXGN::People::Person->new($c->dbc->dbh, $new_user_person_id);

    eval {

	$new_user->set_contact_email(encode_entities($email_address));
	$new_user->set_user_type(encode_entities($new_user_type));
	$new_user->set_first_name(encode_entities($first_name));
	$new_user->set_last_name(encode_entities($last_name));

	$new_user->store();
    };

    if ($@) {
	$c->stash->{rest} = { html => "An error occurred. $@" };
    }
    else {
	$c->stash->{rest} = { html => "<center><h4>Account successfully created for $first_name $last_name</h4><a href=\"/user/admin/quick_create_account\">Create another account" };
    }
}


1;
