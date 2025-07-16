
package SGN::Controller::AJAX::Search::Annotation;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use File::Slurp;
use JSON;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub annotation_search :Path('/ajax/search/annotation') Args(0) {
    my ($self, $c ) = @_;

    my @lines;
    my $number_lines=0;
    my $annotation_file = $c->get_conf('basepath') . $c->req->param("file");

    if(-e $annotation_file){
        my $text = read_file($annotation_file);
    
        while ($text && $text =~ /\G([^\n]*\n|[^\n]+)/g) {
            push @lines, [split /\t/, $1];
            $number_lines++;
        }
    }


    $c->stash->{rest} = { data => [ @lines], draw => '1', recordsTotal => $number_lines,  recordsFiltered => $number_lines };

}

1;
