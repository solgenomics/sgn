

=head1 NAME

AjaxFormPage.pm -- an abstract class that implements a simple Ajax form that can be use to add, view and modify information in the database.

=head1 DESCRIPTION

AjaxFormPage.pm works with the CXGN::Page::Form classes and user-defined database classes that have to follow certain guidelines for this class to work properly (in essence, the database classes need to follow the rules for the CXGN::Page::Form framework. For more information, see the documentation of the L<CXGN::Page::Form> classes).

AjaxFormPage.pm implements a simple authentication for the calls that modify database content. The function check_modify_privileges should return 1 if the current user had edit/delete privileges, otherwise it should return 0. The default implementation returns 1 for the owner and any logged in curators, 0 for all others.

AjaxFormPage contains a number of pre-populated accessors for often used CXGN features, such as CXGN::Page (get_page()), CXGN::DB::Connection (get_dbh()), and CXGN::Login (get_user()). 

When creating a derived class, you need to override the following functions:

C<sub define_object()>

C<sub generate_form()>

If you want to create a page layout different from the default layout, you can also override:

C<sub display_form()>

=head1 AUTHOR(S)

Naama Menda (nm249@cornell.edu)


=head1 FUNCTIONS AND INTERFACES

The following is a list of object functions. Some of these functions are used internally, and some need to be overridden in child classes. See the description above and the individual functions for more details. 

=cut

use strict;
use Carp;

use CXGN::Tools::Text qw | sanitize_string |;

use CXGN::Page::Form::Static;
use CXGN::Page::Form::Editable;
use CXGN::Page::Form::ConfirmStore;

use CXGN::Scrap::AjaxPage;

use CXGN::Login;
use CXGN::DB::Connection;

use CXGN::People;
use CXGN::People::Person;

use CXGN::Contact;
use CXGN::Feed;
use JSON;

package CXGN::Page::Form::AjaxFormPage;

use base qw /CXGN::Debug/ ;
=head2 new

 Usage:        my $s = CXGN::Page::SimpleFormPageSubClass->new();
 Desc:         This class needs to be subclassed and certain functions 
               overridden (the functions are listed above). The constructor
               should not be overridden or called from the overridden 
               constructor. 
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub new { 
    my $class = shift;
    my $self = bless {}, $class;
    
    my $primary_key = shift;
    
    __PACKAGE__->SUPER::new();
    
    my $dbh = CXGN::DB::Connection->new();
    $self->set_ajax_page(CXGN::Scrap::AjaxPage->new() );
   

    my $dbh=CXGN::DB::Connection->new();###$self->get_page()->get_dbh(); # reuse the dbh from the Page object
    $self->set_dbh($dbh);
    
    $self->set_login(CXGN::Login->new($self->get_dbh()));
    $self->get_ajax_page->{request}->no_cache(1);
    my %args = $self->get_ajax_page()->get_all_encoded_arguments(); ##
    my %json_hash=();
    # sanitize the inputs, we don't want to end up like bobby tables school.
    #
    foreach my $k (keys (%args)) { 
	$args{$k} = CXGN::Tools::Text::sanitize_string($args{$k});
    }
    
    $self->set_args(%args);
    
    $self->define_object();

    $self->set_action($args{action});
    
    if (!$self->get_action()) { 
	$self->set_action("view");
    }
    
    if (!$self->get_object_id() && $self->get_action()!~/new|store|confirm_store/) { 
	$json_hash{error}='No identifier provided to display data of this page for action view.'; 
	
    }
    else { 
	if ($self->get_action()!~/new|view|edit|store|delete|confirm_delete|confirm_store/) { 
	    $json_hash{error}='No identifier provided'; 
	}	 
    }
    
    if ($self->get_action() eq "view") { 
 	$self->view();
    }
    elsif ($self->get_action() eq "edit") { 
 	$self->edit();
    }
    elsif ($self->get_action() eq "new") { 
	$self->set_object_id(0);	
	my %args = $self->get_args();
	$args{$self->get_primary_key()}=0;
	$self->set_args(%args);
	$self->add();
    }
    elsif ($self->get_action() eq "store") { 
 	$self->store();
    }
    elsif ($self->get_action() eq "confirm_delete") {
	$self->delete();
    }
    ##action delete is being handled by the JSFormPage javascript object
    
    $self->set_json_hash(%json_hash);
    $self->get_ajax_page()->send_http_header();
    
    return $self;
}

