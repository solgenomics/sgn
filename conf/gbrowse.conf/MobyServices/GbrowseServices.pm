#!/usr/bin/perl -w
package MobyServices::GbrowseServices;

###################################################################
# Non-modperl users should change this variable if needed to point
# to the directory in which the configuration files are stored.
#
$CONF_DIR  = '/tmp/update-vendor-drop-jcQwDOU/FAKEROOT/conf/gbrowse.conf';
#
###################################################################







#====================================================================
#$Id: GbrowseServices.PMS,v 1.2 2004/01/07 22:21:49 markwilkinson Exp $

use strict;
use Text::Shellwords;
use Bio::DB::GFF;
use SOAP::Lite;
use MOBY::CommonSubs qw{:all};
use Bio::Graphics::Browser;
use Bio::Graphics::Browser::Util;
use vars qw(%dbh $CONFIG $authURI $CONF_DIR);

sub _settings {
    $CONF_DIR  = conf_dir($CONF_DIR);  # conf_dir() is exported from Util.pm

    ## CONFIGURATION & INITIALIZATION ################################  
    # preliminaries -- read and/or refresh the configuration directory
    $CONFIG = open_config($CONF_DIR);  # open_config() is exported from Util.pm
    my @sources = $CONFIG->sources; # get all data sources

    foreach (@sources){  # grab the database handle for each source
        $CONFIG->source($_);
        my $db = open_database($CONFIG);
        $dbh{$_}=$db;
    }
    
    open (IN, "$CONF_DIR/MobyServices/moby.conf") || die "\n**** GbrowseServices.pm couldn't open configuration file $CONF_DIR/MobyServices/moby.conf:  $!\n";
    while (<IN>){
        chomp; next unless $_; # filter out blank lines
        next if m/^#/;  # filter out comment lines
        last if $_ =~ /\[Namespace_Class_Mappings\]/;
        my @res = shellwords($_);  # parse the tokens key = value1 value2 value3
        $CONFIG->{MOBY}->{$res[0]} = [@res[2..scalar(@res)]];  # add them to the existing config with a new tag MOBY in key = \@values format
    }
    while (<IN>){  # now process the namespace mappings
        chomp; next unless $_; # filter out blank lines
        next if m/^#/;  # filter out comment lines
        my @res = shellwords($_);  # parse the tokens key = value1 value2 value3
        $CONFIG->{'MOBY'}->{'NAMESPACE'}->{$res[0]} = [$res[2]];  # add them to the existing config with a new tag MOBY in key = \@values format
    }
}

sub _doValidationStuff {
    my $authURI = $CONFIG->{'MOBY'}->{'authURI'};
    $authURI = shift(@$authURI); $authURI ||='unknown.org';

    my $reference = $CONFIG->{'MOBY'}->{'Reference'};
    $reference = shift(@$reference); $reference ||='';
    unless ($reference){
        print STDERR "\n\nMobyServices::GbrowseServices - you have not set a reference class in your moby.conf file\n\n";
        return SOAP::Data->type('base64' => responseHeader($authURI) . responseFooter());
    }

    my (@feat_namespaces) = keys %{$CONFIG->{MOBY}->{NAMESPACE}};  
    my @validNS = validateNamespaces($reference,@feat_namespaces);  # ONLY do this if you are intending to be namespace aware!
    unless (scalar(@validNS)){
        print STDERR "\n\nMobyServices::GbrowseServices - namespace $reference does not exist in the MOBY Namespace ontology\n\n";
        return SOAP::Data->type('base64' => responseHeader($authURI) . responseFooter());
    }
    
    return ($authURI, \@validNS);
}

