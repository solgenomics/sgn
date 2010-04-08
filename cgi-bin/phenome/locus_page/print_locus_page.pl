
use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Allele;
use CXGN::Phenome::LocusGroup;
use CXGN::Phenome::LocusgroupMember;
use CXGN::Page::FormattingHelpers qw /info_table_html
  columnar_table_html
  html_alternate_show
  html_optional_show /;
use CXGN::People::Person;
use CXGN::Chado::Dbxref;
use CXGN::Phenome::LocusDbxref;
use CXGN::Phenome::Locus::LocusPage;

use JSON;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my $dbh = CXGN::DB::Connection->new();
$dbh->add_search_path('phenome');

my ( $login_person_id, $login_user_type ) =
  CXGN::Login->new($dbh)->has_session();

my ( $locus_id, $type ) = $doc->get_encoded_arguments( "locus_id", "type" );

my $locus = CXGN::Phenome::Locus->new( $dbh, $locus_id );

my %error = ();
my $json  = JSON->new();

if ( $type eq 'network' ) {
    eval {

        ##########

        my @locus_groups = $locus->get_locusgroups();

        my $direction;
        my $al_count = 0;
        my $associated_loci;
        my %rel = ();
      GROUP: foreach my $group (@locus_groups) {
            my $relationship = $group->get_relationship_name();
            my @members      = $group->get_locusgroup_members();
            my $members_info;
            my $index = 0;

#check if group has only 1 member. This means the locus itself is the only member (other members might have been obsolete)
            if ( $group->count_members() == 1 ) { next GROUP; }
          MEMBER: foreach my $member (@members) {
                if ( $member->obsolete() == 1 ) {
                    delete $members[$index];
                    $index++;
                    next MEMBER;
                }
                my (
                    $organism,      $associated_locus_name,
                    $gene_activity, $lgm_obsolete_link
                );
                my $member_locus_id = $member->get_column('locus_id');

                my $member_direction = $member->direction() || '';
                my $lgm_id = $member->locusgroup_member_id();
                if ( $member_locus_id == $locus_id ) {
                    $direction = $member_direction;
                }
                else {
                    $al_count++;
                    my $associated_locus =
                      CXGN::Phenome::Locus->new( $dbh, $member_locus_id );
                    $associated_locus_name =
                      $associated_locus->get_locus_name();
                    $gene_activity = $associated_locus->get_gene_activity();
                    $organism      = $associated_locus->get_common_name;

                    ##obsolete link
                    $lgm_obsolete_link =
                      qq | <span class="ghosted">[Remove]</span> |;
                    if ( privileged($login_user_type) ) {
                        $lgm_obsolete_link =
                            CXGN::Phenome::Locus::LocusPage::obsolete_locusgroup_member($lgm_id);
                    }
                    ###########

                    $members_info .=
qq|$organism <a href="/phenome/locus_display.pl?locus_id=$member_locus_id">$associated_locus_name</a> $gene_activity $lgm_obsolete_link <br /> |
                      if ( $associated_locus->get_obsolete() eq 'f' );

                    #directional relationships
                    if ( $member_direction eq 'subject' ) {
                        $relationship = $relationship . ' of';
                    }

                }    #non-self members
                $index++;
            }    #members
            $rel{$relationship} .= $members_info if ( scalar(@members) > 1 );
        }    #groups
        foreach my $r ( keys %rel ) {
            $associated_loci .= info_table_html(
                $r           => $rel{$r},
                __border     => 0,
                __tableattrs => 'width="100%"'
            );
        }

        ################
        $error{"response"} = $associated_loci;
    };

    if ($@) {
        $error{"error"} = $@;
        CXGN::Contact::send_email( 'print_locus_page.pl died',
            $error{"error"}, 'sgn-bugs@sgn.cornell.edu' );

    }
    else {

    }
}

