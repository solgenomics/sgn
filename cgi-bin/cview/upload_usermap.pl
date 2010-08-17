require CGI;
print CGI->header( -status => 410 ), #gone
    "cview user map uploads no longer supported";