sub GbrowseGetFeatureGFF2 {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                $namespace ||="";
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                # okay, we need to map the MOBY namespace back into our namespace system
                my $Groupname = $CONFIG->{MOBY}->{NAMESPACE}->{$namespace};
                unless ($Groupname){
                    $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                    print STDERR "** MOBY Services error - Trying to map apparently valid namespace: '$namespace' but not found\n";
                    next;
                }
                my @features = $db->get_feature_by_name(-class => $Groupname, -name => $identifier);
                my $gff = "";
                foreach my $feat(@features){
                    (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $feat;
                    $gff .= $feat->gff_string."\n";
                    foreach my $sub($feat->sub_SeqFeature){
                        next unless $sub;
                        $gff .= $sub->gff_string."\n";
                    }
                }   
                $MOBY_RESPONSE .= simpleResponse("<moby:GFF2 moby:namespace='$namespace' moby:id='$identifier'>\n$gff\n</moby:GFF2>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}

sub GbrowseGetFeatureGFF3 {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                $namespace ||="";
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                # okay, we need to map the MOBY namespace back into our namespace system
                my $Groupname = $CONFIG->{MOBY}->{NAMESPACE}->{$namespace};
                unless ($Groupname){
                    $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                    print STDERR "** MOBY Services error - Trying to map apparently valid namespace: '$namespace' but not found\n";
                    next;
                }
                my @features = $db->get_feature_by_name(-class => $Groupname, -name => $identifier);
                my $gff = "";
                foreach my $feat(@features){
                    $feat->version(3); # set to GFF3
                    (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $feat;
                    $gff .= $feat->gff_string."\n";
                    foreach my $sub($feat->sub_SeqFeature){
                        next unless $sub;
                        $sub->version(3);
                        $gff .= $sub->gff_string."\n";
                    }
                }   
                $MOBY_RESPONSE .= simpleResponse("<moby:GFF2 moby:namespace='$namespace' moby:id='$identifier'>\n$gff\n</moby:GFF2>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}

sub GbrowseGetFeatureSequenceObject {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();
    my %types = ('dna', 'DNASequence', 'rna', 'RNASequence', 'protein', 'AminoAcidSequence');

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;  # send empty response for empty input
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);  # get the namespace
                $namespace ||="";
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs}); #invalid namespace treated as empty query
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                # okay, we need to map the MOBY namespace back into our namespace system
                my $Groupname = $CONFIG->{MOBY}->{NAMESPACE}->{$namespace};  # map the namespace to our database group name
                unless ($Groupname){
                    $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;  # if it is invlid, send empty respnse and tell the maintainer that something is goofy!
                    print STDERR "** MOBY Services error - Trying to map apparently valid namespace: '$namespace' but not found\n";
                    next;
                }
                my @features = $db->get_feature_by_name(-class => $Groupname, -name => $identifier);  # get feature from DB
                my $gff = "";
                foreach my $feat(@features){
                    $feat->version(3); # set to GFF3
                    (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $feat;

                    my $seq = $feat->seq;
                    $seq =~ s/\s//g;
                    my $length = $feat->length;
                    my $objtype = $types{$feat->alphabet};
                    (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $objtype;
                    $MOBY_RESPONSE .= simpleResponse("<moby:$objtype moby:namespace='$namespace' moby:id='$identifier'>
                                                 <moby:String namespace='' id=''>$seq</moby:String>
                                                 <moby:Integer namespace='' id=''>$length</moby:Integer>
                                                 </moby:$objtype>", "", $qID);
                }   
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}

sub GbrowseGetReferenceGFF2 {   # DO THIS ONE!!
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $gff = join "\n", map {$_->gff_string} ($seg->get_SeqFeatures);
                $MOBY_RESPONSE .= simpleResponse("<moby:GFF2 moby:namespace='$namespace' moby:id='$identifier'>\n$gff\n</moby:GFF2>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}

sub GbrowseGetReferenceDNASequenceWithFeatures {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $seq = $seg->seq; $seq =~ s/\S//g;
                my $length = $seg->length; # DNASequenceWithGFFFeatures
                my $mobyresp = "<moby:DNASequenceWithGFFFeatures moby:namespace='$namespace' moby:id='$identifier'>
                <moby:String moby:namespace='' moby:id=''>$seq</moby:String>
                <moby:Integer moby:namespace='' moby:id=''>$length</moby:Integer>
                ";
                foreach my $feat($seg->get_SeqFeatures){$mobyresp .="
                    <moby:BasicGFFSequenceFeature namespace='' id=''>
                        <String namespace='' id='' articleName='reference'></String>
                        <String namespace='' id='' articleName='source'></String>
                        <String namespace='' id='' articleName='method'></String>
                        <Integer namespace='' id='' articleName='start'></Integer>
                        <Integer namespace='' id='' articleName='stop'></Integer>
                        <Float namespace='' id='' articleName='score'></Float>
                        <String namespace='' id='' articleName='strand'></String>
                        <String namespace='' id='' articleName='frame'></String>
                        <String namespace='' id='' articleName='phase'></String>"
                        
                }
                my $gff = join "\n", map {$_->gff_string} ($seg->get_SeqFeatures);
                $MOBY_RESPONSE .= simpleResponse("<moby:GFF2 moby:namespace='$namespace' moby:id='$identifier'>\n$gff\n</moby:GFF2>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}

sub GbrowseGetReferenceGFF3 {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $gff = join "\n", map {$_->version(3); $_->gff_string} ($seg->get_SeqFeatures);
                my $seq = $seg->seq;
                $seq =~ s/\s//g;
                $seq =~ s/(\S{70})/$1\n/g;
                my $fasta = ">$identifier\n$seq\n";
                $MOBY_RESPONSE .= simpleResponse("<moby:GFF3 moby:namespace='$namespace' moby:id='$identifier'>\n$gff\n###FASTA\n$fasta\n</moby:GFF3>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}


sub GbrowseGetReferenceFasta {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();

    my $MOBY_RESPONSE;
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));
        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $seq = $seg->seq;
                $seq =~ s/\s//g;
                $seq =~ s/(\S{70})/$1\n/g;
                my $fasta = ">$identifier\n$seq\n";
                $MOBY_RESPONSE .= simpleResponse("<moby:FASTA moby:namespace='$namespace' moby:id='$identifier'>\n$fasta\n</moby:FASTA>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}


sub GbrowseGetReferenceSeqObj {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();
    my %types = ('dna', 'DNASequence', 'rna', 'RNASequence', 'protein', 'AminoAcidSequence');

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));

        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $seq = $seg->seq;
                $seq =~ s/\s//g;
                my $length = $seg->length;
                my $objtype = $types{$seg->alphabet};
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $objtype;
                $MOBY_RESPONSE .= simpleResponse("<moby:$objtype moby:namespace='$namespace' moby:id='$identifier'>
                                                 <moby:String namespace='' id=''>$seq</moby:String>
                                                 <moby:Integer namespace='' id=''>$length</moby:Integer>
                                                 </moby:$objtype>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}


sub GbrowseGetSomeFeatureSequence {
    my ($caller, $data) = @_;
    _settings();
    my ($authURI, $validNSs) = _doValidationStuff();
    my %types = ('dna', 'DNASequence', 'rna', 'RNASequence', 'protein', 'AminoAcidSequence');

    my $MOBY_RESPONSE = "";
    foreach my $source($CONFIG->sources){
        $CONFIG->source($source); # set the current source
        next unless (my $db = $dbh{$source});  # get the database object
        my (@inputs)= genericServiceInputParser($data); # ([SIMPLE, $queryID, $simple],...)
        next unless (scalar(@inputs));

        foreach (@inputs){
            my ($articleType, $qID, $input) = @{$_};
            unless (($articleType == SIMPLE) && ($input)){
                $MOBY_RESPONSE .= simpleResponse("", "", $qID) ;
                next;
            } else {
                my $namespace = getSimpleArticleNamespaceURI($input);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless validateThisNamespace($namespace, @{$validNSs});
                my ($identifier) = getSimpleArticleIDs($input);  # note array output!
                my $seg = $db->segment(-name => $identifier);
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $seg;
                my $seq = $seg->seq;
                $seq =~ s/\s//g;
                my $length = $seg->length;
                my $objtype = $types{$seg->alphabet};
                (($MOBY_RESPONSE .= simpleResponse("", "", $qID)) && next) unless $objtype;
                $MOBY_RESPONSE .= simpleResponse("<moby:$objtype moby:namespace='$namespace' moby:id='$identifier'>
                                                 <moby:String namespace='' id=''>$seq</moby:String>
                                                 <moby:Integer namespace='' id=''>$length</moby:Integer>
                                                 </moby:$objtype>", "", $qID);
            }
        }
    }
    #print STDERR (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter);
    return SOAP::Data->type('base64' => (responseHeader($authURI) . $MOBY_RESPONSE . responseFooter));    
}


1;

#===========================================



