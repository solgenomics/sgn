use strict;
use warnings;
use CGI qw /param/;
use CXGN::Chado::Cvterm;

#  Displays a static cvterm detail page.

use CatalystX::GlobalContext qw( $c );


my $q   = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $cvterm_id = $q->param("cvterm_id") + 0;
my $cvterm_accession = $q->param("cvterm_name");
my $cvterm;

if ( $cvterm_accession  ) {
    $cvterm = CXGN::Chado::Cvterm->new_with_accession( $dbh, $cvterm_accession);
    $cvterm_id = $cvterm->get_cvterm_id();
} elsif ( $cvterm_id  ) {
    $cvterm = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
}

unless ( $cvterm_id && $cvterm_id =~ m /^\d+$/ ) {
    $c->throw( is_client_error => 1, public_message => 'Invalid arguments' );
}



$c->forward_to_mason_view(
    '/chado/cvterm.mas',
    cvterm    => $cvterm,
    );
exit();

sub display_page {
    my $self = shift;
    my %args = $self->get_args();
    $self->get_page->jsan_use('CXGN.Onto.Browser');

    my $cvterm            = $self->get_object();
    my $cvterm_id         = $self->get_object_id();
    my $cvterm_name       = $cvterm->get_cvterm_name();
    my $cv_name           = $cvterm->get_cv_name();
    my $db_name           = $cvterm->get_db_name();
    my $definition        = $cvterm->get_definition();
    my $accession         = $cvterm->get_accession();
    my $is_obsolete       = $cvterm->get_obsolete();
    my @synonyms          = $cvterm->get_synonyms();
    my @def_dbxrefs       = $cvterm->get_def_dbxref();
    my @secondary_dbxrefs = $cvterm->get_secondary_dbxrefs();
    my $comment           = $cvterm->comment();

    my $page = "/chado/cvterm.pl?cvterm_id=$cvterm_id";
    my $action = $args{action} || "";
    if ( !$cvterm_id ) {
        $self->get_page->message_page("No term exists for this identifier");
    }

    $self->get_page->header("SGN cvterm $db_name:$accession ($cvterm_name) ");
    print page_title_html("$db_name:$accession '$cvterm_name'\n");

    my $cvterm_html =
      "<br />" . $self->get_form()->as_table_string() . "<br />";

    if ($is_obsolete) { $cvterm_html .= qq|<b>Obsolete:</b> TRUE <br> | }
    $cvterm_html .= qq|<br><b> Synonyms: </b><br> |;
    foreach my $synonym (@synonyms) {
        $cvterm_html .= $synonym . "<br />";
    }
    $cvterm_html .= qq|<br><b> Definition dbxrefs: </b><br> |;
    my @def_accessions;

    foreach my $d (@def_dbxrefs) {
        my $db  = $d->get_db_name();
        my $acc = $d->get_accession();
        push @def_accessions, "$db:$acc";
    }
    foreach my $d (@def_accessions) { $cvterm_html .= $d . "<br />" }

    $cvterm_html .= qq|<br><b>Secondary IDs: </b><br> |;

    my @sec_accessions;

    foreach my $d (@secondary_dbxrefs) { $cvterm_html .= $d . "<br />"; }

    print info_section_html(
        title    => 'Cvterm details',
        contents => $cvterm_html,
    );

    ####embedded ontology browser

    print $c->render_mason("/ontology/embedded_browser.mas", cvterm => $cvterm);

    my ( $pop_count, $pop_list ) = $self->qtl_populations();

    if ($pop_count) {
        print info_section_html(
            title       => "Phenotype data/QTLs ($pop_count)",
            contents    => $pop_list,
            collapsible => 1,
            collapsed   => 0,
        );
    }

    #loci
    my ( $loci_count, $loci_annot ) = loci_annot($cvterm);
    print info_section_html(
        title       => "Annotated loci ($loci_count)",
        contents    => $loci_annot,
        collapsible => 1,
        collapsed   => 1,
    );

    #accessions (stocks)
    my ( $stock_count, $stock_annot ) = stock_annot($cvterm);
    print info_section_html(
        title       => "Annotated accessions ($stock_count)",
        contents    => $stock_annot,
        collapsible => 1,
        collapsed   => 1,
    );

    ####add page comments
    if ($cvterm_name) {
        my $page_comment_obj = CXGN::People::PageComment->new(
            $self->get_dbh(),
            "cvterm",
            $cvterm_id,
            $self->get_page()->{request}->uri() . "?"
              . $self->get_page()->{request}->args()
        );
        print $page_comment_obj->get_html();
    }

    $self->get_page()->footer();
}

