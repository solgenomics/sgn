=head1 NAME

SGN::Controller::AJAX::Locus - a REST controller class to provide the
backend for objects linked with loci

=head1 DESCRIPTION

Browse the locus database for selecting loci to be linked with other objects

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::Locus;

use Moose;

use CXGN::Phenome::LocusDbxref;
use CXGN::Phenome::Locus::LocusDbxrefEvidence;
use CXGN::Phenome::LocusgroupMember;
use CXGN::Chado::Publication;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use List::MoreUtils qw /any /;
use Scalar::Util qw(looks_like_number);

use Try::Tiny;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


=head2 autocomplete

Public Path: /ajax/locus/autocomplete

Autocomplete a locus name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    my $common_name_id = $c->req->param('common_name_id');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @results;
    my $q =  "SELECT  locus_symbol, locus_name, allele_symbol, is_default FROM locus join allele using (locus_id) where (locus_name ilike '%$term%' OR  locus_symbol ilike '%$term%') and locus.obsolete = 'f' and allele.obsolete='f' limit 20"; #and common_name_id = ?
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute;
    while (my ($locus_symbol, $locus_name, $allele_symbol, $is_default) = $sth->fetchrow_array ) {
        my $allele_data = "Allele: $allele_symbol"  if !$is_default  ;
        no warnings 'uninitialized';
        push @results , "$locus_name ($locus_symbol) $allele_data";
    }
    $c->{stash}->{rest} = \@results;
}

=head2 genome_autocomplete

Public Path: /ajax/locus/genome_autocomplete

Autocomplete a genome locus name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.
Genome locus names are stored in the Chado feature table

=cut

sub genome_autocomplete : Local : ActionClass('REST') { }

sub genome_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @results;
    my @feature_names = $schema->resultset("Sequence::Feature")->search(
        { 'me.name'        => { 'like' => 'Solyc%' },
          'me.uniquename'  => { 'ilike' => '%' . $term  . '%' } ,
          'type.name'      => 'gene' },
        { prefetch    => 'type',
          select      => 'me.name' ,
          rows        => 20 ,}
        )->get_column('me.name')->all;
    map ( s/\.\d+$// ,  @feature_names) ;
    $c->{stash}->{rest} = \@feature_names;
}



sub display_ontologies : Chained('/locus/get_locus') :PathPart('ontologies') : ActionClass('REST') { }

