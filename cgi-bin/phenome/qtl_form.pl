=head1 DESCRIPTION
creates all the web forms for the qtl data submission
and sends the data to qtl_load.pl for processing
and loading it to the database.

=head1 AUTHOR
Isaak Y Tecle (iyt2@cornell.edu)

=cut



use strict;
use warnings;



use CXGN::Login;

use CatalystX::GlobalContext qw( $c );



my $dbh  = $c->dbc->dbh;
my $login = CXGN::Login->new($dbh);
my $sp_person_id = $login->verify_session();

my $cgi = CGI->new();
my %args = $cgi->Vars;
my $type = $args{type};
my $pop_id = $args{pop_id};
    
if ($sp_person_id) {
	my $guide   =  qq | <a  href="http://docs.google.com/View?id=dgvczrcd_1c479cgfb">Guidelines</a> |;

	if(!$type) {
	   $c->forward_to_mason_view('/qtl/qtl_form/intro.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                );	   
	    
	}

	elsif($type eq 'pop_form') {
            $c->forward_to_mason_view('/qtl/qtl_form/pop_form.mas',                                    
                                      guide  => $guide
                );
	     
	}


	elsif ($type eq 'trait_form') {
            $c->forward_to_mason_view('/qtl/qtl_form/trait_form.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                );	   
	}


	elsif ($type eq 'pheno_form') {
            $c->forward_to_mason_view('/qtl/qtl_form/pheno_form.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                );
	     
	}

	elsif ($type eq 'geno_form') {
             $c->forward_to_mason_view('/qtl/qtl_form/geno_form.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                );
	   
	}


	elsif ($type eq 'stat_form') {
            $c->forward_to_mason_view('/qtl/qtl_form/stat_form.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                );
	    
	}	
	
	elsif ($type eq 'confirm') {	    
	    $c->forward_to_mason_view('/qtl/qtl_form/confirm.mas',
                                      pop_id => $pop_id,
                                      guide  => $guide
                ); 
	} 	
}


