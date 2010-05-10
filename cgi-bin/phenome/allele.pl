######################################################################
#
#  Displays an editable allele detail page.
#
######################################################################

my $allele_detail_page = CXGN::Phenome::AlleleDetailPage->new();

package CXGN::Phenome::AlleleDetailPage;

use base qw/CXGN::Page::Form::SimpleFormPage/;

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw(info_section_html
				     page_title_html
				     columnar_table_html
				     info_table_html
				     html_optional_show
				    );

use CXGN::Phenome::Locus;
use CXGN::Phenome::Allele;
use CXGN::Phenome::AlleleSynonym;
use CXGN::Chado::Publication;
use CXGN::People::PageComment;
use CXGN::Feed;
use SGN::Image;


sub new {
    my $class  = shift;
    my $schema = 'phenome';
    my $self   = $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self = shift;
    $self->set_dbh( CXGN::DB::Connection->new('phenome') );
    my %args      = $self->get_args();
    my $allele_id = $args{allele_id};
    unless ( !$allele_id || $allele_id =~ m /^\d+$/ ) {
        $self->get_page->message_page(
            "No allele exists for identifier $allele_id");
    }
    $self->set_object_id($allele_id);
    $self->set_object(
        CXGN::Phenome::Allele->new( $self->get_dbh, $self->get_object_id ) );

    $self->set_primary_key("allele_id");
    $self->set_owners( $self->get_object()->get_owners() )
      ;    #instead of get_sp_person_id()
}

# override store to check if an allele with the submitted symbol already exists for this locus

sub store {
    my $self      = shift;
    my $allele    = $self->get_object();
    my $allele_id = $self->get_object_id();
    $allele->set_is_default('f');
    my %args     = $self->get_args();
    my $action   = $args{action};
    my $locus_id = $args{locus_id};

    my ($message) =
      $allele->exists_in_database( $args{allele_symbol}, $args{locus_id} );
    if ($message) {
        $self->get_page()->message_page($message);
        exit();
    }
    else {
        $self->send_allele_email();
        $self->SUPER::store(1);
    }

    $allele_id = $allele->get_allele_id();
    $self->get_page()
      ->client_redirect("/phenome/allele.pl?allele_id=$allele_id");

}

sub delete {
    my $self = shift;
    my %args = $self->get_args();
    $self->check_modify_privileges();

    my $locus;
    my $locus_name;

    my $allele_symbol = $self->get_object()->get_allele_symbol();
    my $locus_id      = $self->get_object()->get_locus_id();
    if ($locus_id) {
        $locus = CXGN::Phenome::Locus->new( $self->get_dbh(), $locus_id );
        $locus_name = $locus->get_locus_name();
        $locus->remove_allele( $args{allele_id} );
        $self->send_allele_email('delete');
    }

    $self->get_page()->header();

    if ($locus) {
        print
qq { Removed allele "$allele_symbol" association from locus "$locus_name". };
        print
qq { <a href="locus_display.pl?locus_id=$locus_id&amp;action=view">back to locus</a> };
    }

    $self->get_page()->footer();

}

=head2 delete_dialog

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:
# $self->delete_dialog("Delete", "Object", 
#  			     $self->get_primary_key(), 
#  			     $id,
#  			     "<a href=\"".$self->get_script_name()."?".$self->get_primary_key()."=".$id."&amp;action=view\">Go back to detail page without deleting</a>");


=cut

sub delete_dialog {

    my $self = shift;
    $self->check_modify_privileges();
    my %args        = $self->get_args();
    my $title       = shift;
    my $object_name = shift;
    my $field_name  = shift;
    my $object_id   = shift;

    my $back_link =
        "<a href=\""
      . $self->get_script_name() . "?"
      . $self->get_primary_key() . "="
      . $object_id
      . "&amp;action=view\">Go back to allele page without deleting</a>";

    $self->get_page()->header();

    page_title_html("$title");
    print qq { 	
	<form>
	Delete allele (id=$object_id)? 
	<input type="hidden" name="action" value="delete" />
	<input type="hidden" name="$field_name" value="$object_id" />

	<input type="submit" value="Delete" />
	</form>
	
	$back_link

    };

    $self->get_page()->footer();
}

