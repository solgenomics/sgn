
package SGN::Controller::AJAX::Wiki;

use URI::FromHash 'uri';
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

    my $wiki_page_name = $page_name;
    $wiki_page_name =~ s/(_|-|\s+)(\w)/\U$2/g;

    my $sp_wiki_id;

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );


    eval {
	$sp_wiki_id = $wiki->new_page($wiki_page_name, $user_id);
    };

    if ($@) {
	$c->stash->{rest} = { error => $@ };
    }
    else {
	$c->stash->{rest} = { success => 1, sp_wiki_id => $sp_wiki_id, page_name => $wiki_page_name };
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

    if (! $sp_person_id) {
	$c->stash->{rest} = { error => "You need to be logged in to store wiki pages." };
	$c->detach();
    }

    my $page_name = $c->stash->{page_name};

    if (! $c->user()->check_roles("curator")) {
	$c->stash->{rest} = { error => "You do not have the privileges to modify wiki pages." };
	$c->detach();
    }
    my $user_id = $c->user()->get_object->get_sp_person_id();


    print STDERR "WIKI ID FOR STORE: $page_name\n";

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema"), page_name => $page_name } );

    print STDERR "PAGE OWNED BY ".$wiki->sp_person_id()."\n";
    if ($wiki->sp_person_id() != $user_id) {
	$c->stash->{rest} = { error => "Only the original owner can modify the wiki page." };
	$c->detach();
    }
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
	version => $content_data->{page_version},
    };
}


sub delete : Chained('ajax_wiki') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "DELETE WIKI PAGE ".$c->stash->{page_name}."\n";

    if (! $c->user()->check_roles("curator")) {
	$c->stash->{rest} = { error => "You do not have the privileges to delete wiki pages." };
	$c->detach();
    }
    my $user_id = $c->user()->get_object->get_sp_person_id();


    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema"), page_name => $c->stash->{page_name} } );

    if ($user_id != $wiki->sp_person_id()) {
	$c->stash->{rest} = { error => "Only the original page creator can delete the page. It is not you." };
	$c->detach();
    }

    eval {
	$wiki->delete($c->stash->{page_name});
    };
    if ($@) {
	$c->stash->{rest} = { error => $@ };
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }


}

sub view : Chained('ajax_wiki') PathPart('view') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "VIEW PAGE NAMED ".$c->stash->{page_name}."\n";

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema"), page_name => $c->stash->{page_name} } );

    my $page_content;
    my $page_version;

    eval {
	my $page_data = $wiki->retrieve_page($c->stash->{page_name});

	$page_content = $page_data->{page_content};

        $page_version = $wiki->get_version();

    };
    if ($@) {
	$c->stash->{rest} = { error => "An error occurred retrieving the page. It may not exist $@" };
	$c->detach();
    }
    my $wiki_html = markdown($page_content, { use_wikilinks => 1, base_url => '/wiki/' } );

    $c->stash->{rest} = {
	html => $wiki_html,
	page_version => $page_version,
    };

}


sub retrieve : Chained('ajax_wiki') PathPart('retrieve') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "RETRIEVING WIKI PAGE NAMED ".$c->stash->{page_name}."\n";

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema"), page_name => $c->stash->{page_name} }  );

    my $page_data = $wiki->retrieve_page($c->stash->{page_name});
    my $page_content = $page_data->{page_content};
    my $page_version = $page_data->{page_version};

    $c->stash->{rest} = {
	raw => $page_content,
	page_version => $page_version,
    };
}


1;