=head2 check_modify_privileges

  Usage:        if ($s->check_modifiy_privileges) { ...}
 Desc:         checks if the currently logged in user has sufficient
               privileges for the current action. This can be overridden
               if the default privileges are undesirable. The default is:
               logged-in curators can do everything
               logged-in owners can do everything
               logged-in users can only view
               non-logged-in users can only view
               
 Ret:          true if the user has sufficient privileges for the action.
 Args:
 Side Effects:
 Example:

=cut

sub check_modify_privileges { 
    my $self = shift;
    my %json_hash= $self->get_json_hash();
    # implement quite strict access controls by default
    # 
    my ($person_id, $user_type)=$self->get_login()->has_session();
    
    #my $person_id = $self->get_login()->verify_session();
    #my $user =  CXGN::People::Person->new($self->get_dbh(), $person_id);
    #my $user_id = $user->get_sp_person_id();
    #my $user_type = $user->get_user_type();
    
    if ($user_type eq 'curator') {
	return 0;
    }
    if (!$person_id) { $json_hash{login} = 1 ; }
    if ($user_type !~ /submitter|sequencer|curator/) { 
	$json_hash{error} = "You must have an account of type submitter to be able to submit data. Please contact SGN to change your account type.";
    }

    my @owners = $self->get_owners();

    if ((@owners) && (!(grep { $_ =~ /^$person_id$/ } @owners) )) {
	# check the owner only if the action is not new
	#
	$json_hash{error} = "You do not have rights to modify this database entry because you do not own it. [$person_id, @owners]";
	
    }else {  $self->set_is_owner(1); }
    
    # override to check privileges for edit, store, delete.
    # return 0 for allow, 1 for not allow.
    $self->set_json_hash(%json_hash);
    return 0;
    
}

=head2 define_object

 Usage:        
 Desc:         define the object that this simple form page operates on.
               The object needs to implement L<CXGN::DB::ModifiableI>
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub define_object { 
    my $self = shift;
    
    my %json_hash= $self->get_json_hash();
    # in the subclass, instantiate your object here and  call
    $self->set_object();
    $self->set_object_id();
    $self->set_object_name();
    $self->set_primary_key();
    $self->set_owners();
    
    if ( $self->get_object()->get_obsolete() eq 't' ) { 
	$json_hash{error} = "Object is obsolete!";
	$self->set_json_hash(%json_hash);
	$self->print_json();
    }
}


# edit is an internally used function to show the editable form.
#

sub edit { 
    my $self = shift;
    $self->check_modify_privileges();
    $self->generate_form();
    $self->display_form();
}

# add is an internally used function to generate an 'emtpy' form.
#

sub add { 
    my $self = shift;
    $self->check_modify_privileges();
    $self->generate_form();
    $self->display_form();
    
}

=head2 store

 Usage:        $s->store()
 Desc:         stores the form into the database. In this default implementation,
               which can but should not overridden, first, the privileges are checked
               and all the form fields are validated for correctness. If this fails,
               the input form is shown again with an appropriate error message.
               Else, the store is issued for the object (set using set_object). 
               If this succeeds, the form div is updated  but with
               the 'view' action parameter.
 Ret:
 Args:
 Side Effects: If the form fails validation, 
               the 'validate' key in $self->get_json_hash is set to '1',
               and the form is re-printed with the relevant error message.
               If validation passes, $form->store is called. 
               If this was an insert of a new object, 
               sets $self->set_object_id($last)insert_id)  
 Example:

=cut


sub store { 
    my $self = shift;
    my $dont_show_form = shift;
    my %json_hash= $self->get_json_hash();
    $self->check_modify_privileges();

    # for the store we need a properly formatted form so that we can
    # use its validate and store functions.
    #
    $self->generate_form();

    # validate the form
    my %errors = $self->get_form()->validate($self->get_args());
    if (!%errors) {
	
	#give the user the opportunity to modify, add or remove form parameters before committing them
	#(this needs to be done after validate() because that assumes it'll have the parameters given on the form as displayed)
	$self->validate_parameters_before_store();
	
	# the form validated. Now let's check if it passes the uniqueness
	# constraints.
 	
	$self->d("**** about to call the get_form->store() ****");
	$self->get_form()->store($self->get_args());
	
	#give the user the opportunity to do anything related to the form after storing
	$self->process_parameters_after_store();
	
	
        # was it an insert? get the insert id
	#
	if (!$self->get_object_id()) { 
	    my $id = $self->get_form()->get_insert_id();
	    $self->set_object_id($id);
	}
    }
    else { 
	# if there was an error, re-display the same forms.
	# the errors will be displayed on the page for each
	# field that did not validate.
	#
	$json_hash{validate} = 1;
	$json_hash{html} = $self->get_form()->as_table_string();
	$self->set_json_hash(%json_hash);
    }

    
    $self->print_json();
}


