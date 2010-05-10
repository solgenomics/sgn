######################################################################
#
#  Displays a static user submitted trait detail page.
#
######################################################################

my $trait_detail_page=CXGN::Phenome::TraitDetailPage->new();

package CXGN::Phenome::TraitDetailPage;

use base qw/CXGN::Page::Form::SimpleFormPage/;

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
   				     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                    /;
   
use CXGN::Phenome::UserTrait;
use CXGN::People::PageComment;

   
sub new {
    my $class=shift;
    my $schema='phenome';
    my $self= $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self=shift;
    $self->set_dbh(CXGN::DB::Connection->new('phenome'));
    my %args= $self->get_args();

    my $user_trait_id="";
    if (exists($args{trait}) && defined($args{trait}))  { 
	my $ut = CXGN::Phenome::UserTrait::->new_with_name($self->get_dbh(), $args{trait});
	$user_trait_id = $ut->get_user_trait_id();
    }
    else {
	$user_trait_id= $args{trait_id};
    }
    unless (!$user_trait_id || $user_trait_id =~m /^\d+$/) { $self->get_page->message_page("No term exists for identifier $user_trait_id"); }  
    $self->set_object_id($user_trait_id);
    $self->set_object(CXGN::Phenome::UserTrait->new($self->get_dbh, $self->get_object_id));
    
    $self->set_primary_key("user_trait_id");
   
}



sub display_page {
    my $self=shift;
    my %args = $self->get_args();
   
    
    my $ut=$self->get_object();
    my $ut_id=$self->get_object_id();
    my $ut_name=$ut->get_name();
    
    my $definition = $ut->get_definition() ;     
    my $page="/phenome/trait.pl?trait_id=$ut_id";
    my $action= $args{action} || ""; 
    if (!$ut_id) {  $self->get_page->message_page("No term exists for this identifier")  } ;
    
    $self->get_page->header("SGN: $ut_name " );
    print page_title_html("$ut_name\n");
    
    my $trait_html= "<br />" .$self->get_form()->as_table_string()."<br />";
    
   
  
    print info_section_html(title    => 'Trait details',
 			    contents => $trait_html,
			    );
    
    my @pops = $ut->get_all_populations_trait();
    my $pop_list;
   
    foreach my $pop (@pops) {
	my $pop_id = $pop->get_population_id();
	my $pop_name = $pop->get_name();
	
	$pop_list .= qq |<a href="../phenome/population_indls.pl?population_id=$pop_id&amp;cvterm_id=$ut_id">$pop_name</a> <br />|;
    }   
   
    my $pop_count = scalar(@pops);
    if ($pop_count > 0) { 
	$pop_count .= " " . 'populations';
    }
            
   print info_section_html(title    => "Phenotype data/QTLs ($pop_count)",
 			    contents => $pop_list,
 			    collapsible=>1,
			    collapsed=>0,
			    );  
     

    ####add page comments
    if ($ut_name) {
	my $page_comment_obj = CXGN::People::PageComment->new($self->get_dbh(), "trait", $ut_id, $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args()); 
	print $page_comment_obj->get_html();
    }
    

    $self->get_page()->footer();    
}
        
  
sub generate_form {
    my $self=shift;
    $self->init_form();
    my $ut=$self->get_object();
    
    my %args=$self->get_args();
       
    my $ut_name=$ut->get_name();
   
    my $definition = $ut->get_definition() ; 
    
    $self->get_form()->add_label(
				 display_name =>"Term name",
				 field_name   =>"term_name",
				 contents     => $ut_name,
				 );
    $self->get_form()->add_label(
				 display_name =>"Definition",
				 field_name   =>"definition",
				 contents     => $definition,
				 );   
    

    if ($self->get_action=~ /view/) {

	$self->get_form->from_database();
    }
    
}

#########################################################

