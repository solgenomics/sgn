#originally written by Koni
#edited by Evan, 1/10/07, to move to the form framework

use strict;

use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::People::Login;

my $account_info_page = new SolPeopleAccountInfoPage();

##################################################################################################

package SolPeopleAccountInfoPage;
use CXGN::Page::FormattingHelpers qw/page_title_html/;
use base qw(CXGN::Page::Form::SimpleFormPage);

sub new
{
	my $class = shift;
	my %params = @_;
	my $self = $class->SUPER::new(%params);
	my (undef, undef, $this_script_filename) = File::Spec->splitpath($0); #$0 contains current filename with some path or other prepended
	$self->set_script_name($this_script_filename);
	return $self;
}

sub define_object
{
	my $self = shift;
	# call set_object_id, set_object and set_primary_key here
	my %args = $self->get_args();
	$self->set_object_id($args{sp_person_id});
	$self->set_object(new CXGN::People::Login($self->get_dbh(), $args{sp_person_id}));
	$self->set_primary_key("sp_person_id");		      
	$self->set_owners($self->get_object()->get_sp_person_id());
}

#specified in SimpleFormPage
sub check_modify_privileges { 
    my $self = shift;

    # implement quite strict access controls by default
    # 
    my $person_id = $self->get_login()->verify_session();
    my $user =  CXGN::People::Person->new($self->get_dbh(), $person_id);
    my $user_id = $user->get_sp_person_id();
    if ($user->get_user_type() eq 'curator') {
        return 0;
    }
    
    # check the owner only if the action is not new
    #
    my @owners= $self->get_owners();

    if ((@owners) && !(grep{/^$user_id$/} @owners ) )
    {
	$self->get_page()->message_page("You do not have rights to modify this database entry because you do not own it. [$user_id, @owners]");
    }
    else { 
	return 0;
    }


    # override to check privileges for edit, store, delete.
    # return 0 for allow, 1 for not allow.
    return 0;

}

