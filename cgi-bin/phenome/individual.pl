use strict;

my $individual_detail_page = CXGN::Phenome::IndividualDetailPage->new();

package CXGN::Phenome::IndividualDetailPage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw /info_section_html 
                                      page_title_html
                                      columnar_table_html 
                                      html_optional_show 
                                      info_table_html
                                      tooltipped_text
                                      html_alternate_show
                                      /;
use SGN::Image;
use CXGN::Phenome::Individual;
use CXGN::Phenome::Population;
use CXGN::Chado::Publication;
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Cview::Map_overviews;
use CXGN::Contact;
use CXGN::Feed;
use CXGN::Tools::Organism;
use JSAN::ServerSide;
use HTML::Entities;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("individual.pl");
    
    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    $self->set_dbh(CXGN::DB::Connection->new('phenome'));
    my %args = $self->get_args();
    my $individual_id= $args{individual_id};
    my $individual_name= $args{individual_name};
    if ($individual_name && !$individual_id ) {
	my $individual_by_name = (CXGN::Phenome::Individual->new_with_name($self->get_dbh(), $individual_name))[0];
	if ($individual_by_name) { $individual_id = $individual_by_name->get_individual_id(); }
    }
   
    unless ( ( $individual_id =~ m /^\d+$/  ) || ($args{action} eq 'new' && !$individual_id) ) 
    {
	$c->throw(is_error=>0,
		  message=>"No accession exists for identifier $individual_id",
	    );
    }
    my $individual=CXGN::Phenome::Individual->new($self->get_dbh(),$individual_id ) ;
    $self->set_object_id($individual_id);
    $self->set_object($individual);
    $self->set_primary_key("individual_id");	
    
    
    if ( $individual->get_obsolete() eq 't' && $self->get_user()->get_user_type() ne 'curator' ) 
    {
	$c->throw(is_error=>0, 
		  title => 'Obsolete accession',
		  message=>"Accession $individual_id is obsolete!",
		  developer_message => 'only curators can see obsolete accessions',
		  notify => 0,   #< does not send an error email
	    );
    }
    my $action= $args{action};
    if ( !$individual->get_individual_id() && $action ne 'new'  ) {
	$c->throw(is_error=>0, message=>'No accession exists for this identifier',);
    }
    
    $self->set_owners($self->get_object()->get_owners());
}


sub delete {
    my $self = shift;
    $self->check_modify_privileges();
    my $individual = $self->get_object();
    my %args = $self->get_args();

    eval { 
	$individual->delete();
    };
    if ($@) { 
	$self->get_page()->message_page("An error occurred during deletion of the accession.");
    }

    $self->get_page()->header();

    print qq { 
	The accession has been successfully deleted.  };
    $self->get_page()->footer();
    exit();
}


