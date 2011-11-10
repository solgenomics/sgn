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

use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use List::MoreUtils qw /any /;
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
                my $unobsolete =
                    my $obsolete_link =  qq | <a href="javascript:"onclick="Tools.unobsoleteAnnotation(\'$evidence_id\')"/>[delete]</a> | if $privileged ;
                push @obs_annot,
                $href->{relationship} . " "
                    . $cvterm_link . " ("
                    . $href->{ev_code} . ")"
                    . $unobsolete;
            }
            else {
                my $ontology_details = $href->{relationship}
                . qq| $cvterm_link ($db_name:<a href="$url$db_accession" target="blank"> $accession</a>)<br />|;
                my $obsolete_link =  qq | <a href="#" onclick="javascript:Tools.obsoleteAnnotation(\'$evidence_id\', \'/locus/$locus_id/ontologies\')" >[delete]</a> | if $privileged ;

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

sub associate_ontology_POST :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a POST.." } ;
}

sub associate_ontology_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $params = map { $_ => $c->req->param($_) } qw/
       object_id ontology_input relationship evidence_code evidence_description
       evidence_with reference
    /;

    my $stock_id       = $c->req->param('object_id');
    my $ontology_input = $c->req->param('term_name');
    my $relationship   = $c->req->param('relationship'); # a cvterm_id
    my $evidence_code  = $c->req->param('evidence_code'); # a cvterm_id
    my $evidence_description = $c->req->param('evidence_description'); # a cvterm_id
    my $evidence_with  = $c->req->param('evidence_with'); # a dbxref_id (type='evidence_with' value = 'dbxref_id'
    my $logged_user = $c->user;
    my $logged_person_id = $logged_user->get_object->get_sp_person_id if $logged_user;

    my $reference = $c->req->param('reference'); # a pub_id

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cvterm_rs = $schema->resultset('Cv::Cvterm');
    my ($pub_id) = $reference ? $reference :
        $schema->resultset('Pub::Pub')->search( { title=> 'curator' } )->first->pub_id; # a pub for 'cuurator' should already be in the sgn database. can add here $curator_cvterm->create_with ... and then create the curator pub with type_id of $curator_cvterm

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
    my ($stock) = $c->stash->{stock} || $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );

    my  $cvterm_id = $cvterm->cvterm_id;
    if (!$c->user) {
        $c->stash->{rest} = { error => 'Must be logged in for associating ontology terms! ' };
        return;
    }
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        # if this fails, it will throw an acception and will (probably
        # rightly) be counted as a server error
        #########################################################
        if ($stock && $cvterm_id) {
            try {
                #check if the stock_cvterm exists
                my $s_cvterm_rs = $stock->search_related(
                    'stock_cvterms', { cvterm_id => $cvterm_id, pub_id => $pub_id } );
                # if it exists , we need to increment the rank
                my $rank = 0;
                if ($s_cvterm_rs->first) {
                    $rank = $s_cvterm_rs->get_column('rank')->max + 1;
                    # now check if the evidence codes already exists
                    my ($rel_prop, $ev_prop, $desc_prop, $with_prop);
                    my $eprops = $s_cvterm_rs->search_related('stock_cvtermprops');
                    $rel_prop = $eprops->search( {
                        type_id => $cvterm_rs->search( { name => 'relationship'})->single->cvterm_id,
                        value => $relationship  })->first;

                    $ev_prop = $eprops->search( {
                        type_id =>   $cvterm_rs->search( { name => 'evidence_code'})->single->cvterm_id,
                        value => $evidence_code })->first;

                    $desc_prop = $eprops->search( {
                        type_id =>  $cvterm_rs->search( { name => 'evidence description'})->single->cvterm_id,
                        value => $evidence_description })->first if $evidence_description;

                    $with_prop = $eprops->search( {
                        type_id =>  $cvterm_rs->search( { name => 'evidence_with'})->single->cvterm_id,
                        value => $evidence_with })->first if $evidence_with;

                    # return error if annotation + evidence exist
                    if ($rel_prop && $ev_prop) {
                        $c->stash->{rest} = { error => "Annotation exists with these evidence codes! " };
                        return;
                    }
                }
                # now store a new stock_cvterm
                my $s_cvterm = $stock->create_related('stock_cvterms', {
                    cvterm_id => $cvterm_id,
                    pub_id    => $pub_id,
                    rank      => $rank, } );
#########
                $s_cvterm->create_stock_cvtermprops(
                    { 'relationship' => $relationship } , { db_name => 'OBO_REL', cv_name =>'relationship' } ) if looks_like_number($relationship);
                $s_cvterm->create_stock_cvtermprops(
                    { 'evidence_code' => $evidence_code } , { db_name => 'ECO', cv_name =>'evidence_code' } ) if looks_like_number($evidence_code);
                 $s_cvterm->create_stock_cvtermprops(
                     { 'evidence_description' => $evidence_description } , { cv_name =>'null', autocreate => 1 } ) if looks_like_number($evidence_description);
                $s_cvterm->create_stock_cvtermprops(
                    { 'evidence_with' => $evidence_with  } , { cv_name =>'local' , autocreate=>1} ) if looks_like_number($evidence_with);
                # store the person loading the annotation 
                $s_cvterm->create_stock_cvtermprops(
                    { 'sp_person_id' => $logged_person_id  } , { cv_name =>'local' , autocreate=>1} );
                #store today's date
                my $val = "now()";
                $s_cvterm->create_stock_cvtermprops(
                    { 'create_date' =>  \$val   } , { cv_name =>'local' , autocreate=>1, allow_duplicate_values => 1} );

                $c->stash->{rest} = ['success'];
                return;
            } catch {
                $c->stash->{rest} = { error => "Failed: $_" };
                # send an email to sgn bugs
                $c->stash->{email} = {
                    to      => 'sgn-bugs@sgn.cornell.edu',
                    from    => 'sgn-bugs@sgn.cornell.edu',
                    subject => 'Associate ontology failed! Stock_id = $stock_id',
                    body    => '$_',
                };
                $c->forward( $c->view('Email') );
                return;
            };
            # if you reached here this means associate_ontology worked. Now send an email to sgn-db-curation
            $c->stash->{email} = {
                to      => 'sgn-db-curation@sgn.cornell.edu',
                from    => 'sgn-bugs@sgn.cornell.edu',
                subject => 'New ontology term loaded. Stock $stock_id',
                body    => "User " . $logged_user->get_object->get_first_name . " " . $logged_user->get_object->get_last_name . "has stored a new ontology term for stock $stock_id http://solgenomics.net/stock/$stock_id/view",
            };
            $c->forward( $c->view('Email') );

        } else {
            $c->stash->{rest} = { error => 'need both valid stock_id and cvterm_id for adding an ontology term to this stock! ' };
        }
    } else {
        $c->stash->{rest} = { error => 'No privileges for adding new ontology terms. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' };
    }
}

