
use Modern::Perl;

package SGN::Controller::AJAX::Wiki;

use base 'Catalyst::Controller::REST';


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub view :Chained('wiki_page') :PathPart('view')  :Args(0) :ActionClass('REST') {}

sub view_POST :Path('view') :Args(0) { 
    my ($self, $c) = @_;

    if ($c->stash->{wiki_rs}->contents()) { 
	$c->stash->{rest} = { contents => $c->stash->{wiki_rs}->contents(), };
	
    }
}

# sub store :Chained('wiki_page') :Path('/w/store') :ActionClass('REST') Args(0) { }

# sub store_POST { 
#     my ($self, $c, $page) = @_;
    
#     my $contents = $c->req->param('contents');

#     my $version = $c->stash->{wiki_rs}->first()->get_column("version");

#     $version++;

#     $c->model('wiki')->create( contents=>$contents, version=>$version, page=>$page );
# }

sub edit :Chained('wiki_page') :PathPart('edit') :Args(0) :ActionClass('REST')  { }

# sub edit_POST { 
#     my ($self, $c) = @_;
    
#     my $contents = $c->stash->{wiki_rs}->first()->get_column("contents");
#     my $html = <<HTML;

#     <textarea cols="20" rows="10" name="contents">$contents</textarea>

# HTML

#     $c->stash->{rest} = { contents => $html };
    

# }

sub wiki_page :PathPart('/wiki') :CaptureArgs(1) { 

    my ($self, $c, $page) = @_;

    print STDERR "WIKI: PROCESSING PAGE $page\n";

    $c->stash->{wiki_rs} = $c->model('wiki')->search(
	{ page => $page }, 
	{ +select => [  { max => 'version' } ] } );
}



1;
