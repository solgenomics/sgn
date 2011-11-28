package SGN::Controller::Search::Transcripts;
use Moose;

BEGIN{ extends 'Catalyst::Controller' }

sub auto : Private {
    $_[1]->stash->{template} = '/search/transcripts/stub.mas';
}

sub est_search : Path('/search/transcripts/est') Args(0) {
    $_[1]->stash(
        template => '/search/transcripts/stub.mas',
        content  => CXGN::Search::CannedForms->est_search_form(),
     );
}

sub library_search : Path('/search/transcripts/est_library') Args(0) {
    $_[1]->stash(
        template => '/search/transcripts/stub.mas',
        content  => CXGN::Search::CannedForms->library_search_form(),
     );
}

sub unigene_search : Path('/search/transcripts/unigene') Path('/search/transcripts') Args(0) {
    $_[1]->stash(
        template => '/search/transcripts/stub.mas',
        content  => CXGN::Search::CannedForms->unigene_search_form(),
     );
}

1;
