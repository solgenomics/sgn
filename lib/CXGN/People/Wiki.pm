
package CXGN::People::Wiki;

use Moose;

use Data::Dumper;
use CXGN::People::Schema;

has people_schema => (isa => 'Ref', is => 'rw');

has page_name => ( isa => 'Str',
		    is => 'rw');

has page_content => ( isa => 'Str',
		      is => 'rw');

has page_version => ( isa => 'Maybe[Int]',
		      is => 'rw');

has sp_person_id => ( isa => 'Int',
		      is => 'rw');

has sp_wiki_id => (isa => 'Int',
		   is => 'rw');

has create_date => (isa => 'Str',
		    is => 'rw');


sub BUILD {
    my $self = shift;

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $self->page_name } );

    if ($row) {
	$self->sp_person_id($row->sp_person_id());
	$self->create_date($row->create_date());
	$self->sp_wiki_id($row->sp_wiki_id());
	$self->page_version($self->get_version());
    }

}


sub new_page {
    my $self = shift;
    my $page_name = shift;
    my $sp_person_id = shift;

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $page_name } );

    if ($row) {
	die "Page named $page_name already exists!\n";
    }

    else {
	my $new_data = {
	    page_name => $page_name,
	    sp_person_id => $sp_person_id,

	};

	my $new_row = $self->people_schema()->resultset("SpWiki")->create($new_data);

	return $new_row->sp_wiki_id();

    }

}

sub retrieve_page {
    my $self = shift;
    my $page_name = shift;

    print STDERR "RETRIEVING WIKI PAGE NAMED $page_name\n";

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $page_name });

    if (! $row && ($page_name eq "WikiHome" )) {
	return "WELCOME TO THE WIKI!";
    }

    if (! $row) {
	die "The page with name $page_name does not exist!";
    }

    else {
	my $sp_wiki_id = $row->sp_wiki_id();

	my $content_rs = $self->people_schema()->resultset("SpWikiContent")->search( { sp_wiki_id => $sp_wiki_id }, { order_by => { -desc => 'page_version' } } );

	my $content_row;
	if ($content_rs->count() > 0) {
	    $content_row = $content_rs->next();

	    return {
		content => $content_row->page_content(),
		version => $content_row->page_version(),
	    };
	}

	else {
	    return undef;
	}
    }

}


sub store_page {
    my $self = shift;
    my $page_name = shift || 'WikiHome';
    my $content = shift || "empty page";
    my $sp_person_id = shift;

    print STDERR "STORE_PAGE: $page_name, $content\n";

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $page_name });

    if (! $row && $page_name eq 'WikiHome') {
	$row = $self->people_schema()->resultset("SpWiki")->create(
	    {
		sp_wiki_id => 1,
		sp_person_id => $sp_person_id,
		page_name => "WikiHome",
	    });

	$row->insert();

    }
    if (! $row) {
	print STDERR "THE WIKI PAGE DOES NOT EXIST ($page_name)\n";
 	die "The page with page name $page_name does not exist!";
    }

    my $sp_wiki_id = $row->sp_wiki_id();

    # figure out previous version, if any
    #
    my $current_version = 0;

    my $previous_content_rs = $self->people_schema()->resultset("SpWikiContent")->search( { sp_wiki_id => $sp_wiki_id }, { order_by => { -desc => 'page_version' } } );

    my $previous_content_row;

    print STDERR "FINDING CURRENT VERSION...\n";

    if ($previous_content_rs->count() > 0) {
	print STDERR "WE HAVE PREVIOUS DATA...\n";
	$previous_content_row = $previous_content_rs->next();
	if ($previous_content_row) {
	    print STDERR "WE HAVE A ROW...\n";
	    $current_version = $previous_content_row->page_version();
	}
    }

    print STDERR "CURRENT VERSION: $current_version\n";

    my $new_version = $current_version + 1;

    print STDERR "NEW VERSION : $new_version\n";
    my $wiki_content = {
	page_content => $content,
	page_version => $new_version,
	sp_wiki_id   => $sp_wiki_id,
    };

    my $new_row;
    eval {
	print STDERR "STORING PAGE DATA... $content\n";
	$new_row = $self->people_schema()->resultset("SpWikiContent")->create($wiki_content);
	$new_row->insert();
    };
    if ($@) {
	print STDERR "An error occurred storing content. $@\n";
	return { error => $@ };
    }

    return {
	version => $new_row->page_version(),
	wiki_content_id => $new_row->sp_wiki_content_id()
    };
}

sub delete {
    my $self = shift;
    my $page_name = shift;

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $page_name });

    $row->delete();
}


sub get_version {
    my $self =shift;
    my $page_name = shift || $self->page_name();

    my $row = $self->people_schema()->resultset("SpWiki")->find( { page_name => $page_name });

    my $page_version;

    my $version_rs = $self->people_schema()->resultset("SpWikiContent")->search( { sp_wiki_id => $row->sp_wiki_id() }, { order_by => { -desc => 'page_version' } } );

    if ($version_rs->count() > 0) {
	my $version_row = $version_rs->next();
	$page_version = $version_row->page_version();
    }

    return $page_version;
}


sub all_pages {
    my $self = shift;

    my $rs = $self->people_schema()->resultset("SpWiki")->search();

    my @pages;
    while (my $row = $rs->next()) {
	push @pages, $row->page_name();
    }

    my @pages = sort(@pages);

    print STDERR "PAGES ".Dumper(\@pages);
    return @pages;
}

1;
