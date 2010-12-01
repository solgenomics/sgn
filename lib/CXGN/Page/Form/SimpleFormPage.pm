=head1 NAME

SimpleFormPage.pm -- an abstract class that implements a simple webpage that can be use to add, view and modify information in the database.

=head1 DESCRIPTION

SimpleFormPage.pm works with the CXGN::Page::Form classes and user-defined database classes that have to follow certain guidelines for this class to work properly (in essence, the database classes need to follow the rules for the CXGN::Page::Form framework. For more information, see the documentation of the L<CXGN::Page::Form> classes).

SimpleFormPage.pm implements a simple authentication for the calls that modify database content. The function check_modify_privileges should return 1 if the current user had edit/delete privileges, otherwise it should return 0. The default implementation returns 1 for the owner and any logged in curators, 0 for all others.

SimpleFormPage contains a number of pre-populated accessors for often used CXGN features, such as CXGN::Page (get_page()), CXGN::DB::Connection (get_dbh()), and CXGN::Login (get_user()).

When creating a derived class, you need to override the following functions:

C<sub define_object()>

C<sub generate_form()>

If you want to create a page layout different from the default layout, you can also override:

C<sub display_page()>

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)


=head1 FUNCTIONS AND INTERFACES

The following is a list of object functions. Some of these functions are used internally, and some need to be overridden in child classes. See the description above and the individual functions for more details.

=cut

use strict;
use Carp;

use CXGN::Tools::Text qw | sanitize_string |;
use CXGN::Page;
use CXGN::Page::Form::Static;
use CXGN::Page::Form::Editable;
use CXGN::Page::Form::ConfirmStore;

use CXGN::Login;
use CXGN::DB::Connection;

use CXGN::People;
use CXGN::People::Person;

package CXGN::Page::Form::SimpleFormPage;

use CXGN::Page::FormattingHelpers qw / page_title_html blue_section_html /;

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
    my $schema= shift;
    my $self = bless {}, $class;

    my $primary_key = shift;

    $self->set_page(CXGN::Page->new("SGN", "Lukas"));
    my $dbh=$self->get_page()->get_dbh(); # reuse the dbh from the Page object
    $self->set_dbh($dbh);

    $self->set_login(CXGN::Login->new($self->get_dbh()));
    my %args = $self->get_page()->cgi_params(); #multi-valued parameters have values in a string, delimited by \0

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
        $self->get_page()->message_page("No identifier provided to display data of this page for action view.");
    }
    else {
        if ($self->get_action()!~/new|view|edit|store|delete|confirm_delete|confirm_store/) {
            $self->get_page()->error_page("Undefined input. Cannot proceed. Sorry.\n");
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
        my $id = $args{$self->get_primary_key()};
        if (!$id) {
            $self->get_page()->error_page("need an id for deleting");
        }
        $self->delete_dialog("Delete", "Object",
                             $self->get_primary_key(),
                             $id,
                             "<a href=\"".$self->get_script_name()."?".$self->get_primary_key()."=".$id."&amp;action=view\">Go back to detail page without deleting</a>");

     }
     elsif ($self->get_action() eq "delete") {
        $self->delete();
     }
    elsif ($self->get_action() eq "confirm_store") {

        $self->confirm_store();
     }
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

    # implement quite strict access controls by default
    #
    my $person_id = $self->get_login()->verify_session();
    my $user =  CXGN::People::Person->new($self->get_dbh(), $person_id);
    my $user_id = $user->get_sp_person_id();
    if ($user->get_user_type() eq 'curator') {
        return 0;
    }
    if ($user->get_user_type() !~ /submitter|sequencer|curator/) {
        $self->get_page()->message_page("You must have an account of type submitter to be able to submit data. Please contact SGN to change your account type.");
    }

    my @owners = $self->get_owners();
    if ((@owners) && (!(grep { $_ =~ /^$user_id$/ } @owners) )) {
        # check the owner only if the action is not new
        #
        #my $owner_id = $self->get_object_owner();
        #  if (($owner_id) && ($owner_id != $user_id))
        #  {


        $self->get_page()->message_page("You do not have rights to modify this database entry because you do not own it. [$user_id, @owners]");
    }
    else {
        return 0;
    }


    # override to check privileges for edit, store, delete.
    # return 0 for allow, 1 for not allow.
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

    # in the subclass, instantiate your object here and  call
    $self->set_object();
    $self->set_object_id();
    $self->set_primary_key();
}


