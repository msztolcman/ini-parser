Introduction
============

Ini::Parser - simple INI files parser/reader with imports feature!

Syntax
======

```perl
my $parser = Ini::Parser->new();
$parser->feed('filename.ini', { src_type => 'filename' });
$parser->parse();
$parser->to_hash();
my $section = $parser->section('section');
$section->get('key');
$section->keys();
$section->values();
$section->to_hash();
```

Description
===========

This module have many competitors, such as: [Config::Tiny](https://metacpan.org/module/Config::Tiny), [Config::Simple](https://metacpan.org/module/Config::Simple), [Config::General](https://metacpan.org/module/Config::General). They are great, but are missing one key feature: importing other files.
```Ini::Parser``` recognize ```!import``` directive, which is an answer to my needs.

```Ini::Parser``` is able also to interpolate variables (can be disabled in constructor). Syntax:
    ${section.key}
or
    ${key}

There is mandatory dollar sign, and whole expression is surrounded by braces. Expression can be _absolute_ (```section.key``` - ```section``` as section name, ```key``` as key name), or _relative_ (```key``` - just key name from current section).

Main class is ```Ini::Parser```. After feed an instance, and call ```Ini::Parser::parse```, there will be work with another class: ```Ini::Parser::Section```.
The last one you don't instantiate - it's created for you when it's needed (lazy evaluation). It means - when ```Ini::Parser::section``` method is called.

There is yet another class: ```Ini::Parser::Error```. It's an exception class, raised if any problem when using ```Ini::Parser``` is used.

Piece of code
=============

```perl
use strict;
use warnings;

use Data::Dumper;
use HTTP::Tiny;
use Ini::Parser;
use MIME::Base64 qw/encode_base64/;
use Try::Tiny::SmartCatch qw/:all/;

try sub {
    my($auth, $host_cfg, $parser);

    $parser = Ini::Parser->new({ src => 'config.ini', src_type => 'filename' });
    $parser->parse ();
    $auth = $parser->section('auth');
    $host_cfg = $parser->section('host_cfg');

    my(%headers, $http, $request, $url);

    $headers{Authorization} = 'Basic ' . encode_base64($auth->get('login') . ':' . $auth->get('password'))
        if ($auth->get('login') && $auth->get('password'));

    $http = HTTP::Tiny->new();
    $url = 'http://' . $host_cfg->get('host') . $host_cfg->get('uri');
    $request = $http->head($url, { headers => \%headers });

    throw(qq/Cannot access server "$url": [/ . $$request{status} . '] ' . $$request{reason})
        if ($$request{status} != 200);

    print Dumper($$request{headers}), "\n";
},
catch_when 'Ini::Parser::Error' => sub {
    print "Some error occured: $_\n";
    # or:
    # print 'Some error occured: ', $_->code(), ':', $_->message(), "\n";
},
catch_default sub {
    print "Unknown error: $_\n";
};
```

Most interesting here are lines 13-16, 21 and 24 - which show as typical usage of ```Ini::Parser```.

More
====

More info and full documentation is in module. Use ```perldoc Ini::Parser```, or go to [Metacpan: Ini::Parser](https://metacpan.org/module/Ini::Parser).