sub generate_form {
    my $self = shift;
    $self->init_form();
    my $cvterm = $self->get_object();

    my %args = $self->get_args();

    my $cvterm_name = $cvterm->get_cvterm_name();
    my $cv_name     = $cvterm->get_cv_name();
    my $db_name     = $cvterm->get_db_name();
    my $definition  = $cvterm->get_definition();
    my $accession   = $cvterm->get_full_accession();
    my $is_obsolete = $cvterm->get_obsolete();

    my $comment = $cvterm->comment();

    $self->get_form()->add_label(
        display_name => "Term id",
        field_name   => "term_id",
        contents     => "$accession",
    );
    $self->get_form()->add_label(
        display_name => "Term name",
        field_name   => "term_name",
        contents     => $cvterm_name,
    );
    $self->get_form()->add_label(
        display_name => "Definition",
        field_name   => "definition",
        contents     => $definition,
    );

    $self->get_form()->add_label(
        display_name => "Comment",
        field_name   => "comment",
        contents     => $comment,
    );

    if ( $self->get_action =~ /view/ ) {

        $self->get_form->from_database();
    }

}

#########################################################

sub loci_annot {
    my $cvterm = shift;
    my @loci   = $cvterm->get_recursive_loci();
    if (@loci) {
        my $num = scalar(@loci);
        my @locus_info;
        foreach my $l (@loci) {
            my $id = $l->get_locus_id();
            push @locus_info,
              [
                map { $_ } (
                    $l->get_common_name(),
                    qq|<a href="/phenome/locus_display.pl?locus_id=$id">|
                      . $l->get_locus_symbol() . "</a>",
                    $l->get_locus_name(),
                )
              ];
        }
        my $title = 'loci';
        $title = 'locus' if $num == 1;
        return (
            scalar(@loci),
            columnar_table_html(
                headings => [ 'Organism', 'Symbol', 'Name' ],
                data     => \@locus_info
            )
        );

    }
    else { return ( 0, undef ); }
}

sub stock_annot {
    my $cvterm = shift;
    my $ids    = $cvterm->get_recursive_stocks;
    if ($ids) {
        my $num = scalar(keys %$ids);
        my @stock_info;

        foreach my $id (sort { $ids->{$a}->{name} cmp $ids->{$b}->{name} } keys %$ids) {
            my $name = $ids->{$id}->{name};
            push @stock_info,
            [
             map { $_ } (
                 qq|<a href="/stock/$id/view">|
                 . $name . "</a>",
                 $ids->{$id}->{description},
             )
            ];
        }
        return (
            $num,
            columnar_table_html(
                headings => [ 'Accession name', 'Description' ],
                data     => \@stock_info
            )
            );
    }
    else { return ( 0, undef ); }
}

=head2 qtl_populations

 Usage: my ($pop_c, $pop_list) = $self->qtl_populations();
 Desc: creates links to the qtl pages of cvterms and user submitted traits 
    
 Ret: pop count and qtl links in list context or false
 Args: none
 Side Effects:
 Example:

=cut

sub qtl_populations {
    my $self        = shift;
    my $cvterm      = $self->get_object();
    my $cvterm_name = $cvterm->get_cvterm_name();
    my $cvterm_id   = $cvterm->get_cvterm_id();

    my @pops1 = $cvterm->get_all_populations_cvterm();
    my ( $pop_list, $is_qtl_pop );

    my $qtltool = CXGN::Phenome::Qtl::Tools->new();
    my @qtlpops = $qtltool->has_qtl_data();

    foreach my $pop (@pops1) {
        my $pop_id   = $pop->get_population_id();
        my $pop_name = $pop->get_name();

        foreach my $qtlpop (@qtlpops) {
            my $qtlpop_id = $qtlpop->get_population_id();
            if ( $pop_id && $qtlpop_id == $pop_id ) {
                $is_qtl_pop = 1;
            }
        }

        if ($is_qtl_pop) {

            $pop_list .=
qq | <a href="../phenome/population_indls.pl?population_id=$pop_id&amp;cvterm_id=$cvterm_id">$pop_name</a> <br />|;
        }
        else {
            $pop_list .=
qq | <a href="../phenome/population.pl?population_id=$pop_id">$pop_name</a> <br />|;
        }
    }

    my $user_trait =
      CXGN::Phenome::UserTrait->new_with_name( $self->get_dbh(), $cvterm_name );

    my @pops2;
    if ($user_trait) {
        my $trait_id = $user_trait->get_user_trait_id();
        @pops2 = $user_trait->get_all_populations_trait();

        foreach my $pop (@pops2) {
            my $pop_id   = $pop->get_population_id();
            my $pop_name = $pop->get_name();

            $pop_list .=
qq |<a href="../phenome/population_indls.pl?population_id=$pop_id&amp;cvterm_id=$trait_id">$pop_name</a> <br />|;
        }
    }

    my $pop_count = @pops1 + @pops2;
    if ( $pop_count > 0 ) {
        $pop_count .= " " . 'populations';

        return $pop_count, $pop_list;
    }
    else {
        return 0;
    }

}