sub display_page {
    my $self = shift;
    my %args = $self->get_args();

    my $allele        = $self->get_object();
    my $allele_id     = $self->get_object_id();
    my $allele_symbol = $allele->get_allele_symbol();
    my $locus_id      = $allele->get_locus_id();
    my $locus_name    = $allele->get_locus_name();

    my @individuals    = $allele->get_individuals();
    my $default_allele = $allele->get_is_default();

    ###import js libraries
    $self->get_page->jsan_use("CXGN.Phenome.Tools");
    $self->get_page->jsan_use("CXGN.Phenome.Locus");
    $self->get_page->jsan_use("MochiKit.DOM");
    $self->get_page->jsan_use("Prototype");
    $self->get_page->jsan_use("jQuery");
    $self->get_page->jsan_use("thickbox");
    ###

    my $page = "../phenome/allele.pl?allele_id=$allele_id";
    my $action = $args{action} || "";
    if ( $default_allele eq 't'
        || ( !$allele_id & ( $action eq 'view' || $action eq 'edit' ) ) )
    {
        $self->get_page->message_page("No allele exists for this identifier");
    }

    if ( $args{locus_id} ) {
        $locus_id = $args{locus_id};
        $locus_name =
          CXGN::Phenome::Locus->new( $self->get_dbh(), $locus_id )
          ->get_locus_name();
    }
    $self->get_page->header("SGN allele $allele_symbol of locus $locus_name");
    print page_title_html("Allele:\t'$allele_symbol'\n");

    my $edit_links = $self->get_edit_links();

    my $allele_html =
      $edit_links . "<br />" . $self->get_form()->as_table_string() . "<br />";

    my $allele_synonym_link =
      "allele_synonym.pl?allele_id=$allele_id&amp;action=new";
    my $allele_synonyms = "";
    foreach my $a_synonym ( $allele->get_allele_aliases() ) {
        $allele_synonyms .= $a_synonym->get_allele_alias() . "  ";
    }

    $allele_html .= qq|<br><b> Allele synonyms: </b>$allele_synonyms|;
    unless ( $self->get_action =~ /new/ ) {
        $allele_html .=
          qq|<a href="$allele_synonym_link"> [Add/remove] </a> <br><br>|;
    }

    ###history
    my $login_user      = $self->get_user();
    my $login_user_id   = $login_user->get_sp_person_id();
    my $login_user_type = $login_user->get_user_type();
    my $object_owner    = $allele->get_sp_person_id();
    my @locus_owners    = $allele->get_locus()->get_owners();
    if (   $login_user_type eq 'curator'
        || $login_user_id == $object_owner
        || ( grep { /^$login_user_id$/ } @locus_owners ) )
    {
        my $history_data = $self->print_allele_history() || "";
        $allele_html .= $history_data;
    }
    print info_section_html(
        title    => 'Allele details',
        contents => $allele_html,
    );
    my $individuals_html = "<TABLE>";
    my %imageHoA
      ; # hash of image arrays. Keys are individual_ids, values are arrays of image_ids
    my %individualHash;
    my %imageHash;
    my @no_image = ();

    foreach my $individual (@individuals) {
        my $individual_id   = $individual->get_individual_id();
        my $individual_name = $individual->get_name();
        $individualHash{$individual_id} = $individual_name;

        my @images = map SGN::Image->new( $self->get_dbh, $_ ), $individual->get_image_ids();
        foreach my $image (@images) {
            my $image_id    = $image->get_image_id();
            my $img_src_tag = $image->get_img_src_tag("thumbnail");
            $imageHash{$image_id} = $img_src_tag;
            push @{ $imageHoA{$individual_id} }, $image_id;
        }

        #if there are no associated images with this individual:
        if ( !@images ) { push @no_image, $individual_id; }
    }
    for my $individual_id (
        sort { @{ $imageHoA{$b} } <=> @{ $imageHoA{$a} } }
        keys %imageHoA
      )
    {

        #print "$individual_id: @{ $imageHoA{$individual_id} }<br>\n";
        my $individual_name = $individualHash{$individual_id};
        $individuals_html .=
qq|<TR valign="top"><TD><a href="individual.pl?individual_id=$individual_id">$individual_name </a></TD>|;

        foreach my $image_id ( @{ $imageHoA{$individual_id} } ) {
            my $image_src_tag = $imageHash{$image_id};
            $individuals_html .=
qq |<TD><a href="../image/index.pl?image_id=$image_id">$image_src_tag</a></TD>|;
        }
        $individuals_html .= "</TR>";
    }
    if ( !@individuals ) { $individuals_html = undef; }
    else                 { $individuals_html .= "</TABLE>"; }

    foreach my $individual_id (@no_image) {
        my $individual_name = $individualHash{$individual_id};
        $individuals_html .=
qq|<a href="individual.pl?individual_id=$individual_id">$individual_name </a>|;
    }

    my $ind_subtitle = "";
    if (
        $allele_symbol
        && (   $login_user_type eq 'curator'
            || $login_user_type eq 'submitter'
            || $login_user_type eq 'sequencer' )
      )
    {

#$ind_subtitle .= qq| <a href="javascript:Tools.toggleContent('associateIndividualAllele', 'allele_accessions')">[Associate accession]</a> |;

        $ind_subtitle .=
qq| <a href="javascript:Tools.toggleContent('associateIndividualForm', 'allele_accessions')">[Associate accession]</a> |;

        $individuals_html .= $self->associate_individual();
    }
    else {
        $ind_subtitle .=
          qq|<span class= "ghosted">[Associate accession]</span> |;
    }

    print info_section_html(
        title       => 'Associated accessions',
        subtitle    => $ind_subtitle,
        contents    => $individuals_html,
        id          => "allele_accessions",
        collapsible => 1,
        collapsed   => 1,
    );

    ######

    my ( $pubmed_links, $pub_count, $genbank, $gb_count ) =
      $self->get_dbxref_info();

    my $new_gb =
qq|<a href="/chado/add_feature.pl?type=allele&amp;type_id=$allele_id&amp;&amp;refering_page=$page&amp;action=new">[Associate new genbank sequence]</a>|
      if $allele_symbol;

    print info_section_html(
        title       => "Sequence annotations ($gb_count)",
        subtitle    => $new_gb,
        contents    => $genbank,
        collapsible => 1,
    );

    my $new_pub_link .=
qq|<a href="../chado/add_publication.pl?type=allele&amp;type_id=$allele_id&amp;&amp;refering_page=$page&amp;action=new">[associate new publication]</a>|
      if $allele_symbol;

    print info_section_html(
        title       => 'Literature annotation',
        subtitle    => $new_pub_link,
        contents    => $pubmed_links,
        collapsible => 1,
    );

####add page comments
    if ($allele_symbol) {
        my $page_comment_obj =
          CXGN::People::PageComment->new( $self->get_dbh(), "allele",
            $allele_id, $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args() );
        print $page_comment_obj->get_html();
    }

    $self->get_page()->footer();
}

