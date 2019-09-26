
use strict;
use warnings;

my $image_ajax_form = CXGN::ImageAjaxForm->new();

package CXGN::ImageAjaxForm;

use CatalystX::GlobalContext '$c';

use base "CXGN::Page::Form::AjaxFormPage";

use JSON;
use SGN::Image;
use Try::Tiny;

sub define_object {
    my $self = shift;

    my %json_hash = $self->get_json_hash();

    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();

    if ( !exists( $args{object_id} ) ) {
        $json_hash{error} = "No object_id provided";
    }

    $self->set_object_name('image');
    $self->set_object_id( $args{object_id} );
    $self->set_object(
        SGN::Image->new( $self->get_dbh(), $self->get_object_id(), $c ) );
    $self->set_primary_key("object_id");
    $self->set_owners( $self->get_object()->get_sp_person_id() );
    $self->set_json_hash(%json_hash);
}

sub generate_form {
    my $self = shift;

    my $form_id = 'image_form';
    my %args    = $self->get_args();

    $self->init_form($form_id);
    my $form = $self->get_form();

    my $image          = $self->get_object();
    my $object_id      = $self->get_object_id();
    my $submitter      = CXGN::People::Person->new( $self->get_dbh(), $image->get_sp_person_id() );
    my $sp_person_id   = $submitter->get_sp_person_id();
    my $submitter_name = ($submitter->get_first_name() || '') . " " . ($submitter->get_last_name() || '');
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;

    my $name        = "";
    my $description = "";

    if ( $self->get_action() =~ /view|edit/i ) {
        $name        = $image->get_name();
        $description = $image->get_description();
    }
    if ( $self->get_action() =~ /edit/i ) {
        $name        ||= $args{name};
        $description ||= $args{description};
    }
    if ( $self->get_action() =~ /store/i ) {
        $name        = $args{name};
        $description = $args{description};
    }

    $form->add_field(
        display_name => "Image Name:",
        field_name   => "name",
        contents     => $name,
        length       => 15,
        object       => $image,
        getter       => "get_name",
        setter       => "set_name"
    );
    $form->add_field(
        display_name => "Image Description: ",
        field_name   => "description",
        contents     => $description,
        length       => 40,
        object       => $image,
        getter       => "get_description",
        setter       => "set_description"
    );
    $form->add_hidden(
        display_name => "Image ID",
        field_name   => "object_id",
        contents     => $object_id
    );
    $form->add_hidden(
        display_name => "Action",
        field_name   => "action",
        contents     => "store"
    );
    $form->add_label(
        display_name => "Uploaded by: ",
        field_name   => "submitter",
        contents     => $submitter_link,
    );
    $self->set_form($form);

}

sub delete {
    my ( $self ) = @_;

    $self->check_modify_privileges
        or $self->print_json;


    my %json = $self->get_json_hash;

    try {
        $self->get_object->delete;
        $json{success} = 1;
    } catch {
        $json{error} = "Deletion failed ($_)";
    };

    #$self->set_json_hash( %json );
    #$self->print_json;

}


sub store {
    my $self=shift;
    my $image    = $self->get_object();
    my $image_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $error;
    try{
        $self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
        $image_id = $image->get_image_id;
    } catch {
        $error = " An error occurred. Cannot store to the database\n An  email message has been sent to the SGN development team";
        CXGN::Contact::send_email('image_ajax_form.pl died', $error . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
    };
    #the validate field is false is validation passed for all fields, true if did not pass and the form is re-printed

    %json_hash= $self->get_json_hash();
    my $validate= $json_hash{validate};
    $json_hash{error} = $error if $error;

    my $refering_page="/image/index.pl?image_id=$image_id";
    $self->send_form_email({subject=>"[New image details stored] image $image_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if  !$validate && !$error;

    $self->set_json_hash(%json_hash);
    $self->print_json();
}