=head2 view

  Description: Displays the form in the 'view' mode.

=cut

sub view { 
    my $self = shift;
    
    # make sure we get a static form.
    #
    $self->set_action("view");
    
    $self->generate_form();
    $self->display_form();
}

=head2 get_user()

 Usage:
 Desc:         returns a CXGN::People::Person object
               that represents the currently logged in user
               or an empty user if the page is being viewed
               without login.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_user {
  my $self=shift;
  my $person_id = $self->get_login()->has_session();
  return CXGN::People::Person->new($self->get_dbh(), $person_id);
}

=head2 generate_form

 Usage:        $s->generate_form()
 Desc:         this method needs to be overridden. In this method, 
               a new form must be generated (as a CXGN::Page::Form object)
               which can be instantiated either as a Static or Editable 
               version.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub generate_form { 
    my $self = shift;
    my $error=  "Please subclass 'generate_form' function!\n";
    warn $error;
    my %json_hash=$self->get_json_hash();
    $json_hash{error} = $error;
    $self->set_json_hash(%json_hash);
    $self->print_json();
}


=head2 delete

 Usage:
 Desc:         actually performs the delete in the database.
               Database objects should implement the delete as a 
               obsoletion. See L<CXGN::DB::ModifiableI>
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete { 
    my $self = shift;
    warn "Override 'delete' function in derived class\n";

    my $error="Deleting is not implemented for this object. Override 'delete' function in derived class.";
    my %json_hash=$self->get_json_hash();
    $json_hash{error} = $error;
    $self->set_json_hash(%json_hash);
}

=head2 display_form

 Usage:        $s->display_form()
 Desc:         can be overridden in the subclass. In the default
               implementation, displays the
               form in table format,
               in the appropriate Editable or Static form.
 Ret:
 Args:
 Side Effects: Sets user_type, is_owner, and editable_form_id keys for 
               $self->get_json_hash() to be used in the javascript object
               (See CXGN/Page/Form/JSFormPage.js ) 
 Example:

=cut

sub display_form { 
    my $self=shift;
    my %json_hash= $self->get_json_hash();
    # edit links are printed from the javascript object! See JSFormPage.js
    #print $self->get_edit_links();
     
    if (!($json_hash{html}) ) { $json_hash{html} = $self->get_form()->as_table_string() ; }		
    $self->check_modify_privileges();
    
    $json_hash{"user_type"} = $self->get_user()->get_user_type();
    $json_hash{"is_owner"} = $self->get_is_owner();
    
    $json_hash{"editable_form_id"} = $self->get_form()->get_form_id();
   
    
    $self->set_json_hash(%json_hash);
    $self->print_json();
}


=head2 get_ajax_page, set_ajax_page

 Usage:        $p = $s->get_ajax_page();
 Desc:         get the ajax page object of the current page.
               the simple form page automatically initializes
               this property.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_ajax_page {
  my $self=shift;
  return $self->{ajax_page};

}

sub set_ajax_page {
  my $self=shift;
  $self->{ajax_page}=shift;
}

=head2 get_dbh

 Usage:        $dbh = $s->get_dbh();
 Desc:         get the dbh connection of this simple form page.
               the simple form page constructor initializes this
               property 
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_dbh {
  my $self=shift;
  return $self->{dbh};

}

sub set_dbh {
  my $self=shift;
  $self->{dbh}=shift;
}

=head2 get_login

 Usage:        my $l = $s->get_login()
 Desc:         get the login object of the simple form page.
               the simple form page constructor initializes this
               property.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_login {
  my $self=shift;
  return $self->{login};

}

sub set_login {
  my $self=shift;
  $self->{login}=shift;
}

=head2 get_args

 Usage:        my %args = $s ->get_args()
 Desc:         gets the page arguments as a hash. The
               simple form page constructor initializes
               this property.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_args {
  my $self=shift;
  if (!$self->{args}) { %{$self->{args}} = (); }
  return %{$self->{args}};

}

sub set_args {
  my $self=shift;
  %{$self->{args}}=@_;
}


