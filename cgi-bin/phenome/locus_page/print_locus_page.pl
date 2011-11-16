use CatalystX::GlobalContext qw( $c );

use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
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

use JSON;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my $dbh = $c->dbc->dbh ;

my ( $login_person_id, $login_user_type ) =
  CXGN::Login->new($dbh)->has_session();

my ( $locus_id, $type ) = $doc->get_encoded_arguments( "locus_id", "type" );

my $locus = CXGN::Phenome::Locus->new( $dbh, $locus_id );

my %error = ();
my $json  = JSON->new();

my $priv =  privileged($login_user_type);

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
                $gene_activity
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
                my $lgm_obsolete_link =  $priv ?
                    $c->render_mason("/locus/obsolete_locusgroup_member.mas", lgm_id=>$lgm_id) : qq | <span class="ghosted">[Remove]</span> |;
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
}


if ( $type eq 'unigenes' ) {

    eval {
        my @unigenes = $locus->get_unigenes({current=>1});
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
        my @solcyc;
        my ( $solcyc_links, $sequence_links );
        my $solcyc_count = 0;
        foreach my $unigene (@unigenes) {
            my $unigene_id    = $unigene->get_unigene_id();
            my $unigene_build = $unigene->get_unigene_build();
            my $organism_name = $unigene_build->get_organism_group_name();
            my $build_nr      = $unigene->get_build_nr();
            my $nr_members    = $unigene->get_nr_members();
            my $locus_unigene_id = $locus->get_locus_unigene_id($unigene_id);

	    my $unigene_obsolete_link = privileged( $login_user_type ) ?
		$c->render_mason("/locus/obsolete_locus_unigene.mas", id=>$locus_unigene_id )
		: qq | <span class="ghosted">[Remove]</span> |;
            my $blast_link = "<a href='/tools/blast/?preload_id=" . $unigene_id . "&preload_type=15'>[Blast]</a>";
            $unigenes .=
                qq|<a href="/search/unigene.pl?unigene_id=$unigene_id">SGN-U$unigene_id</a> $organism_name -- build $build_nr -- $nr_members members $unigene_obsolete_link $blast_link<br />|;

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

sub privileged {
    my $t = shift
        or return;

    for (qw( curator submitter sequencer )) {
        return 1 if $t eq $_;
    }
    return 0;
}
