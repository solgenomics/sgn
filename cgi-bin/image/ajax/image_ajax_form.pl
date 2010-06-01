
use strict;
use warnings;

my $image_ajax_form = CXGN::ImageAjaxForm->new();

package CXGN::ImageAjaxForm; 

use base "CXGN::Page::Form::AjaxFormPage";

use JSON;
use SGN::Image;

sub define_object { 
    my $self = shift;

    my %json_hash = ();
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();

    if (!exists($args{object_id})) { $json_hash{error} = "No object_id provided"; }

    $self->set_object_name('image');
    $self->set_object_id($args{object_id});
    $self->set_object(SGN::Image->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("object_id");		      
    $self->set_owners($self->get_object()->get_sp_person_id());
    $self->set_json_hash(%json_hash);
    $self->print_json() if exists($json_hash{error});
}

sub generate_form { 
    my $self = shift;


    my $form_id = 'image_form';
    my %args = $self->get_args();
    

    $self->init_form($form_id);
    my $form = $self->get_form();

    my $image = $self->get_object();
    my $object_id = $self->get_object_id();
    my $submitter = CXGN::People::Person->new($self->get_dbh(), $image->get_sp_person_id());
    my $sp_person_id= $submitter->get_sp_person_id();
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;

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

#     my $form = undef;
#     if ($self->get_action()=~/new|edit|store/ ) { 
# 	print STDERR "Generating EditableForm..\n";
# 	$form = CXGN::Page::Form::Editable->new();
#     }
#     else { 
# 	print STDERR "Generating static Form...\n";
# 	$form = CXGN::Page::Form::Static->new();
#     }

    $form->add_field( display_name=>"Image Name:", field_name=>"name", contents=>$name, length=>15, object=>$image, getter=>"get_name", setter=>"set_name" );
    $form->add_field(  display_name=>"Image Description: ", field_name=>"description", contents=>$description, length=>40, object=>$image, getter=>"get_description", setter=>"set_description" );
    $form->add_hidden( display_name=>"Image ID", field_name=>"object_id", contents=>$object_id);
    $form->add_hidden(  display_name=>"Action", field_name=>"action", contents=>"store"  );
    $form->add_label( display_name=>"Uploaded by: ", 
				  field_name=>"submitter", 
				  contents=>$submitter_link,
				  );
    $self->set_form($form);
        
}


