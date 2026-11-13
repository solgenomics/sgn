package SGN::Controller::AJAX::Search::File;

=head1 NAME

SGN::Controller::AJAX::Search::File - AJAX search endpoint for stored files
(metadata.md_files), for search pages and for picking files into collections

=head1 DESCRIPTION

Mirrors SGN::Controller::AJAX::Search::Image: DataTables serverSide params,
optional html_select_box checkbox column, rows formatted as arrays.

Requires a logged in user. Any logged in user can search every archived file;
results are not restricted to the files the user uploaded.

POST params:
  file_name            - composite: matches basename OR comment (ilike)
  file_type            - filetype (ilike); comma list supported
  file_uploader        - uploader username (ilike)
  file_tag             - only files carrying all of these tags (comma list ok),
                         e.g. "processed"
  file_interval        - only files archived within this interval, one of the
                         intervals in %CXGN::File::VALID_ARCHIVE_INTERVALS
                         (e.g. "3 months"); default "all time"
  collection_id        - only files in these collections (comma list ok)
  html_select_box      - name of the checkbox input rendered in column 0
  length / start / draw - DataTables serverSide

=cut

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

use CXGN::File;
use CXGN::File::Search;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub file_search : Path('/ajax/search/files') : ActionClass('REST') { }

sub file_search_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    # Any logged in user can search all archived files (the search filters by uploader), but
    # archived files are not public, so anonymous requests are refused.
    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to search files." };
        return;
    }

    my $sp_person_id = $c->user->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado', $sp_person_id);
    my $params = $c->req->params() || {};

    # Composite term matches name OR comment, like the image search's
    # image_description_filename_composite.
    my @descriptors;
    if (exists($params->{file_name}) && $params->{file_name}) {
        if (ref($params->{file_name}) eq 'ARRAY') {
            push @descriptors, @{ $params->{file_name} };
        } else {
            push @descriptors, $params->{file_name};
        }
    }

    my @filetype_list;
    if (exists($params->{file_type}) && $params->{file_type}) {
        if (ref($params->{file_type}) eq 'ARRAY') {
            push @filetype_list, @{ $params->{file_type} };
        } else {
            @filetype_list = split /,/, $params->{file_type};
        }
    }

    my @uploader_list;
    if (exists($params->{file_uploader}) && $params->{file_uploader}) {
        push @uploader_list, $params->{file_uploader};
    }

    my @collection_id_list;
    if (exists($params->{collection_id}) && $params->{collection_id}) {
        if (ref($params->{collection_id}) eq 'ARRAY') {
            @collection_id_list = @{ $params->{collection_id} };
        } else {
            @collection_id_list = split /,/, $params->{collection_id};
        }
    }

    my @tag_list;
    if (exists($params->{file_tag}) && $params->{file_tag}) {
        my @raw_tags = ref($params->{file_tag}) eq 'ARRAY' ? @{ $params->{file_tag} } : ($params->{file_tag});
        @tag_list = grep { length } map { my $t = $_; $t =~ s/^\s+|\s+$//g; $t } map { split /,/ } @raw_tags;
    }

    my $interval = $params->{file_interval} || 'all time';
    if (!exists($CXGN::File::VALID_ARCHIVE_INTERVALS{$interval})) {
        $c->stash->{rest} = { error => "\"$interval\" is not a valid time interval." };
        return;
    }

    my $limit = $params->{length};
    my $offset = $params->{start};

    my $file_search = CXGN::File::Search->new({
        bcs_schema              => $schema,
        basename_list           => \@descriptors,
        comment_list            => \@descriptors,
        filetype_list           => \@filetype_list,
        uploader_username_list  => \@uploader_list,
        collection_id_list      => \@collection_id_list,
        tag_list                => \@tag_list,
        interval                => $interval,
        limit                   => $limit,
        offset                  => $offset,
    });
    my ($result, $records_total) = $file_search->search();

    my $draw = $params->{draw};
    if ($draw) {
        $draw =~ s/\D//g; # cast to int
    }

    my @return;
    foreach (@$result) {
        my @line;
        if ($params->{html_select_box}) {
            push @line, "<input type='checkbox' name='".$params->{html_select_box}."' value='".$_->{file_id}."'>";
        }
        push @line, (
            "<a href='/breeders/phenotyping/download/".$_->{file_id}."' >".$_->{basename}."</a>",
            $_->{filetype},
            $_->{comment},
            $_->{sp_person_id}
                ? "<a href='/solpeople/personal-info.pl?sp_person_id=".$_->{sp_person_id}."' >".$_->{username}."</a>"
                : '',
            $_->{create_date},
            join(', ', @{ $_->{tags} }),
        );
        push @return, \@line;
    }

    $c->stash->{rest} = {
        data            => [ @return ],
        draw            => $draw,
        recordsTotal    => $records_total,
        recordsFiltered => $records_total,
    };
}

1;