sub generate_form { 
    my $self = shift;

    $self->init_form();

    my %args = $self->get_args();
    
    my $individual = $self->get_object();
    my $type_id = $args{type_id};
    my $type=$args{type};
    
    #my $individual_id = $self->get_object_id();
    my $sp_person_id= $individual->get_sp_person_id();
    my $submitter = CXGN::People::Person->new($self->get_dbh(), $individual->get_sp_person_id());
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;
    my $pop_name = $individual->get_population_name();
    my $pop_id = $individual->get_population_id();
    my $pop_link = qq |<a href="/phenome/population.pl?population_id=$pop_id">$pop_name </a> |;
    my $population_names_ref = CXGN::Phenome::Population::get_all_populations($self->get_dbh());
   
    my @p_names= map {$_->[1]} (@$population_names_ref);
    my @p_ids=   map {$_->[0]} (@$population_names_ref);
    my ($organism_names_ref, $organism_ids_ref) = CXGN::Tools::Organism::get_all_organisms($self->get_dbh());
    
    my $form = undef;
    if ($self->get_action()=~/new|edit|store/ ) { 
	$form = CXGN::Page::Form::Editable->new();
    }
    else { 
	$form = CXGN::Page::Form::Static->new();
    }
       
    $form->add_field( 
		      display_name=>"Accession", 
		      field_name=>"name", 
		      length=>15, 
		      object=>$individual, 
		      getter=>"get_name", 
		      setter=>"set_name",
		      validate => 'string',
		      );
    $form->add_textarea(  
			  display_name=>"Description", 
			  field_name=>"description",
			  object=>$individual, 
			  getter=>"get_description", setter=>"set_description",
			  columns => 40,
			  rows =>4,
			  );
    
    
    
    if ($self->get_action=~ /new|store/) {
	$form->add_select(
			  display_name => "Population",
			  field_name  => "population_id",
			  contents =>$individual->get_population_id(),
			  length=> 20,
			  object => $individual,
			  getter => "get_population_id",
			  setter => "set_population_id",
			  select_list_ref => \@p_names,
			  select_id_list_ref=>\@p_ids,
			  );
	$form->add_select(
			  display_name => "Organism",
			  field_name  => "common_name_id",
			  contents =>$individual->get_common_name_id(),
			  length=> 20,
			  object => $individual,
			  getter => "get_common_name_id",
			  setter => "set_common_name_id",
			  select_list_ref => $organism_names_ref,
			  select_id_list_ref=> $organism_ids_ref,
			  );
    } else {
	$form->add_label( display_name=>"Population", 
			  field_name=>"population_name", 
			  contents=>$pop_link,
			  );
	$form->add_label( display_name=>"Organism", 
			  field_name=>"common_name", 
			  contents=>$individual->get_common_name(),
			  );
    }
    
    $form->add_hidden( field_name=>"individual_id", contents=>$args{individual_id});
    $form->add_hidden( field_name=>"action", contents=>"store"  );
    $form->add_hidden (
		       field_name => "sp_person_id",
		       contents   =>$self->get_user()->get_sp_person_id(), 
		       object     => $individual,
		       setter     =>"set_sp_person_id", 
		       );
    
    $form->add_hidden (
		       field_name => "updated_by",
		       contents   =>$self->get_user()->get_sp_person_id(), 
		       object     => $individual,
		       setter     =>"set_updated_by", 
		       );

    $form->add_hidden( field_name=>"type", contents=>$args{type} );
    $form->add_hidden( field_name=>"type_id", contents=>$args{type_id} );
    
    #$form->add_hidden( field_name=>"locus_id", contents=>$locus_id);
   
    $self->set_form($form);
    
    if ($self->get_action=~ /view|edit/) {
	$self->get_form->from_database();

	$form->add_hidden (
			   field_name => "population_id",
			   contents   =>$individual->get_population_id(), 
			   );
	
	$form->add_label( display_name=>"Uploaded by", 
			  field_name=>"submitter", 
			  contents=>$submitter_link,
			  );
	
    }elsif ($self->get_action=~ /store/) {
	$self->get_form->from_request($self->get_args());
	#if ($type && $type_id) {
	if ($type eq "locus") { $individual->associate_locus(); }
	elsif ($type eq "allele") { $individual->associate_allele($type_id, $self->get_user()->get_sp_person_id() ); }
	my $subject="[New accession details stored] individual $args{individual_id}";
	my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
	my $sp_person_id=$self->get_user()->get_sp_person_id();
	my $usermail=$self->get_user()->get_private_email();
	my $fdbk_body="$username has submitted data for individual $args{individual_id}\nsp_person_id = $sp_person_id, $usermail";
	CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
	#}
    }
}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();
    
    my $individual = $self->get_object();
    my $individual_id = $self->get_object_id();
    my $individual_name = $individual->get_name();

    #insert the necessary javascript for the ajax forms in this page
    #$self->add_javascript();
    $self->get_page->jsan_use("CXGN.Phenome.Individual");
    $self->get_page->jsan_use("CXGN.Phenome.Tools");

    $self->get_page->jsan_use("MochiKit.DOM");
    $self->get_page->jsan_use("Prototype");
    $self->get_page->jsan_use("jQuery");
    $self->get_page->jsan_use("thickbox");
    
     my $action = $args{action};
    if (!$individual_id && $action ne 'new' && $action ne 'store') { $self->get_page->message_page("No accession exists for this identifier"); }
    
    #used to show certain elements to only the proper users
    my $login_user= $self->get_user();
    my $login_user_id= $login_user->get_sp_person_id();
    my $login_user_type= $login_user->get_user_type(); 
     
    my $tag_link = qq { <a href="tag.pl?individual_id=$individual_id&amp;action=new">Add tag</a> };
   
    $self->get_page()->header("SGN accession name: $individual_name");
    
    print page_title_html("SGN accession: $individual_name \n");
    
    my $page="../phenome/individual.pl?individual_id=$individual_id";
    $args{calling_page} = $page;

    my $individual_html = $self->get_edit_links()."<br />";
    
    #print all editable form  fields
    $individual_html .= $self->get_form()->as_table_string(); 

     ##############history:
   
    my $object_owner = $individual->get_sp_person_id();
    if ($login_user_type eq 'curator' || $login_user_id == $object_owner) {
	
	my $history_data= $self->print_individual_history();
	
	$individual_html .= $history_data; 
    }
    ####### print associated loci
    $individual_html .=  qq { <br /><br /><b>Associated loci:</b>  };
    my @loci = $individual->get_loci();
    foreach my $locus (@loci) {
	unless ($locus->get_obsolete() eq 't') { 
	    my $locus_id = $locus->get_locus_id();
	    my $locus_name = $locus->get_locus_name();
	    $individual_html .=qq{&nbsp<a href ="locus_display.pl?locus_id=$locus_id">$locus_name </a>&nbsp}; 
	}
    }
    #######associate locus
    if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {
	if ($individual_name) {  $individual_html .= $self->associate_loci();  }
    } else { $individual_html .= qq |<span class = "ghosted"> [Associate locus]</span><br /> |; }
    

    ####### dbxref data: ontology annotations, publications...:
    my ($xref_source, $pubs, $pub_count, $genbank, $gb_count, $onto_ref) = $self->get_dbxref_info();
    
    $individual_html .= $xref_source; 
    
     print info_section_html(title   => 'Accession details',
			    contents => $individual_html,
			    );
    ##############images:
    
    my $image_html;
    #$image_html .=qq|<table><tr valign="top">|;
    my @images = $individual->get_image_ids();  #array of associated image objects
    my $image_count = 0;
    
    $image_html .=qq|<table><tr valign="top">|;
    
    foreach my $image_id (@images) {
	$image_count ++;
	if ($image_count == 8) { 
	    $image_html .= qq|</tr><tr valign="top">|;
	    $image_count=1;
	}
	my $image=SGN::Image->new($individual->get_dbh(), $image_id);
	my $small_image=$image->get_image_url("thumbnail");
	my $medium_image=$image->get_image_url("medium");
	my $image_page= "/image/index.pl?image_id=$image_id";
	$image_html .=qq|<td><a href="$medium_image" title="<a href=$image_page>Go to image page </a>" class="thickbox" rel="gallery-images"><img src="$small_image" alt="" /></a></td> |;
    }
    $image_html .= "</tr></table>";
    #link for adding new images
    if ($individual_name) 
    { $image_html .= 
	  qq|<br /><a href="../image/add_image.pl?type_id=$individual_id&amp;action=new&amp;type=individual&amp;refering_page=$page">[Add new image]</a>|; 
    } 

    
    print info_section_html(title   => 'Images',
			    contents => $image_html,
			    );
    

