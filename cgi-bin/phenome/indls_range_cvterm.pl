#!/usr/bin/perl -wT

=head1 DESCRIPTION

generates a page with the list of individual
plant accessions (and their corresponding trait values)
falling within a phenotypic range in a population.
 
=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut



use strict;

my $individuals_range_detail_page = CXGN::Phenome::IndividualsRangeDetailPage->new();

package CXGN::Phenome::IndividualsRangeDetailPage;


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
use CXGN::Tools::WebImageCache;
use CXGN::VHost;
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;
use GD;
#use GD::Image;
use GD::Graph::bars;
use GD::Graph::Map;
use Statistics::Descriptive;
use CXGN::Scrap::AjaxPage;
use CXGN::Contact;



use base qw / CXGN::Page::Form::SimpleFormPage CXGN::Phenome::Main/;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("indls_range_cvterm.pl");
    

    return $self; 
}

sub define_object { 
    my $self = shift;
     
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
    my $pop_name = $population->get_name();
    my $pop_link = qq |<a href="/phenome/population.pl?population_id=$population_id">$pop_name</a> |;
    
    my $sp_person_id= $population->get_sp_person_id();
    my $submitter = CXGN::People::Person->new($self->get_dbh(), $population->get_sp_person_id());
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;
   
   
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
       
   $form->add_label ( 
		      display_name=>"Name:",
		      field_name=>"name",
		      contents=> $pop_link, 
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
    my $login_user= $self->get_user();
    my $login_user_id= $login_user->get_sp_person_id();
    my $login_user_type= $login_user->get_user_type(); 
    
    
    $self->get_page()->header("SGN Population name: $population_name");
    
    print page_title_html("SGN population: $population_name \n");
 
    my $population_html .= $self->get_form()->as_table_string(); 
   
    my $phenotype = ""; 
    my @phenotype;
    
    my @cvterm_names;
   
    my $cvterm_id = $args{cvterm_id};
    my $lower = $args{lower};
    my $upper = $args{upper};
	
    my ($indl_id, $indl_name, $value)= $population->indls_range_cvterm($cvterm_id, $lower, $upper);
    my @indls_id = @$indl_id;
    my $indls_count = scalar @indls_id;
    
    
    my $cvterm = CXGN::Chado::Cvterm->new($self->get_dbh(), $args{cvterm_id});
    my $cvterm_name = $cvterm->get_cvterm_name();
    my $cvterm_id = $args{cvterm_id};		
    my ($min, $max, $avg, $count)= $population->get_pop_data_summary($cvterm_id);
	
	    for (my $i=0; $i<@$indl_name; $i++) {
		
	push  @phenotype,  [map {$_} ( qq | <a href="/phenome/individual.pl?individual_id=$indl_id->[$i]">$indl_name->[$i]</a>|, $value->[$i]) ];
    } 

   
    my ($phenotype_data, $data_view, $data_download);
    
    my $cvterm_note = " <br><b>$indls_count plant accessions had 
                            $cvterm_name values >$lower but <= $upper. 
                            The population average, minimum, and maximum 
                            values for the trait were $avg, $min, and $max, 
                            respectively.</b> <br />";   
    
    if (@phenotype) {
	$phenotype_data = columnar_table_html(headings => [
							   'Plant accession',
							   'Value',
                                                         
							   ],
					      data     =>\@phenotype,
					      __alt_freq   =>2,
					      __alt_width  =>1,
					      __alt_offset =>3,
					      __align =>'l',
					      );
        
	$data_view = html_optional_show("phenotype",
					'View/hide phenotype data summary',
					qq|<b>$phenotype_data</b>|,
					1, #<  show data by default
					);
	$data_download .=  qq { <span><a href="pop_download.pl?population_id=$population_id"><b>\[download population raw data\]</b></a></span> }; 
    }
    
    my $page="../phenome/indls_range_cvterm.pl?cvterm_id=$cvterm_id&amp;lower=$lower&amp;upper=$upper&amp;population_id=$population_id ";
    $args{calling_page} = $page;

   
    my $pubmed;
    my $url_pubmed = qq | http://www.ncbi.nlm.nih.gov/pubmed/|;

    my @publications = $population->get_population_publications();
    my $abstract_view;
    my $abstract_count = 0;
    
    

    foreach my $pub (@publications) {
	my ($title, $abstract, $authors, $journal, $pyear, $volume, $issue, $pages, $obsolete, $pub_id, $accession);
	$abstract_count++;
	
	my @dbxref_objs = $pub->get_dbxrefs();
	my $dbxref_obj = shift(@dbxref_objs);
	
	$obsolete = $population->get_population_dbxref($dbxref_obj)->get_obsolete();
	
	if ($obsolete eq 'f') {
	$pub_id = $pub->get_pub_id();
	$accession = $pub->get_accession();
	$title = $pub->get_title();
	$abstract = $pub->get_abstract();
	$pyear = $pub->get_pyear();
	$volume = $pub->get_volume();
	$journal = $pub->get_series_name();
	$pages = $pub->get_pages();
	$issue = $pub->get_issue();
	$accession = $dbxref_obj->get_accession();
	my $pub_info = qq|<a href="/chado/publication.pl?pub_id=$pub_id" >PMID:$accession</a> |;
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
   
	
     $pubmed .= qq|<div><a href="$url_pubmed$accession" target="blank">$pub_info</a> $title $abstract_view </div> |;
    }
}

    print info_section_html(title   => 'Population details',
			    contents => $population_html,
			    );   
    
    print info_section_html(title   => 'Phenotype Data',
			    contents =>$cvterm_note . $data_view ." ".$data_download, 
			    );
    

    
    print info_section_html(title   => 'Literature annotation',
			    #subtitle => $pub_subtitle,
			    contents =>$pubmed , 
			    );
    
    
    if ($population_name) { 
	my $page_comment_obj = CXGN::People::PageComment->new($self->get_dbh(), "population", $population_id, $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args());  
	print $page_comment_obj->get_html();
    }
   
  

    $self->get_page()->footer();
    
    
    exit();
}