sub display_ontologies_GET  {
    my ($self, $c) = @_;
    $c->forward('/locus/get_locus_dbxrefs');
    my $locus = $c->stash->{locus};
    my $locus_id = $locus->get_locus_id;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    ##############
    #hash of arrays. keys=dbname values= dbxref objects
    my %dbs = $locus->get_dbxref_lists();
    my (@alleles) = $locus->get_alleles();

    #add the allele dbxrefs to the locus dbxrefs hash...
    #This way the allele associated ontologies
    #it might be a good idea to print a link to the allele next to each allele-derived annotation
    foreach my $a (@alleles) {
            my %a_dbs = $a->get_dbxref_lists();
            foreach my $a_db_name ( keys %a_dbs )
            {    #add allele_dbxrefs to the locus_dbxrefs list
                my %seen = () ; #hash for assisting filtering of duplicated dbxrefs (from allele annotation)
                foreach ( @{ $dbs{$a_db_name} } ) {
                    $seen{ $_->[0]->get_accession() }++;
                }    #populate with the locus_dbxrefs
                foreach ( @{ $a_dbs{$a_db_name} } ) {    #and filter duplicates
                    push @{ $dbs{$a_db_name} }, $_
                        unless $seen{ $_->[0]->get_accession() }++;
                }
            }
    }
    my $hashref;
    # need to check if the user is logged in, and has editing privileges
    my $privileged;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    #now add all GO PO SP annotations to an array
    my @ont_annot;
    foreach ( @{ $dbs{'GO'} } ) { push @ont_annot, $_; }
    foreach ( @{ $dbs{'PO'} } ) { push @ont_annot, $_; }
    foreach ( @{ $dbs{'SP'} } ) { push @ont_annot, $_; }
    my @obs_annot;
    my %ont_hash = () ; #keys= cvterms, values= hash of arrays (keys= ontology details, values= list of evidences)
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
        for my $href (@AoH) {
            my $relationship = $href->{relationship};
            my $evidence_id = $href->{dbxref_ev_object}->get_object_dbxref_evidence_id;
            my $ontology_url = "/locus/$locus_id/ontologies/";
            if ( $href->{obsolete} eq 't' ) {
                my $unobsolete =  qq | <input type = "button" onclick= "javascript:Tools.toggleObsoleteAnnotation('0', \'$evidence_id\',  \'/ajax/locus/toggle_obsolete_annotation\', \'/locus/$locus_id/ontologies\')" value = "unobsolete" /> | if $privileged ;
                push @obs_annot,
                $href->{relationship} . " "
                    . $cvterm_link . " ("
                    . $href->{ev_code} . ")"
                    . $unobsolete;
            }
            else {
                my $ontology_details = $href->{relationship}
                . qq| $cvterm_link ($db_name:<a href="$url$db_accession" target="blank"> $accession</a>)<br />|;
                my $obsolete_link =  qq | <input type = "button" onclick="javascript:Tools.toggleObsoleteAnnotation('1', \'$evidence_id\',  \'/ajax/locus/toggle_obsolete_annotation\', \'/locus/$locus_id/ontologies\')" value ="delete" /> | if $privileged ;

                ##################
                # add an empty row if there is more than 1 evidence code
                my $ev_string;
                $ev_string .= "<hr />"
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
    my $ontology_evidence;
    #now we should have an %ont_hash with all the details we need for printing ...
    #hash keys are the cv names ..
    for my $cv_name ( sort keys %ont_hash ) {
        my @evidence;
        #and for each ontology annotation create an array ref of evidences
        for my $ont_detail ( sort keys %{ $ont_hash{$cv_name} } ) {
            push @evidence,
            [ $ont_detail, $ont_hash{$cv_name}{$ont_detail} ];
        }
        my $ev = join "\n", map {
            qq|<div class="term">$_->[0]</div>\n|
                .qq|<div class="evidence">$_->[1]</div>\n|;
        } @evidence;
        $ontology_evidence .= info_table_html(
            $cv_name     => $ev,
            __border     => 0,
            __tableattrs => 'width="100%"',
            );
    }
    #display ontology annotation form
    my $print_obsoleted;
    if ( @obs_annot &&  $privileged ) {
        #####$ontology_evidence .= print_obsoleted(@obs_annot);
        my $obsoleted;
        foreach my $term (@obs_annot) {
            $obsoleted .= qq |$term  <br />\n |;
        }
        $print_obsoleted = html_alternate_show(
            'obsoleted_terms', 'Show obsolete',
            '',                qq|<div class="minorbox">$obsoleted</div> |,
            );
    }
    $hashref->{html} = $ontology_evidence . $print_obsoleted;
    $c->stash->{rest} = $hashref;
}

############
sub associate_ontology:Path('/ajax/locus/associate_ontology') :ActionClass('REST') {}

sub associate_ontology_GET :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a GET.." } ;
}
#########################change this to the locus object !! 
sub associate_ontology_POST :Args(0) {
    my ( $self, $c ) = @_;

    my $dbh = $c->dbc->dbh;
     my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $cvterm_rs = $schema->resultset('Cv::Cvterm');

    my $locus_id       = $c->req->param('object_id');
    my $ontology_input = $c->req->param('term_name');
    my $relationship   = $c->req->param('relationship'); # a cvterm_id
    my ($relationship_id) = $cvterm_rs->find( { cvterm_id => $relationship } )->dbxref_id;
    my $evidence_code  = $c->req->param('evidence_code'); # a cvterm_id
    my ($evidence_code_id) = $cvterm_rs->find( {cvterm_id => $evidence_code })->dbxref_id;
    my $evidence_description = $c->req->param('evidence_description') || undef; # a cvterm_id
    my ($evidence_description_id) = $cvterm_rs->find( {cvterm_id => $evidence_description })->dbxref_id if $evidence_description;
    my $evidence_with = $c->req->param('evidence_with') || undef; # a dbxref_id (type='evidence_with' value = 'dbxref_id'
    my ($evidence_with_id) = $evidence_with if $evidence_with && $evidence_with ne 'null';
    my $logged_user = $c->user;
    my $logged_person_id = $logged_user->get_object->get_sp_person_id if $logged_user;

    my $reference = $c->req->param('reference');
    my $reference_id = $reference ? $reference :
        CXGN::Chado::Publication::get_curator_ref($dbh);
##
    my ($locus_dbxref, $locus_dbxref_id, $locus_dbxref_evidence);
    ##
    #solanaceae_phenotype--SP:000001--fruit size
    my ($cv_name, $db_accession, $cvterm_name)  = split /--/ , $ontology_input;
    my ($db_name, $accession) = split ':' , $db_accession;

    my ($cvterm) = $schema
        ->resultset('General::Db')
        ->search({ 'me.name' => $db_name, } )->search_related('dbxrefs' , { accession => $accession } )
        ->search_related('cvterm')->first; # should be only 1 cvterm per dbxref
    if (!$cvterm) {
        $c->stash->{rest} = { error => "no ontology term found for term $db_name : $accession" };
        return;
    }
    my $locus = CXGN::Phenome::Locus->new($dbh, $locus_id);
    my $cvterm_id = $cvterm->cvterm_id;
    my $dbxref_id  = $cvterm->dbxref_id;
    if (!$c->user) {
        $c->stash->{rest} = { error => 'Must be logged in for associating ontology terms! ' };
        return;
    }
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        # if this fails, it will throw an acception and will (probably
        # rightly) be counted as a server error
        #########################################################
        if ($locus->get_locus_id && $cvterm_id) {
            try {
                #check if the locus cvterm annotation exists. These annotations are stored in locus_dbxref

                $locus_dbxref_id= CXGN::Phenome::LocusDbxref::locus_dbxref_exists($dbh,$locus_id, $dbxref_id);
                $locus_dbxref=CXGN::Phenome::LocusDbxref->new($dbh, $locus_dbxref_id);
                $locus_dbxref->set_locus_id($locus_id);

                $locus_dbxref_evidence= CXGN::Phenome::Locus::LocusDbxrefEvidence->new($dbh);

                $locus_dbxref->set_dbxref_id($dbxref_id);
                $locus_dbxref->set_sp_person_id($logged_person_id);

                #this store should insert a new locus_dbxref if !$locus_dbxref_id
                #update obsolete to 'f' if $locus_dbxref_id and obsolete ='t'
                #do nothing if $locus_dbxref_id and obsolete = 'f'
                my $obsolete = $locus_dbxref->get_obsolete();

                #if the dbxref exists this should just return the database id to be used for
                #storing a  dbxref_evidence
                $locus_dbxref_id = $locus_dbxref->store;
                #print STDERR "object_dbxref_id = $object_dbxref_id ! \n";
                $locus_dbxref_evidence->set_object_dbxref_id($locus_dbxref_id);
                $locus_dbxref_evidence->set_relationship_type_id($relationship_id);
                $locus_dbxref_evidence->set_evidence_code_id($evidence_code_id);
                $locus_dbxref_evidence->set_evidence_description_id($evidence_description_id);
                $locus_dbxref_evidence->set_evidence_with($evidence_with_id);
                $locus_dbxref_evidence->set_reference_id($reference_id);
                $locus_dbxref_evidence->set_sp_person_id($logged_person_id);

                my $locus_dbxref_evidence_id = $locus_dbxref_evidence->store ;

##########################################
                $c->stash->{rest} = ['success'];
            } catch {
                $c->stash->{rest} = { error => "Failed: $_" };
                # send an email to sgn bugs
                $c->stash->{email} = {
                    to      => 'sgn-bugs@sgn.cornell.edu',
                    from    => 'sgn-bugs@sgn.cornell.edu',
                    subject => "Associate ontology failed! locus_id = $locus_id",
                    body    => $_,
                };
                $c->forward( $c->view('Email') );
                return;
            };
            # if you reached here this means associate_ontology worked. Now send an email to sgn-db-curation
            $c->stash->{email} = {
                to      => 'sgn-db-curation@sgn.cornell.edu',
                from    => 'www-data@sgn-vm.sgn.cornell.edu',
                subject => "New ontology term loaded. Locus $locus_id",
                body    => "User " . $logged_user->get_object->get_first_name . " " . $logged_user->get_object->get_last_name . "has stored a new ontology term for locus $locus_id http://solgenomics.net/locus/$locus_id/view",
            };
            $c->forward( $c->view('Email') );
        } else {
            $c->stash->{rest} = { error => 'need both valid locus_id and cvterm_id for adding an ontology term to this locus! ' };
        }
    } else {
        $c->stash->{rest} = { error => 'No privileges for adding new ontology terms. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' };
    }
}

