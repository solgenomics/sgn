#!/usr/bin/perl
#
# $Id: Coverage.pm,v 1.1.16.1 2007/03/26 14:10:54 briano Exp $
#

=head1 NAME 

Coverage

=head1 DESCRIPTION

This is a plugin to find the Coverage of a feature (query) in other 
feature (anchor).

=head1 TODO

Write some docs.

=head1 AUTHOR

Marco Valtas E<lt>mavcunha@bit.fmrp.usp.brE<gt>

Copyright (c) 2002 Regional Blood Center of Ribeirao Preto

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

package Bio::Graphics::Browser::Plugin::Coverage;
use strict;
use Bio::Graphics::Browser::Plugin;
use warnings;
use Carp;
use CGI qw(:standard *table); 
use vars qw($VERSION @ISA);

@ISA = qw(Bio::Graphics::Browser::Plugin);

$VERSION = '0.10';

sub name { "Coverage" }

sub description {
    p("This is a plugin to find the Coverage of a feature (query) in other feature (anchor).").
    p(q[ Revision: $Revision: 1.1.16.1 $]).
    p("Author: Marco Valtas (mavcunha\@bit.fmrp.usp.br)");
}

sub mime_type { "text/html"; }

sub type { 'dumper'; }

sub dump {
    my ($self,$segment) = @_;
    my $config = $self->configuration;

    my $DEBUG = $config->{"debug"};# We are in debug mode?

    # Checking some commom mistakes.
    $self->_error('config',$segment) unless ($config->{query} and $config->{anchor});
    
    # The multiple nature of query select turn check for same kind complicated.
    #$self->_error('select',$segment) if ($config->{query} eq $config->{anchor});

    if($DEBUG){
        warn("===>Coverage Plugin Start ".localtime()." <===\n");
        $self->_html_header("Coverage Plugin DEBUG Mode - ".localtime());
        print "Segment requested: <b>$segment</b><br>";
        print "User Configuration:<br>";
        my $q = join(b(' and '),@{$config->{'query'}});
        print "QUERY: <b>".$q."</b><br>";
        print "ANCHOR:<b>".$config->{'anchor'}."</b><br>";
    } 

    # Getting some more objects.
    my $browser = $self->browser_config;
    my $gff_db = $self->database;
    
    my @query_feature;
    push(@query_feature,$browser->label2type($_)) foreach @{$config->{'query'}};

    my ($anchor_feature) = $browser->label2type($config->{'anchor'});

    # what I got?
    if($DEBUG){
        print "Features:<br>";
        print "QUERY FEATURE: <b>@query_feature</b><br>";
        print "ANCHOR FEATURE: <b>$anchor_feature</b><br>";
    }

    my @anchors = $segment->features($anchor_feature);
    my $total_q;
    
    {
        my %total_query;
        $total_query{$_->name}++ foreach $segment->features(-type=>@query_feature);
        $total_q = int(keys %total_query);
    }

    # We have found a anchor in the present segment?
    $self->_error("noanchor",$segment) unless @anchors;

    print "<br>Anchors found: <b>@anchors</b><br><br>" if $DEBUG;

 
    my $total_anchors = $#anchors + 1;# How many anchors?
    my %total_query_overlap;
    my %total_anchor_overlap; 
    
    # if we are here, probably is alright, so let's begin the html.
    $self->_html_header("Coverage Plugin - $segment ") unless $DEBUG;
    
    my @table_fill; # This will keep the list of match, for later.

    # Overlap block search.
    print "Starting overlap search:<br>" if $DEBUG;
    foreach my $anchor (@anchors){
        my $a_seg = $gff_db->segment($anchor);
        print "ANCHOR <b>$anchor</b> SEGMENT <b>$a_seg</b><BR>" if $DEBUG;
        
        my @overlap = $a_seg->overlapping_features(@query_feature);# See Bio:DB::GFF

        # Buffering our results.
        push(@table_fill,td({-class=>'datatitle'},a({-href=>"gbrowse?name=".$anchor->name},$anchor->name)));
        foreach my $match (@overlap){
            
            $total_query_overlap{$match->name}++; # Count all query overlaps.
            $total_anchor_overlap{$anchor}++; # Count overlaps by anchors
            
            # Preparing the output table.
            push(@table_fill,td({-class=>'databody'},$match->name));

            print "->Overlap <b>$match</b><br>" if $DEBUG;
            
        }
    }

    my $q = join(b(' and '),@{$config->{query}});
   
    #We need a summary table.
    print
    table({-width=>'100%'},
        TR({-class=>'searchtitle'},
            td({-colspan=>'2',-align=>'center'},b("Summary of the Coverage"))
        ),
        TR({-class=>'searchbody'},[
            td(["Anchor Selected",$config->{anchor}]),
            td(["Query Selected",$q]),
            td(["Total of anchors in segment", $total_anchors]),
            td(["Total of queries in segment", $total_q]),
            td(["Total of overlapping queries", int(keys %total_query_overlap) ]),
            td(["Total of anchors that had at least one overlap",int(keys %total_anchor_overlap)]),
            td(["Percent of Coverage",sprintf("%.2f",((int(keys %total_anchor_overlap)/$total_anchors)*100))."%"]),
            ])
    );
   
   
    # Here is the list of features that matched, if the user marked
    # show all matchs, this will displayed too.
    if($config->{list_match}){
        print
        table({-width=>'100%'},
            TR({-align=>'left'},
                td({-class=>'datatitle',-align=>'center'},"List of the overlapping features")
            ),
            TR({-align=>'left'},\@table_fill)
        );
    }
 
    
    $self->_html_footer; 
    warn("===>Coverage Plugin End ".localtime()." <===\n") if $DEBUG;
    return;

}