############################### PHENOTYPE DATA 

   
    my @phenotypes= $individual->get_phenotypes();
    my $population_obj = $individual->get_population();          
    my @phenotype;
    my ($data_view, $term_obj, $term_name, $term_id, $min, $max, $ave, $value);
    
    foreach my $p (@phenotypes) 
    {

	if (!$population_obj->get_web_uploaded()) 
	{
	    $term_obj  = CXGN::Chado::Cvterm->new( $self->get_dbh(), $p->get_observable_id());
	    $term_name = $term_obj->get_cvterm_name();
	    $term_id   = $term_obj->get_cvterm_id();
	    ($min, $max, $ave) = $population_obj->get_pop_data_summary($term_id);
	    $value = $p->get_value();
	    if (!defined($value)) {$value= 'N/A';}
	    elsif ($value == 0) {$value = '0.0';}


	} else 
	{
	    $term_obj  = CXGN::Phenome::UserTrait->new($self->get_dbh(), $p->get_observable_id());
	    $term_name = $term_obj->get_name();
	    $term_id   = $term_obj->get_user_trait_id();
	    ($min, $max, $ave) = $population_obj->get_pop_data_summary($term_id);
	    $value = $p->get_value();
	}    

	$term_obj  = CXGN::Chado::Cvterm::get_cvterm_by_name( $self->get_dbh(), $term_name);
	my $cvterm_id = $term_obj->get_cvterm_id();
	
	if ($cvterm_id)	
	{
	    $term_id = $term_obj->get_cvterm_id();
	    if ($term_obj->get_definition() ) 
	    {
		push  @phenotype,  [map {$_} 
				    ((tooltipped_text(qq|<a href="/chado/cvterm.pl?cvterm_id=$term_id">$term_name</a>|, 
						      $term_obj->get_definition() )), $value, $min, $max, $ave) ]; 	
	    }else 
	    {
		push  @phenotype,  [map {$_} qq|<a href="/chado/cvterm.pl?cvterm_id=$term_id">$term_name</a>|, 
				    $value, $min, $max, $ave ]; 
	    }
	}
	else 
	{
	    if ($term_obj->get_definition() ) 
	    {
		push  @phenotype,  [map {$_} 
				    ((tooltipped_text(qq|<a href="/phenome/trait.pl?trait_id=$term_id">$term_name</a>|, 
						      $term_obj->get_definition() )), $value, $min, $max, $ave) ]; 	
	    }else {
		push  @phenotype,  [map {$_} qq|<a href="/phenome/trait.pl?trait_id=$term_id">$term_name</a>|, 
				    $value, $min, $max, $ave ]; 
	    }
	}
    }
  
    if (@phenotype) {
	my $phenotype_data .= columnar_table_html(
	                                        headings  => 
	                                            [
						    'Trait',
						    'Value',
						    'Pop min',
						    'Pop max',
						    'Pop mean',								   
	                                            ],
	                                           data     =>\@phenotype, 
						  __alt_freq   =>2,
						  __alt_width  =>1,
						  __alt_offset =>3,
						  __align =>'l',
					          );
	    
	$data_view = html_optional_show("phenotype",
					'View/hide phenotype data summary',
					qq|$phenotype_data|,
					1, #<  show data by default
	    );  
    }
    
    print info_section_html(title   => 'Phenotype data',
			    contents => $data_view,
			    );
    
 ######## map:

    my $overview = CXGN::Cview::Map_overviews::Individual->new($individual_id);
    my $map_html;
    if ($overview) {
	$overview->render_map();
	#my ($url, $path) = $overview->get_file_png();
	
	$map_html .= $overview->get_image_html(); 
    }
    print info_section_html(title   => 'Mapping data',
			    contents => $map_html,
			    );
    
    ######## alleles:
    
    my @alleles = $individual->get_alleles(); #array of associated allele objects    
    my @allele_data;
    my $allele_data;
    foreach my $allele(@alleles) {
	my $allele_id= $allele->get_allele_id();
	my $locus_id = $allele->get_locus_id();
	my $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $locus_id);
	my $locus_name= $locus->get_locus_name();
	my $phenotype = $allele->get_allele_phenotype();
	
	push @allele_data, [map {$_} ( qq|<a href= "locus_display.pl?locus_id=$locus_id">$locus_name</a>|,
				       $allele->get_allele_symbol(), qq|<div align="left"><a href= "allele.pl?allele_id=$allele_id">$phenotype</a></div>|,)
			    ];
    }

    if (@allele_data) {
	$allele_data .=columnar_table_html(headings => ['Locus name', 'Allele symbol', 'Phenotype',],
					   data     =>\@allele_data,
					   );
    }
    print info_section_html(title =>'Known alleles',
			    contents => $allele_data,
			    );
    
