#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $section);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');
ok($parser->parse(), 'parse');

$section = $parser->section('section1');
ok($section, 'section exists');
isa_ok($section, 'Ini::Parser::Section', 'is correct type');

is_deeply([$section->keys()], [qw/key1 key2/], 'section::keys');
is_deeply([$section->values()], ['value1', "value2\nvalue3"], 'section::values');

is_deeply({$section->to_hash()}, { key1 => 'value1', key2 => "value2\nvalue3" }, 'section::to_hash');

