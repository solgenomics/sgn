#!/usr/bin/perl

=head1 NAME

  unigene_mason.pl
  Controller to show the web_page for unigene using MASON.

=cut

=head1 SYNOPSIS


=head1 DESCRIPTION

  This is the script to show the web_page using MASON

=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut


use strict;
use warnings;

use CGI ();

use CXGN::DB::Connection;

use CXGN::Transcript::Unigene;

use CatalystX::GlobalContext '$c';

## Use of CXGN::Page to take the arguments from the URL

my $q = CGI->new;

my %args = $q->Vars;

my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
my $schema     = $c->dbic_schema( 'CXGN::GEM::Schema', 'sgn_chado', $sp_person_id );
my $sgn_schema = $c->dbic_schema( 'SGN::Schema', undef, $sp_person_id );

my $dbh = CXGN::DB::Connection->new();

## To do more flexible how the unigene can be called

if (defined $args{'unigene_id'}) {
    $args{'id'} = $args{'unigene_id'} ;
    $args{'id'} =~ s/^SGN-U//;

    # convert CGN-U to SGN-U
    if( $args{unigene_id} =~ s/^CGN-?U//i ) {
        my ($sgnid) = $dbh->selectrow_array(<<EOS,undef, $args{unigene_id}, 'CGN');
SELECT unigene_id FROM unigene WHERE sequence_name = ? AND database_name=?
EOS
        if( $sgnid ) {
            $args{'id'} = $sgnid;
        }
    }
}



## Random function will get at random unigene from the latest unigene build

if (defined $args{'random'}) {
    if ($args{'random'} =~ m/^yes$/i) {
	my $last_unigene_build_id = $sgn_schema->resultset('UnigeneBuild')
	                                       ->search(
	                                                 undef,
	                                                 {
							    order_by => 'unigene_build_id DESC',
							    limit => 1
							 }
					               )
					       ->first()
					       ->get_column('unigene_build_id');

        ## Now get all the unigene_id for this unigene_build_id

	my $random_unigene_id = $sgn_schema->resultset('Unigene')
	                                   ->search(
	                                              {
							unigene_build_id => $last_unigene_build_id
						      },
	                                              {
							order_by => 'random()',
							limit    => 1
						      }
					           )
					   ->first()
					   ->get_column('unigene_id');

	## It will replace $args{'id'}

	$args{'id'} = $random_unigene_id;
    }
}

## Now it will take the unigene object based in the unigene_id (it will create an empty object by default)

my $unigene = CXGN::Transcript::Unigene->new($dbh);

if (defined $args{'id'} && $args{'id'} =~ m/^\d+$/) {

    $unigene = CXGN::Transcript::Unigene->new($dbh, $args{'id'});
}


## Now depending if there are enought condition, it will call a mason unigen page ($unigene object has an id)
## or an error page

if (defined $unigene && defined $unigene->get_unigene_id() ) {

    $c->forward_to_mason_view(
        '/transcript/unigene_detail.mas',
	     dbh         => $dbh,
	     schema      => $schema,
	     sgn_schema  => $sgn_schema,
	     unigene     => $unigene,
	     highlight   => $args{'highlight'},
	     force_image => $args{'force_image'},
	     basepath    => $c->config->{basepath},
	     temp_dir    => $c->tempfiles_subdir('unigene_images'),
            );
} else {
    $c->forward_to_mason_view(
        '/transcript/transcript_page_error.mas',
        object      => $unigene );
}