sub references : Chained('/locus/get_locus') :PathPart('references') : ActionClass('REST') { }


sub references_GET :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    # get a list of references
    my $q = "SELECT dbxref.dbxref_id, accession,title
                                          FROM public.dbxref
                                          JOIN public.pub_dbxref USING (dbxref_id)
                                          JOIN public.pub USING (pub_id)
                                          JOIN phenome.locus_dbxref USING (dbxref_id)
                                          WHERE locus_id= ?
                                          AND phenome.locus_dbxref.obsolete = 'f'";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($locus->get_locus_id);
    my $response_hash={};
    while (my ($dbxref_id, $accession, $title) = $sth->fetchrow_array) {
        $response_hash->{$accession . ": " . $title} = $dbxref_id;
    }
    $c->stash->{rest} = $response_hash;
}

sub evidences : Chained('/locus/get_locus') :PathPart('evidences') : ActionClass('REST') { }

sub evidences_GET :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    # get a list of evidences
    my $q = "SELECT dbxref.dbxref_id, accession,name, description
                                          FROM public.dbxref
                                          JOIN feature USING (dbxref_id)
                                          JOIN phenome.locus_dbxref USING (dbxref_id)
                                          WHERE locus_id= ?
                                          AND phenome.locus_dbxref.obsolete = 'f'" ;
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($locus->get_locus_id);
    my $response_hash={};
    while (my ($dbxref_id, $accession, $name, $description) = $sth->fetchrow_array) {
        $response_hash->{$name . ": " . $description} = $dbxref_id ;
    }
    $c->stash->{rest} = $response_hash;
}

