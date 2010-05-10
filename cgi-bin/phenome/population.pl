use strict;

my $population_detail_page = CXGN::Phenome::PopulationDetailPage->new();

package CXGN::Phenome::PopulationDetailPage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw /info_section_html 
                                      page_title_html
                                      columnar_table_html 
                                      html_optional_show 
                                      info_table_html
                                      tooltipped_text
                                      html_alternate_show
                                      /;

use CXGN::Phenome::Population;
use CXGN::Phenome::PopulationDbxref;
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;

use CXGN::Contact;
use CXGN::Map;


use base qw / CXGN::Page::Form::SimpleFormPage CXGN::Phenome::Main/;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("population.pl");
    

    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    $self->set_dbh(CXGN::DB::Connection->new('phenome'));
    my %args = $self->get_args();
    my $population_id= $args{population_id};
    unless (!$population_id || $population_id =~m /^\d+$/) { $self->get_page->message_page("No population exists for identifier $population_id"); }  
    $self->set_object_id($population_id);
    $self->set_object(CXGN::Phenome::Population->new($self->get_dbh(),$self->get_object_id()));
    $self->set_primary_key("population_id");		      
    $self->set_owners($self->get_object()->get_owners());
}




sub generate_form { 
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();
    
    my $population = $self->get_object();
    my $population_id = $self->get_object_id();
    my $type_id = $args{type_id};
    my $type=$args{type};
       
    my ($submitter, $submitter_link) = $self->submitter();
      
    my $login_user= $self->get_user();
    my $login_user_id= $login_user->get_sp_person_id();
    my $form = undef;
    
    if ($self->get_action()=~/edit|store/ && ($login_user_id = $submitter || $self->get_user()->get_user_type() eq 'curator') ) { 
	print STDERR "Generating EditableForm..\n";
	$form = CXGN::Page::Form::Editable->new();
    }
    else { 
	print STDERR "Generating static Form...\n";
	$form = CXGN::Page::Form::Static->new();
    }
       
   $form->add_field( 
		      display_name=>"Name:", 
		      field_name=>"name", 
		      length=>15, 
		      object=>$population, 
		      getter=>"get_name", 
		      setter=>"set_name",
		      validate => 'string',
		      );
    $form->add_textarea(  
			  display_name=>"Description: ", 
			  field_name=>"description",
			  object=>$population, 
			  getter=>"get_description", setter=>"set_description",
			  columns => 40,
			  rows =>4,
			  );
    
    	    
    $form->add_label( display_name=>"Uploaded by: ", 
			  field_name=>"submitter", 
			  contents=>$submitter_link,
			  );
    $form->add_hidden( field_name=>"population_id", contents=>$args{population_id});
   
    $form->add_hidden (
		       field_name => "sp_person_id",
		       contents   =>$self->get_user()->get_sp_person_id(), 
		       object     => $population,
		       setter     =>"set_sp_person_id", 
		       );
    
    $form->add_hidden( field_name=>"action", contents=>"store"  );

   
    
   
   
    $self->set_form($form);
    
    if ($self->get_action=~ /view|edit/) {
	$self->get_form->from_database();	
	
	
    }elsif ($self->get_action=~ /store/) {
	$self->get_form->from_request($self->get_args());
    
 }   
   
    
  
}