sub generate_form {
    my $self = shift;
    $self->init_form();
    my $allele = $self->get_object();

    my %args           = $self->get_args();
    my $mode_names_ref = [ 'recessive', 'partially dominant', 'dominant' ];
    my $locus_name     = $allele->get_locus_name();
    my $locus_id       = $allele->get_locus_id();
    if ( $self->get_action =~ /new/ ) {
        $locus_id = $args{locus_id};
        my $locus_obj =
          CXGN::Phenome::Locus->new( $self->get_dbh(), $locus_id );
        $locus_name = $locus_obj->get_locus_name();
    }
    $locus_name =
      qq|<a href= "locus_display.pl?locus_id=$locus_id">$locus_name</a>|;

    $self->get_form()->add_label(
        display_name => "Locus name",
        field_name   => "locus_name",
        contents     => $locus_name,
    );

    $self->get_form()->add_field(
        display_name => "Allele symbol ",
        field_name   => "allele_symbol",
        object       => $allele,
        getter       => "get_allele_symbol",
        setter       => "set_allele_symbol",
        validate     => 'allele_symbol',
    );
    $self->get_form()->add_field(
        display_name => "Allele name ",
        field_name   => "allele_name",
        object       => $allele,
        getter       => "get_allele_name",
        setter       => "set_allele_name",
        validate     => 'string',
    );

    $self->get_form()->add_select(
        display_name       => "Mode of inheritance ",
        field_name         => "mode_of_inheritance",
        object             => $allele,
        contents           => $args{mode_of_inheritance},
        getter             => "get_mode_of_inheritance",
        setter             => "set_mode_of_inheritance",
        select_list_ref    => $mode_names_ref,
        select_id_list_ref => $mode_names_ref,
    );

    $self->get_form()->add_textarea(
        display_name => "Phenotype ",
        field_name   => "allele_phenotype",
        object       => $allele,
        getter       => "get_allele_phenotype",
        setter       => "set_allele_phenotype",
        columns      => 40,
        rows         => => 4,
    );

    $self->get_form()->add_textarea(
        display_name => "Sequence/mutation ",
        field_name   => "allele_sequence",
        object       => $allele,
        getter       => "get_sequence",
        setter       => "set_sequence",
        columns      => 40,
        rows         => => 4,
    );

    $self->get_form()->add_hidden(
        field_name => "allele_id",
        contents   => $args{allele_id},
        object     => $allele,
        getter     => "get_allele_id",
        setter     => "set_allele_id"
    );

    $self->get_form()->add_hidden(
        field_name => "action",
        contents   => "store",
    );

    $self->get_form()->add_hidden(
        field_name => "sp_person_id",
        contents   => $self->get_user()->get_sp_person_id(),
        object     => $allele,
        setter     => "set_sp_person_id",

    );

    $self->get_form()->add_hidden(
        field_name => "updated_by",
        contents   => $self->get_user()->get_sp_person_id(),
        object     => $allele,
        setter     => "set_updated_by",
    );

    $self->get_form()->add_hidden(
        field_name => "locus_id",
        contents   => $args{locus_id},
        object     => $allele,
        getter     => "get_locus_id",
        setter     => "set_locus_id"
    );

    if ( $self->get_action =~ /view|edit/ ) {

        $self->get_form->from_database();
    }
    elsif ( $self->get_action =~ /store/ ) {
        $self->get_form->from_request( $self->get_args() );
    }

}

