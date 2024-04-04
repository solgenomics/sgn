
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


sub ann_search :Path('/ajax/search/annotation') Args(0) {
    my ($self, $c ) = @_;

    my $text = read_file($c->get_conf('basepath') . '/static/documents/annotation2.tsv');
    
    my @lines;
    my $number_lines=0;
    
    while ($text =~ /\G([^\n]*\n|[^\n]+)/g) {
        push @lines, [split /\t/, $1];
        $number_lines++;

    }
     print STDERR Dumper \@lines;

    $c->stash->{rest} = { data => [ @lines], draw => '1', recordsTotal => $number_lines,  recordsFiltered => $number_lines };

}

1;
