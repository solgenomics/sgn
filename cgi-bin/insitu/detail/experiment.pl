
use strict;

my $experiment_detail_page = CXGN::Insitu::Experiment_detail_page->new('insitu');

package CXGN::Insitu::Experiment_detail_page;

use CXGN::Insitu::Experiment;
use CXGN::Insitu::Organism;
use CXGN::Insitu::Toolbar;
use SGN::Image;
use CXGN::Tag;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::People::Person;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    #$self->set_script_name("experiment.pl");

    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{experiment_id});
    $self->set_object(CXGN::Insitu::Experiment->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("experiment_id");		      
    $self->set_owners($self->get_object()->get_user_id());
}

sub delete { 
    my $self = shift;
    $self->check_modify_privileges();
    my $experiment = $self->get_object();
    my $experiment_name = $experiment->get_name();
    my $error = $experiment->delete();
    $self->get_page()->message_page("The experiment $experiment_name has been deleted.");
}


sub generate_form { 
    my $self = shift;

    $self->init_form();
    my %args = $self->get_args();
    my $experiment = $self->get_object();
    my $experiment_id = $self->get_object_id();
 
    # get some organism and probe information for the drop down menus
    #
    my ($organism_names_ref, $organism_ids_ref) = CXGN::Insitu::Organism::get_all_organisms($self->get_dbh());
    my ($probe_names_ref, $probe_ids_ref) = CXGN::Insitu::Probe::get_all_probes($self->get_dbh());
    my $types_names_ref = [ "Insitu", "Immunolocalization", "Histochemical localization" ]; 
   
    my %field = (
		 experiment_name => "",
		 date => "",
		 tissue => "",
		 stage => "",
		 description => "",
		 probe_id => "",
		 probe_name => "", 
		 organism_id => "",
		 user_id =>"",
		 );
    my $organism_name = "";
    my $organism_link = "";
    my $submitter;
    my $submitter_name="";
    my $probe_name="";
    
    if ($self->get_action()=~/view|edit/i) { 
	$field{type} = $experiment->get_type();
	$field{probe_id} = $experiment->get_probe_id();
	$field{user_id} = $experiment->get_user_id();
	$probe_name = $experiment->get_probe()->get_name();
	$field{organism_id} = $experiment -> get_organism_id();
	$organism_name = $experiment->get_organism();
	$organism_link = qq { <a href="organism.pl?organism_id=$field{organism_id}&amp;action=view">$organism_name</a> };
	$field{user_id} = $experiment->get_user_id();
	$submitter = CXGN::People::Person->new($self->get_dbh(), $field{user_id});
	$submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    }
#     if ($self->get_action()=~/edit/i) { 
# 	$submitter ||= CXGN::People::Person->new($field{user_id});
# 	$submitter_name ||= $submitter->get_first_name()." ".$submitter->get_last_name();

#     }
    if ($self->get_action()=~/store/i) { 
	$probe_name = CXGN::Insitu::Probe->new($self->get_dbh(), $field{probe_id})->get_name();
	$organism_name = CXGN::Insitu::Organism->new($self->get_dbh(), $field{organism_id})->get_name();
	$submitter = CXGN::People::Person->new($self->get_dbh(), $field{user_id});
	$submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();

    }
        
    # generate the form using CXGN::Form.
    # setup the form using the CXGN::Page::Form functions for editable content
    #
    $self->get_form()-> add_field( display_name=>"Name", field_name=>"name", contents=>$field{name}, length=>20, object=>$experiment, getter=>"get_name", setter=>"set_name", validate=>"string" );
    
    $self->get_form()-> add_field( display_name=>"Date", field_name=>"date", contents=>$field{date}, length=>15, object=>$experiment, getter=>"get_date", setter=>"set_date", validate=>"date");
    


    $self->get_form -> add_field( display_name=>"Tissue", field_name=>"tissue", contents=> $field{tissue}, length=>15, object=>$experiment, getter=>"get_tissue", setter=>"set_tissue");
    
    $self->get_form -> add_field( display_name=>"Stage", field_name=>"stage", contents=>$field{stage}, length=>20, object=>$experiment, getter=>"get_stage", setter=>"set_stage"  );
    
    $self->get_form -> add_field( display_name=>"Other info", field_name=>"description", contents=> $field{description}, length=>30, object=>$experiment, getter=>"get_description", setter=>"set_description"  );
    
    $self->get_form -> add_hidden( field_name => "experiment_id", contents=>$experiment_id );

    $self->get_form -> add_hidden( field_name => "action", contents=>"store" );
    
#    if ($self->get_action() =~/edit|new|store/) {     

	$self->get_form -> add_select( display_name=>"Type", field_name=>"type", contents=>$field{type}, length=>20, object => $experiment, getter=>"get_type", setter=>"set_type", select_list_ref=>$types_names_ref, select_id_list_ref=>$types_names_ref );

	$self->get_form->add_select( display_name=>"Organism", field_name=>"organism_id", contents=>$field{organism_id}, length=>10, object=>$experiment, getter=>"get_organism_id", setter=>"set_organism_id",  select_list_ref=>$organism_names_ref, select_id_list_ref=>$organism_ids_ref );
	
	$self->get_form->add_select( display_name=>"Probe", field_name=>"probe_id", contents=>$field{probe_id}, length=>10, object=>$experiment, getter=>"get_probe_id", setter=>"set_probe_id", select_list_ref=>$probe_names_ref, select_id_list_ref=>$probe_ids_ref );
	
 #   }
#    elsif ($self->get_action() eq "view") { 

# 	    $self->get_form -> add_field( display_name=>"Type", field_name=>"type", contents=>$field{type}, length=>20, object => $experiment, getter=>"get_type", setter=>"set_type" );

# 	$self->get_form->add_field( display_name=>"Organism", field_name=>"organism_id", contents=>$organism_link, length=>20, validate=>"integer" );

# 	$self->get_form()->add_field( display_name=>"Probe", field_name=>"probe_id", contents=> qq { <a href="probe.pl?probe_id=$field{probe_id}">$probe_name</a> } , length=>20, validate=>"integer" );

#     }
    $self->get_form()->add_label( display_name=>"Submitter", 
				  field_name=>"submitter", 
				  contents=>$submitter_name,
				  );

    if ($self->get_action()=~ /edit|view/) { 
	$self->get_form()->from_database();
    }
    if ($self->get_action()=~/store/) { 
	$self->get_form()->from_request(%args);
    }


}