sub toggle_obsolete_annotation : Path('/ajax/locus/toggle_obsolete_annotation') : ActionClass('REST') { }

sub toggle_obsolete_annotation_POST :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    my $locus_dbxref_evidence_id = $c->request->body_parameters->{id};
    my $obsolete = $c->request->body_parameters->{obsolete};

    my $response = {} ;
    if ($locus_dbxref_evidence_id && $c->user ) {
        my $locus_dbxref_evidence = $c->dbic_schema('CXGN::Phenome::Schema')->resultset('LocusDbxrefEvidence')->find( {
            locus_dbxref_evidence_id => $locus_dbxref_evidence_id });
        if ($locus_dbxref_evidence) {
            $locus_dbxref_evidence->update( { obsolete => $obsolete } );
            $response->{response} = "success";
        }else { $response->{error} = "No locus evidence found for locus_dbxref_evidence_id $locus_dbxref_evidence_id! "; }
        #set locus_dbxref_evidence to obsolete
    } else { $response->{error} = "locus_dbxref_evidence $locus_dbxref_evidence_id does not exists! ";  }
    $c->stash->{rest} = $response;
}

sub locus_network : Chained('/locus/get_locus') :PathPart('network') : ActionClass('REST') { }

sub locus_network_GET :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    my $locus_id = $locus->get_locus_id;
    my $privileged;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    my $dbh = $c->dbc->dbh;
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
        my ($organism, $associated_locus_name, $gene_activity);
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
            my $lgm_obsolete_link =  $privileged ?
                qq | <input type = "button" onclick="javascript:Locus.obsoleteLocusgroupMember(\'$lgm_id\',  \'$locus_id\', \'/ajax/locus/obsolete_locusgroup_member\', \'/locus/$locus_id/network\')" value ="Remove" /> |
                : qq| <span class="ghosted">[Remove]</span> |;
            ###########
            $members_info .=
                qq|$organism <a href="/locus/$member_locus_id/view">$associated_locus_name</a> $gene_activity $lgm_obsolete_link <br /> |
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
    $c->stash->{rest} = { html => $associated_loci } ;
}


