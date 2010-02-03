
use strict;

my $probe_detail_page = CXGN::Insitu::Probe_detail_page->new();

package CXGN::Insitu::Probe_detail_page;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::Insitu::Toolbar;
use CXGN::Insitu::Probe;
use CXGN::Phenome::DbxrefType;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("probe.pl");
    
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
    $self->set_object_id($args{probe_id});
    $self->set_object( CXGN::Insitu::Probe->new($self->get_dbh(),
						 $self->get_object_id()) );
    $self->set_primary_key("probe_id");		      
    $self->set_owners($self->get_object()->get_user_id());
}

# override delete to provide a delete mechanism for this page
#
sub delete { 
    my $self = shift;
    $self->check_modify_privileges();
    my $probe = $self->get_object();
    my $probe_name = $probe->get_name();
    my $errors = $probe->delete();
    if ($errors) { 
	$self->get_page()->message_page("This probe has either associated experiments or has not yet been saved and therefore cannot be deleted.\n");
    }
    else { 
	$self->get_page()->message_page("The probe $probe_name has been deleted\n");
    }				
}

# override generate_form to create the corresponding form
#
sub generate_form { 
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();
    my $probe = $self->get_object();
    my $probe_id = $self->get_object_id();

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
    my $identifier = "";
    my $primer1 = "";
    my $primer1_seq = "";
    my $primer2 = "";
    my $primer2_seq = "";
    my $dbxref_type_id = 0;

    my ($dbxref_list_ref, $dbxref_id_ref) = CXGN::Phenome::DbxrefType::get_all_dbxref_types($self->get_dbh());

    if ($self->get_action()=~/view|edit/) { 
	$name = $probe->get_name();
	$sequence = $probe ->get_sequence();
	$link = $probe->get_link();
	$link_desc = $probe->get_link_desc();
	$identifier = $probe->get_identifier();
	$primer1 = $probe->get_primer1();
	$primer1_seq = $probe->get_primer1_seq();
	$primer2 = $probe->get_primer2();
	$primer2_seq = $probe->get_primer2_seq();
	$dbxref_type_id = $probe->get_dbxref_type_id();
	
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
	$identifier = $args{identifier};
	$primer1 = $args{primer1};
	$primer1_seq = $args{primer1_seq};
	$primer2 = $args{primer2};
	$primer2_seq = $args{primer2_seq};
	$dbxref_type_id = $args{dbxref_type_id};
    }

    $self->get_form()->add_field( display_name=>"Name", field_name=>"name", 
		      contents=>$name, length=>20, object=>$probe, 
		      getter=>"get_name", setter=>"set_name", 
		      validate=>"string"
		      );
    $self->get_form()->add_field( display_name=>"Sequence", field_name=>"sequence", 
		      contents=>$sequence, length=>50, 
		      object=>$probe, getter=>"get_sequence", 
		      setter=>"set_sequence"
		      );

    $self->get_form()->add_select( display_name=>"Namespace", 
				   field_name=>"dbxref_type_id",
				   contents=>$dbxref_type_id,
				   object=>$probe,
				   getter=>"get_dbxref_type_id",
				   setter=>"set_dbxref_type_id",
				   select_list_ref => $dbxref_list_ref,
				   select_id_list_ref => $dbxref_id_ref,
				   );

    $self->get_form()->add_field( display_name=>"Identifier", field_name=>"identifier",
				  contents=>$identifier, object=>$probe,
				  getter=>"get_identifier", setter=>"set_identifier"
				  );

    $self->get_form()->add_field( display_name=>"5' primer name", field_name=>"primer1",
				  contents=>$primer1, object=>$probe,
				  getter=>"get_primer1", setter=>"set_primer1"
				  );

    $self->get_form()->add_field( display_name=>"5' primer sequence", field_name=>"primer1_seq",
				  contents=>$primer1_seq, object=>$probe,
				  getter=>"get_primer1_seq", setter=>"set_primer1_seq"
				  );

    $self->get_form()->add_field( display_name=>"3' primer name", field_name=>"primer2", 
				  contents=>$primer2, object=>$probe,
				  getter=>"get_primer2", setter=>"set_primer2"
				  );

    $self->get_form()->add_field( display_name=>"3' primer sequence", field_name=>"primer2_seq",
				  contents=>$primer2_seq, object=>$probe,
				  getter=>"get_primer2_seq", setter=>"set_primer2_seq"
				  );
    
#     $self->get_form()->add_field( display_name=>"Link", field_name=>"link",
#                       contents=>$link, object=>$probe,
# 		      getter=>"get_link", setter=>"set_link"
# 		      );
#     $self->get_form()->add_field( display_name=>"Link description", field_name=>"link_desc",
# 		      contents=>$link_desc, object=>$probe,
# 		      getter=>"get_link_desc", setter=>"set_link_desc"
# 		      );

    $self->get_form()->add_hidden( field_name=>"probe_id", 
		       contents=>$probe->get_probe_id(),
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
    my $probe = $self->get_object();
    my $probe_id = $self->get_object_id();

    # create some static information
    #
    my $edit_link = "";
    my $delete_link = "";
    my $identifier = $probe->get_identifier();
    if ($self->get_action() eq "view" ) { 
	$edit_link = qq { <a href="probe.pl?probe_id=$probe_id&amp;action=edit">[Edit]</a> };
	my $delete_link = qq { <a href="probe.pl?probe_id=$probe_id&amp;action=confirm_delete">[Delete]</a> };
    }
    elsif ($self->get_action() eq "edit") { 
	$edit_link = qq { <a href="probe.pl?probe_id=$probe_id&amp;action=view">[View]</a> };
    }
    elsif ($self->get_action() eq "new") { 
	$edit_link = qq { <a href="/insitu/manage.pl">[Cancel]</a> };
    }

    my $dbxref = CXGN::Phenome::DbxrefType->new($self->get_dbh(), $probe->get_dbxref_type_id());
    my $probe_link = "<a href=\"".($dbxref->get_dbxref_type_url().$identifier)."\">".($dbxref->get_dbxref_type_name())."</a>";
    
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
    
    print page_title_html(qq { $action <a href="/insitu/">Insitu</a> Probe Detail });
    print "$edit_link $delete_link <br /><br />\n";
    
    $self->get_form()->as_table();

    print qq { Probe link : $probe_link };
    
    print qq { <br /><br />This probe is associated with these experiments:<br /><br /> };
    my @experiments = $probe->get_experiments();
    if (!@experiments) { print qq { (None found) }; }
    foreach my $e (@experiments) { 
	my $name = $e->get_name();
	my $id = $e->get_experiment_id();
	print qq { <a href="experiment.pl?experiment_id=$id">$name</a><br /> };
    }
    print qq { <br /><br /> };
    
    $self->get_page()->footer();
}