####### Germplasms:
    
    my $germplasm_data="";
    my @germplasms= $individual->get_germplasms(); #array of associated germplasm objects

    print info_section_html(title =>'Available germplasms',
			    contents => $germplasm_data,
			    );
    
    ##########literature ########################################
    my ($pub_links, $pub_subtitle);
    if ($pubs) {
	$pub_links = info_table_html( "  "    =>$pubs, 
				      __border => 0,
				      );
    }
    
    if ($individual_name && ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer')) { 
	$pub_subtitle .= qq|<a href="/chado/add_publication.pl?type=individual&amp;type_id=$individual_id&amp;refering_page=$page&amp;action=new"> [Associate publication] </a>|; 
    }else { $pub_subtitle= qq|<span class=\"ghosted\">[Associate publication]</span>|;}
    
    
    print info_section_html(title   => "Literature annotation ($pub_count)",
			    subtitle=> $pub_subtitle,
			    contents =>$pub_links,
			    collapsible=>1,
			    collapsed=>1,
			    );

  
 ######################################## Ontology details ##############
    
    my ($ontology_links, $ontology_evidence, $ontology_info);
    my $onto_hash;
    #my ($po_str, $po_gro, $sp) ; 
    #my ( @po_str_evidence, @po_gro_evidence, @sp);
    
    my @obs_annot;
    my $ont_count=0 ;
    my %ont_hash=(); #keys= cvterms, values= hash of arrays (keys= ontology details, values= list of evidences)
    foreach (@$onto_ref ) {   # ([dbxref_object, ind_dbxref_obsolete])
	my $cv_name= $_->[0]->get_cv_name();
 	my $cvterm_id= $_->[0]->get_cvterm_id();
 	my $cvterm_name= $_->[0]->get_cvterm_name();
 	my $db_name= $_->[0]->get_db_name();
 	my $accession = $_->[0]->get_accession();
	my $db_accession = $accession;
	$db_accession= $cvterm_id if $db_name eq 'SP';
 	my $url=  $_->[0]->get_urlprefix() .  $_->[0]->get_url();
 	my $cvterm_link= qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id" target="blank">$cvterm_name</a>|;
	my $ind_dbxref= $individual->get_individual_dbxref($_->[0]);
	my @AoH= $ind_dbxref->evidence_details();
	
	for my $href (@AoH) {
	    my $relationship= $href->{relationship};
	    
	    if ($href->{obsolete} eq 't') { 
		push @obs_annot, $href->{relationship}." ".$cvterm_link." (".$href->{ev_code}.")"
		    . $self->unobsolete_ev($href->{dbxref_ev_object});
	    }else {
		my $ontology_details= $href->{relationship}.qq| $cvterm_link ($db_name:<a href="$url$db_accession" target="blank"> $accession</a>)<br />|;
		# add an empty row if there is more than 1 evidence code
		my $ev_string;
		$ev_string .= "<br /><hr>" if $ont_hash{$cv_name}{$ontology_details};
		$ev_string .= $href->{ev_code}."<br />". $href->{ev_desc}."<br /><a href=\"". $href->{ev_with_url}. "\">" . $href->{ev_with_acc} . "</a><br /><a href=\"" . $href->{reference_url} ."\">" . $href->{reference_acc} . "</a><br />".$href->{submitter}. $self->get_ev_obs_link($href->{dbxref_ev_object}) ;	
		$ont_hash{$cv_name}{$ontology_details} .= $ev_string ;
	    }
	}
    }

    #now we should have an %ont_hash with all the details we need for printing ...
    #hash keys are the cv names .. 
    for my $cv_name (sort keys %ont_hash) { 
	my @evidence;
	#create a string of ontology details from the end level hash keys, which are the values of each cv_name 
	my $cv_ont_details; 
	#and for each ontology annotation create an array ref of evidences 
	for my $ont_detail (sort keys  %{ $ont_hash{$cv_name} } ) {
	    $ont_count++;
	    $cv_ont_details .= $ont_detail ;
	    push @evidence, [$ont_detail, $ont_hash{$cv_name}{$ont_detail}];
	}
	$ontology_links .= info_table_html($cv_name=> $cv_ont_details,
					   __border=>0,
	    );
	my $ev_table= columnar_table_html(data=>\@evidence,__align=>'lll',__alt_freq=>2,__alt_offset => 1);
	$ontology_evidence .= info_table_html($cv_name=>$ev_table, __border=>0,__tableattrs=>'width="100%"',);
    }
    
    #display ontology annotation form
    my $ontology_add_link;
    my $ontology_subtitle;
    if (($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') ) {
	if ($individual_name) { 
	    if (@obs_annot) { $ontology_links .=print_obsoleted(@obs_annot) } ; 
	    $ontology_subtitle .= qq|<a href="javascript:Tools.toggleContent('associateOntForm', 'individual_ontology')">[Add ontology annotation]</a> |;
	    $ontology_add_link= $self->associate_ontology_term(); 
	}
    }else { $ontology_subtitle =qq |<span class = "ghosted"> [Add ontology annotations]</span> |; }
    
    $ontology_info .=$ontology_add_link;#the javascript form for adding new annotations
	if ($ontology_evidence) { 
	    
	    $ontology_info .=  html_alternate_show('ontology_annotation',
						  'Annotation info',
						  $ontology_links,
						  $ontology_evidence,
						  );
	}else { $ontology_info .= $ontology_links; }
    print info_section_html(title =>"Ontology annotations ($ont_count)",
			    subtitle=>$ontology_subtitle,
			    contents => $ontology_info,
			    id      =>"individual_ontology",
			    collapsible=>1,
	);
    
    ###########Page comments############
    if ($individual_name) { 
	# change sgn_people.forum_topic.page_type and the CHECK constraint!!
	my $page_comment_obj = CXGN::People::PageComment->new($self->get_dbh(), "individual", $individual_id,
	    $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args() );  
	print $page_comment_obj->get_html();
    }
    ######################################3
    
    $self->get_page()->footer();    
    exit();
}

sub print_individual_history {
    my $self=shift;
    my $individual=$self->get_object();
    
    my @history;
    my $history_data;
    my $print_history;
    my @history_objs = $individual->show_history(); #array of individual_history objects
    
    foreach my $h (@history_objs) {
	
	my $created_date= $h->get_create_date();
	$created_date = substr $created_date, 0, 10;
	
	my $history_id = $h->{individual_history_id};
	my $updated_by_id= $h->{updated_by};
	my $updated=CXGN::People::Person->new($self->get_dbh(), $updated_by_id);
	my $u_first_name = $updated->get_first_name();
	my $u_last_name = $updated->get_last_name();
	my $up_person_link =qq |<a href="/solpeople/personal-info.pl?sp_person_id=$updated_by_id">$u_first_name $u_last_name</a> ($created_date)|;
	
	push @history, [map {$_} ($h->get_name,$h->get_description,$h->get_population()->get_name(),
				  $up_person_link,)
			];
    }
    
    if (@history) {    
       	$history_data .= columnar_table_html(headings => ['Name',
							  'Description',
							  'Population',
							  'Updated by',
					     ],
					     data     =>\@history,
					     __alt_freq   =>2,
					     __alt_width  =>1,
					     __alt_offset =>3,
	    );
	$print_history= 
	    html_optional_show('accession_history',
			       'Show accession history',
			       qq|<div class="minorbox">$history_data</div> |,
	    );
    }
    
    return $print_history;
}#print_individual_history


# override store to check if a locus with the submitted symbol/name already exists in the database

sub store { 
   my $self = shift;
   my $individual = $self->get_object();
   my $individual_id = $self->get_object_id();
   my %args = $self->get_args();
   
  
   my $message = $individual->exists_in_database( $args{name} );
   
   if ($message ) {#&& $name_id!= $locus_id && $name_obsolete==0 ) { 
       $self->get_page()->message_page($message);
   } else { 
       $self->SUPER::store(0); 
   }
}


sub get_ev_obs_link {
    my $self =shift;
    my $ind=$self->get_object();
    my $ev_dbxref=shift;
    my $delete_link = "";
    my $user_type= $self->get_user->get_user_type();
    my $logged_user= $self->get_user()->get_sp_person_id();
    my $ev_dbxref_id= $ev_dbxref->get_object_dbxref_evidence_id();
    #check obsolete permissions. Granted for
    #curators, the individual owner(s) and the submitter of the annotation 
    #(in this case we go by the evidence code, since annotations can have multiple evidences) 
    if (($ind->get_sp_person_id == $logged_user) || ($ev_dbxref->get_sp_person_id() == $logged_user) || ($user_type eq 'curator' ) ) {
	$delete_link=qq| 
	    <a href="javascript:Tools.obsoleteAnnotEv('individual', '$ev_dbxref_id')">[delete]</a><br>
	    
	    <div id='obsoleteIndividualOntologyForm' style="display: none">
            <div id='ev_dbxref_id_hidden'>
	               <input type="hidden" 
		       value=$ev_dbxref_id
		       id="$ev_dbxref_id">
		       </div>
	    </div>
	    |;
    }
}

sub unobsolete_ev {
    my $self =shift;
    my $ind=$self->get_object();
    my $ev_dbxref= shift;
    my $ev_dbxref_id= $ev_dbxref->get_object_dbxref_evidence_id();
    my $unobsolete_link = "";
    
    if (($self->get_user()->get_user_type() eq 'submitter') || ($self->get_user()->get_user_type() eq 'curator') || ($self->get_user()->get_user_type() eq 'sequencer')) {
	$unobsolete_link=qq| 
	    <a href="javascript:Tools.unobsoleteAnnotEv('individual','$ev_dbxref_id')">[unobsolete]</a>
	    
	    <div id='unobsoleteAnnotationForm' style="display: none">
            <div id='ev_dbxref_id_hidden'>
	    <input type="hidden" 
	    value=$ev_dbxref_id
	    id="$ev_dbxref_id">
	    </div>
	    </div>
	    |;
    } 
    return $unobsolete_link;
}


########################

sub print_obsoleted {
    my @ontology_terms=@_;
    my $obsoleted;
    foreach my $term (@ontology_terms) {
	$obsoleted .=  qq |$term  <br />\n |;
    }
    my $print_obsoleted= 
	html_optional_show('obsoleted_terms',
			   'Show obsolete',
			   qq|<div class="minorbox">$obsoleted</div> |,
			   );
    return $print_obsoleted;

}


sub get_dbxref_info {
    my $self=shift;
    my $ind=$self->get_object();
    my $ind_name=$ind->get_name();
    my %dbs = $ind->get_dbxref_lists(); #hash of arrays. keys=dbname values= dbxref objects
    my ($xref_source, $pubs, $genbank, $onto_ref, $ont_ev,$obs_annot);
    ##tgrc
    foreach (@{$dbs{'TGRC_accession'}} ) {
	if ($_->[1] eq '0') {
	    my $url= $_->[0]->get_urlprefix() . $_->[0]->get_url();
	    my $accession= $_->[0]->get_accession();
	    $xref_source .= qq|$ind_name is a <a href="$url$accession" target="blank">TGRC accession</a><br />|; 
	}
    }
    foreach (@{$dbs{'EUSOL:accession'}} ) {
	if ($_->[1] eq '0') {
	    my $url= $_->[0]->get_urlprefix() . $_->[0]->get_url();
	    my $accession= $_->[0]->get_accession();
	    $xref_source .= qq|<br />Available at  <br /><a href="$url$accession" target="blank"><img src= "/documents/img/eusol_logo_small.jpg" border="0" /></a><br />|; 
	}
    }
    my $abs_count=0;
    foreach (@{$dbs{'PMID'}} ) { 
	$pubs .= $self->get_pub_info($_->[0],$abs_count++) if $_->[1] eq '0'; }
    foreach (@ {$dbs{'SGN_ref'}} ) { $pubs .= $self->get_pub_info($_->[0],$abs_count++) if $_->[1] eq '0'; }
    my @pop_dbxrefs=$ind->get_population()->get_all_population_dbxrefs();
    foreach (@pop_dbxrefs) {
	my $db_name = $_->get_db_name();
	if ($db_name eq 'PMID' || $db_name eq  'SGN_ref' ) {
	    $pubs .= $self->get_pub_info($_, $abs_count++);
	}
    }
    my $gb_count=0;
    foreach (@{$dbs{'DB:GenBank_GI'}} ) {
	if ($_->[1] eq '0') {
	    $gb_count++;
	    my $url= $_->[0]->get_urlprefix() . $_->[0]->get_url();
	    my $gb_accession=$self->CXGN::Chado::Feature::get_feature_name_by_gi($_->[0]->get_accession());
	    my $description=$_->[0]->get_description();
	    $genbank .=qq|<a href="$url$gb_accession" target="blank">$gb_accession</a> $description<br />|; 
	}
    }
    my @ont_annot;
    foreach ( @{$dbs{'GO'}}) { push @ont_annot, $_; }
    foreach ( @{$dbs{'PO'}}) { push @ont_annot, $_; }
    foreach ( @{$dbs{'SP'}}) { push @ont_annot, $_; }
    
    return ($xref_source, $pubs, $abs_count, $genbank, $gb_count, \@ont_annot);
}

sub abstract_view {
    my $self=shift;
    my $pub=shift;
    my $abs_count=shift;
    my $abstract=encode_entities($pub->get_abstract());
    my $authors=encode_entities($pub->get_authors_as_string() ) ;#self->author_info($pub->get_pub_id());
    my $journal=$pub->get_series_name() ; 
    my $pyear=$pub->get_pyear();
    my $volume=$pub->get_volume() ;
    my $issue=$pub->get_issue();
    my $pages=$pub->get_pages();
    my $abstract_view = html_optional_show("abstracts$abs_count",
					   'Show/hide abstract',
					   qq|$abstract <b> <i>$authors.</i> $journal. $pyear. $volume($issue). $pages. </b>|,
					   0, #< do not show by default
					   'abstract_optional_show', #< don't use the default button-like style
					   );
    return $abstract_view;
}#

sub get_pub_info {
    my $self=shift;
    my ($dbxref,  $count)=@_;
    my $db=$dbxref->get_db_name();
    my $pub_info;
    my $accession= $dbxref->get_accession();
    my $pub_title=$dbxref->get_publication()->get_title();
    my $pub_id= $dbxref->get_publication()->get_pub_id();
    my $abstract_view=$self->abstract_view($dbxref->get_publication(), $count);
    $pub_info = qq|<div><a href="/chado/publication.pl?pub_id=$pub_id" >$db:$accession</a> $pub_title $abstract_view </div> |;
    return $pub_info;
}#


#################################
sub associate_loci {
    my $self=shift;
    my $individual_id=$self->get_object_id();
    my $sp_person_id= $self->get_user->get_sp_person_id();
    my $user_type = $self->get_user->get_user_type();
   # my $locus_tip= tooltipped_text('Locus name or symbol', 'To filter your locus search by the organism of interest, enter a locus name or symbol followed by comma and the organism name (eg. flower, tomato).');
    my $associate_html = qq^
<br><a href=javascript:Individual.toggleAssociateFormDisplay()>[associate new locus]</a>
<div id="associationForm" style="display: none">
       
       <input type="text"
	       style="width: 50%"
	       id="locus_name"
	       onkeyup="Tools.getLoci(this.value, '$individual_id');">
       <select id = "organism_select" onchange="Tools.getLoci( MochiKit.DOM.getElement('locus_name').value, '$individual_id')"> 
   	          <option value="Tomato">tomato</option> 
	 	  <option value="Potato">potato</option> 
	          <option value="Pepper">pepper</option> 
	 	  <option value="Eggplant">eggplant</option> 
	 	  <option value="Coffee">coffee</option> 	 	        
	 </select> 
	       <select id="locus_select"
                style="width: 100%"
		size=10
        	onchange="Individual.getAlleles(this.value, '$individual_id');MochiKit.DOM.getElement('associate_locus_button').disabled=false;">
	</select>
	<span id ="alleleSelect" style="display: none">
            <b>Would you Like to specify an allele?</b>
	    <select id="allele_select"
		    style="width: 100%">
	    </select>
	</span>
	<input type="button"
               id="associate_locus_button"
	       value="associate locus"
	       disabled="true"
	       onclick="Individual.associateAllele('$sp_person_id', '$individual_id');this.disabled=true;">
    </div><br><br>^;

    return $associate_html;
}


sub associate_ontology_term{
    my $self=shift;
    my $individual_id=$self->get_object_id();
    my $sp_person_id= $self->get_user->get_sp_person_id();

    #	<a href=javascript:Tools.toggleAssociateOntology()>[Add ontology annotations]</a><br>
    my $associate = qq^
	<div id='associateOntForm' style="display: none">
            <div id='ontology_search'>
	   	    
	    Ontology term:
	        <input type="text" 
		       style="width: 50%"
		       id="ontology_input"
		       onkeyup="Tools.getOntologies(this.value)">
	        <select id = "cv_select" onchange="Tools.getOntologies(MochiKit.DOM.getElement('ontology_input').value, this.value)">
		       <option value="PO">PO (plant ontology)</option>
		       <option value="SP">SP (Solanaceae phenotypes)</option>
		</select><br>
	        
		<select id="ontology_select"
	                style="width: 100%"
			name="ontology_select"
			size=10 
		
			onchange="Tools.getRelationship()">
			
		</select>
		
		<b>Relationship type:</b>
		<select id="relationship_select" style="width: 100%"
		onchange="Tools.getEvidenceCode()">
		</select>
		<b>Evidence code:</b>
		<select id="evidence_code_select" style="width: 100%"
		onchange="Tools.getEvidenceDescription();Individual.getEvidenceWith('$individual_id');Individual.getReference('$individual_id')">
		</select>
		
		<b>Evidence description:</b>
		<select id="evidence_description_select" style="width: 100%">
		</select>

		<b>Evidence with:</b>
		<select id="evidence_with_select" style="width: 100%">
		</select>
		
		<b>Reference:</b>
		<select id="reference_select" style="width: 100%">
		</select>
		
		<input type="button"
		       id="associate_ontology_button"
		       value="associate ontology"
		       disabled="true"
		       onclick="Individual.associateOntology('$individual_id', '$sp_person_id');this.disabled=true;">
	      </div>
  	</div>
^;
    return $associate;
}