# Empty defaults.
sub config_defaults {
    my $self = shift;
    return { };
}

sub reconfigure {
    my($self) = @_;
    my $config = $self->configuration;

    # Madatory configurations
#    foreach my $option (@queries){
#        push(@{$config->{'query'}},$option
#    my @queries
    $config->{'query'} = [param('Coverage.query')];
    $config->{'anchor'} = param('Coverage.anchor');

    # Optional configuration.
    # This configuration lists all matches.
    $config->{'list_match'} = param('Coverage.list_match');

    
    # Debug mode checkbox.
    $config->{'debug'}  = param('Coverage.debug');
    return;
}

sub configure_form {
    my ($self) = @_;
    
    my $b = $self->browser_config;
    my $config = $self->configuration;

    return 
    table({-width=>'100%'},
        TR({-class=>'searchtitle'},
            th({-colspan=>'3',-align=>'LEFT'},
                "Enter the configuration.",
                )
        ),
        TR({-class=>'searchbody','-align'=>'left'},
            td(b('Query<br>'),
                checkbox_group('-name'=>"Coverage.query",
                    -values=>[$b->labels],
                    -linebreak=>'true',
                    -default=>\@{$config->{query}},
                ),
                td({-valign=>'top'},b('Anchor<br>'),
                    radio_group('-name'=>"Coverage.anchor",
                        -values=>[$b->labels],
                        -linebreak=>'true',
                        -default=>$config->{anchor},
                    ),
                ),
                td({-valign=>'top'},b('Options<br>'),
                    checkbox(-name=>'Coverage.list_match',
                        -value=>'1',
                        -label=>'Show match list'),'<br>',
                    #checkbox(-name=>'Coverage.debug',
                    #    -value=>'1',
                    #    -label=>'Turn on debug'),
                ),
            ),
        )
    );
}

sub _error {
    my($self,$error_key,$segment) = @_;

    my $config = $self->configuration;
    
    # Error messages
    my %error_message = (
        
        "noanchor" =>
        p("Can not find a anchor ",
            font({-color=>'red'},$config->{anchor}),
            " in this segment ",
            font({-color=>'red'},$segment)
        ),
        
        "config"   =>
        p("Missing configuration, use ",
            font({-color=>'red'},"Configure"),
            " before hit ",
            font({-color=>'red'},"Go!")
        ),
        
        "select"   =>
        p("You selected the same feature ",
            font({-color=>'red'},$config->{query}),
            " in both boxes, please select different 
            features. Hit \"Back\" on your Browser"
        ),
    );

    # Now we print out the error to the user.
    print 
    $self->_html_header('Coverage Plugin Error'),
    table({-width=>'100%'},
        TR({-class=>'datatitle'},
            td({-colspan=>'2',-align=>'LEFT'},
                "An error occured in your request",
                )
        ),
        TR({-class=>'databody'},
            td({-colspan=>'2',-align=>'LEFT'},
                $error_message{$error_key},
                )
        ),
    );

    $self->_html_footer; # the end.
    exit(0);
}

sub _html_header {
    my($self,$title) = @_;

    my $browser = $self->browser_config;    
    print
    start_html(-title =>$title,
        -style => {src=>$browser->setting('stylesheet')},
    ),h1($title);
    return;
}
   
sub _html_footer {
    my($self) = @_;
    print
    table({-width=>'100%'},
        th(
            p({-align=>'left'},"Author: ",
                a({-href=>'mailto:mavcunha@bit.fmrp.usp.br'},"Marco Valtas (mavcunha\@bit.fmrp.usp.br) ").
                localtime()
            ),
        )
    ).
    end_html;
    return;
}
    
1;