sub references : Chained('/locus/get_stock') :PathPart('references') : ActionClass('REST') { }


sub references_GET :Args(0) {
    my ($self, $c) = @_;
    my $stock = $c->stash->{stock};
    # get a list of references
    my $q =  "SELECT dbxref.dbxref_id, pub.pub_id, accession,title
              FROM public.stock_pub
              JOIN public.pub USING (pub_id)
              JOIN public.pub_dbxref USING (pub_id)
              JOIN public.dbxref USING (dbxref_id)
              WHERE stock_id= ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($stock->get_stock_id);
    my $response_hash={};
    while (my ($dbxref_id, $pub_id, $accession, $title) = $sth->fetchrow_array) {
        $response_hash->{$pub_id} = $accession . ": " . $title;
    }
    $c->stash->{rest} = $response_hash;
}



sub obsolete_annotation : Path('/ajax/locus/obsolete_annotation') : ActionClass('REST') { }

sub obsolete_annotation_POST :Args(0) {
    my ($self, $c) = @_;
    my $locus = $c->stash->{locus};
    my $locus_dbxref_evidence_id = $c->request->body_parameters->{id};
    my $response = {} ;
    print STDERR "ABOUT TO obsolete locus_dbxref_evidence $locus_dbxref_evidence_id \n\n";
    if ($locus_dbxref_evidence_id && $c->user ) {
        my $locus_dbxref_evidence = $c->dbic_schema('CXGN::Phenome::Schema')->resultset('LocusDbxrefEvidence')->find( {
            locus_dbxref_evidence_id => $locus_dbxref_evidence_id });
        if ($locus_dbxref_evidence) {
            $locus_dbxref_evidence->update( { obsolete => 1 } );
            $response->{response} = "success";
        }else { $response->{error} = "No locus evidence found for locus_dbxref_evidence_id $locus_dbxref_evidence_id! "; }
        #set locus_dbxref_evidence to obsolete
    } else { $response->{error} = 'locus_dbxref_evidence $locus_dbxref_evidence_id does not exists! ';  }
    $c->stash->{rest} = $response;
}


sub unobsolete_annotation :Path('ajax/locus/unobsolete_annotation') : ActionClass('REST') { }

sub unobsolete_annotation_POST :Args(1) {
    my ($self, $c, $locus_dbxref_evidence_id) = @_;
    my $locus = $c->stash->{locus};
    
    my $response ={} ;
    if ($locus_dbxref_evidence_id) {
        #set locus_dbxref_evidence to obsolete = 0
       
    } else { $response->{error} = 'locus_dbxref_evidence $locus_dbxref_evidence_id does not exists! '; }
    $c->stash->{rest} = $response;
}



1;