#########################################################
#
sub get_dbxref_info {
    my $self   = shift;
    my $allele = $self->get_object();
    my %dbs    = $allele->get_dbxref_lists()
      ;    #hash of arrays. keys=dbname values= dbxref objects

    my ( $pubs, $genbank );

    my $abs_count = 0;
    foreach ( @{ $dbs{'PMID'} } ) {
        $abs_count++;
        my ( $detail, $abstract ) =
          CXGN::Chado::Publication::get_pub_info( $_->[0], 'PMID' )
          if $_->[1] eq '0';
        $pubs .= "<div>" . $detail . html_optional_show(
            "abstract$abs_count",
            'Show/hide abstract',
            $abstract,
            0,                        #< do not show by default
            'abstract_optional_show', #< don't use the default button-like style
        ) . "</div>";
    }
    foreach ( @{ $dbs{'SGN_ref'} } ) {
        $abs_count++;
        my ( $det, $abs ) =
          CXGN::Chado::Publication::get_pub_info( $_->[0], 'SGN_ref' )
          if $_->[1] eq '0';
        $pubs .= "<div>" . $det . html_optional_show(
            "abstract$abs_count",
            'Show/hide abstract',
            $abs,
            0,                        #< do not show by default
            'abstract_optional_show', #< don't use the default button-like style
        ) . "</div>";
    }

    my $gb_count = 0;
    foreach ( @{ $dbs{'DB:GenBank_GI'} } ) {
        if ( $_->[1] eq '0' ) {
            $gb_count++;
            my $url = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $gb_accession =
              $self->CXGN::Chado::Feature::get_feature_name_by_gi(
                $_->[0]->get_accession() );
            my $description = $_->[0]->get_description();
            $genbank .=
qq|<a href="$url$gb_accession" target="blank">$gb_accession</a> $description<br />|;
        }
    }

    return ( $pubs, $abs_count, $genbank, $gb_count );
}

###########

sub get_edit_links {
    my $self      = shift;
    my $form_name = shift;
    return
        $self->get_new_link_html($form_name) . " "
      . $self->get_edit_link_html($form_name) . " "
      . $self->get_delete_link_html($form_name);

}