sub display_page { 
    my $self = shift;

    $self->get_page->add_style( text => <<EOS);
    
a.abstract_optional_show {
  color: blue;
  cursor: pointer;
  white-space: nowrap;
}
div.abstract_optional_show {
  background: #f0f0ff;
  border: 1px solid #9F9FC7;
  margin: 0.2em 1em 0.2em 1em;
  padding: 0.2em 0.5em 0.2em 1em;
}
EOS



    my %args = $self->get_args();
    
    my $population = $self->get_object();
    my $population_id = $self->get_object_id();
    my $population_name = $population->get_name();

    my $action = $args{action};
    if (!$population_id && $action ne 'new' && $action ne 'store') 
                     { $self->get_page->message_page("No population exists for this identifier"); }
    
    #used to show certain elements to only the proper users
    my $login_user= $self->get_user();
    my $login_user_id= $login_user->get_sp_person_id();
    my $login_user_type= $login_user->get_user_type(); 
    my $page="../phenome/population.pl?population_id=$population_id";
    
    $self->get_page()->header("SGN Population name: $population_name");
    
    print page_title_html("Population: $population_name \n");
    
    my $page="../phenome/population.pl?population_id=$population_id";
    $args{calling_page} = $page;
    
    my $population_html = $self->get_edit_link_html(). "\t[<a href=/phenome/qtl_form.pl>New QTL Population</a>] <br />";
    
    #print all editable form  fields
    $population_html .= $self->get_form()->as_table_string(); 

    
    my $phenotype = ""; 
    my @phenotype;
    my $graph_icon = qq |<img src="../documents/img/pop_graph.png"/> |;
    
    if ($population->get_web_uploaded()) {
	my @traits = $population->get_cvterms();

	foreach my $trait (@traits)  {
	    my $trait_id = $trait->get_user_trait_id();
	    my $trait_name = $trait->get_name();
	    my $definition = $trait->get_definition();
	    my ($min, $max, $avg, $std, $count)= $population->get_pop_data_summary($trait_id);
	
	    my $cvterm_obj  = CXGN::Chado::Cvterm::get_cvterm_by_name( $self->get_dbh(), $trait_name);
	    my $trait_link;	    
	    my $cvterm_id = $cvterm_obj->get_cvterm_id();
	    if ($cvterm_id)
	    {
	
		print STDERR "cvterm_id: $cvterm_id\n";
		$trait_link = qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">$trait_name</a>|; 

	    } else
	    {	
		print STDERR "trait_id: $trait_id\n";
		$trait_link = qq |<a href="/phenome/trait.pl?trait_id=$trait_id">$trait_name</a>|; 
	    }
	    

	    if ($definition) {
		push  @phenotype,  [map {$_} ( (tooltipped_text($trait_link, $definition)), 
                                    $min, $max, $avg, 
                           qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$trait_id">
                                 $count</a> 
                              |,
                           qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$trait_id">
                                  $graph_icon</a> 
                              | )];
	    } else  { push  @phenotype,  [map {$_} ($trait_name, $min, $max, $avg, 
                          qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$trait_id">
                             $count</a> 
                             |,
                           qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$trait_id">
                                  $graph_icon</a> 
                              |  )];
	    }
	}
    }
     else {
	 my @cvterms = $population->get_cvterms();
	 foreach my $cvterm(@cvterms)  {	
	     my ($min, $max, $avg, $std, $count)= $population->get_pop_data_summary($cvterm->get_cvterm_id());
	     my $cvterm_id = $cvterm->get_cvterm_id();
	     my $cvterm_name = $cvterm->get_cvterm_name();
	     if ($cvterm->get_definition()) {
		 push  @phenotype,  [map {$_} ( (tooltipped_text( qq|<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">
                                                                      $cvterm_name</a>
                                                                     |, 
                                    $cvterm->get_definition())), $min, $max, $avg, 
		          qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$cvterm_id">
                             $count</a> 
                             |,
		          qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$cvterm_id">
                               $graph_icon</a> 
                             | ) ];
	     } else  { push  @phenotype,  [map {$_} (qq | <a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">$cvterm_name</a>|, 
                            $min, $max, $avg, 
                     qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$cvterm_id">
                          $count</a> 
                        |, 
                     qq | <a href="/phenome/population_indls.pl?population_id=$population_id&amp;cvterm_id=$cvterm_id">
                          $graph_icon</a> 
                        |  ) ];
	     }
	 }
     }   
    
    my $accessions_link = qq |<a href="../search/phenotype_search.pl?wee9_population_id=$population_id">
                              See all accessions ...</a> 
                             |;
    
    my ($phenotype_data, $data_view, $data_download);
    
    if (@phenotype) {
	$phenotype_data = columnar_table_html(headings => [
							   'Trait',
							   'Minimum',
							   'Maximum',
							   'Average',
							   'No. of lines',
							   'QTL(s)...',
							   ],
					      data     =>\@phenotype,
					      __alt_freq   =>2,
					      __alt_width  =>1,
					      __alt_offset =>3,
					      __align =>'l',
					      );
        
# 	$data_view = html_optional_show("phenotype",
# 					'View/hide phenotype data summary',
# 					qq|$phenotype_data</b>|,
# 					1, #<  show data by default
# 					);

	$data_download .=  qq { <span><br/><br/>Download:<a href="pop_download.pl?population_id=$population_id"><b>\
                                [Phenotype raw data]</b></a><a href="genotype_download.pl?population_id=$population_id">\
                                <b>[Genotype raw data\]</b></a></span> 
                              }; 
    }
   
    
    my $pub_subtitle;
    if ($population_name && ($login_user_type eq 'curator' || $login_user_type eq 'submitter')) { 
	$pub_subtitle .= qq|<a href="../chado/add_publication.pl?type=population&amp;type_id=$population_id&amp;refering_page=$page&amp;action=new">[Associate publication]</a>|;
	
    }
    
    else { $pub_subtitle= qq|<span class=\"ghosted\">[Associate publication]</span>|;
       
    }

   
    my $pubmed;
    my $url_pubmed = qq | http://www.ncbi.nlm.nih.gov/pubmed/|;

    my @publications = $population->get_population_publications();
    my $abstract_view;
    my $abstract_count = 0;
    
    

    foreach my $pub (@publications) {
	my ($title, $abstract, $authors, $journal, $pyear, 
            $volume, $issue, $pages, $obsolete, $pub_id, $accession
           );
	$abstract_count++;

	my @dbxref_objs = $pub->get_dbxrefs();
	my $dbxref_obj = shift(@dbxref_objs);
	
	$obsolete = $population->get_population_dbxref($dbxref_obj)->get_obsolete();
	
	if ($obsolete eq 'f') {
	    $pub_id = $pub->get_pub_id();
	    $title = $pub->get_title();
	    $abstract = $pub->get_abstract();
	    $pyear = $pub->get_pyear();
	    $volume = $pub->get_volume();
	    $journal = $pub->get_series_name();
	    $pages = $pub->get_pages();
	    $issue = $pub->get_issue();
	
	    $accession = $dbxref_obj->get_accession();
	    my $pub_info = qq|<a href="/chado/publication.pl?pub_id=$pub_id" >PMID:$accession</a>|;
	
	    my @authors;
	    my $authors;
	    if ($pub_id) {  
	    
		my @pubauthors_ids = $pub->get_pubauthors_ids($pub_id);
	
		foreach my $pubauthor_id (@pubauthors_ids) {
		    my  $pubauthor_obj = CXGN::Chado::Pubauthor->new($self->get_dbh, $pubauthor_id);
		    my $last_name  = $pubauthor_obj->get_surname();
		    my $first_names = $pubauthor_obj->get_givennames();
		    my @first_names = split (/,/, $first_names);
		    $first_names = shift (@first_names);
		    push @authors, ("$first_names" ."  ". "$last_name");
		    $authors = join (", ", @authors);
		}
	    }     
         
 
	 
    	
	    $abstract_view = html_optional_show("abstracts$abstract_count",
			       'Show/hide abstract',
			       qq|$abstract <b> <i>$authors.</i> $journal. $pyear. $volume($issue). $pages.</b>|,
						 0, #< do not show by default
						 'abstract_optional_show', #< don't use the default button-like style
						);
   
	
	    $pubmed .= qq| <div><a href="$url_pubmed$accession" target="blank">$pub_info</a> $title $abstract_view</div> |;
	}
    }

    my $is_public = $population->get_privacy_status();
    my ($submitter_obj, $submitter_link) = $self->submitter();
    my $map_link = $self->genetic_map();
    print info_section_html(title   => 'Population Details',
			    contents => $population_html,
			    );

    if ($is_public || 
        $login_user_type eq 'curator' || 
        $login_user_id == 
        $population->get_sp_person_id() 
       )  {   
	if ($phenotype_data) {
	    print info_section_html(title    => 'Phenotype Data and QTLs',
			            contents => $phenotype_data ." ".$data_download 
		                   );
	} else {
	    print info_section_html(title    => 'Phenotype Data',
			            contents => $accessions_link 
	                           );
	}
    
	unless (!$map_link) {
	    print info_section_html( title    => 'Genetic Map',
				     contents => $map_link 
		                   );
	}	

    } else {
	my $message = "The QTL data for this population is not public yet. 
                       If you would like to know more about this data, 
                       please contact the owner of the data: <b>$submitter_link</b> 
                       or email to SGN:
                       <a href=mailto:sgn-feedback\@sgn.cornell.edu>
                       sgn-feedback\@sgn.cornell.edu</a>.\n";
	
	print info_section_html(title   => 'Phenotype Data and QTLs',
			        contents =>$message, 
	                       );

    }
    print info_section_html(title   => 'Literature Annotation',
			    #subtitle => $pub_subtitle,
			    contents => $pubmed, 
			    );
    
    if ($population_name) { 
	# change sgn_people.forum_topic.page_type and the CHECK constraint!!
	my $page_comment_obj = CXGN::People::PageComment->new($self->get_dbh(), "population", $population_id, $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args());  
	print $page_comment_obj->get_html();
    }
    
    $self->get_page()->footer();
    
    
    exit();
}






# override store to check if a locus with the submitted symbol/name already exists in the database

sub store { 
   my $self = shift;
   my $population = $self->get_object();
   my $population_id = $self->get_object_id();
   my %args = $self->get_args();
  
   $self->SUPER::store(0); 

 exit(); 
}


sub submitter {
    my $self = shift;    
    my $population = $self->get_object();
    my $sp_person_id= $population->get_sp_person_id();
    my $submitter = CXGN::People::Person->new($self->get_dbh(), $population->get_sp_person_id());
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name</a> |;
    
    return $submitter, $submitter_link;

}

sub genetic_map {
    my $self     = shift;
    my $mapv_id  = $self->get_object()->mapversion_id();

    if ($mapv_id) {
	my $map      = CXGN::Map->new( $self->get_dbh(), { map_version_id => $mapv_id } );
	my $map_name = $map->get_long_name();
	my $genetic_map =
	    qq | <a href=/cview/map.pl?map_version_id=$mapv_id>$map_name</a>|;

   	return $genetic_map;
    }
    else { 
	return; 
    }

}

	        

