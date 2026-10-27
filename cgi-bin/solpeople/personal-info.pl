# Evan, 1 / 15 / 07: combines contact-info.pl and research-info.pl

#if a user is logged in, look at the logged-in user's info;
#else, can call with an id parameter to get a read-only view of any user's info
#(if no login and no 'id=', no good)

#(we don't want to encourage users to go directly to this page to edit their own info;
# they should go through /solpeople/profile/<sp_person_id>, so they'll already be logged in when they get here)

use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';

use CXGN::Login;

    my SGN::I18N $ui_people_i18n = SGN::I18N::translate($c);
    my %ui_people_text = (
        profile_home => SGN::I18N::translate($ui_people_i18n, 'community.people.profile_home', '[Profile Home]', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        directory_update_home => SGN::I18N::translate($ui_people_i18n, 'community.people.directory_update_home', '[Directory Update Home]', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        cancel_edit => SGN::I18N::translate($ui_people_i18n, 'community.people.cancel_edit', '[Cancel Edit]', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        edit => SGN::I18N::translate($ui_people_i18n, 'community.people.edit', '[Edit]', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        interests_and_organisms_preview => SGN::I18N::translate($ui_people_i18n, 'community.people.interests_and_organisms_preview', 'Interests and Organisms Preview', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        your_research_interests_will_be_displayed_on_sgn_s_website_as_shown_in_the_box_below_the_box_will_not_be_displayed => SGN::I18N::translate($ui_people_i18n, 'community.people.your_research_interests_will_be_displayed_on_sgn_s_website_as_shown_in_the_box_below_the_box_will_not_be_displayed', 'Your research interests will be displayed on SGN\'s website as shown in the box below (the box will not be displayed).', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        you_have_entered_the_following_currently_unlisted_organisms_please_check_that_these_names_are_spelled_correctly => SGN::I18N::translate($ui_people_i18n, 'community.people.you_have_entered_the_following_currently_unlisted_organisms_please_check_that_these_names_are_spelled_correctly', 'You have entered the following currently unlisted organisms. Please check that these names are spelled correctly.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        once_committed_these_names_cannot_be_changed_by_this_interface => SGN::I18N::translate($ui_people_i18n, 'community.people.once_committed_these_names_cannot_be_changed_by_this_interface', 'Once committed, these names cannot be changed by this interface.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        if_you_accidentally_save_an_incorrect_organism_name_please_contact_us_via => SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_accidentally_save_an_incorrect_organism_name_please_contact_us_via', 'If you accidentally save an incorrect organism name, please contact us via', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        personal_info_for => SGN::I18N::translate($ui_people_i18n, 'community.people.personal_info_for', 'Personal info for ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    );

my $contact_info_page = SolPeoplePersonalInfoPage->new();

package SolPeoplePersonalInfoPage; ## no critic (Modules::RequireFilenameMatchesPackage) # This CGI script intentionally declares its historical page package.

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html/;
use CXGN::People;
use File::Spec;
use HTML::Entities;
use CXGN::Phenome::Locus;
use Digest::MD5 qw | md5_hex |;

use base qw | CXGN::Page::Form::SimpleFormPage |;

sub new {
	my $class = shift;
	my $person_id = shift;
	my $self = $class->SUPER::new(); #arguments are parsed from the Page here
	my (undef, undef, $this_script_filename) = File::Spec->splitpath($0); #$0 contains current filename with some path or other prepended
	$self->set_script_name($this_script_filename);
	return $self;
}

sub define_object {
	my $self = shift;
	# call set_object_id, set_object and set_primary_key here
	my %args = $self->get_args();
	$self->set_object_id($args{sp_person_id});
	$self->set_object(CXGN::People::Person->new($self->get_dbh(), $args{sp_person_id}));
	$self->set_primary_key("sp_person_id");		      
	$self->set_owners($self->get_object()->get_sp_person_id());
}

#specified in SimpleFormPage
sub check_modify_privileges { 
    my $self = shift;

    # implement quite strict access controls by default
    # 
    my $person_id = $self->get_login()->has_session();
    my $user =  CXGN::People::Person->new($self->get_dbh(), $person_id);
    my $user_id = $user->get_sp_person_id();
    if ($user->get_user_type() eq 'curator') {
        return 0;
    }
    
    # check the owner only if the action is not new
    #
    my @owners= $self->get_owners();
    
    
    if (!(grep {/^$user_id$/} @owners )) 
    {
	$self->get_page()->message_page(SGN::I18N::translate($ui_people_i18n, 'community.people.not_record_owner', 'You do not have rights to modify this database entry because you do not own it. [%{user}, %{owners}]', { user => $user_id, owners => "@owners" }));
    }
    else { 
	return 0;
    }


    # override to check privileges for edit, store, delete.
    # return 0 for allow, 1 for not allow.
    return 0;

}

#specified in SimpleFormPage
sub validate_parameters_before_store
{
	my $self = shift;
	my %args = $self->get_args();
	
	my ($keywords, $format, $research_interests, $organism_codes_str, $unlisted_organisms_str) = 
		@args{qw(keywords format research_interests organisms unlisted_organisms)};
	$format = "auto" unless $format eq "html";

	#after checking for legal values, do the actual storing of existing organism IDs here
	my @organism_codes = map {
	    my $organism_code = $_;
	    $organism_code =~ tr/[0-9]//cds;
	    $organism_code;
	} split(/\0/, $organism_codes_str);
	foreach my $c ( @organism_codes )
	{
		my $test = CXGN::People::Organism->new($self->get_dbh(), $c);
		if(!defined($test))
		{
			$self->get_page()->message_page(SGN::I18N::translate($ui_people_i18n, 'community.people.organism_code_missing', 'Organism code "%{code}" is not defined in the database.
', { code => $_ }));
		}
	}
	my %selected_organisms = map {$_ => 1} @organism_codes; #ids of only those organisms selected with the multiselect appear in the hash
	my $person = $self->get_object();
	foreach my $o ($person->get_organisms())
	{
		$o->set_selected(0);
		if($selected_organisms{$o->get_sp_organism_id()})
		{
			$o->set_selected(1);
		}
	}
	
	#deal with unlisted organisms
	my @unlisted_organisms;
	foreach (split(/;/, $unlisted_organisms_str))
	{
		if(m/^\s*((\S.*\S)|\S)\s*$/) #remove leading and trailing spaces
		{
			push @unlisted_organisms, $1;
		}
	}
	my $unlisted_organisms = join("\0", @unlisted_organisms);
	
	# Quick, dirty hack method of defenestrating disallowed HTML tags in 
	# research interest statements: replace allowed tags with a marker string,
	# then delete all tokens of the form "<[^>]+>", then replace the marker string
	# with the original tag. 
	#
	# Using the marker string allows us to "save" the information about the tag
	# that is allowed -- changing it to a token that won't match the "<[^>]+>"
	# pattern. Using a random marker string prevents a user learning (through a
	# website error or something that reveals a static marker string) the marker
	# and trying to insert illegal tags by typing the marker into their statement
	# manually. This is further guarded against by only recognizing marker strings
	# with allowed tags encoded. (Yes, I am paranoid)
	#
	# The main problem with this is if someone happens to use both a literal "<"
	# and a matching ">" in their research statement -- if that happens, the
	# text flanked by these will be deleted -- they'll need to use &lt; and &gt;
	# instead.
	my $tag_marker = $self->get_page()->tempname();
	my $formatted_interests = $research_interests;
	$formatted_interests =~ s/<(\/{0,1})([pbi]|br)>/$1-$2-$tag_marker/g;
	$formatted_interests =~ s/\<[^>]+\>//g;
	$formatted_interests =~ s/(\/{0,1})-([pbi]|br)-$tag_marker/<$1$2>/g;
	
	# This is stored separately in the database, without tags, for full-text searching.
	$research_interests =~ s/\<[^>]+\>//g;
	
	if ($format eq "auto")
	{
		$formatted_interests =~ s/\r{0,1}\n\r{0,1}\n/<\/p><p>/g;
		$formatted_interests = "<p>$formatted_interests</p>";
	}
	
	$args{keywords} = HTML::Entities::encode_entities($keywords);
	$args{format} = $format;
	$args{research_interests} = ($format eq "auto") ? HTML::Entities::encode_entities($research_interests) : $formatted_interests;
	$args{unlisted_organisms} = $unlisted_organisms;
	$self->set_args(%args); #necessary if you want to affect the arguments that will be stored
}

sub generate_form
{
	my $self = shift;
	
	my %args = $self->get_args();
	my $person = $self->get_object();
	
	$self->init_form();
	my $form = $self->get_form();
	if ($form->is_editable()) { 
		$form->set_submit_method('post'); #avoid long URLs caused by research interests
	}
	
	my ($displayed_first_name, $displayed_last_name) = ($person->get_first_name(), $person->get_last_name());
	#i added some html into empty name fields asking people to update their blank entries in the database.
	#if we encounter one of these, do not fill in the field for their name with the html! --john
	if($displayed_first_name=~/^</){$displayed_first_name='';}
	if($displayed_last_name=~/^</){$displayed_last_name='';}
	
	my @organisms = $person->get_organisms();
	my @organism_ids = map {$_->get_organism_id()} @organisms;
	my @organism_names = map {$_->get_organism_name()} @organisms;
	my @organism_selections = map {$_->is_selected() ? '1' : '0'} @organisms;
	
	#element IDs for the source elements for the preview panes
	$self->{html_source_element_id} = 'html_source';
	$self->{organisms_source_element_id} = 'organisms_source';
	
	my $default_field_length = 22;
	if($form->is_editable()) {
	    $form->add_label(display_name => "",
			     field_name => "lbl1",
			     contents => SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_would_like_to_enter_or_update_information_at_this_time_but_do_not_want_it_displayed_publically_check_this_option', 'If you would like to enter or update information at this time but do not want it displayed publicly, check this option.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	    
	    $form->add_checkbox(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.censor_contact_information_from_directory_search_and_public_display', 'Censor contact information from directory search and public display', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
				field_name => "censor",
				contents => "1",
				selected => $person->get_censored(), 
				object => $person, 
				getter => "get_censored", 
				setter => "set_censor");
	    
	    $form->add_label(display_name => "",
			     field_name => "lbl2",
			     contents => SGN::I18N::translate($ui_people_i18n, 'community.people.the_first_and_last_names_you_enter_here_will_be_displayed_in_the_sgn_directory_if_not_censored_using_the_box_above', 'The first and last names you enter here will be displayed in the SGN directory (if not censored using the box above).', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
			     . SGN::I18N::translate($ui_people_i18n, 'community.people.your_username_for_this_interface_is_not_displayed', ' Your username for this interface is not displayed.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_select(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.salutation', 'Salutation', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			  field_name => "salutation",
			  contents => $person->get_salutation(),
			  object => $person, 
			  getter => "get_salutation",
			  setter => "set_salutation",
			  select_list_ref => [SGN::I18N::translate($ui_people_i18n, 'community.people.no_salutation', 'None', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }), qw(Prof. Dr. Mr. Ms. Mrs.)],
			  select_id_list_ref => ['', qw(Prof. Dr. Mr. Ms. Mrs.)]);
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.first_name', 'First name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			 field_name => "first_name",
			 contents => $displayed_first_name,
			 length => $default_field_length,
			 object => $person,
			 getter => "get_first_name",
			 setter => "set_first_name",
			 validate => "string");
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.last_name', 'Last name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			 field_name => "last_name",
			 contents => $displayed_last_name,
			 length => $default_field_length,
			 object => $person,
			 getter => "get_last_name",
			 setter => "set_last_name",
			 validate => "string");
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.organization', 'Organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			 field_name => "organization",
			 contents => $person->get_organization(),
			 length => 50,
			 object => $person, 
			 getter => "get_organization",
			 setter => "set_organization");
	$form->add_textarea(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.address', 'Address', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			    field_name => "address",
			    contents => $person->get_address(),
			    rows => 4,
			    columns => 50,
			    object => $person, 
			    getter => "get_address",
			    setter => "set_address");
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.country', 'Country', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			 field_name => "country",
			 contents => $person->get_country(),
			 length => $default_field_length,
			 object => $person, 
			 getter => "get_country",
			 setter => "set_country");
	if($form->is_editable()) {
	    $form->add_label(display_name => "",
			     field_name => "lbl3",
			     contents => SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_wish_to_be_contacted_via_telephone_or_fax_by_interested_parties_who_found_your_directory_entry_on_sgn_please_enter', 'If you wish to be contacted via telephone or fax by interested parties who found your directory entry on SGN, please enter', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
			     . SGN::I18N::translate($ui_people_i18n, 'community.people.telephone_numbers_here_these_numbers_will_be_displayed_publically_to_all_sgn_users_who_view_your_entry', ' telephone numbers here. These numbers will be displayed publicly to all SGN users who view your entry.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.phone', 'Phone', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			 field_name => "phone",
			 contents => $person->get_phone_number(),
			 length => $default_field_length,
			 object => $person, 
			 getter => "get_phone_number",
			 setter => "set_phone_number");
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.fax', 'Fax', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
							field_name => "fax",
							contents => $person->get_fax(),
							length => $default_field_length,
							object => $person, 
							getter => "get_fax",
							setter => "set_fax");
	if($form->is_editable())
	{
		$form->add_label(display_name => "",
								field_name => "lbl4",
								contents => SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_would_like_to_be_contacted_via_email_by_interested_parties_who_found_your_directory_entry_on_sgn_please_enter', 'If you would like to be contacted via email by interested parties who found your directory entry on SGN, please enter', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
								. SGN::I18N::translate($ui_people_i18n, 'community.people.an_address_here_this_address_will_be_displayed_publically_to_all_sgn_users_who_view_your_entry', ' an address here. This address will be displayed publicly to all SGN users who view your entry.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.contact_e_mail', 'Contact E-mail', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
							field_name => "contact_email",
							contents => $person->get_contact_email(),
							length => $default_field_length,
							object => $person, 
							getter => "get_contact_email",
							setter => "set_contact_email");
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.website', 'Website', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
							field_name => "webpage",
							contents => $person->get_webpage(),
							length => $default_field_length,
							object => $person, 
							getter => "get_webpage",
							setter => "set_webpage");
	if($form->is_editable())
	{
		$form->add_label(display_name => "",
								field_name => "lbl5",
								contents => SGN::I18N::translate($ui_people_i18n, 'community.people.enter_research_keywords_for_searching_and_a_fuller_explanation_of_your_research_interests_for_searching_and_displaying_below', 'Enter research keywords (for searching) and a fuller explanation of your research interests (for searching and displaying) below.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.keywords', 'Keywords', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
							field_name => "keywords",
							contents => $person->get_research_keywords(),
							length => 60,
							object => $person,
							getter => 'get_research_keywords',
							setter => 'set_research_keywords');
	if($form->is_editable())
	{
		$form->add_label(display_name => "",
								field_name => "lbl6",
								contents => SGN::I18N::translate($ui_people_i18n, 'community.people.please_separate_terms_with_a_b_semicolon_b_do_not_use_quotation_marks_or_other_punctuation_example_fruit_development', 'Please separate terms with a <b>semicolon</b>. Do not use quotation marks or other punctuation. (Example: fruit development;', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
												. SGN::I18N::translate($ui_people_i18n, 'community.people.host_pathogen_interaction_drought_tolerance', ' host pathogen interaction; drought tolerance)', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_multiselect(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.research_organisms', 'Research Organisms', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
									field_name => "organisms",
									choices => \@organism_ids,
									labels => \@organism_names,
									contents => \@organism_selections,
									object => $person,
									getter => 'get_organism_id_string');
	if($form->is_editable())
	{
		$form->add_label(display_name => "",
								field_name => "lbl7",
								contents => SGN::I18N::translate($ui_people_i18n, 'community.people.you_may_select_multiple_organisms_by_clicking_on_more_than_one_while_holding_the_control_key_down_if_an_organism_is_not_listed', 'You may select multiple organisms by clicking on more than one while holding the control key down. If an organism is not listed', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
												. SGN::I18N::translate($ui_people_i18n, 'community.people.in_the_selection_box_please_specify_your_additional_organisms_by_their_official_latin_names_in_the_text_entry_box_below_in', ' in the selection box, please specify your additional organisms by their official Latin names in the text entry box below, in', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
												. SGN::I18N::translate($ui_people_i18n, 'community.people.a_b_semicolon_b_separated_list', ' a <b>semicolon</b>-separated list.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
		#the contents will be edited by the pre-storing validation function; notice this field never needs to be gotten, only sotten
		$form->add_field(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.unlisted_organisms', 'Unlisted Organisms', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
								field_name => "unlisted_organisms",
								id => $self->{organisms_source_element_id},
								contents => "",
								length => 60,
								object => $person,
								setter => 'add_organisms');
	}
	
	if($form->is_editable()) { 	
	    $form->add_radio_list(display_name => "",
				  field_name => "format",
				  id_prefix => "format_",
				  choices => ["auto", "html"],
				  labels => [SGN::I18N::translate($ui_people_i18n, 'community.people.auto_format_entry_is_plain_text', 'Auto-format (entry is plain text)', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }), SGN::I18N::translate($ui_people_i18n, 'community.people.use_html_markup_tags', 'Use HTML markup tags', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })],
				  contents => $person->get_user_format(),
				  object => $person,
				  getter => 'get_user_format',
				  setter => 'set_user_format');
	    
	    $form->add_label(display_name => "",
			     field_name => "lbl8",
			     contents => SGN::I18N::translate($ui_people_i18n, 'community.people.for_auto_formatted_plain_text_entries_separate_paragraphs_by_a_single_empty_line_for_html_entries_please_use_only_paragraph', 'For auto-formatted plain text entries, separate paragraphs by a single empty line. For HTML entries, please use only paragraph', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
			     . SGN::I18N::translate($ui_people_i18n, 'community.people.tags_lt_p_gt_bold_and_italic_tags_lt_b_gt_lt_i_gt_and_break_tags_lt_br_gt_all_other_tags_will_be_removed', ' tags (&lt;p&gt;), bold and italic tags (&lt;b&gt;, &lt;i&gt;), and break tags (&lt;br&gt;). All other tags will be removed.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	$form->add_textarea(display_name => SGN::I18N::translate($ui_people_i18n, 'community.people.interests', 'Interests', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
			    field_name => "research_interests",
			    id => $self->{html_source_element_id},
			    contents => $person->get_research_interests(),
			    rows => 20,
			    columns => 80,
			    object => $person,
			    getter => 'get_research_interests',
			    setter => 'set_research_interests');
	if($form->get_action() =~ /edit|store/)
	{
		$form->add_label(display_name => "",
								field_name => "lbl9",
								contents => SGN::I18N::translate($ui_people_i18n, 'community.people.the_preview_feature_below_requires_javascript_shows_your_current_interests_statement_if_you_ve_selected_html_format_also', 'The preview feature below (requires JavaScript) shows your current interests statement if you\'ve selected HTML format. Also,', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 })
												. SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_need_to_define_new_organisms_the_preview_will_show_how_the_website_is_parsing_the_text_you_ve_entered_above', ' if you need to define new organisms, the preview will show how the website is parsing the text you\'ve entered above.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	
	#for allowing the form to make changes
	if($form->is_editable())
	{
		$form->add_hidden(display_name => "ID", field_name => "sp_person_id", contents => $person->get_sp_person_id());
		$form->add_hidden(display_name => "Action", field_name => "action", contents => "store");
	}
	
	if($form->is_editable())
	{
		$form->set_reset_button_text(SGN::I18N::translate($ui_people_i18n, 'community.people.clear', 'Clear', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
		$form->set_submit_button_text(SGN::I18N::translate($ui_people_i18n, 'community.people.submit_changes', 'Submit Changes', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
	}
	if($self->get_action() =~ /view|edit/)
	{
		$form->from_database();
	}
	
	elsif($self->get_action() =~ /store/)
	{
		$form->from_request($self->get_args());
	}
}

#no arguments
#return an HTML string for a toolbar with other possible actions for the form
sub get_actions_toolbar
{
	my $self = shift;
	my $user_id= $self->get_user()->get_sp_person_id();
	my @owners= $self->get_owners();
 
	my $script_name = $self->get_script_name();
	my $user_is_owner = (grep {/^$user_id$/} @owners);
	my %args = $self->get_args();
	my $sp_person_id = $args{sp_person_id};
	
	my ($login_user_id, $user_type) = CXGN::Login->new($self->get_dbh())->has_session();
	my $home;
	if($user_is_owner || $user_type eq 'curator')
	{
		$home = qq(<a href="/solpeople/profile/$sp_person_id">$ui_people_text{profile_home}</a>&nbsp;&nbsp;);
	}
	else
	{
		$home = qq(<span class="ghosted">$ui_people_text{directory_update_home}</span>);
	}
	
	if($self->get_action() eq "edit")
	{
		if($user_is_owner || $user_type eq 'curator')
		{
			return $home . qq(<a href="$script_name?action=view&sp_person_id=$sp_person_id">$ui_people_text{cancel_edit}</a>);
		}
		else
		{
			return $home . qq(<span class="ghosted">$ui_people_text{cancel_edit}</span>);
		}
	}
	elsif($self->get_action() eq "view")
	{
		if($user_is_owner || $user_type eq 'curator')
		{
			return $home . qq(<a href="$script_name?action=edit&sp_person_id=$sp_person_id">$ui_people_text{edit}</a>);
		}
		else
		{
			return $home . qq(<span class="ghosted">$ui_people_text{edit}</span>);
		}
	}
	elsif($self->get_action() eq "store") {}
}

sub display_page
{
	my $self = shift;
	my $person = $self->get_object();
	my $page = $self->get_page();
	#SimpleFormPage takes care of some unknown action strings, but we don't handle the full set of actions it supports
	if($self->get_action() !~ /^view|edit|store$/)
	{
		$page->message_page(SGN::I18N::translate($ui_people_i18n, 'community.people.illegal_person_action', 'Illegal parameter: action \'%{action}\' is not supported by %{script}', { action => $self->get_action(), script => $self->get_script_name() }));
		exit();
	}
	
	$page->add_style(text => ".subtitle {font-weight: bold; text-align: center}");
	$page->add_style(text => ".invisible {display: none}");
	$page->jsan_use("CXGN.DynamicPreviewPane", "MochiKit.DOM", "MochiKit.Signal"); #include javascript modules
	$page->header(SGN::I18N::translate($ui_people_i18n, 'community.people.sol_people_contact_and_research_info', 'Sol People: contact and research info', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));

	print qq{<table><tr valign="middle"><td width="670" align="center" valign="middle" ><br />};

	print page_title_html("$ui_people_text{personal_info_for}" . $person->get_first_name() . " " . $person->get_last_name());

	print "</td><td>";

	
	print qq { <a href="https://gravatar.com/" class="footer" ><img src="http://gravatar.com/avatar/}. md5_hex(lc($person->get_contact_email())). qq {?d=mm" /></a>};
	print "</td></tr></table>";



	print $self->get_actions_toolbar() . "<hr />\n";
	print $self->get_form()->as_table_string();


	if($self->get_action() =~ /^edit$/) {
		#show the preview panes
		my $html_preview_pane_parent_id = 'html_preview_pane_parent';
		my $organisms_preview_pane_parent_id = 'organisms_preview_pane_parent';
		print <<EOHTML;
<hr width="90%" />
<div class="subtitle">$ui_people_text{interests_and_organisms_preview}</div>
<div id="all_html_preview_stuff">
$ui_people_text{your_research_interests_will_be_displayed_on_sgn_s_website_as_shown_in_the_box_below_the_box_will_not_be_displayed}
<div id="$html_preview_pane_parent_id"></div>
</div>
<br />$ui_people_text{you_have_entered_the_following_currently_unlisted_organisms_please_check_that_these_names_are_spelled_correctly}
$ui_people_text{once_committed_these_names_cannot_be_changed_by_this_interface}\x20
$ui_people_text{if_you_accidentally_save_an_incorrect_organism_name_please_contact_us_via} <a href="mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a>.
<div id="$organisms_preview_pane_parent_id"></div>
<script type="text/javascript">
DynamicPreviewPane.createPreviewPane('html', '$self->{html_source_element_id}', '$html_preview_pane_parent_id');
DynamicPreviewPane.createPreviewPane('list(;)', '$self->{organisms_source_element_id}', '$organisms_preview_pane_parent_id');

//show or hide the interests preview pane based on user format selection
function makeVisible() {MochiKit.DOM.removeElementClass(this, "invisible");}
function makeInvisible() {MochiKit.DOM.addElementClass(this, "invisible");}
var previewPaneSection = MochiKit.DOM.getElement("all_html_preview_stuff");
MochiKit.Signal.connect("format_auto", "onclick", previewPaneSection, makeInvisible);
MochiKit.Signal.connect("format_html", "onclick", previewPaneSection, makeVisible);
//initialize
if(MochiKit.DOM.getElement("format_auto").checked) MochiKit.DOM.addElementClass("all_html_preview_stuff", "invisible");
</script>
EOHTML
	}

	my ($locus_annotations, $more_annotations) ;
	my @annotated_loci = ();

	if ($self->get_action() !~ /^edit$/) { 
	    my $person_id=  $person->get_sp_person_id();
	    @annotated_loci = CXGN::Phenome::Locus::get_locus_ids_by_editor($self->get_dbh(), $person_id);
	    my $top= 50;
	    my $more = 0;
	    my $max = @annotated_loci;
	    if (@annotated_loci>24) { 
		$more = @annotated_loci-24;
		$max = 24;
	    }
	    
	    
	    for (my $i=0; $i<$top; $i++) {
		my $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $annotated_loci[$i]);
		my $symbol = $locus->get_locus_symbol();
		my $locus_id = $locus->get_locus_id();
		

		if ($locus_id && $symbol) { #deanx jan23 2008
		  if ($i<$max)  {
		     $locus_annotations .= qq | <a href="/locus/$locus_id/view">$symbol</a> | }  
		  else {
		    $more_annotations .= qq { <a href="/locus/$locus_id/view">$symbol</a> };
		  }
		}
	    }
	    
	    if ($more) { 
		$locus_annotations .= qq|<br><b>and <a href="/search/locus">$more more</a></b><br />|; 
		
		
	    }
	}

	if (@annotated_loci) { 
	    print "<hr />\n";
	    print "Locus editor assignments:&nbsp;\n";
	    print $locus_annotations;
	}
	 
	my $pop_list = $self->owner_populations();
	if ($pop_list) {
	    print "<hr />\n $pop_list";
	}

	$page->footer();
}

sub owner_populations {
    my $self = shift;
    my $sp_person_id = $self->get_object_id();
    my @pops = CXGN::Phenome::Population->my_populations($sp_person_id);
    my $pop_list = 'Populations:<br/>';
   
    if (@pops) {   
	foreach my $pops (@pops) {
	    my $pop_name = $pops->get_name();
	    my $pop_id = $pops->get_population_id();
	    #my $is_public = $pops->get_privacy_status();
	    #if ($is_public) {$is_public = 'is publicly available';}
	    #if (!$is_public) {$is_public = 'is not publicly available yet';}
	    $pop_list .= qq |<a href="/phenome/population.pl?population_id=$pop_id">$pop_name</a><br/>|;	   
	}
   	return $pop_list;
     
    } else { 
	return;
    }

}