sub associate_locus:Path('/ajax/locus/associate_locus') :ActionClass('REST') {}

sub associate_locus_POST :Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $privileged;
    my $response;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    my $logged_person_id = $c->user->get_object->get_sp_person_id if $c->user;
    my %params = map { $_ => $c->request->body_parameters->{$_} } qw/
       locus_reference_id locus_evidence_code_id
       object_id locus_relationship_id locus_id
    /;
    my $locus_id = $params{locus_id};
    my $relationship;
    if ($privileged) {
        try {
            my $bcs = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
            my $cvterm = $bcs->resultset('Cv::Cvterm')->find( { cvterm_id => $params{locus_relationship_id} } );
            $relationship=$cvterm->name();
            my %directional_rel =
                ('Downstream'=>1,
                 'Inhibition'=>1,
                 'Activation'=>1
                );
            my $directional= $directional_rel{$relationship};
            my $lgm=CXGN::Phenome::LocusgroupMember->new($schema);
            $lgm->set_locus_id($locus_id );
            $lgm->set_evidence_id($params{locus_evidence_code_id});
            $lgm->set_reference_id($params{locus_reference_id});
            $lgm->set_sp_person_id($logged_person_id);
            my $a_lgm=CXGN::Phenome::LocusgroupMember->new($schema);
            $a_lgm->set_locus_id($params{object_id});
            $a_lgm->set_evidence_id($params{locus_evidence_code_id});
            $a_lgm->set_reference_id($params{locus_reference_id});
            $a_lgm->set_sp_person_id($logged_person_id);

            if ($directional) {
                $lgm->set_direction('subject');
                $a_lgm->set_direction('object')
            }
            my $locusgroup= $lgm->find_or_create_group($params{locus_relationship_id}, $a_lgm);
            my $lg_id= $locusgroup->get_locusgroup_id();
            $lgm->set_locusgroup_id($lg_id);
            $a_lgm->set_locusgroup_id($lg_id);

            my $lgm_id= $lgm->store();
            my $algm_id=$a_lgm->store();
            $response->{response} = 'success';
            return;
        } catch {
            $response->{error} = "Failed: $_" ;
            # send an email to sgn bugs
            $c->stash->{email} = {
                to      => 'sgn-bugs@sgn.cornell.edu',
                from    => 'sgn-bugs@sgn.cornell.edu',
                subject => "Associate locus failed! locus_id = $locus_id",
                body    => $_,
            };
            $c->forward( $c->view('Email') );
            return;
        };
        # if you reached here this means associate_locus worked. Now send an email to sgn-db-curation
        $c->stash->{email} = {
            to      => 'sgn-db-curation@sgn.cornell.edu',
            from    => 'www-data@sgn-vm.sgn.cornell.edu',
            subject => "New locus associated with locus $locus_id",
            body    => "User " . $c->user->get_object->get_first_name . " " . $c->user->get_object->get_last_name . "has associated locus $locus_id ($relationship) with locus " . $params{object_id} . "( /solgenomics.net/locus/$locus_id/view )",
        };
        $c->forward( $c->view('Email') );
    } else {
        $response->{ error} = 'No privileges for associating loci. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' ;
    }
    $c->stash->{rest} = $response;
}


