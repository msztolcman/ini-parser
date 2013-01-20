#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

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

my @keys = $section->keys();
my @values = $section->values();
is_deeply(\@keys, [qw/key1 key2/], 'section::keys');
is_deeply(\@values, ['value1', "value2\nvalue3"], 'section::values');

# test for correct order from keys and values
for (my $i = 0; $i < scalar @keys; ++$i) {
    is($section->get($keys[$i]), $values[$i], "Key and value form index $i corresponds to proper values from section data");
}

is_deeply({$section->to_hash()}, { key1 => 'value1', key2 => "value2\nvalue3" }, 'section::to_hash');