sub display_page { 
    my $self = shift;
    
    my %args = $self->get_args();
    my $experiment = $self->get_object();
    my $experiment_id = $self->get_object_id();
    my $user_id = $experiment->get_user_id();
    my $user = CXGN::People::Person->new($self->get_dbh(), $user_id);

    # display and edit and delete link if we are not currently 
    # in editing mode...
    #
    my $edit_link = "";
    my $delete_link = "";
    if ($self->get_action eq "new" ) { 
	$edit_link = " <a href=\"/insitu/manage.pl\">[Cancel]</a>";
    }
    elsif ($self->get_action() eq "edit") { 
	$edit_link = " <a href=\"experiment.pl?experiment_id=$experiment_id&amp;action=view\">[View]</a>";
    }
    else {
	$edit_link = " <a href=\"experiment.pl?experiment_id=$experiment_id&amp;action=edit\">[Edit]</a>";
	$delete_link = "<a href=\"experiment.pl?experiment_id=$experiment_id&amp;action=confirm_delete\">[Delete]</a>";
    }
    
    # get some information that will be displayed statically only
    #
    my $page_title = page_title_html("<a href=\"/insitu/\">Insitu</a> Experiment \"".$experiment->get_name()."\"");
    
    my $username = $experiment->get_user()->get_first_name()." ".$experiment->get_user()->get_last_name();
    if (!$username) { 
	$username=$user->get_first_name()." ".$user->get_last_name(); 
    }
    
    my $submit_user_id = $experiment->get_user()->get_sp_person_id();
    my $probe_id = $experiment->get_probe()->get_probe_id();
    my $probe_name = $experiment->get_probe()->get_name();
    
    my $categories = ""; # $experiment->get_categories();
    my $organism_name = $experiment -> get_organism();
    my $organism_id = $experiment->get_organism_id();
    my $action = $self->get_action();
    
    #print STDERR "*****   Organism: $organism_name id: $organism_id\n";
    my $image_count = $experiment->get_images();
    
    $self->get_page()->add_style(text => ".centered {text-align: center}");
    $self->get_page()->header();
    
    CXGN::Insitu::Toolbar::display_toolbar();
    
    my $categories = "";
    
    print <<HTML;
    
    $page_title
    <h3>$action</h3>
	
	<b>Experiment Info</b> $edit_link $delete_link<br /><br />

HTML

    $self->get_form()->as_table();

    my $tag_count = scalar($experiment->get_tags());

    print qq { <br /><br /><b>Associated tags</b> [<a href="/tag/?experiment_id=$experiment_id&amp;action=new">add/remove</a>]: <b>$tag_count</b> };

    foreach my $tag ($experiment->get_tags()) { 
	print $tag->get_name()."  ";
    }

	my $assoc_imgs_html = qq {<br /><br /><b>Associated images</b>: $image_count<br /><br />};
	
	$assoc_imgs_html .= "<table width=\"90%\" cellpadding=\"0\" cellspacing=\"0\" class=\"centered\"><tr>\n";
    
    my $i = 0;
    for ($i; $i< (my @image = $experiment->get_image_ids()); $i++) {
	my $image_id = $image[$i];
	my $image = SGN::Image->new($self->get_dbh(), $image_id);	
	$assoc_imgs_html .= "<td valign=\"top\"><a href=\"/image/view/$image_id\">".$image->get_img_src_tag("small")."</a>&nbsp;<br />";

	if ($self->get_action() eq "edit") { 
	    $assoc_imgs_html .= qq {<a href="/image/?image_id=$image_id&amp;type=experiment&amp;type_id=$experiment_id&amp;action=confirm_delete">Delete</a><br />};
	}
	
	$assoc_imgs_html .= qq { </td><td width="20">&nbsp;</td> };
	if (($i+1) % 3 == 0 ) { $assoc_imgs_html .= "</tr><tr>"; }
	
    }
    $assoc_imgs_html .= "<td></td></tr></table>"; #in xhtml 1.0+, a <tr> must have <td> children -- Evan, 1/6/07
    
    print $assoc_imgs_html;
    
    if ($self->get_action() eq "edit") { 
	print qq {<a href="/image/add?type=experiment&amp;type_id=$experiment_id&amp;action=new">Add new image</a> };
    }
    $self->get_page()->footer();
}