# edit is an internally used function to show the editable form.
#

sub edit {
    my $self = shift;
    $self->check_modify_privileges();
    $self->generate_form();
    $self->display_page();
}

# add is an internally used function to generate an 'emtpy' form.
#

sub add {
    my $self = shift;
    $self->check_modify_privileges();
    $self->generate_form();
    $self->display_page();

}

=head2 store

 Usage:        $s->store()
 Desc:         stores the form into the database. In this default implementation,
               which can but should not overridden, first, the privileges are checked
               and all the form fields are validated for correctness. If this fails,
               the input form is shown again with an appropriate error message.
               Else, the store is issued for the object (set using set_object).
               If this succeeds, the page is re-directed to the same page, but with
               the 'view' action parameter.
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub store {
    my $self = shift;
    my $dont_show_form = shift;

    $self->check_modify_privileges();

    # for the store we need a properly formatted form so that we can
    # use its validate and store functions.
    #
    $self->generate_form();

    # validate the form
    my %errors = $self->get_form()->validate($self->get_args());
    if (!%errors)
         {

         #give the user the opportunity to modify, add or remove form parameters before committing them
         #(this needs to be done after validate() because that assumes it'll have the parameters given on the form as displayed)
         $self->validate_parameters_before_store();

        # the form validated. Now let's check if it passes the uniqueness
        # constraints.
        # Assume that the database accessor class inherits from
        # CXGN::DB::Modifiable and thus has a exists_in_database
        # function - but don't make it a requirement. If it doesn't -- never mind.
        #
#       if ($self->get_object()->can("exists_in_database")) {
#           if ($self->get_object()->exists_in_database()) {
#               $self->get_page()->message_page("Some fields in this object must be unique in the database.
#                                     Please modify your input and try to submit again.");
#           }
#       }

#       eval
#       {
         #print STDERR "**** about to call the get_form->store() ****";
                $self->get_form()->store($self->get_args());

                #give the user the opportunity to do anything related to the form after storing
                $self->process_parameters_after_store();
#       };
#       if ($@) {
#           $self->get_page()->message_page("An error occurred while attempting to store data. Please verify your input and try again. $@");
#       }

        # was it an insert? get the insert id
        #
        if (!$self->get_object_id()) {
            my $id = $self->get_form()->get_insert_id();
            $self->set_object_id($id);
        }
        my %args = $self->get_args();

        # if we are supposed to show the form, redirect to the
        # script this script with the appropriate parameters,
        # the object_id, and the action = view.
        #
        if (!$dont_show_form) {
            my $url =
                $self->get_script_name()."?".
                $self->get_primary_key()."=".
                $self->get_object_id()."&action=view";

            $self->get_page()->client_redirect($url);
        }

    }
    else {
        # if there was an error, re-display the same page.
        # the errors will be displayed on the page for each
        # field that did not validate.
        #
        $self->display_page();
        exit();
    }

}


=head2 view

  Description: Displays the page in the 'view' mode.

=cut

sub view {
    my $self = shift;

    # make sure we get a static form.
    #
    $self->set_action("view");

    $self->generate_form();
    $self->display_page();
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
    warn "Please subclass 'generate_form' function!\n";
}

=head2 delete_dialog

 Desc:         Displays a verification dialog for a delete action.

=cut

sub delete_dialog {
    my $self = shift;
    $self->check_modify_privileges();
    my $title = shift;
    my $object_name = shift;
    my $field_name = shift;
    my $object_id = shift;
    my $back_link = shift;

    $self->get_page()->header();

    page_title_html("$title");
    print qq {
        <form>
        Delete database object $object_name (id=$object_id)?
        <input type="hidden" name="action" value="delete" />
        <input type="hidden" name="$field_name" value="$object_id" />
        <input type="submit" value="Delete" />
        </form>

        $back_link

    };

    $self->get_page()->footer();

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

    $self->get_page()->message_page("Deleting is not implemented for this object");

}

=head2 confirm_store

 Desc:         displays a confirmation dialog for before certain store
               operations.

=cut