sub obsolete_locusgroup_member : Path('/ajax/locus/obsolete_locusgroup_member') : ActionClass('REST') { }

sub obsolete_locusgroup_member_POST :Args(0) {
    my ($self, $c) = @_;
    my $locus_id = $c->request->body_parameters->{locus_id};
    my $lgm_id = $c->request->body_parameters->{lgm_id};
    my $obsolete = $c->request->body_parameters->{obsolete};
    my $schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $response = {} ;
    if ($lgm_id && $c->user ) {
        my $lgm=CXGN::Phenome::LocusgroupMember->new($schema, $lgm_id);
        if ($lgm->get_locusgroup_member_id) {
            try {
                $lgm->obsolete_lgm();
            } catch {
                $c->stash->{rest} = { error => "Failed: $_" };
                $c->stash->{email} = {
                    to      => 'sgn-bugs@sgn.cornell.edu',
                    from    => 'sgn-bugs@sgn.cornell.edu',
                    subject => " /ajax/locus/obsolete_locusgroup_member failed! locus_id = $locus_id, locusgroup_member_id = $lgm_id, obsolete = $obsolete",
                    body    => $_,
                };
                $c->forward( $c->view('Email') );
                return;
            };
            $response->{response} = "success";
            $c->stash->{email} = {
                to      => 'sgn-db-curation@sgn.cornell.edu',
                from    => 'www-data@sgn-vm.sgn.cornell.edu',
                subject => "[A locus group member has been obsoleted]",
                body    => "User " . $c->user->get_object->get_first_name . " " . $c->user->get_object->get_last_name .  " has obsoleted locus group member $lgm_id \n ( /solgenomics.net/locus/$locus_id/view )",
            };
            $c->forward( $c->view('Email') );
        }else { $response->{error} = "No locus group member  for locus group member_id $lgm_id! "; }
    } else { $response->{error} = "locus group member  $lgm_id does not exists! ";  }
    $c->stash->{rest} = $response;
}


sub locus_unigenes : Chained('/locus/get_locus') :PathPart('unigenes') : ActionClass('REST') { }

sub locus_unigenes_GET :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    my $locus_id = $locus->get_locus_id;
    my $privileged;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    my $dbh = $c->dbc->dbh;
    my $response ={};
    try {
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
            #
            my $unigene_obsolete_link = $privileged ?
                qq | <input type = "button" onclick="javascript:Locus.obsoleteLocusUnigene(\'$locus_unigene_id\',  \'$locus_id\')" value ="Remove" /> |
                : qq| <span class="ghosted">[Remove]</span> |;
            #
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

        $response->{unigenes} = $unigenes;
        $response->{solcyc}   = $solcyc_links;

    } catch {
        $response->{error} = "Failed: $_" ;
        # send an email to sgn bugs
        $c->stash->{email} = {
            to      => 'sgn-bugs@sgn.cornell.edu',
            from    => 'sgn-bugs@sgn.cornell.edu',
            subject => "locus_unigenes failed! locus_id = $locus_id",
            body    =>  $_,
        };
        $c->forward( $c->view('Email') );
        return;
    };
    $c->stash->{rest} = $response ;
}



sub obsolete_locus_unigene : Path('/ajax/locus/obsolete_locus_unigene') : ActionClass('REST') { }