=head2 get_object, set_object

 Usage:        $s->define_object(CXGN::Phenome::Locus->new($self->get_dbh(), $self->get_object_id())
 Desc:         sets the object that this simple form page operates on.
               this needs to be called in the define_object method, which must
               be overridden. see define_object for more info.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_object {
  my $self=shift;
  return $self->{object};

}

sub set_object {
  my $self=shift;
  $self->{object}=shift;
}

=head2 accessors get_object_name, set_object_name

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_object_name {
  my $self = shift;
  return $self->{object_name}; 
}

sub set_object_name {
  my $self = shift;
  $self->{object_name} = shift;
}


=head2 get_owners

 Usage:  my @owners = $self->get_owners()
 Desc:  find the owner(s) of your object
        most tables have a single owner (the field sp_person_id) 
        and this accessor will return an array with one element.
        However, if the object has multiple owners  
        (such as 'Locus' - group of owners is defined in locus_owner table)
        this function will need to be overriden (see CXGN/Phenome/Locus.pm) 
 Ret:   an array
 Args:  none
 Side Effects:
 Example:

=cut

sub get_owners {
  my $self=shift;
  return @{$self->{owners}};
  
}

sub set_owners {
  my $self=shift;
  @{$self->{owners}}=@_;
}

=head2 get_action, set_action

 Usage:        my $action = $s ->get_action()
 Desc:         the current action of the simple form page. 
               can be either edit, save, view, etc.
               the action is set by the constructor, so the
               setter should never be called.
 Ret:
 Args:
 Side Effects:
 Example:

=cut 

sub get_action {
  my $self=shift;
  return $self->{action};

}

sub set_action {
  my $self=shift;
  $self->{action}=shift;
}


=head2 get_primary_key, set_primary_key

 Usage:        $s->set_primary_key("read_id")
 Desc:         sets the name of the primary key of the data at hand.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_primary_key {
  my $self=shift;
  return $self->{primary_key};

}


sub set_primary_key {
  my $self=shift;
  $self->{primary_key}=shift;
}

=head2 get_script_name, set_script_name

 Usage:        $s->get_script_name()
 Desc:         gets the name of the script that uses the simple form page.
               useful for constructing links. 
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_script_name {
    my $self=shift;
    if (!exists($self->{script_name})) { 
	#return CXGN::Apache::Request::page_name();
	return $ENV{SCRIPT_NAME};
    }
    else { 
	return $self->{script_name};
    }
    
}

sub set_script_name {
    my $self=shift;
    $self->{script_name}=shift;
}

=head2 get_object_id, set_object_id

 Usage:        my $id = $s->get_object_id()
 Desc:         get/set the primary id for the object at hand
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_object_id {
  my $self=shift;
  return $self->{object_id};

}

sub set_object_id {
  my $self=shift;
  $self->{object_id}=shift;
}

=head2 get_form, set_form

 Usage:        my $f = $s->get_form()
 Desc:         get the form object associated with the simple
               form page. The form is initialized automatically to the
               appropriate subclass, either L<CXGN::Page::Form::Static> or 
               L<CXGN::Page::Form::Editable>, depending on the action, 
               according to the form object defined in the generate_form 
               method, which needs to be overridden in the subclass.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_form {
  my $self=shift;

  return $self->{form};

}

sub set_form {
  my $self=shift;
  $self->{form}=shift;
}

=head2 accessors get_json_hash, set_json_hash

 Usage: my %json_hash= $self->get_json_hash() ;
        
        # the store function in this class sets the validate key to 1
        #if the form fields pass permissions and validation
        my $validate = $json_hahs{validate};
        
         $json_hash{error} = "this is an error";
         $json_hash{html} = $self->get_form()->as_table_string();
         $json_hash{user_type} = $user_type;
         
         $json_hash{is_owner} = 1;
         $json_hash{editable_form_id} = $self->get_form()->get_form_id();
         $json_hash{refering_page} = "/my_page.pl?id=$id";

         #Force page reloading (e.g. after deleting an object)  
         $json_hash{reload} = 1; 
         
         $self->set_json_hash(%json_hash)
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_json_hash {
  my $self=shift;
  if (!$self->{json_hash}) { %{$self->{json_hash}} = (); }
  return %{$self->{json_hash}};

}

sub set_json_hash {
  my $self=shift;
  %{$self->{json_hash}}=@_;
}

=head2 accessors get_is_owner, set_is_owner

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_is_owner {
  my $self = shift;
  return $self->{is_owner}; 
}

sub set_is_owner {
  my $self = shift;
  $self->{is_owner} = shift;
}

=head2 init_form

 Usage:        $s->init_form()
 Desc:         initializes the correct form subclass, either
               CXGN::Page::Form::Editable or CXGN::Page::Form::Static,
               or CXGN::Page::Form::ConfirmStore.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub init_form {
    my $self = shift;
    my $form_id = shift;
    
    if ($self->get_action() =~/edit|^store|new/) { 
	$self->set_form( CXGN::Page::Form::Editable -> new({no_buttons=>1, form_id=>$form_id} ) ) ;
	
    }elsif ($self->get_action() =~/confirm_store/) {
	$self->set_form( CXGN::Page::Form::ConfirmStore->new() ) ; 
	
    }else  {
	$self->set_form( CXGN::Page::Form::Static -> new() );
    }
    
}

=head2 get_request, set_request

 Usage:        my $r = $s->get_request()
 Desc:         returns the apache request object for the 
               simple form page.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_request {
  my $self=shift;
  return $self->{request};

}

sub set_request {
  my $self=shift;
  $self->{request}=shift;
}

=head2 validate_parameters_before_store

 Desc: Allow for custom validation of the form as a whole, 
       and in perl rather than javascript; parameters can be 
       removed, modified or added as necessary before the database 
       is touched. Meant to be overridden.
		 
       Complements ElementI::validate(), which simply allows for 
       checking format of individual fields.
       validate_parameters_before_store() is called after all 
       Elements have validate()d themselves.
		 
       To avoid letting the store go through, create an error or 
       message page and call exit().

 Ret:  none
 
=cut

sub validate_parameters_before_store {
}

=head2 process_parameters_after_store

 Desc: Allow for custom postprocessing, eg logging to disk, sending 
       e-mail confirmations, or changing the template of the form
       before it\'s viewed again. Meant to be overridden.
 Ret:  none
 
=cut

sub process_parameters_after_store {
}

=head2 print_json

 Usage: $self->print_json()
 Desc:  print a json object. To be used  in the javascript JSFormPage object.
 Ret:   nothing
 Args:  none
 Side Effects: prints encoded JSON object
 Example:

=cut


sub print_json {
    my $self=shift;
    my %results= $self->get_json_hash();
    
    if ($results{die_error} ) { 
	CXGN::Contact::send_email('AjaxFormPage died',$results{"error"} );
    }
    my $json = JSON->new();
    my $jobj = $json->encode(\%results);
    print  $jobj;
}

=head2 send_form_email

 Usage: $self->send_form_email( { subject=>foo, mailing_list=>bar, refering_page=>my_page.pl, acion=>delete});
 Desc:  send an email after the user stored something in the database
 Ret:   nothing
 Args:  hash with the following optional keys
    subject       => the subject row of the email
    mailing_list  => defaults to sgn-bugs. Usually curation emails should go to sgn-db-curation
    refering_page=> your page would show as a link in the email
    action        => 'delete' value will send an 'object $id was obsoleted...'
 Side Effects:  send an email with an informative message about the nature of the database change.
 Example:

=cut

sub send_form_email {
    my $self   = shift;
    my $opts=shift;
    $opts ||= {};
    my $subject=$opts->{subject};
    my $mailing_list = $opts->{mailing_list};
    my $refering_page_link = $opts->{refering_page};
    my $action = $opts->{action};
    
    my $user=$self->get_user();
    
    my $object_id = $self->get_object_id();
    
    my $username =
        $user->get_first_name() . " "
	. $user->get_last_name();
    my $sp_person_id = $user->get_sp_person_id();
    
    
    my $user_link =
	qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    
    my $usermail = $user->get_private_email();
    my $fdbk_body;
    if ( $action eq 'delete' ) {
        $fdbk_body =
	    "$username ($user_link) has obsoleted " . $self->get_object_name() . "  $object_id ($refering_page_link) \n  $usermail";
    }
    elsif ( $object_id == 0 ) {
        $fdbk_body =
	    "$username ($user_link) has submitted a new ". $self->get_object_name()  . "   \n$usermail ";
    }
    else {
        $fdbk_body =
	    "$username ($user_link) has submitted data for " . $self->get_object_name() ." ($refering_page_link) \n $usermail";
    }
    
    CXGN::Contact::send_email( $subject, $fdbk_body,$mailing_list );
    CXGN::Feed::update_feed( $subject, $fdbk_body );
}


return 1;