###########
if ( $type eq 'ontology' ) {

    eval {
        my %dbs = $locus->get_dbxref_lists()
          ;    #hash of arrays. keys=dbname values= dbxref objects
        my (@alleles) = $locus->get_alleles();

#add the allele dbxrefs to the locus dbxrefs hash...
#This way the allele associated ontologies
#it might be a good idea to pring a link to the allele next to each allele-derived annotation

        foreach my $a (@alleles) {
            my %a_dbs = $a->get_dbxref_lists();

            foreach my $a_db_name ( keys %a_dbs )
            {    #add allele_dbxrefs to the locus_dbxrefs list
                my %seen = ()
                  ; #hash for assisting filtering of duplicated dbxrefs (from allele annotation)
                foreach ( @{ $dbs{$a_db_name} } ) {
                    $seen{ $_->[0]->get_accession() }++;
                }    #populate with the locus_dbxrefs
                foreach ( @{ $a_dbs{$a_db_name} } ) {    #and filter duplicates
                    push @{ $dbs{$a_db_name} }, $_
                      unless $seen{ $_->[0]->get_accession() }++;
                }
            }
        }

        #now add all GO PO SP annotations to an array
        my @ont_annot;
        foreach ( @{ $dbs{'GO'} } ) { push @ont_annot, $_; }
        foreach ( @{ $dbs{'PO'} } ) { push @ont_annot, $_; }
        foreach ( @{ $dbs{'SP'} } ) { push @ont_annot, $_; }

        my ( $ontology_links, $ontology_evidence, $ontology_info );

        my @obs_annot;
        my $ont_count = 0;

        my %ont_hash = ()
          ; #keys= cvterms, values= hash of arrays (keys= ontology details, values= list of evidences)
        foreach (@ont_annot) {

            my $cv_name      = $_->[0]->get_cv_name();
            my $cvterm_id    = $_->[0]->get_cvterm_id();
            my $cvterm_name  = $_->[0]->get_cvterm_name();
            my $db_name      = $_->[0]->get_db_name();
            my $accession    = $_->[0]->get_accession();
            my $db_accession = $accession;
            $db_accession = $cvterm_id if $db_name eq 'SP';
            my $url = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $cvterm_link =
qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id" target="blank">$cvterm_name</a>|;
            my $locus_dbxref = $locus->get_locus_dbxref( $_->[0] );

            my @AoH = $locus_dbxref->evidence_details();

            my $c;
            for my $href (@AoH) {
                my $relationship = $href->{relationship};

                if ( $href->{obsolete} eq 't' ) {
                    my $unobsolete;
                    $unobsolete =
                      CXGN::Phenome::Locus::LocusPage::unobsolete_evidence(
                        $href->{dbxref_ev_object}
                          ->get_object_dbxref_evidence_id )
                      if privileged( $login_user_type );

                    push @obs_annot,
                        $href->{relationship} . " "
                      . $cvterm_link . " ("
                      . $href->{ev_code} . ")"
                      . $unobsolete;
                }
                else {
                    $c++;
                    my $ontology_details = $href->{relationship}
                      . qq| $cvterm_link ($db_name:<a href="$url$db_accession" target="blank"> $accession</a>)<br />|;

                    # add an empty row if there is more than 1 evidence code
                    my $obsolete_link =
                      CXGN::Phenome::Locus::LocusPage::obsolete_evidence(
                        $href->{dbxref_ev_object}
                          ->get_object_dbxref_evidence_id )
                      if privileged( $login_user_type );

                    my $ev_string;
                    $ev_string .= "<br /><hr>"
                      if $ont_hash{$cv_name}{$ontology_details};
                    no warnings 'uninitialized';
                    $ev_string .=
                        $href->{ev_code}
                      . "<br />"
                      . $href->{ev_desc}
                      . "<br /><a href=\""
                      . $href->{ev_with_url} . "\">"
                      . $href->{ev_with_acc}
                      . "</a><br /><a href=\""
                      . $href->{reference_url} . "\">"
                      . $href->{reference_acc}
                      . "</a><br />"
                      . $href->{submitter}
                      . $obsolete_link;
                    $ont_hash{$cv_name}{$ontology_details} .= $ev_string;
                }
            }
        }

  #now we should have an %ont_hash with all the details we need for printing ...
  #hash keys are the cv names ..
        for my $cv_name ( sort keys %ont_hash ) {
            my @evidence;

#create a string of ontology details from the end level hash keys, which are the values of each cv_name
            my $cv_ont_details;

            #and for each ontology annotation create an array ref of evidences
            for my $ont_detail ( sort keys %{ $ont_hash{$cv_name} } ) {
                $ont_count++;
                $cv_ont_details .= $ont_detail;
                push @evidence,
                  [ $ont_detail, $ont_hash{$cv_name}{$ont_detail} ];
            }
            $ontology_links .= info_table_html(
                $cv_name => $cv_ont_details,
                __border => 0,
            );
            my $ev_table = columnar_table_html(
                data         => \@evidence,
                __align      => 'lll',
                __alt_freq   => 2,
                __alt_offset => 1
            );
            $ontology_evidence .= info_table_html(
                $cv_name     => $ev_table,
                __border     => 0,
                __tableattrs => 'width="100%"',
            );
        }

        #display ontology annotation form

        if ( @obs_annot &&  privileged($login_user_type) ) {
            $ontology_links .= print_obsoleted(@obs_annot);
        }

        if ($ontology_evidence) {
            $ontology_info .= html_alternate_show(
                'ontology_annotation', 'Annotation info',
                $ontology_links,       $ontology_evidence,
            );
        }
        else { $ontology_info .= $ontology_links; }

        $error{"response"} = $ontology_info;
    };

    if ($@) {
        $error{"error"} = $@;
        CXGN::Contact::send_email( 'print_locus_page.pl died',
            $error{"error"}, 'sgn-bugs@sgn.cornell.edu' );

    }

}

