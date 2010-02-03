
use strict;

my $organism_detail_page = CXGN::Insitu::Organism_detail_page->new();

package CXGN::Insitu::Organism_detail_page;

use CXGN::Insitu::Organism;
use CXGN::Insitu::Toolbar;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("organism_new.pl");

    return $self; 
}

sub define_object { 
    my $self = shift;
    my %args = $self->get_args();
    $self->set_object_id($args{organism_id});
    $self->set_object(CXGN::Insitu::Organism->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("organism_id");		      
    $self->set_owners($self->get_object()->get_user_id());
}

sub generate_form { 
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();
    my $organism = $self->get_object();

    my $organism_name = "";
    my $common_name = "";
    my $description = "";
    my $organism_id = 0;
    
    if ($self->get_action()=~/view|edit/i) { 
	$organism_name = $organism->get_name();

	$common_name = $organism->get_common_name();
	$description= $organism->get_description();
	$organism_id = $organism->get_organism_id();
	
    }
    if ($self->get_action()=~/view/i) { 
	$organism_name = "<i>$organism_name</i>";
    }

    if ($self->get_action()=~/store/i) { 
	$organism_name = $args{name};
	$common_name = $args{common_name};
	$description = $args{description};
	$organism_id = $args{organism_id};
    }

    
    # add form elements
    #
    $self->get_form()->add_field(display_name=>"Scientific name: ", field_name=>"name", contents=>$organism_name, length=>20, object=>$organism, getter=>"get_name", setter=>"set_name", validate=>"string");
    
    $self->get_form()->add_field( display_name=>"Common name: ", field_name=>"common_name", contents=>$common_name, length=>20, object=>$organism, getter=>"get_common_name", setter=>"set_common_name");
    
    $self->get_form()->add_field( display_name=>"Description: ", field_name=>"description", contents=>$description, length=>50, object=>$organism, getter=>"get_description", setter=>"set_description");
    
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    $self->get_form()->add_hidden( field_name=>"organism_id", contents=>$args{organism_id} );
    
}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();

    # generate an appropriate edit link
    #
    my $organism=$self->get_object();
    my $organism_id=$self->get_object_id();

    my $script_name = $self->get_script_name();
    my @associated_experiments = $self->get_object()->get_associated_experiments();

    my $edit_link = "";
    if ($self->get_action() eq "edit") { 
	$edit_link = qq { <a href="$script_name?organism_id=$organism_id&amp;action=view">View</a> };
    }
    if ($self->get_action() eq "view") { 
	$edit_link = qq { <a href="$script_name?organism_id=$organism_id&amp;action=edit">Edit</a>};
    }
    
    
    # render the form
    #
    $self->get_page()->header();
    
    CXGN::Insitu::Toolbar::display_toolbar();
    
    print page_title_html("<h3><a href=\"/\">Insitu</a> Organism Detail</h3>" );

    print "<h3>$args{action} </h3>";
    print $edit_link;
 
    print qq { <center> };
    
    $self->get_form()->as_table();
    
    print qq { </center> };
    
    print qq { <br /><br /><b>Associated experiments</b>: <br /><br /> };
    foreach my $e (@associated_experiments) { 
	my $experiment_name = $e->get_name();
	my $experiment_id = $e->get_experiment_id();
	print qq { <a href="experiment.pl?experiment_id=$experiment_id&amp;action=view">$experiment_name</a> <br /> };
    }

    $self->get_page()->footer();

}