sub obsolete_locus_unigene_POST :Args(0) {
    my ($self, $c) = @_;
    my $locus_unigene_id = $c->request->body_parameters->{locus_unigene_id};
    my $locus_id = $c->request->body_parameters->{locus_id};
    my $dbh = $c->dbc->dbh;
    my $response = {} ;
    try {
        my $u_query="UPDATE phenome.locus_unigene SET obsolete='t' WHERE locus_unigene_id=?";
        my $u_sth=$dbh->prepare($u_query);
        $u_sth->execute($locus_unigene_id);
    } catch {
        $c->stash->{rest} = { error => "Failed: $_" };
        $c->stash->{email} = {
            to      => 'sgn-bugs@sgn.cornell.edu',
            from    => 'sgn-bugs@sgn.cornell.edu',
            subject => " /ajax/locus/obsolete_locus_unigene failed! locus_unigene_id = $locus_unigene_id",
            body    => $_,
        };
        $c->forward( $c->view('Email') );
        return;
    };
    $response->{response} = "success";
    $c->stash->{email} = {
        to      => 'sgn-db-curation@sgn.cornell.edu',
        from    => 'www-data@sgn-vm.sgn.cornell.edu',
        subject => "[A locus-unigene link has beed obsoleted] locus_id = $locus_id",
        body    => "User " . $c->user->get_object->get_first_name . " " . $c->user->get_object->get_last_name .  " has obsoleted locus_unigene_id $locus_unigene_id \n ( /solgenomics.net/locus/$locus_id/view )",
    };
    $c->forward( $c->view('Email') );
    $c->stash->{rest} = $response;
}

sub associate_unigene : Chained('/locus/get_locus') :PathPart('associate_unigene') : ActionClass('REST') { }

sub associate_unigene_POST :Args(0) {
    my ($self, $c) = @_;
    my  $locus   = $c->stash->{locus};
    my $locus_id = $locus->get_locus_id;
    my $response;
    my $unigene_input = $c->request->body_parameters->{unigene_input};
    my ($unigene_id, undef, undef) = split /--/ , $unigene_input;
    # "SGN-U$unigene_id--build $build_id--$nr_members members";
    $unigene_id =~ s/sgn-u//i ;
    if ( !(looks_like_number($unigene_id)) ) {
        $response->{ error} = "This does not look like a valid unigene id ($unigene_id). Check your input! \n " ;
        $c->stash->{rest} = $response;
        return;
    }
    my $dbh = $c->dbc->dbh;
    my $privileged;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    my $logged_person_id = $c->user->get_object->get_sp_person_id if $c->user;
    if ($privileged) {
        try {
            print STDERR "****ABOUT TO ADD UNIGENE $unigene_id to locus $locus_id\n\n\n";
            my $id = $locus->add_unigene($unigene_id, $logged_person_id);
            print STDERR "**DONE id = $id \n\n\n";
        } catch {
            $response->{error} = "Failed: $_" ;
            # send an email to sgn bugs
            $c->stash->{email} = {
                to      => 'sgn-bugs@sgn.cornell.edu',
                from    => 'sgn-bugs@sgn.cornell.edu',
                subject => "Associate unigene failed! locus_id = $locus_id",
                body    => $_,
            };
            $c->forward( $c->view('Email') );
            $c->stash->{rest} = $response;
            return;
        };
        # if you reached here this means associate_unigene worked.
        #Now send an email to sgn-db-curation
        $c->stash->{email} = {
            to      => 'sgn-db-curation@sgn.cornell.edu',
            from    => 'www-data@sgn-vm.sgn.cornell.edu',
            subject => "New unigene associated with locus $locus_id",
            body    => "User " . $c->user->get_object->get_first_name . " " . $c->user->get_object->get_last_name . "has associated unigene $unigene_id  with locus $locus_id " . "( /solgenomics.net/locus/$locus_id/view )",
        };
        $c->forward( $c->view('Email') );
        $response->{response} = "success";
    } else {
        $response->{ error} = 'No privileges for associating unigenes. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' ;
    }
    $c->stash->{rest} = $response;
}

####
1;
###