if ( $type eq 'unigenes' ) {

    eval {
        my @unigenes = $locus->get_unigenes();

        my $unigenes;
        my $common_name    = $locus->get_common_name();
        my %solcyc_species = (
            Tomato  => "LYCO",
            Potato  => "POTATO",
            Pepper  => "CAP",
            Petunia => "PET",
            Coffee  => "COFFEA"
        );
        if ( !@unigenes ) {
            $unigenes = qq|<span class=\"ghosted\">none</span>|;
        }
        my $unigene_count = 0;
        my @solcyc;
        my ( $solcyc_links, $sequence_links );
        my $solcyc_count = 0;
        foreach my $unigene (@unigenes) {
            my $unigene_id    = $unigene->get_unigene_id();
            my $unigene_build = $unigene->get_unigene_build();
            my $organism_name = $unigene_build->get_organism_group_name();
            my $build_nr      = $unigene->get_build_nr();
            my $nr_members    = $unigene->get_nr_members();
            my $unigene_obsolete_link =
              qq | <span class="ghosted">[Remove]</span> |;
            my $locus_unigene_id = $locus->get_locus_unigene_id($unigene_id);
            if ( privileged( $login_user_type )) {
                $unigene_obsolete_link =
                  CXGN::Phenome::Locus::LocusPage::obsolete_locus_unigene(
                    $locus_unigene_id);
            }
            my $status = $unigene->get_status();

            if ( $status eq 'C' ) {
                $unigene_count++;
                $unigenes .=
qq|<a href="/search/unigene.pl?unigene_id=$unigene_id">SGN-U$unigene_id</a> $organism_name -- build $build_nr -- $nr_members members $unigene_obsolete_link<br />|;
            }

#######
            # get solcyc links from the unigene page...
            #

            foreach my $dbxref ( $unigene->get_dbxrefs() ) {
                if ( $dbxref->get_db_name() eq "solcyc_images" ) {
                    my $url       = $dbxref->get_url();
                    my $accession = $dbxref->get_accession();
                    my ( $species, $reaction_id ) = split /\_\_/, $accession;
                    my $description = $dbxref->get_description();
                    unless ( grep { /^$accession$/ } @solcyc ) {
                        push @solcyc, $accession;
                        if ( $solcyc_species{$common_name} =~ /$species/i ) {
                            $solcyc_count++;
                            $solcyc_links .=
qq |  <a href="http://solcyc.solgenomics.net/$species/NEW-IMAGE?type=REACTION-IN-PATHWAY&object=$reaction_id" border="0" ><img src="http://$url$accession.gif" border="0" width="25%" / ></a> |;
                        }
                    }
                }
            }
        }
        $error{"response"} = $unigenes;
        $error{"solcyc"}   = $solcyc_links;

    };
    if ($@) {
        $error{"error"} = $@;
        CXGN::Contact::send_email( 'print_locus_page.pl died',
            $error{"error"}, 'sgn-bugs@sgn.cornell.edu' );

    }
}

##########
my $jobj = $json->encode( \%error );
print $jobj;

sub print_obsoleted {
    my @ontology_terms = @_;
    my $obsoleted;
    foreach my $term (@ontology_terms) {
        $obsoleted .= qq |$term  <br />\n |;
    }
    my $print_obsoleted = html_alternate_show(
        'obsoleted_terms', 'Show obsolete',
        '',                qq|<div class="minorbox">$obsoleted</div> |,
    );
    return $print_obsoleted;
}

sub privileged {
    my $t = shift
        or return;

    for (qw( curator submitter sequencer )) {
        return 1 if $t eq $_;
    }
    return 0;
}
