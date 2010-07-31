#!/usr/bin/perl -wT


=head1 SYNOPSIS
A simple script that retrieves common names and their ids, and 
writes out id of the selected organism into a file.
It is used to work with the Ajax form for the QTL webform.



=head1 AUTHOR

Isaak Y Tecle iyt2@cornell.edu 

=cut



use strict;
use warnings;

use Path::Class;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Phenome::Qtl;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();


my ($common_name, $common_name_id, $type, $sp_person_id) = $doc->get_encoded_arguments("organism", "organism_id", "type", "sp_person_id");
 
print STDERR "common_name : $common_name\n";
print STDERR "common_name_id : $common_name_id\n";
print STDERR "type: $type\n";

#$organism_id =~/(\d+)/;
#$organism_id =$1;
#$organism_id =~ s/\s//;

my $dbh = CXGN::DB::Connection->new();
my ($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();


if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    if ($type eq 'browse') {
	&browse_organisms($dbh, $type, $common_name);
    }
    elsif ($type eq 'associate') {
	&associate_organism($dbh, $type, $common_name_id, $login_person_id);
    }

}         
 
sub browse_organisms {
    my $dbh = shift;
    my $type = shift;
    my $common_name = shift;
    
    print STDERR "common_name : $common_name";  
    my $organisms;
    
    if ($type eq 'browse') {

	if ($common_name) { 
	    my $sth = $dbh->prepare ("SELECT common_name_id, common_name 
                                              FROM sgn.common_name                                                                                             WHERE common_name ILIKE '$common_name%'"
                                    );
	    $sth->execute();

	    while (my ($common_name_id, $common_name)	= $sth->fetchrow_array()) {		
		$organisms .= "$common_name_id*$common_name_id -- $common_name |";
		    
	    }
	
	    print $organisms;
	  }  
	
    }
  
}

sub associate_organism {
    my $dbh = shift;
    my $type = shift;
    my $common_name_id = shift;
    my $sp_person_id = shift;

    my $qtl = CXGN::Phenome::Qtl->new($sp_person_id);
    my ($temp_qtl_dir, $temp_user_dir) = $qtl->create_user_qtl_dir($c); 

    my $f = file( $temp_user_dir, 'organism.txt' )->openw
        or die "Can't create file: $! \n";
    $f->print( "common_name_id\t$common_name_id" );
}

