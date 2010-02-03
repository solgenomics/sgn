use strict;

my $image_detail_page = CXGN::Insitu::Image_detail_page->new();

package CXGN::Insitu::Image_detail_page;

use CXGN::Insitu::Image;
use CXGN::Insitu::Experiment;
use CXGN::Insitu::Toolbar;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("image.pl");

    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{image_id});
    $self->set_object(CXGN::Insitu::Image->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("image_id");		      
    $self->set_owners($self->get_object()->get_user_id());
}

sub delete {
    my $self = shift;
    my $image = $self->get_object();
    my $experiment_id = $image->get_experiment_id();

    $image->delete();
    $self->get_page()->header();

    print qq { 
	The image has been successfully deleted. 
	    <a href="experiment.pl?experiment_id=$experiment_id&amp;action=edit">Return to experiment page.</a> };
    $self->get_page()->footer();
    exit();
}


# the following function was moved to the parent class:
#
# sub check_modify_privileges { 
#     my $self = shift;
#     my $image = $self->get_object();
    
#     my $person_id = $self->get_login()->verify_session();
#     my $user =  CXGN::People::Person->new($person_id);
#     my $user_id = $user->get_sp_person_id();
#     if ($user->get_user_type() !~ /submitter|sequencer|curator/) { 
# 	$self->get_page()->message_page("You must have an account of type submitter to be able to submit data. Please contact SGN to change your account type.");
#     }
#     if ($image->get_user_id() && ($image->get_user_id() != $user_id))
#     {
# 	$self->get_page()->message_page("You do not have rights to modify this database entry because you do not own it.");
#     }
#     else { 
# 	return 0;
#     }


# }

sub generate_form { 
    my $self = shift;

    my $form;

    $self->init_form();

    my %args = $self->get_args();
    
    my $image = $self->get_object();
    my $image_id = $self->get_object_id();
    my $submitter = CXGN::People::Person->new($image->get_user_id());
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $name = "";
    my $description = "";

    if ($self->get_action()=~/view|edit/i) { 
	$name = $image->get_name();
	$description = $image->get_description();
    }
    if ($self->get_action()=~/edit/i) { 
	$name ||= $args{name};
	$description ||= $args{description};
    }
    if ($self->get_action()=~/store/i) { 
	$name = $args{name};
	$description = $args{description};
    }

    my $form = undef;
    if ($self->get_action()=~/new|edit|store/ ) { 
	print STDERR "Generating EditableForm..\n";
	$form = CXGN::Page::Form::Editable->new();
    }
    else { 
	print STDERR "Generating static Form...\n";
	$form = CXGN::Page::Form::Static->new();
    }

    $form->add_field( display_name=>"Image Name:", field_name=>"name", contents=>$name, length=>15, object=>$image, getter=>"get_name", setter=>"set_name");
    $form->add_field(  display_name=>"Image Description: ", field_name=>"description", contents=>$description, length=>40, object=>$image, getter=>"get_description", setter=>"set_description" );
    $form->add_hidden( display_name=>"Image ID", field_name=>"image_id", contents=>$image_id);
    $form->add_hidden(  display_name=>"Action", field_name=>"action", contents=>"store");
    $form->add_label( display_name=>"Submitter", 
				  field_name=>"submitter", 
				  contents=>$submitter_name
				  );
    $self->set_form($form);
        
}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();
    
    my $image = $self->get_object();
    my $image_id = $self->get_object_id();

    my $experiment_id = $image->get_experiment_id();
    my $experiment = CXGN::Insitu::Experiment->new($self->get_dbh(), $experiment_id);

    my $experiment_name = $experiment->get_name();
    my $image_fullsize_url = $image->get_fullsize_url();
    my $image_id = $image->get_image_id();

    my $tag_link = qq { <a href="tag.pl?image_id=$image_id&amp;action=new">Add tag</a> };
    my $edit_link = "";
    my $delete_link = "";
    if ($self->get_action() eq "view") {
	$edit_link = qq { <a href="image.pl?image_id=$image_id&amp;action=edit">[Edit]</a> };
	$delete_link = qq { <a href="image.pl?image_id=$image_id&amp;action=confirm_delete">[Delete]</a> };
    }
    if ($self->get_action()=~/edit|store/) { 
	$edit_link = qq { <a href="image.pl?image_id=$image_id&amp;action=view">[View]</a> };
    }

    $self->get_page()->header();
    
    print page_title_html(qq{<a href="/insitu/">Insitu</a> Image });
    
    CXGN::Insitu::Toolbar::display_toolbar();

    print qq { $edit_link $delete_link <br /> };

    $self->get_form()->as_table();
    
    print qq { <br /><a href="$image_fullsize_url"> };
    print $image->get_img_src_tag();
    print qq { </a> };

    print qq { <br /><br /><b>Associated tags:</b> [$tag_link] <br /> };

    foreach my $t ($image->get_tags()) { 
	print $t->get_name(). "<br />";
    }
    
    print qq { <br /><br /><b>Associated to experiment: </b> 
		   <a href="experiment.pl?experiment_id=$experiment_id&amp;action=view">$experiment_name</a>
	       };

    $self->get_page()->footer();
    
    exit();
}