#specified in SimpleFormPage
sub validate_parameters_before_store
{
	my $self = shift;
	my $person = new CXGN::People::Person($self->get_dbh(), $self->get_object_id());
	my %args = $self->get_args();
	my ($current_password, $change_username, $change_password, $change_email) = @args{qw(current_password change_username change_password change_email)};
		
	# If this happens, there is something wrong with the validation logic or 
	# account creation step allowed someone to have an empty password.
	if(!$person->get_password())
	{
		print STDERR "Can't find password for sp_user \"" . $person->get_sp_person_id() . "\" when updating account\n";
		$self->get_page()->error_page("User account could not be updated because it was not found.\n");
		exit();
	}
		
	if(!$change_password && !$change_username && !$change_email)
	{
		$self->failed("No actions were requested. Please select which fields you would like to update by checking the appropriate checkbox(es) on the form and entering your new information.");
	}
	if($person->get_password() ne $current_password)
	{
		$self->failed("Your current password does not match SGN records.");
	}
	
	# Check for error conditions in all changes, before making any of them.
	# Otherwise, we could end up making some changes and then failing on later
	# ones. The user would then push the back button and their information may
	# be different now but they will probably assume no changes were made. This
	# is most troublesome if the current password changes.
	if($change_username) {
		#unless change_username is set, new_username won't be in the args hash because of the prestore test
		my $new_username = $args{new_username};
		if(length($new_username) < 7) {
			$self->failed("Username must be at least 7 characters long.");
		}
		
		my $other_user = CXGN::People::Login->get_login($self->get_dbh(), $new_username);
		if(defined $other_user->get_sp_person_id() && ($person -> get_sp_person_id() != $other_user->get_sp_person_id())) {
			$self->failed("Username \"$new_username\" is already in use. Please select a different username.");
		}
	}
	else {
		$self->get_form()->get_field_obj_by_name("new_username")->set_store_enabled(0); #turn off storing username from form
	}
	if($change_password) {
		#unless change_password is set, new_password won't be in the args hash because of the prestore test
		my ($new_password, $confirm_password) = @args{qw(new_password confirm_password)};
		if(length($new_password) < 7) {
			$self->failed("Password must be at least 7 characters long.");
		}
		#format check
		if($new_password !~ /^[a-zA-Z0-9~!@#$^&*_.=:;<>?]+$/) {
			$self->failed("Password can't contain spaces or these symbols: <u><b>` ( ) [ ] { } - + ' \" / \\ , |</b></u>.");
		}
		if($new_password ne $confirm_password) {
			$self->failed("New password entries do not match. You must enter your new password twice to verify accuracy.");
		}
	}
	else {
		$self->get_form()->get_field_obj_by_name("new_password")->set_store_enabled(0); #turn off storing password from form
	}
	if($change_email) {
		#unless change_email is set, private_email won't be in the args hash because of the prestore test
		my ($private_email, $confirm_email) = @args{qw(private_email confirm_email)};
		if($private_email !~ m/^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$/) {
			$self->failed("E-mail address \"$private_email\" does not appear to be a valid e-mail address.");
		}
		if($private_email ne $confirm_email) {
			$self->failed("New e-mail address entries do not match. You must enter your new e-mail address twice to verify accuracy.");
		}
	}
	else {
		$self->get_form()->get_field_obj_by_name("private_email")->set_store_enabled(0); #turn off storing e-mail from form
	}
	
	#the confirm code needs to be part of a DBI object so it can be stored to the database
	my $confirm_code = $self->get_page()->tempname();
	$self->get_object()->set_confirm_code($confirm_code);
}

#display a 'failure; please try again' message
#argument: failure message
sub failed {
	my ($self, $msg) = @_;
	my $try_again = "<br />Please use your browser's back button to try again.\n";
	$self->get_page()->message_page("Account Update Failed", $msg . $try_again);
	exit();
}

#specified in SimpleFormPage
sub process_parameters_after_store {
	my $self = shift;
	my %args = $self->get_args();
	if($args{change_email}) {
		my $person = new CXGN::People::Person($self->get_dbh(), $self->get_object_id());
		$self->send_confirmation_email($person->get_username(), $person->get_private_email());
		warn "sent e-mail change confirmation to " . $person->get_private_email() . "\n";
	}
}

#e-mail the user after a successful change of private e-mail address
#arguments: (possibly new) username, new private e-mail address
sub send_confirmation_email {
	my ($self, $username, $private_email) = @_;
	my $confirm_code = $self->get_object()->get_confirm_code();
	my $host = $self->get_page()->get_hostname();
	my $subject = "[SGN] E-mail Address Confirmation Request";
	my $body = <<END_HEREDOC;
Please do *NOT* reply to this message. The return address is not valid. 
Use sgn-feedback\@sgn.cornell.edu instead.

This message is sent to confirm the private e-mail address for community user
\"$username\".

Please click (or cut and paste into your browser) the following link to
confirm your account and e-mail address:

http://$host/solpeople/account-confirm.pl?username=$username&confirm=$confirm_code

Thank you.
Sol Genomics Network
END_HEREDOC

	CXGN::Contact::send_email($subject, $body, $private_email);
}

sub generate_form {
	my $self = shift;
	my %args = $self->get_args();
	my $login = $self->get_object();
	my $person = new CXGN::People::Person($self->get_dbh(), $self->get_object_id());
	
	$self->init_form();
	my $form = $self->get_form();
	if($form->is_editable()) {
		$form->set_submit_method('post'); #passwords are sensitive data
	}
	
	my $default_field_length = 22;
	if($form->is_editable()) {
		$form->add_label(display_name => "",
							field_name => "lbl1",
							contents => "Please verify your current password to make changes. Select changes desired by checking the appropriate checkbox and entering"
											. " the new information.");
		$form->add_password_field(display_name => "Current password",
											field_name => "current_password",
											contents => "",
											length => $default_field_length,
											validate => "1"); #means it must have a value
		$form->add_checkbox(display_name => "Change username",
									field_name => "change_username",
									contents => "1",
									selected => 0);
		my $username_change_checkbox = $form->get_field_obj_by_name("change_username");
		$form->add_field(display_name => "New username",
								field_name => "new_username",
								contents => $login->get_username(),
								length => $default_field_length,
								object => $login,
								getter => 'get_username',
								setter => 'set_username');
		$form->add_checkbox(display_name => "Change password",
									field_name => "change_password",
									contents => "1",
									selected => 0);
		my $password_change_checkbox = $form->get_field_obj_by_name("change_password");
		$form->add_password_field(display_name => "New password",
											field_name => "new_password",
											contents => "",
											length => $default_field_length,
											object => $login,
											getter => 'get_password',
											setter => 'set_password');
		$form->add_password_field(display_name => "Confirm new password",
											field_name => "confirm_password",
											contents => "",
											length => $default_field_length);
	}
	else {
		$form->add_field(display_name => "Username",
								field_name => "username",
								contents => $login->get_username());
	}
	$form->add_label(display_name => "",
							field_name => "lbl2",
							contents => "Your private e-mail address is not publically displayed online. It is used only for SGN staff to contact you about changes to"
											. " your record or for e-mailing your password to you. Changing your private e-mail address will trigger a confirmation message from"
											. " SGN to verify the address is usable by SGN.");
	if($form->is_editable()) {
		$form->add_checkbox(display_name => "Change private e-mail address",
									field_name => "change_email",
									contents => "1",
									selected => 0);
		my $email_change_checkbox = $form->get_field_obj_by_name("change_email");
		$form->add_field(display_name => "Private e-mail address",
								field_name => "private_email",
								contents => $login->get_private_email(),
								length => $default_field_length,
								object => $login,
								getter => 'get_private_email',
								setter => 'set_private_email');
		$form->add_field(display_name => "Confirm e-mail address",
								field_name => "confirm_email",
								contents => "",
								length => $default_field_length);
	}
	else {
		$form->add_field(display_name => "Private e-mail address",
								field_name => "private_email",
								contents => $login->get_private_email());
	}
	
	#for allowing the form to make changes
	if($self->get_action() =~ /^edit$/) {
		$form->add_hidden(display_name => "ID", field_name => "sp_person_id", contents => $person->get_sp_person_id());
		$form->add_hidden(display_name => "Action", field_name => "action", contents => "store");
	}
	
	if($form->is_editable()) {
		$form->set_reset_button_text("Clear Form");
		$form->set_submit_button_text("Change Account Information");
	}
	
	if($self->get_action() =~ /^store$/) {
		$form->from_request($self->get_args());
	}
}

#no arguments
#return an HTML string for a toolbar with other possible actions for the form
sub get_actions_toolbar {
	my $self = shift;
	
	my $script_name = $self->get_script_name();
	my $user_id= $self->get_user()->get_sp_person_id();
	my @owners=$self->get_owners();
	my $user_is_owner = (grep{/^$user_id$/} @owners);
	my %args = $self->get_args();
	my $sp_person_id = $args{sp_person_id};
	
	my $home = qq(<a href="/solpeople/profile/$sp_person_id">[Profile Home]</a>&nbsp;&nbsp;);
	
	if($self->get_action() eq "edit") {
		if($user_is_owner) {
			return $home . qq(<a href="$script_name?action=view&sp_person_id=$sp_person_id">[Cancel Edit]</a>);
		}
		else {
			return $home . qq(<span class="ghosted">[Cancel Edit]</span>);
		}
	}
	elsif($self->get_action() eq "view") {
		if($user_is_owner) {
			return $home . qq(<a href="$script_name?action=edit&sp_person_id=$sp_person_id">[Edit]</a>);
		}
		else {
			return $home . qq(<span class="ghosted">[Edit]</span>);
		}
	}
	elsif($self->get_action() eq "store") {
		return "";
	}
}

sub display_page {
	my $self = shift;
	#SimpleFormPage takes care of some unknown action strings, but we don't handle the full set of actions it supports
	if($self->get_action() !~ /^view|edit|store$/) {
		$self->get_page()->message_page("Illegal parameter: action '" . $self->get_action() . "' is not supported by " . $self->get_script_name());
		exit();
	}
	my $page = $self->get_page();
	my $person = new CXGN::People::Person($self->get_dbh(), $self->get_object_id());
	
	$page->header("Sol People: account info");
	print page_title_html("Account info for user <tt>" . $person->get_username() . "</tt>");
	print $self->get_actions_toolbar() . "<hr />\n";
	print $self->get_form()->as_table_string();
	$page->footer();
}
