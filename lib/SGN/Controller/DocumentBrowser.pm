

=head1 NAME

SGN::Controller::DocumentBrowser - a controller for viewing document browser page

=head1 DESCRIPTION

The document browser is a tool that allows the user to upload a tsv file. The file is archived so others can view it as well. Users can then search the file for text matches and the value from the first column can then be saved to a list.

=head1 AUTHOR

=cut


package SGN::Controller::DocumentBrowser;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }


sub document_browser :Path('/tools/documents/') :Args(0) { 
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my @file_array;
	my %file_info;
	my $q = "SELECT file_id, m.create_date, p.sp_person_id, p.username, basename, dirname, filetype FROM metadata.md_files JOIN metadata.md_metadata as m using(metadata_id) JOIN sgn_people.sp_person as p ON (p.sp_person_id=m.create_person_id) WHERE filetype='document_browser' and m.obsolete = 0 ORDER BY file_id ASC";
	my $h = $bcs_schema->storage()->dbh()->prepare($q);
	$h->execute();

	while (my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype) = $h->fetchrow_array()) {
		$file_info{$file_id} = [$file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype];
	}
	foreach (keys %file_info){
		push @file_array, $file_info{$_};
	}

    $c->stash->{files} = \@file_array;
    $c->stash->{template} = '/tools/document_browser.mas';
}

1;
