#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 27;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $src);
$parser = Ini::Parser->new ({ property_access => 1 });
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');
ok($parser->parse(), 'parse');

isa_ok($parser->section1, 'Ini::Parser::Section', 'get section1 - filled');
isa_ok($parser->section2, 'Ini::Parser::Section', 'get section2 - empty');

is($parser->section1->key1, 'value1', 'get single line value');
is($parser->section1->key2, "value2\nvalue3", 'get multi line value');

is($parser->section3->key3, "", 'get empty value');

is($parser->section4->key4, "value4", 'get single line value - no space around equal sign, no quotes');
is($parser->section4->key5, "value5", 'get single line value - no space before equal sign, no quotes');
is($parser->section4->key6, "value6", 'get single line value - no space after equal sign, no quotes');

is($parser->section4->key7, "value7", 'get single line value - no space around equal sign, with quotes');
is($parser->section4->key8, "value8", 'get single line value - no space before equal sign, with quotes');
is($parser->section4->key9, "value9", 'get single line value - no space after equal sign, with quotes');

is($parser->section7->key14, 'value1', 'interpolate: single value from other section without quotes');
is($parser->section7->key15, 'value1', 'interpolate: single value from other section with quotes');
is($parser->section7->key16, 'value13', 'interpolate: single value from same section (relative) without quotes');
is($parser->section7->key17, 'value13', 'interpolate: single value from same section (relative) with quotes');
is($parser->section7->key18, 'value13', 'interpolate: single value from same section (absolute) without quotes');
is($parser->section7->key19, 'value13', 'interpolate: single value from same section (absolute) with quotes');
is($parser->section7->key20, 'value24', 'interpolate: single value from same section (relative) without quotes, defined after this key');
is($parser->section7->key21, 'value24', 'interpolate: single value from same section (relative) with quotes, defined after this key');
is($parser->section7->key22, 'value1 value13 value24', 'interpolate: multiple values from different sections without quotes');
is($parser->section7->key23, 'value1 value13 value24', 'interpolate: multiple values from different sections with quotes');

try sub {
    $parser->section('nonexistent');
    fail('get non existent section - no exception found');
},
catch_when 'Ini::Parser::Error' => sub {
    if ($_->msg() =~ /unknown section/i) {
        pass('Exception with unknown section correctly raised');
    }
    else {
        fail('Raised unknown exception: ' . $_);
    }
},
catch_default sub {
    fail('Raised unknown exception: ' . $_);
};

