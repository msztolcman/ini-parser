#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 30;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $src);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');
ok($parser->parse(), 'parse');

isa_ok($parser->section('section1'), 'Ini::Parser::Section', 'get section1 - filled');
isa_ok($parser->section('section2'), 'Ini::Parser::Section', 'get section2 - empty');

is($parser->section('section1')->get('key1'), 'value1', 'get single line value');
is($parser->section('section1')->get('key2'), "value2\nvalue3", 'get multi line value');

is($parser->section('section3')->get('key3'), "", 'get empty value');

is($parser->section('section4')->get('key4'), "value4", 'get single line value - no space around equal sign, no quotes');
is($parser->section('section4')->get('key5'), "value5", 'get single line value - no space before equal sign, no quotes');
is($parser->section('section4')->get('key6'), "value6", 'get single line value - no space after equal sign, no quotes');

is($parser->section('section4')->get('key7'), "value7", 'get single line value - no space around equal sign, with quotes');
is($parser->section('section4')->get('key8'), "value8", 'get single line value - no space before equal sign, with quotes');
is($parser->section('section4')->get('key9'), "value9", 'get single line value - no space after equal sign, with quotes');

is($parser->section('section with space')->get('key10'), "value10", 'get value from section with space');
is($parser->section('section!with:exclamation and colon and space')->get('key11'), "value11", 'get value from section with space, exclamation and colon');

is($parser->section('section!with:exclamation and colon and space')->get('key12 with=some chars'), 'value12', 'get value from key with space and equal character (in quotes)');

is($parser->section('section7')->get('key14'), 'value1', 'interpolate: single value from other section without quotes');
is($parser->section('section7')->get('key15'), 'value1', 'interpolate: single value from other section with quotes');
is($parser->section('section7')->get('key16'), 'value13', 'interpolate: single value from same section (relative) without quotes');
is($parser->section('section7')->get('key17'), 'value13', 'interpolate: single value from same section (relative) with quotes');
is($parser->section('section7')->get('key18'), 'value13', 'interpolate: single value from same section (absolute) without quotes');
is($parser->section('section7')->get('key19'), 'value13', 'interpolate: single value from same section (absolute) with quotes');
is($parser->section('section7')->get('key20'), 'value24', 'interpolate: single value from same section (relative) without quotes, defined after this key');
is($parser->section('section7')->get('key21'), 'value24', 'interpolate: single value from same section (relative) with quotes, defined after this key');
is($parser->section('section7')->get('key22'), 'value1 value13 value24', 'interpolate: multiple values from different sections without quotes');
is($parser->section('section7')->get('key23'), 'value1 value13 value24', 'interpolate: multiple values from different sections with quotes');

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

