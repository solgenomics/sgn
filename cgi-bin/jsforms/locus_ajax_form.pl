
my $locus_form = CXGN::Phenome::LocusForm->new();

package CXGN::Phenome::LocusForm;

use base qw/CXGN::Page::Form::AjaxFormPage  /; ##move all relevant functions to this parent class

use strict;
use warnings;

use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LinkageGroup;
use CXGN::Tools::Organism;

use CXGN::People::Person;
use CXGN::Contact; 
use CXGN::Feed;
use CXGN::Debug;

use Try::Tiny;

use JSON;


sub new {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    $self->get_ajax_page()->send_http_header();
    
    return $self;
}

sub define_object {
    my $self = shift;
   
    my %args      = $self->get_args();
    my $locus_id  = $args{locus_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    $self->set_object_id($locus_id);
    $self->set_object(
        CXGN::Phenome::Locus->new( $self->get_dbh(), $self->get_object_id() ) );
    if ( $self->get_object()->get_obsolete() eq 't' && $user_type ne 'curator' )
    {
	$self->set_json_hash({error=>'Locus $locus_id is obsolete!'});
	$self->return_json();
    }
    unless ( ( $locus_id =~ m /^\d+$/ ) || $args{action} eq 'new' ) {
        $self->set_json_hash({error=>'No locus exists for identifier $locus_id'});
	$self->return_json();
    }
    $self->set_primary_key("locus_id");
    $self->set_owners( $self->get_object()->get_owners() );
}

sub display_form {
    my $self = shift;
    my %json_hash = $self->get_json_hash();
   
    
    if (!($json_hash{html}) ) { $json_hash{html} = $self->get_form()->as_table_string() ;
    }		
    
    $json_hash{"user_type"} = $self->get_user()->get_user_type();
    $json_hash{"is_owner"} = $self->get_is_owner();
    $json_hash{"editable_form_id"} = $self->get_form()->get_form_id();


    $self->set_json_hash(%json_hash);
    $self->return_json();
}

sub store {
    my $self=shift;
    
    my $locus    = $self->get_object();
    my $locus_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    
    
    my ($message) =
	$locus->exists_in_database( $args{locus_name}, $args{locus_symbol} );
    
    if ($message) {
	$json_hash{error} = " Locus $args{locus_name} (symbol=  $args{locus_symbol} ) already exists in the database ";
	
    }else {
	try{
	    $self->SUPER::store();
	    %json_hash=$self->get_json_hash();
	    
	} catch { 
	    $json_hash{error} = " An error occurred. Cannot store to the database\n An  email message has been sent to the SGN development team";
	    CXGN::Contact::send_email('locus_ajax_form.pl died',$json_hash{"error"} . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
	};
    }
    $self->send_form_email({subject=>'[New locus details stored] locus $locus_id', mailing_list=>'sgn-db-curation@sgn.cornell.edu', referring_page=>'www.solgenomics.net/phenome/locus_display.pl?locus_id=$locus_id'});
    $self->set_json_hash(%json_hash);
    $self->return_json();
    
}


####################################
sub delete {
    ##Delete the locus (actually set obsolete = 't')
    my $self = shift;
    $self->check_modify_privileges();
    my $locus      = $self->get_object();
    my $locus_name = $locus->get_locus_name();
    my %json_hash= $self->get_json_hash();
    if (!$json_hash{error} ) {
	try {
	    $locus->delete();
	}catch {
	    $json_hash{error} = " An error occurred. Cannot delete locus\n An  email message has been sent to the SGN development team";
	};
	$json_hash{reload} = 1;
    }
    $self->send_locus_email('delete') if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->return_json();
}



sub return_json {
    my $self=shift;
    my %results= $self->get_json_hash();
    
    if ($results{die_error} ) { 
	CXGN::Contact::send_email('locus_ajax_form.pl died',$results{die_error}, 'sgn-bugs@sgn.cornell.edu');
    }
    
    my $json = JSON->new();
    my $jobj = $json->encode(\%results);
    print  $jobj;
}




sub generate_form {
    my $self = shift;
    my $form_id = 'edit_locus'; # a form_id is required for ajax forms
    
    $self->init_form($form_id) ; ## instantiate static/editable/confirmStore form
    
    my $locus = $self->get_object();
    my %args  = $self->get_args();
    my $form = $self->get_form();
    my $dbh = $self->get_dbh();

    my ( $organism_names_ref, $organism_ids_ref ) =
	CXGN::Tools::Organism::get_all_organisms( $self->get_dbh() );
    my ($lg_names_ref) =
	CXGN::Phenome::Locus::LinkageGroup::get_all_lgs( $self->get_dbh() );
    my ($lg_arms_ref) =
	CXGN::Phenome::Locus::LinkageGroup::get_lg_arms( $self->get_dbh() );
    
 
    if ( $self->get_action =~ /new/ ) {
	$self->get_form->add_select(
	    display_name       => "Organism ",
	    field_name         => "common_name_id",
	    contents           => $locus->get_common_name_id(),
	    length             => 20,
	    object             => $locus,
	    getter             => "get_common_name_id",
	    setter             => "set_common_name_id",
	    select_list_ref    => $organism_names_ref,
	    select_id_list_ref => $organism_ids_ref,
	    );
	
    }
    if ( $locus->get_obsolete() eq 't' ) {
	$form->add_label(
	    display_name => "Status",
	    field_name   => "obsolete_stat",
	    contents     => 'OBSOLETE',
	    );
    }
    $form->add_field(
	display_name => "Locus name ",
	field_name   => "locus_name",
	object       => $locus,
	getter       => "get_locus_name",
	setter       => "set_locus_name",
	validate     => 'string',
	);
    
    $form->add_field(
        display_name => "Symbol ",
        field_name   => "locus_symbol",
        object       => $locus,
        getter       => "get_locus_symbol",
        setter       => "set_locus_symbol",
        validate     => 'token',
	formatting   => '<i>*</i>',
	);
    
    $form->add_field(
	display_name => "Gene activity ",
	field_name   => "gene_activity",
	object       => $locus,
	getter       => "get_gene_activity",
	setter       => "set_gene_activity",
	length       => '50',
	);
    
    $form->add_textarea(
	display_name => "Description ",
	field_name   => "description",
	object       => $locus,
	getter       => "get_description",
	setter       => "set_description",
	columns      => 40,
	rows         => => 4,
	);
    
    $form->add_select(
	display_name       => "Chromosome ",
	field_name         => "lg_name",
	contents           => $locus->get_linkage_group(),
	length             => 10,
	object             => $locus,
	getter             => "get_linkage_group",
	setter             => "set_linkage_group",
	select_list_ref    => $lg_names_ref,
	select_id_list_ref => $lg_names_ref,
	);
    
    $form->add_select(
	display_name       => "Arm",
	field_name         => "lg_arm",
	contents           => $locus->get_lg_arm(),
	length             => 10,
	object             => $locus,
	getter             => "get_lg_arm",
	setter             => "set_lg_arm",
	select_list_ref    => $lg_arms_ref,
	select_id_list_ref => $lg_arms_ref,
	);
    
    $form->add_hidden(
	field_name => "locus_id",
	contents   => $locus->get_locus_id(),
	);
    
    $form->add_hidden(
	field_name => "action",
	contents   => "store",
	);
    
    $form->add_hidden(
	field_name => "sp_person_id",
	contents   => $self->get_user()->get_sp_person_id(),
	object     => $locus,
	setter     => "set_sp_person_id",
	
	);
    $form->add_hidden(
	field_name => "updated_by",
	contents   => $self->get_user()->get_sp_person_id(),
	object     => $locus,
	setter     => "set_updated_by",
	);
    
    if ( $self->get_action() =~ /view|edit/ ) {
	$form->from_database();
	$form->add_hidden(
	    field_name => "common_name_id",
	    contents   => $locus->get_common_name_id(),
	    );
	
    }
    elsif ( $self->get_action() =~ /store/ ) {
	#print STDERR "getting form from request ...\n\n\n\n";
	$form->from_request( %args );
    }
}



sub send_locus_email {
    my $self   = shift;
    my $action = shift;
    my $user=$self->get_user();
    my $locus= $self->get_object();
    
    my $locus_id = $locus->get_locus_id();
    my $name     = $locus->get_locus_name();
    my $symbol   = $locus->get_locus_symbol();

    my $subject = "[New locus details stored] locus $locus_id";
    my $username =
        $user->get_first_name() . " "
	. $user->get_last_name();
    my $sp_person_id = $user->get_sp_person_id();
    
    my $locus_link =
	qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
    my $user_link =
	qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    
    my $usermail = $user->get_private_email();
    my $fdbk_body;
    if ( $action eq 'delete' ) {
        $fdbk_body =
	    "$username ($user_link) has obsoleted locus  $name ($locus_link) \n  $usermail";
    }
    elsif ( $locus_id == 0 ) {
        $fdbk_body =
	    "$username ($user_link) has submitted a new locus  \n$name ($locus_link)\nLocus symbol: $symbol\n $usermail ";
    }
    else {
        $fdbk_body =
	    "$username ($user_link) has submitted data for locus $name ($locus_link) \nLocus symbol: $symbol\n $usermail";
    }
    
    CXGN::Contact::send_email( $subject, $fdbk_body,'sgn-db-curation@sgn.cornell.edu' );
    CXGN::Feed::update_feed( $subject, $fdbk_body );
}
