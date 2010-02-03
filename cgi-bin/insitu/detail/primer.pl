
use strict;

my $primer_detail_page = CXGN::Insitu::Primer_detail_page->new();

package CXGN::Insitu::Primer_detail_page;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::Insitu::Toolbar;
use CXGN::Insitu::Primer;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("primer.pl");
    
    return $self; 
}

# override define object to tell this page what object
# we are dealing with
#
sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{primer_id});
    $self->set_object( CXGN::Insitu::Primer->new($self->get_dbh(),
						 $self->get_object_id()) );
    $self->set_primary_key("primer_id");		      
    $self->set_owners($self->get_object()->get_user_id());
}

# override delete to provide a delete mechanism for this page
#
sub delete { 
    my $self = shift;
    $self->check_modify_privileges();
    my $primer = $self->get_object();
    my $primer_name = $primer->get_name();
    my $errors = $primer->delete();
    if ($errors) { 
	$self->get_page()->message_page("This primer has either associated experiments or has not yet been saved and therefore cannot be deleted.\n");
    }
    else { 
	$self->get_page()->message_page("The primer $primer_name has been deleted\n");
    }				
}

# override generate_form to create the corresponding form
#
sub generate_form { 
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();
    my $primer = $self->get_object();
    my $primer_id = $self->get_object_id();

    # generate the form with the appropriate values filled in.
    # if we view, then take the data straight out of the database
    # if we edit, take data from database and override with what's
    # in the submitted form parameters.
    # if we store, only take the form parameters into account.
    # for new, we don't do anything - we present an empty form.
    #
    my $name = "";
    my $sequence = "";
    my $link = "";
    my $link_desc = "";
    my $namespace_id = 0;

    my ($namespace_name_list_ref, $namespace_id_list_ref) = CXGN::Insitu::Namespace::get_all_namespaces($self->get_dbh());

    

    if ($self->get_action()=~/view|edit/) { 
	$name = $primer->get_name();
	$sequence = $primer ->get_sequence();
	$link = $primer->get_link();
	$link_desc = $primer->get_link_desc();
	$namespace_id = $primer->get_namespace_id();
	
    }
#     if ($self->get_action()=~/edit/) { 
# 	$name ||= $args{name};
# 	$sequence ||=$args{sequence};
# 	$link ||= $args{link};
# 	$link_desc ||= $args{link_desc};
#     }
    if ($self->get_action()=~/store/) { 
	$name = $args{name};
	$sequence = $args{sequence};
	$link = $args{link};
	$link_desc = $args{link_desc};
	$namespace_id = $args{namespace_id};
    }

    $self->get_form()->add_field( display_name=>"Name", field_name=>"name", 
		      contents=>$name, length=>20, object=>$primer, 
		      getter=>"get_name", setter=>"set_name", 
		      validate=>"string"
		      );
    $self->get_form()->add_field( display_name=>"Sequence", field_name=>"sequence", 
		      contents=>$sequence, length=>50, 
		      object=>$primer, getter=>"get_sequence", 
		      setter=>"set_sequence"
		      );

    $self->get_form()->add_select( display_name=>"Namespace", 
				   field_name=>"namespace",
				   contents=>$namespace_id,
				   object=>$primer,
				   getter=>"get_namespace_id",
				   setter=>"set_namespace_id",
				   select_list_ref => $namespace_name_list_ref,
				   select_id_list_ref => $namespace_id_list_ref,
				   );

    $self->get_form()->add_field( display_name=>"Link", field_name=>"link",
                      contents=>$link, object=>$primer,
		      getter=>"get_link", setter=>"set_link"
		      );
    $self->get_form()->add_field( display_name=>"Link description", field_name=>"link_desc",
		      contents=>$link_desc, object=>$primer,
		      getter=>"get_link_desc", setter=>"set_link_desc"
		      );

    $self->get_form()->add_hidden( field_name=>"primer_id", 
		       contents=>$primer->get_primer_id(),
		       );
    $self->get_form()->add_hidden( field_name=>"action", 
		       contents=>"store",
		       );
}

# override display_page
#
sub display_page { 
    my $self = shift;
    my %args = $self->get_args();
    my $primer = $self->get_object();
    my $primer_id = $self->get_object_id();

    # create some static information
    #
    my $edit_link = "";
    my $delete_link = "";
    if ($self->get_action() eq "view" ) { 
	$edit_link = qq { <a href="primer.pl?primer_id=$args{primer_id}&amp;action=edit">[Edit]</a> };
	my $delete_link = qq { <a href="primer.pl?primer_id=$args{primer_id}&amp;action=confirm_delete">[Delete]</a> };
    }
    elsif ($self->get_action() eq "edit") { 
	$edit_link = qq { <a href="primer.pl?primer_id=$args{primer_id}&amp;action=view">[View]</a> };
    }
    elsif ($self->get_action() eq "new") { 
	$edit_link = qq { <a href="/insitu/manage.pl">[Cancel]</a> };
    }

    
    # display the form using the as_table() function of the form object.
    # This will be either the static or editable html code, depending 
    # on the type of form object (Form or EditableForm).
    # The hash also contains the FORM_START and FORM_END keys, which
    # need to be specified to start and end the form.
    #
    # create the fields for the page and render the page
    #

    my $action = $self->get_action();

    $self->get_page()->header();

    CXGN::Insitu::Toolbar::display_toolbar();
    
    print page_title_html(qq { $action <a href="/insitu/">Insitu</a> Primer Detail });
    print "$edit_link $delete_link <br /><br />\n";
    
    $self->get_form()->as_table();
    
    print qq { <br /><br />This primer is associated with these experiments:<br /><br /> };
    my @experiments = $primer->get_experiments();
    if (!@experiments) { print qq { (None found) }; }
    foreach my $e (@experiments) { 
	my $name = $e->get_name();
	my $id = $e->get_experiment_id();
	print qq { <a href="experiment.pl?experiment_id=$id">$name</a><br /> };
    }
    print qq { <br /><br /> };
    
    $self->get_page()->footer();
}
