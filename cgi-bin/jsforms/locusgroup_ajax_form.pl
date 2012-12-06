
use strict;
use warnings;

my $form = CXGN::Phenome::LocusGroupForm->new();

package CXGN::Phenome::LocusGroupForm;

use base qw/CXGN::Page::Form::AjaxFormPage  /;

use CXGN::Phenome::LocusGroup;
use CXGN::Phenome::Schema;

use CXGN::Tools::Organism;

use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Feed;

use Try::Tiny;

use JSON;


sub new {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self = shift;
    my %args      = $self->get_args();
    my $lg_id  = $args{locusgroup_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    my %json_hash= $self->get_json_hash();
    my $schema= CXGN::Phenome::Schema->connect( sub { $self->get_dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );

    $self->set_object_id($lg_id);
    $self->set_object_name('LocusGroup'); #this is useful for email messages
    $self->set_object(
        CXGN::Phenome::LocusGroup->new( $schema, $self->get_object_id ) );
    if ( $self->get_object()->get_obsolete() eq 't' && $user_type ne 'curator' )
    {
        $json_hash{error}="Locus group $lg_id is obsolete!";
    }
    unless ( ( $lg_id =~ m /^\d+$/ || !$lg_id  )  ) {
	$json_hash{error}="No locus group exists for identifier $lg_id";
    }
    $self->set_json_hash(%json_hash);
    $self->set_primary_key("locusgroup_id");
    $self->set_owners( $self->get_object->get_sp_person_id );
    $self->print_json() if $json_hash{error};
}


sub store {
    my $self=shift;
    my $locusgroup    = $self->get_object();
    my $lg_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $initial_lg_id = $lg_id;

    my $error;
    print STDERR "****locusgroup name arg = " . $args{locusgroup_name} ;
    $locusgroup->set_locusgroup_name($args{locusgroup_name});
    my ($message) = $locusgroup->exists_in_database($args{locusgroup_name});
    my $validate;
    if ($message) {
	$error = " Locus group $args{locusgroup_name} already exists in the database ";
    }else {
	try{
	    $self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
	    $lg_id = $locusgroup->get_locusgroup_id() ;
	} catch {
	    $error = " An error occurred. Cannot store to the database\n An  email message has been sent to the SGN development team";
	    CXGN::Contact::send_email('locus_ajax_form.pl died', $error . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
	};
    }
    #the validate field is false is validation passed for all fields, true if did not pass and the form is re-printed
    #$json_hash{validate}= $validate;
    %json_hash= $self->get_json_hash();
    $validate= $json_hash{validate};
    $json_hash{error} = $error if $error;

    my $refering_page="/genefamily/manual/$lg_id/view";
    $self->send_form_email({subject=>"[New locusgroup details stored] locusgroup $lg_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if !$initial_lg_id && !$validate && !$error;

    $self->set_json_hash(%json_hash);
    $self->print_json();
}


####################################
sub delete {
    ##Delete the locusgroup (actually set obsolete = 't')
    my $self = shift;
    my $check = $self->check_modify_privileges();
    $self->print_json() if $check ; #error or no user privileges

    my $locusgroup = $self->get_object();
    my $lg_name = $locusgroup->get_locusgroup_name();
    my $lg_id = $locusgroup->get_locusgroup_id();
    my %json_hash= $self->get_json_hash();
    my $refering_page="/genefamily/manual/$lg_id/view";
    if (!$json_hash{error} ) {
	try {
	    $locusgroup->delete();
	}catch {
	    $json_hash{error} = " An error occurred. Cannot delete locusgroup\n An  email message has been sent to the SGN development team";
	};
	$json_hash{reload} = 1;
    }
    $self->send_form_email({subject=>"LocusGroup obsoleted ($lg_name)", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'}) if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->print_json();
}



sub generate_form {
    my $self = shift;
    my $form_id = 'edit_locusgroup'; # a form_id is required for ajax forms
    $self->init_form($form_id) ; ## instantiate static/editable/confirmStore form

    my $locusgroup = $self->get_object();
    my %args  = $self->get_args();
    my $form = $self->get_form();
    my $relationship = $locusgroup->get_relationship_name;

    if ( $locusgroup->get_obsolete() eq 't' ) {
	$form->add_label(
	    display_name => "Status",
	    field_name   => "obsolete_stat",
	    contents     => 'OBSOLETE',
	    );
    }
    $form->add_field(
        display_name => "Gene family name",
        field_name   => "locusgroup_name",
        id           => "locusgroup_name",
        object       => $locusgroup,
        getter       => "get_locusgroup_name",
        setter       => "set_locusgroup_name",
        validate     => 'string',
        );
    $form->add_label(
        display_name => "Relationship",
        field_name   => "relationship",
        contents     => $relationship,
	    );
    #$form->add_select(
#	display_name       => "Chromosome ",
#	field_name         => "lg_name",
#	contents           => $locus->get_linkage_group(),
#	length             => 10,
#	object             => $locus,
#	getter             => "get_linkage_group",
#	setter             => "set_linkage_group",
	#select_list_ref    => $lg_names_ref,
	#select_id_list_ref => $lg_names_ref,
#	);

    $form->add_hidden(
	field_name => "locusgroup_id",
	contents   => $locusgroup->get_locusgroup_id(),
	);

    $form->add_hidden(
	field_name => "action",
	contents   => "store",
	);

    $form->add_hidden(
	field_name => "sp_person_id",
	contents   => $self->get_user()->get_sp_person_id(),
	object     => $locusgroup,
	setter     => "set_sp_person_id",

	);
#    $form->add_hidden(
#	field_name => "updated_by",
#	contents   => $self->get_user()->get_sp_person_id(),
#	object     => $locusgroup,
#	setter     => "set_updated_by",
#	);

    if ( $self->get_action() =~ /view|edit/ ) {
	$form->from_database();
	#$form->add_hidden(
	#    field_name => "common_name_id",
	#    contents   => $locus->get_common_name_id(),
	#    );
    }
    elsif ( $self->get_action() =~ /store/ ) {
	$form->from_request( %args );
    }
}
