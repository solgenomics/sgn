
package SGN::Controller::AJAX::Wiki;


use Text::MultiMarkdown qw | markdown |;
use CXGN::People::Wiki;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


has people_schema => ( isa => 'Ref',
		       is => 'rw'
    );

# has page_title => ( isa => 'Str',
# 		    is => 'rw');

# has page_content => ( isa => 'Str',
# 		      is => 'rw');

# has page_version => ( isa => 'Int',
# 		      is => 'rw');

# has sp_person_id => ( isa => 'Int',
# 		      is => 'rw');

has wiki_id => (isa => 'Int',
		is => 'rw');


sub ajax_wiki : Chained('/') PathPart('ajax/wiki') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;

    $c->stash->{page_name} = shift;
}

sub ajax_wiki_new :Path('/ajax/wiki/new') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id = $c->user->get_object->get_sp_person_id();

    my $page_name = $c->req->param('page_name');

    my $sp_wiki_id;

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );

    eval {
	$sp_wiki_id = $wiki->new_page($page_name, $user_id);
    };

    if ($@) {
	$c->stash->{rest} = { error => $@ };
    }
    else {
	$c->stash->{rest} = { success => 1, sp_wiki_id => $sp_wiki_id };
    }
}

sub ajax_edit_page : Chained('ajax_wiki') PathPart('edit') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "EDIT WIKI\n";
    $c->stash->{rest} = { error => '' };
}

# this needs to be POST
# stores the content for a given wiki_id
#
sub store : Chained('ajax_wiki') PathPart('store')  Args(0) ActionClass('REST') { }

sub store_POST {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user->get_object->get_sp_person_id();
    my $page_name = $c->stash->{page_name};

    print STDERR "WIKI ID FOR STORE: $page_name\n";

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );

    my $content_data;

    my $content = $c->req->param('content');

    eval {
	print STDERR "CONTROLLER: STORE $page_name, $content\n";
	$content_data = $wiki->store_page($page_name, $content, $sp_person_id);
    };

    if ($@) {
	print STDERR "An error occurred in store_POST: $@\n";
	$c->stash->{rest} = { error => $@ };
	$c->detach();
    }

    $c->stash->{rest} = {
	success => 1,
	wiki_content_id => $content_data->{wiki_content_id},
	version => $content_data->{version},
    };
}


sub delete : Chained('ajax_wiki') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "DELETE WIKI\n";
    $c->stash->{rest} = { error => '' };


}

sub view : Chained('ajax_wiki') PathPart('view') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "VIEW PAGE NAMED ".$c->stash->{page_name}."\n";

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );

    my $page_contents;
    eval {
	$page_contents = $wiki->retrieve_page($c->stash->{page_name});
    };
    if ($@) {
	$c->stash->{rest} = { error => "An error occurred retrieving the page. It may not exist $@" };
	$c->detach();
    }
    my $wiki_html = markdown($page_contents, { use_wikilinks => 1 } );

    $c->stash->{rest} = { html => $wiki_html };

}


sub retrieve : Chained('ajax_wiki') PathPart('retrieve') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "RETRIEVING WIKI PAGE NAMED ".$c->stash->{page_name}."\n";

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );

    my $page_contents = $wiki->retrieve_page($c->stash->{page_name});

    $c->stash->{rest} = { raw => $page_contents };

}


1;
