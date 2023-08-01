use strict;
use warnings;

package CXGN::Phenome::Stock::StockForm;
my $stock_form = CXGN::Phenome::Stock::StockForm->new();

use base qw/CXGN::Page::Form::AjaxFormPage  /;


use CXGN::Tools::Organism;
use Bio::Chado::Schema;
use CXGN::Stock;

use CXGN::People::Person;
use CXGN::Contact;


use Try::Tiny;

use JSON;
use CatalystX::GlobalContext qw( $c );


sub new {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self = shift;
    my %args      = $self->get_args();
    my $stock_id  = $args{stock_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    my %json_hash= $self->get_json_hash();
    my $sp_person_id = $self->get_user()->get_sp_person_id();

    print STDERR "this is sp_person_id before dbic_schema: ".$sp_person_id."\n";

    my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    $self->set_object_id($stock_id);
    $self->set_object_name('Stock'); #this is useful for email messages
    $self->set_object( CXGN::Stock->new({schema=>$schema, stock_id=>$stock_id}) );

    if ( $self->get_object()->is_obsolete() == 1 && $user_type ne 'curator' )
    {
        $json_hash{error}="Stock $stock_id is obsolete!";
    }
    unless ( ( $stock_id =~ m /^\d+$/ || !$stock_id  )  ) {
        $json_hash{error}="No stock exists for identifier $stock_id";
    }
    $self->set_json_hash(%json_hash);
    $self->set_primary_key("stock_id");
    my @owners;
    #my @owners = $self->get_object()->search_related("stockprops", {
    #type_id => $sp_person_cvterm_id } );

    $self->set_owners( @owners );

    $self->print_json() if $json_hash{error};
}


sub store {
    my $self=shift;

    my $stock    = $self->get_object();
    my $stock_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $initial_stock_id = $stock_id;

    my $error;
    $stock->species($args{organism});
    $stock->type_id($args{type_id});
    $stock->name($args{uniquename});
    $stock->uniquename($args{uniquename});
    $stock->description($args{description});


    my $message = $stock->exists_in_database();
    my $validate;
    if ($message) {
        $error = " Stock $args{uniquename}  already exists in the database ";
    }else {
        try{
            $self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
            $stock_id = $stock->stock_id() ;
        } catch {
            $error = " An error occurred. Cannot store to the database\n An  email message has been sent to the SGN development team";
            CXGN::Contact::send_email('stock_ajax_form.pl died', $error . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
        };
    }
    #the validate field is false is validation passed for all fields, true if did not pass and the form is re-printed

    %json_hash= $self->get_json_hash();
    $validate= $json_hash{validate};
    $json_hash{error} = $error if $error;

    my $refering_page="/stock/$stock_id/view";
    $self->send_form_email({subject=>"[New stock details stored] stock $stock_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if !$initial_stock_id && !$validate && !$error;

    $self->set_json_hash(%json_hash);

    $self->print_json();
}


####################################
sub delete {
    ##Delete the stock (actually set obsolete = 't')
    my $self = shift;
    my $check = $self->check_modify_privileges();
    $self->print_json() if $check ; #error or no user privileges

    my $stock      = $self->get_object();
    my $stock_name = $stock->uniquename();
    my $stock_id = $stock->stock_id();
    my %json_hash= $self->get_json_hash();
    my $refering_page="/stock/$stock_id/view";

    if (!$json_hash{error} ) {
        try {
            $stock->is_obsolete(1) ;
            $stock->store();
        }catch {
            $json_hash{error} = " An error occurred. Cannot delete stock\n An  email message has been sent to the SGN development team";
            $self->send_form_email({subject=>"Stock delete failed!  ($stock_name) $_", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'});
        };
        $json_hash{reload} = 1;
    }
    $self->send_form_email({subject=>"Stock obsoleted ($stock_name)", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'}) if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->print_json();
}



sub generate_form {
    my $self = shift;
    my $form_id = 'edit_stock'; # a form_id is required for ajax forms

    $self->init_form($form_id) ; ## instantiate static/editable/confirmStore form
    my $stock = $self->get_object();
    my %args  = $self->get_args();
    my $form = $self->get_form();

    #########
    my $species = $stock->get_species() ;
    my $organism_id = $species ? $stock->stock->organism_id : undef ;
    my ($stock_type) = $stock->get_schema->resultset("Cv::Cv")->search(
        { name => 'stock_type' , }
        );
    my @types;
    my @type_ids;
    if ($stock_type) {
        my $cvterm_res = $stock_type->
            search_related('cvterms');
        while (my $cvterm = $cvterm_res->next() ) {
            push @types, $cvterm->name() ;
            push @type_ids, $cvterm->cvterm_id();
        }
    }
          ##########

    if ( $self->get_action =~ /new|store|edit/ ) {
        $form->add_field(
            display_name => "Organism",
            field_name   => "Organism",
            id           => "species_name",
            object       => $stock,
            getter       => "get_species",
            setter       => "set_species",
            autocomplete => '/ajax/organism/autocomplete',
            );
        $self->get_form->add_select(
            display_name       => "Stock type",
            field_name         => "type_id",
            contents           => $stock->type_id(),
            length             => 20,
            object             => $stock,
            getter             => "type_id",
            setter             => "type_id",
            select_list_ref    => \@types,
            select_id_list_ref => \@type_ids,
            );
    }
    if ( $stock->is_obsolete()  ) {
        $form->add_label(
            display_name => "Status",
            field_name   => "obsolete_stat",
            contents     => 'OBSOLETE',
            );
    }
    if ( $self->get_action =~ /view/ ) {
        $form->add_label(
            display_name => "Organism",
            field_name   => "stock_organism",
            contents => $species ? qq|<a href="/organism/$organism_id/view"> | . $species . "</a>" : '',
            );
        $form->add_label(
            display_name => "Stock type",
            field_name   => "stock_type",
            contents => $stock->type() ,
            );
    }

    $form->add_field(
        display_name => "Uniquename ",
        field_name   => "uniquename",
        object       => $stock,
        getter       => "uniquename",
        setter       => "uniquename",
        validate     => 'string',
        );

    $form->add_textarea(
        display_name => "Description",
        field_name   => "description",
        object       => $stock,
        getter       => "description",
        setter       => "description",
        columns      => 40,
        rows         => 4,
        );

    $form->add_hidden(
        field_name => "stock_id",
        contents   => $stock->stock_id(),
        );
    $form->add_hidden(
	field_name => "sp_person_id",
	contents   => $self->get_user()->get_sp_person_id(),
	object     => $stock,
	setter     => "sp_person_id",
	);
    $form->add_hidden(
        field_name => "action",
        contents   => "store",
        );
    if ($self->get_action =~ /view/ ) {
        $form->add_hidden(
            field_name => "type_id",
            contents   => $stock->type_id,
            );
    }
    if ( $self->get_action() =~ /view|edit/ ) {
        $form->from_database();
    }
    elsif ( $self->get_action() =~ /store/ ) {
        my %json_hash = $self->get_json_hash() ;
        print $json_hash{html} ;
        $form->from_request( %args );
    }
}


1;
