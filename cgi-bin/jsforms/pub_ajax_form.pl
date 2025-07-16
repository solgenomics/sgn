use strict;
use warnings;

package CXGN::Chado::Pub::PubForm;
my $pub_form = CXGN::Chado::Pub::PubForm->new();

use base qw/CXGN::Page::Form::AjaxFormPage  /;


use Bio::Chado::Schema;
use CXGN::Chado::Publication;

use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Page::FormattingHelpers qw/
                                     tooltipped_text
                                   /;

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
    my $pub_id  = $args{pub_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    my %json_hash= $self->get_json_hash();

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id );
    my $dbh = $schema->storage->dbh;
    $self->set_object_id($pub_id);
    $self->set_object_name('publication'); #this is useful for email messages
    $self->set_object( CXGN::Chado::Publication->new($dbh, $pub_id) );


    unless ( ( $pub_id =~ m /^\d+$/ || !$pub_id  )  ) {
        $json_hash{error}="No publication exists for identifier $pub_id";
    }
    $self->set_json_hash(%json_hash);
    $self->set_primary_key("pub_id");
    

    $self->print_json() if $json_hash{error};
}


sub store {
    my $self=shift;

    my $pub    = $self->get_object();
    my $pub_id = $self->get_object_id();
   
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $initial_pub_id = $pub_id;

    my $error;


    $pub->set_title($args{title});
    $pub->set_series_name($args{series});
    $pub->set_volume($args{volume});
    $pub->set_issue($args{issue});
    $pub->set_pyear($args{pyear});
    $pub->set_pages($args{pages});
    $pub->set_abstract($args{abstract});
    $pub->set_author_string($args{authors});
    $pub->set_cvterm_name($args{cvterm_name});

#########

    my $validate;
    try{
	$self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
	$pub_id = $pub->get_pub_id() ;
    } catch {
	$error = " An error occurred. Cannot store to the database\n An  email message has been sent to the SGN development team";
	CXGN::Contact::send_email('pub_ajax_form.pl died', $error . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
    };
    
    #the validate field is false is validation passed for all fields, true if did not pass and the form is re-printed
    
    %json_hash= $self->get_json_hash();
    $validate= $json_hash{validate};
    $json_hash{error} = $error if $error;
    
    my $refering_page="/publication/$pub_id/view";
    $self->send_form_email({subject=>"[New publication details stored] publication $pub_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if !$initial_pub_id && !$validate && !$error;

    $self->set_json_hash(%json_hash);
    $self->print_json();
}


####################################
sub delete {
    my $self = shift;
    my $check = $self->check_modify_privileges();
    $self->print_json() if $check ; #error or no user privileges

    my $pub = $self->get_object();
    my $pub_id = $pub->get_pub_id;
    my $pub_title;

    my %json_hash= $self->get_json_hash();
    my $refering_page="/publication/$pub_id/view";
    my $message;

    if ($pub_id &&  !$json_hash{error}  ) {
	$pub_title = $pub->get_title;
	
	try {
            $message = $pub->delete ;
	    $json_hash{error} = $message;
	}catch {
            $json_hash{error} = " An error occurred. Cannot delete publication\n An  email message has been sent to the SGN development team";
            $self->send_form_email({subject=>"Publication delete failed!  ($pub_id) $_", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'});
        };
        $json_hash{reload} = 1;
    }

    $self->send_form_email({subject=>"Publication deleted ($pub_id)", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'}) if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->print_json();
    
}



sub generate_form {
    my $self = shift;
    my $form_id = 'edit_pub'; # a form_id is required for ajax forms

    $self->init_form($form_id) ; ## instantiate static/editable/confirmStore form
    my $pub = $self->get_object();
    my %args  = $self->get_args();
    my $form = $self->get_form();
    my $type = $args{type};
    my $type_id = $args{type_id};
    my $refering_page= $args{refering_page};

    my @types = qw |journal book curator |;

    #########
    my $author_example = tooltipped_text('Authors', 'Author names should be entered in the order of  last name, followed by "," then first name followed by ".". e.g Darwin, Charles. van Rijn, Henk. Giorgio,AB'); 

    if ($self->get_action =~ /new|edit/ ) { 
	$form->add_select(
            display_name       => "Publication type",
            field_name         => "cvterm_name",
            contents           => $pub->get_cvterm_name(),
            length             => 20,
            object             => $pub,
            getter             => "get_cvterm_name",
            setter             => "set_cvterm_name",
	    select_list_ref    => \@types,
            select_id_list_ref => \@types,
            );
    }
    $form->add_textarea(
	display_name => "Title",
	field_name   => "title",
	object       => $pub,
	getter       => "get_title",
	setter       => "set_title",
	validate      => 'string',
	columns      => 80,
	rows         => 1,
	);
    $form->add_field(
	display_name       => "Series name",
	field_name         => "series_name",
	object             => $pub,
	getter             => "get_series_name",
	setter             => "set_series_name",
	validate           => 'string',
	);
    
    $form->add_field(
	display_name       => "Volume",
	field_name         => "volume",
	object             => $pub,
	getter             => "get_volume",
	setter             => "set_volume",
	);
    $form->add_field(
	display_name       => "Issue",
	field_name         => "issue",
	object             => $pub,
	getter             => "get_issue",
	setter             => "set_issue",
	);
    $form->add_field(
	display_name       => "Year",
	field_name         => "year",
	object             => $pub,
	getter             => "get_pyear",
	setter             => "set_pyear",
	validate           => 'integer',
	);
    $form->add_field(
	display_name       => "Pages",
	field_name         => "pages",
	object             => $pub,
	getter             => "get_pages",
	setter             => "set_pages",
	validate           => 'string',
	);
    $form->add_field(
	display_name       => $author_example,
	field_name         => "author",
	object             => $pub,
	getter             => "get_authors_as_string",
	setter             => "set_author_string",
	columns            => 80,
	rows               => 1,
	);

    $form->add_textarea(
	display_name       => "Abstract",
	field_name         => "abstract",
	object             => $pub,
	getter             => "get_abstract",
	setter             => "set_abstract",
	columns            => 80,
	rows               => 12,
	);

    $form->add_hidden(
        field_name => "pub_id",
        contents   => $pub->get_pub_id(),
	object     => $pub,
	getter     => "get_pub_id",
	setter     => "set_pub_id",
        );

    $form->add_hidden(
        field_name => "type",
        contents   => $type,
        );
    $form->add_hidden(
        field_name => "type_id",
        contents   => $type_id,
        );
    $form->add_hidden(
        field_name => "refering_page",
        contents   => $refering_page,
	 );
    $form->add_hidden(
        field_name => "action",
        contents   => "store",
	);
    
   
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
