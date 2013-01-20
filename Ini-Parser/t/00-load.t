#!/usr/bin/perl

use Test::More tests => 1;

BEGIN {
    use_ok('Ini::Parser') || print "Bail out!\n";
}

diag("Testing Ini::Parser $Ini::Parser::VERSION, Perl $], $^X");

