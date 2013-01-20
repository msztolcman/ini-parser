#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 21;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $src);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');
ok($parser->parse(), 'parse');

is_deeply($parser->sections(), [], 'all sections in file');
