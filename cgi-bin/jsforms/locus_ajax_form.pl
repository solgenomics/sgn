
use strict;
use warnings;

my $locus_form = CXGN::Phenome::LocusForm->new();

package CXGN::Phenome::LocusForm;

use base qw/CXGN::Page::Form::AjaxFormPage  /; 

use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LinkageGroup;
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
    my $locus_id  = $args{locus_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    my %json_hash= $self->get_json_hash();
    
    $self->set_object_id($locus_id);
    $self->set_object_name('Locus'); #this is useful for email messages
    $self->set_object(
        CXGN::Phenome::Locus->new( $self->get_dbh(), $self->get_object_id() ) );
    if ( $self->get_object()->get_obsolete() eq 't' && $user_type ne 'curator' )
    {
	##print STDERR "ERROR:: Locus $locus_id is obsolete!";
	$json_hash{error}="Locus $locus_id is obsolete!";
    }
    unless ( ( $locus_id =~ m /^\d+$/ || !$locus_id  )  ) {
        #print STDERR "ERROR:: 'No locus exists for identifier $locus_id'\n\n";
	$json_hash{error}="No locus exists for identifier $locus_id";
    }
    $self->set_json_hash(%json_hash);
    $self->set_primary_key("locus_id");
    $self->set_owners( $self->get_object()->get_owners() );
   
    $self->print_json() if $json_hash{error};
}


sub store {
    my $self=shift;
    
    my $locus    = $self->get_object();
    my $locus_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $initial_locus_id = $locus_id;
   
    my $error;
    $locus->set_common_name_id($args{common_name_id});
    
    my ($message) =
	$locus->exists_in_database( $args{locus_name}, $args{locus_symbol} );
    my $validate;
    if ($message) {
	$error = " Locus $args{locus_name} (symbol=  $args{locus_symbol} ) already exists in the database ";
    }else {
	try{
	    $self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
	    $locus_id = $locus->get_locus_id() ;
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
    
    my $refering_page="/phenome/locus_display.pl?locus_id=$locus_id";
    $self->send_form_email({subject=>"[New locus details stored] locus $locus_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if !$initial_locus_id && !$validate && !$error;
    
    $self->set_json_hash(%json_hash);
    
    $self->print_json();
}


####################################
sub delete {
    ##Delete the locus (actually set obsolete = 't')
    my $self = shift;
    my $check = $self->check_modify_privileges();
    $self->print_json() if $check ; #error or no user privileges
    
    my $locus      = $self->get_object();
    my $locus_name = $locus->get_locus_name();
    my $locus_id = $locus->get_locus_id();
    my %json_hash= $self->get_json_hash();
    my $refering_page="/phenome/locus_display.pl?locus_id=$locus_id";
    
    if (!$json_hash{error} ) {
	try {
	    $locus->delete();
	}catch {
	    $json_hash{error} = " An error occurred. Cannot delete locus\n An  email message has been sent to the SGN development team";
	};
	$json_hash{reload} = 1;
    }
    $self->send_form_email({subject=>"Locus obsoleted ($locus_name)", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'}) if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->print_json();
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
    
    if ( $self->get_action =~ /new|store/ ) {
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
	$form->from_request( %args );
    }
}