sub confirm_store {

    my $self=shift;
    $self->get_page()->header();


    page_title_html("Confirm store");
    print qq {
        <form>
        Store object in the database?
        <input type="hidden" name="action" value="store" />

        <input type="submit" value="Store" />
        </form>

        <a href="javascript:history.back(1)">Go back without storing the object</a>

    };

    $self->get_page()->footer();

}

=head2 display_page

 Usage:        $s->display_page()
 Desc:         can be overridden in the subclass. In the default
               implementation, displays the header and footer, the
               appropriate edit links and the form in table format,
               in the appropriate Editable or Static form.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub display_page {
    my $self=shift;

    $self->get_page()->header();
    print $self->get_edit_links();
    $self->get_form()->as_table();

    $self->get_page()->footer();

}


=head2 get_page, set_page

 Usage:        $p = $s->get_page();
 Desc:         get the page object of the current page.
               the simple form page automatically initializes
               this property.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_page {
  my $self=shift;
  return $self->{page};

}

sub set_page {
  my $self=shift;
  $self->{page}=shift;
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

    if ($self->get_action() =~/edit|^store|new/) {
        $self->set_form( CXGN::Page::Form::Editable -> new() );

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

=head2 get_edit_links

 Usage:        my $edit_links = $s->get_edit_links()
 Desc:         gets a string corresponding to the edit links to be placed
               on the page, as appropriate for the current action. The edit
               link, for example, is replaced with a 'cancel edit' in edit mode
               etc.
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub get_edit_links {
    my $self =shift;
    my $form_name = shift;
    return $self->get_new_link_html($form_name)." ".
        $self->get_edit_link_html($form_name)." ".$self->get_delete_link_html($form_name);

}

=head2 function get_new_link_html

  Synopsis:
  Description: Creates an appropriate 'new' link for the edit links.

=cut

sub get_new_link_html {
    my $self = shift;
    my $form_name = shift;

    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();

    my $new_link = qq { <a href="$script_name?action=new&amp;form=$form_name">[New]</a> };
    if ($self->get_action() eq "edit") {
        $new_link = qq { <span class="ghosted">[New]</span> };
    }
    if ($self->get_action() eq "new") {
        $new_link = qq { <a onClick="history.go(-1)">[Cancel]</a> };
    }
    return $new_link;
}

=head2 function get_edit_link_html

  Description:  Creates an appropriate 'edit' link for the edit links.

=cut

sub get_edit_link_html {
    my $self = shift;
    my $form_name = shift;

    my $edit_link = "";
    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();

    my $user_id= $self->get_user()->get_sp_person_id();
    my @owners= $self->get_owners();
    if (($self->get_user()->get_user_type() eq "curator") || $user_id && grep{/^$user_id$/} @owners ) {
         $edit_link = qq { <a href="$script_name?action=edit&amp;form=$form_name&amp;$primary_key=$object_id">[Edit]</a> };

     }else {
         $edit_link = qq { <span class="ghosted">[Edit]</span> };
     }


    if ($self->get_action() eq "edit") {
        $edit_link = qq { <a href="$script_name?action=view&amp;form=$form_name&amp;$primary_key=$object_id">[Cancel Edit]</a> };
    }

    if ($self->get_action() eq "new") {
        $edit_link = qq { <span class="ghosted">[Edit]</span> };
    }

    return $edit_link;
}

=head2 function get_delete_link_html

  Description: Generates and appropriate 'delete' link for the edit links.

=cut

sub get_delete_link_html {
    my $self = shift;
    my $form_name = shift;

    my $delete_link = "";
    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();
    my $user_id= $self->get_user()->get_sp_person_id();
    my @owners= $self->get_owners();
    if (($self->get_user()->get_user_type() eq "curator") || grep{/^$user_id$/} @owners ) {

        $delete_link = qq { <a href="$script_name?action=confirm_delete&amp;form=$form_name&amp;$primary_key=$object_id">[Delete]</a> };

    }else {
        $delete_link = qq { <span class="ghosted">[Delete]</span> };
    }

    if ($self->get_action() eq "edit") {
        $delete_link = qq { <span class="ghosted">[Delete]</span> };
    }

    if ($self->get_action() eq "new") {
        $delete_link = qq { <span class="ghosted">[Delete]</span> };
    }
    return $delete_link;
}


1;