sub get_new_link_html {
    my $self      = shift;
    my $form_name = shift;

    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id   = $self->get_object_id();
    my $locus_id    = $self->get_object->get_locus_id();

    my $new_link =
qq { <a href="$script_name?action=new&amp;locus_id=$locus_id&amp;form=$form_name">[New]</a> };
    if ( $self->get_action() eq "edit" ) {
        $new_link = qq { <span class="ghosted">[New]</span> };
    }
    if ( $self->get_action() eq "new" ) {
        $new_link = qq { <a onClick="history.go(-1)">[Cancel]</a> };
    }
    return $new_link;
}

sub print_allele_history {

    my $self   = shift;
    my $allele = $self->get_object();
    my @history;
    my $history_data;
    my $print_history;
    my @history_objs = $allele->show_history(); #array of allele_history objects

    foreach my $h (@history_objs) {

        my $created_date = $h->get_create_date();
        $created_date = substr $created_date, 0, 10;

        my $history_id    = $h->{allele_history_id};
        my $updated_by_id = $h->{updated_by};
        my $updated =
          CXGN::People::Person->new( $self->get_dbh(), $updated_by_id );
        my $u_first_name = $updated->get_first_name();
        my $u_last_name  = $updated->get_last_name();
        my $up_person_link =
qq |<a href="/solpeople/personal-info.pl?sp_person_id=$updated_by_id">$u_first_name $u_last_name</a> ($created_date)|;

        push @history,
          [
            map { $_ } (
                $h->get_allele_symbol,    $h->get_allele_name,
                $h->get_allele_phenotype, $h->get_sequence,
                $up_person_link,
            )
          ];
    }

    if (@history) {

        $history_data .= columnar_table_html(
            headings =>
              [ 'Symbol', 'Name', 'Phenotype', 'Sequence', 'Updated by', ],
            data         => \@history,
            __alt_freq   => 2,
            __alt_width  => 1,
            __alt_offset => 3,
        );
        $print_history = html_optional_show(
            'allele_history',
            'Show allele history',
            qq|<div class="minorbox">$history_data</div> |,
        );
    }

    return $print_history;
}    #print_allele_history

sub associate_individual {

    my $self         = shift;
    my $allele_id    = $self->get_object_id();
    my $sp_person_id = $self->get_user->get_sp_person_id();
    my $locus_id     = $self->get_object()->get_locus_id();

    my $associate_html = qq^

<div id="associateIndividualForm" style="display: none">
    Accession name:
    <input type="text"
           style="width: 50%"
           id="a_name"
           onkeyup="Locus.getAlleleIndividuals(this.value, '$allele_id');">
    <input type="button"
           id="associate_individual_button"
           value="associate accession"
	   disabled="true"
           onclick="Locus.associateAllele('$sp_person_id', '$allele_id');this.disabled=true;">
    <select id="individual_select"
            style="width: 100%"
	    onchange="Tools.enableButton('associate_individual_button');"
            size=10>
       </select>
</div>
^;

    return $associate_html;
}

sub send_allele_email {
    my $self        = shift;
    my $action      = shift;
    my $allele_id   = $self->get_object()->get_allele_id();
    my $allele_name = $self->get_object()->get_allele_name();
    my %args        = $self->get_args();
    my $locus_id    = $args{locus_id};

    my $subject = "[New allele details stored] allele $allele_id";
    my $username =
        $self->get_user()->get_first_name() . " "
      . $self->get_user()->get_last_name();
    my $sp_person_id = $self->get_user()->get_sp_person_id();

    my $locus_link =
qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
    my $user_link =
qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    my $usermail = $self->get_user()->get_private_email();
    my $fdbk_body;
    if ( $action eq 'delete' ) {
        $fdbk_body =
"$username ($user_link) has obsoletes allele $allele_id ($locus_link) \n$usermail";
    }
    elsif ($allele_id) {
        $fdbk_body =
"$username ($user_link) has submitted data for allele $allele_name ($locus_link) \n$usermail";
    }
    else {
        $fdbk_body =
"$username ($user_link) has submitted a new  allele $allele_name for locus $locus_link \n$usermail";
    }
    CXGN::Contact::send_email( $subject, $fdbk_body,
        'sgn-db-curation@sgn.cornell.edu' );
    CXGN::Feed::update_feed( $subject, $fdbk_body );
}
